#!/usr/bin/env python3
"""Local media providers for OpenMontage Studio.

A tiny stdlib-only HTTP service exposing the local, offline, no-API-key
providers the app reaches over localhost (the same boundary used for the LLM):

  GET  /health               -> {"ok": true, "engine": "macos-say+ffmpeg"}
  POST /tts    {text,voice}   -> writes an AIFF clip, returns {path, bytes, seconds}
  POST /tts/play {path}       -> plays a clip through the speakers (afplay)
  POST /render {scenes}       -> renders a real MP4 (ffmpeg color cards + drawtext
                                 + per-scene `say` narration), returns {path,...}

TTS uses the macOS `say` engine; rendering uses ffmpeg. Run with:
  python3 backend/provider_server.py   (listens on 127.0.0.1:8765)
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = "127.0.0.1"
PORT = 8765
DEFAULT_VOICE = "Samantha"
OUT_DIR = Path(tempfile.gettempdir()) / "openmontage-tts"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# First existing font wins; drawtext needs a concrete file.
FONT = next(
    (
        p
        for p in [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
            "/Library/Fonts/Arial.ttf",
        ]
        if Path(p).exists()
    ),
    "/System/Library/Fonts/Supplemental/Arial.ttf",
)

BG = "0x0F172A"  # studio background
HEADLINE_COLOR = "0xE2E8F0"
SUBTITLE_COLOR = "0x94A3B8"
W, H, FPS = 1920, 1080, 30

_clip_index = 0


def _duration_seconds(path: Path) -> float:
    try:
        out = subprocess.run(
            ["afinfo", str(path)], capture_output=True, text=True, timeout=10
        ).stdout
        match = re.search(r"estimated duration:\s*([\d.]+)", out)
        return round(float(match.group(1)), 2) if match else 0.0
    except Exception:
        return 0.0


def _list_voices() -> list[str]:
    """English `say` voices installed on this Mac, in a curated order so the
    common high-quality ones surface first."""
    try:
        out = subprocess.run(
            ["say", "-v", "?"], capture_output=True, text=True, timeout=10
        ).stdout
    except Exception:
        return [DEFAULT_VOICE]
    names: list[str] = []
    for line in out.splitlines():
        match = re.match(r"^(.*?)\s+([a-z]{2}[-_][A-Z]{2})\s", line)
        if match and match.group(2).startswith("en"):
            names.append(match.group(1).strip())
    if not names:
        return [DEFAULT_VOICE]
    preferred = ["Samantha", "Alex", "Daniel", "Karen", "Moira", "Tessa"]
    ordered = [v for v in preferred if v in names]
    ordered += [v for v in names if v not in ordered]
    return ordered


def _say(text: str, voice: str, out_path: Path) -> None:
    subprocess.run(
        ["say", "-v", voice, "-o", str(out_path), text], check=True, timeout=60
    )


def _synthesize(text: str, voice: str) -> dict:
    global _clip_index
    _clip_index += 1
    out_path = OUT_DIR / f"narration_{_clip_index}.aiff"
    _say(text, voice, out_path)
    return {
        "path": str(out_path),
        "voice": voice,
        "bytes": out_path.stat().st_size,
        "seconds": _duration_seconds(out_path),
    }


def _normalize_hex(value: str | None) -> str:
    if not value:
        return "0x22D3EE"
    value = value.lstrip("#")
    return value if value.startswith("0x") else f"0x{value}"


def _render(scenes: list[dict], voice: str) -> dict:
    work = OUT_DIR / "render"
    work.mkdir(exist_ok=True)
    clip_paths: list[Path] = []
    durations: list[float] = []
    total = 0.0

    for i, sc in enumerate(scenes):
        headline = (sc.get("headline") or sc.get("title") or "").strip()
        subtitle = (sc.get("subtitle") or "").strip()
        seconds = float(sc.get("seconds") or 4)
        accent = _normalize_hex(sc.get("accent"))

        narration = ". ".join(p for p in [headline, subtitle] if p)
        narr_path = work / f"narr_{i}.aiff"
        adur = 0.0
        if narration:
            _say(narration, voice, narr_path)
            adur = _duration_seconds(narr_path)
        duration = max(seconds, adur + 0.3, 1.5)
        total += duration

        # Build a designed scene: vignette for depth, an accent kicker + bar, an
        # animated headline, and a delayed subtitle. Text fades in for motion;
        # the piece fades in on the first scene and out on the last.
        title = (sc.get("title") or "").strip()
        stype = (sc.get("type") or "").strip()
        # Font sizes are tuned for the 1080p canvas.
        if stype == "stat_card":
            hsize = 124
        elif len(headline) > 26:
            hsize = 62
        elif len(headline) > 16:
            hsize = 84
        else:
            hsize = 98
        hcolor = accent if stype == "stat_card" else HEADLINE_COLOR

        filters = ["vignette=PI/4.5"]
        if headline:
            filters.append(
                f"drawbox=x=(iw-96)/2:y={int(H * 0.40)}:w=96:h=6:color={accent}@1:t=fill"
            )
        if title:
            kf = work / f"kick_{i}.txt"
            kf.write_text(title.upper(), encoding="utf-8")
            filters.append(
                f"drawtext=fontfile={FONT}:textfile={kf}:fontcolor={accent}:fontsize=32:"
                f"x=(w-text_w)/2:y={int(H * 0.33)}:alpha='if(lt(t,0.3),t/0.3,1)'"
            )
        if headline:
            hf = work / f"head_{i}.txt"
            hf.write_text(headline, encoding="utf-8")
            filters.append(
                f"drawtext=fontfile={FONT}:textfile={hf}:fontcolor={hcolor}:fontsize={hsize}:"
                f"x=(w-text_w)/2:y={int(H * 0.45)}:alpha='if(lt(t,0.45),t/0.45,1)':"
                f"shadowcolor=black@0.6:shadowx=0:shadowy=3"
            )
        if subtitle:
            sf = work / f"sub_{i}.txt"
            sf.write_text(subtitle, encoding="utf-8")
            filters.append(
                f"drawtext=fontfile={FONT}:textfile={sf}:fontcolor={SUBTITLE_COLOR}:fontsize=44:"
                f"x=(w-text_w)/2:y={int(H * 0.45) + hsize + 30}:"
                f"alpha='if(lt(t,0.35),0,if(lt(t,0.75),(t-0.35)/0.4,1))'"
            )
        if i == 0:
            filters.append("fade=t=in:st=0:d=0.5")
        if i == len(scenes) - 1:
            filters.append(f"fade=t=out:st={max(0.0, duration - 0.6):.2f}:d=0.6")

        # Every clip carries an audio track (real narration or silence) so the
        # cross-fade assembly can treat all clips uniformly.
        clip = work / f"clip_{i}.mp4"
        cmd = [
            "ffmpeg",
            "-hide_banner",
            "-y",
            "-f",
            "lavfi",
            "-i",
            f"color=c={BG}:s={W}x{H}:rate={FPS}:duration={duration}",
        ]
        if narration:
            cmd += ["-i", str(narr_path)]
        else:
            cmd += [
                "-f",
                "lavfi",
                "-i",
                "anullsrc=channel_layout=stereo:sample_rate=44100",
            ]
        if filters:
            cmd += ["-vf", ",".join(filters)]
        cmd += [
            "-map",
            "0:v:0",
            "-map",
            "1:a:0",
            "-c:v",
            "libx264",
            "-crf",
            "20",
            "-preset",
            "medium",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-t",
            f"{duration}",
            str(clip),
        ]
        subprocess.run(cmd, check=True, capture_output=True, timeout=180)
        clip_paths.append(clip)
        durations.append(duration)

    final, final_seconds = _assemble(clip_paths, durations, work)
    return {
        "path": str(final),
        "scenes": len(clip_paths),
        "seconds": round(final_seconds, 2),
        "bytes": final.stat().st_size,
    }


def _assemble(
    clip_paths: list[Path], durations: list[float], work: Path
) -> tuple[Path, float]:
    """Joins per-scene clips with cross-fade transitions (video + audio). Falls
    back to a plain concat if the filter graph fails for any reason, so a render
    never breaks on the transition step."""
    final = work / "render.mp4"
    n = len(clip_paths)
    if n == 1:
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-y", "-i", str(clip_paths[0]),
             "-c", "copy", str(final)],
            check=True, capture_output=True, timeout=120,
        )
        return final, durations[0]

    # Transition length: short enough to fit the briefest clip.
    fade = max(0.1, min(0.5, min(durations) / 2 - 0.05))
    inputs: list[str] = []
    for c in clip_paths:
        inputs += ["-i", str(c)]

    filt: list[str] = []
    prev_v, prev_a = "0:v", "0:a"
    merged = durations[0]
    for i in range(1, n):
        offset = merged - fade
        vout, aout = f"v{i}", f"a{i}"
        filt.append(
            f"[{prev_v}][{i}:v]xfade=transition=fade:"
            f"duration={fade:.3f}:offset={offset:.3f}[{vout}]"
        )
        filt.append(f"[{prev_a}][{i}:a]acrossfade=d={fade:.3f}[{aout}]")
        prev_v, prev_a = vout, aout
        merged = merged + durations[i] - fade

    cmd = (
        ["ffmpeg", "-hide_banner", "-y"]
        + inputs
        + [
            "-filter_complex",
            ";".join(filt),
            "-map",
            f"[{prev_v}]",
            "-map",
            f"[{prev_a}]",
            "-c:v",
            "libx264",
            "-crf",
            "20",
            "-preset",
            "medium",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            str(final),
        ]
    )
    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=300)
        return final, merged
    except subprocess.CalledProcessError:
        # Fallback: hard-cut concat so a render always completes.
        list_file = work / "concat.txt"
        list_file.write_text(
            "".join(f"file '{c}'\n" for c in clip_paths), encoding="utf-8"
        )
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-y", "-f", "concat", "-safe", "0",
             "-i", str(list_file), "-c", "copy", str(final)],
            check=True, capture_output=True, timeout=120,
        )
        return final, sum(durations)


# ---------------------------------------------------------------------------
# Remotion runtime — the cinematic renderer (React motion graphics), the same
# engine the OpenMontage project uses. Maps the scene plan to the Explainer
# composition's props and renders via `npx remotion render`.
# ---------------------------------------------------------------------------


def _composer_dir() -> Path | None:
    """Locate the vendored remotion-composer with installed deps."""
    candidates = [
        Path(__file__).resolve().parent.parent / "remotion-composer",
        Path.cwd() / "remotion-composer",
    ]
    for c in candidates:
        if (c / "node_modules").exists() and (c / "src" / "index.tsx").exists():
            return c
    return None


def _remotion_available() -> bool:
    return bool(shutil.which("npx")) and _composer_dir() is not None


def _chart_data(subtitle: str) -> list[dict] | None:
    """Synthesizes illustrative chart data from a subtitle's label list (e.g.
    "Tokyo · Delhi · Shanghai") so chart scenes animate even without numbers."""
    parts = re.split(r"[·,|/]|\s-\s", subtitle)
    labels = [p.strip() for p in parts if p.strip()]
    if len(labels) < 2:
        return None
    labels = labels[:6]
    n = len(labels)
    return [
        {"label": lab, "value": round(100 * (n - idx) / n)}
        for idx, lab in enumerate(labels)
    ]


def _hex(value: str | None) -> str:
    raw = _normalize_hex(value).replace("0x", "")
    return f"#{raw}"


def _scene_to_cut(i: int, sc: dict, cursor: float, dur: float) -> dict:
    headline = (sc.get("headline") or sc.get("title") or "").strip()
    subtitle = (sc.get("subtitle") or "").strip()
    stype = (sc.get("type") or "text_card").strip()
    cut: dict = {
        "id": f"cut_{i}",
        "source": "",
        "in_seconds": round(cursor, 3),
        "out_seconds": round(cursor + dur, 3),
        "accentColor": _hex(sc.get("accent")),
    }
    if stype == "stat_card":
        cut.update(type="stat_card", stat=headline or "—", subtitle=subtitle)
    elif stype == "hero_title":
        cut.update(type="hero_title", text=headline, heroSubtitle=subtitle)
    elif stype in ("bar_chart", "pie_chart"):
        data = _chart_data(subtitle)
        if data:
            cut.update(
                type=stype, title=headline, chartData=data, showValues=True
            )
        else:
            cut.update(type="text_card", text=headline or subtitle)
    else:
        cut.update(type="text_card", text=headline or subtitle)
    return cut


def _render_remotion(scenes: list[dict], voice: str) -> dict:
    composer = _composer_dir()
    if composer is None:
        raise RuntimeError("Remotion composer not available")
    work = OUT_DIR / "render"
    work.mkdir(exist_ok=True)

    # Pass 1: synthesize per-scene narration and derive durations.
    raws: list[Path | None] = []
    durations: list[float] = []
    for i, sc in enumerate(scenes):
        headline = (sc.get("headline") or sc.get("title") or "").strip()
        subtitle = (sc.get("subtitle") or "").strip()
        seconds = float(sc.get("seconds") or 4)
        narration = ". ".join(p for p in [headline, subtitle] if p)
        adur = 0.0
        raw: Path | None = None
        if narration:
            raw = work / f"rm_narr_{i}.aiff"
            _say(narration, voice, raw)
            adur = _duration_seconds(raw)
        raws.append(raw)
        durations.append(max(seconds, adur + 0.3, 1.5))

    # Build cuts and a single narration track aligned to scene boundaries.
    cuts = []
    segs: list[Path] = []
    cursor = 0.0
    for i, sc in enumerate(scenes):
        cuts.append(_scene_to_cut(i, sc, cursor, durations[i]))
        seg = work / f"rm_seg_{i}.wav"
        if raws[i] is not None:
            subprocess.run(
                ["ffmpeg", "-hide_banner", "-y", "-i", str(raws[i]), "-af",
                 "apad", "-t", f"{durations[i]}", "-ar", "44100", "-ac", "2",
                 str(seg)],
                check=True, capture_output=True, timeout=60,
            )
        else:
            subprocess.run(
                ["ffmpeg", "-hide_banner", "-y", "-f", "lavfi", "-i",
                 "anullsrc=r=44100:cl=stereo", "-t", f"{durations[i]}",
                 str(seg)],
                check=True, capture_output=True, timeout=60,
            )
        segs.append(seg)
        cursor += durations[i]

    # Stage the narration inside the composer's public/ so staticFile() loads it.
    public = composer / "public"
    public.mkdir(exist_ok=True)
    narration_name = "studio_narration.wav"
    lst = work / "rm_concat.txt"
    lst.write_text("".join(f"file '{s}'\n" for s in segs), encoding="utf-8")
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-y", "-f", "concat", "-safe", "0", "-i",
         str(lst), "-c", "copy", str(public / narration_name)],
        check=True, capture_output=True, timeout=120,
    )

    props = {"cuts": cuts, "audio": {"narration": {"src": narration_name}}}
    props_path = work / "rm_props.json"
    props_path.write_text(json.dumps(props), encoding="utf-8")

    final = work / "render.mp4"
    cmd = [
        "npx", "remotion", "render",
        str(composer / "src" / "index.tsx"),
        "Explainer", str(final), "--props", str(props_path),
    ]
    subprocess.run(
        cmd, check=True, capture_output=True, timeout=600, cwd=str(composer)
    )
    return {
        "path": str(final),
        "scenes": len(cuts),
        "seconds": round(cursor, 2),
        "bytes": final.stat().st_size,
        "runtime": "remotion",
    }


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self) -> None:  # noqa: N802 (http.server API)
        if self.path == "/health":
            self._send(
                200, {"ok": True, "engine": "macos-say+ffmpeg", "voice": DEFAULT_VOICE}
            )
        elif self.path == "/voices":
            self._send(200, {"voices": _list_voices()})
        elif self.path == "/runtimes":
            runtimes = ["ffmpeg"]
            if _remotion_available():
                runtimes.append("remotion")
            self._send(200, {"runtimes": runtimes})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802 (http.server API)
        try:
            data = self._read_json()
            if self.path == "/tts":
                text = (data.get("text") or "").strip()
                if not text:
                    return self._send(400, {"error": "text is required"})
                self._send(200, _synthesize(text, data.get("voice") or DEFAULT_VOICE))
            elif self.path == "/tts/play":
                path = data.get("path")
                if not path or not Path(path).exists():
                    return self._send(400, {"error": "valid path is required"})
                subprocess.Popen(["afplay", path])
                self._send(200, {"ok": True})
            elif self.path == "/render":
                scenes = data.get("scenes") or []
                if not scenes:
                    return self._send(400, {"error": "scenes are required"})
                voice = data.get("voice") or DEFAULT_VOICE
                runtime = (data.get("runtime") or "ffmpeg").lower()
                if runtime == "remotion" and _remotion_available():
                    self._send(200, _render_remotion(scenes, voice))
                else:
                    self._send(200, _render(scenes, voice))
            elif self.path == "/open":
                path = data.get("path")
                if not path or not Path(path).exists():
                    return self._send(400, {"error": "valid path is required"})
                subprocess.Popen(["open", path])  # opens in the default player
                self._send(200, {"ok": True})
            elif self.path == "/reveal":
                path = data.get("path")
                if not path or not Path(path).exists():
                    return self._send(400, {"error": "valid path is required"})
                subprocess.Popen(["open", "-R", path])  # selects it in Finder
                self._send(200, {"ok": True})
            else:
                self._send(404, {"error": "not found"})
        except subprocess.CalledProcessError as exc:
            self._send(500, {"error": f"ffmpeg/say failed: {exc}"})
        except Exception as exc:
            self._send(500, {"error": str(exc)})

    def log_message(self, *args) -> None:
        pass


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"OpenMontage providers on http://{HOST}:{PORT} (say + ffmpeg)")
    print(f"Output: {OUT_DIR}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()

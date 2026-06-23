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
W, H, FPS = 1280, 720, 30

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
        if stype == "stat_card":
            hsize = 84
        elif len(headline) > 26:
            hsize = 42
        elif len(headline) > 16:
            hsize = 56
        else:
            hsize = 66
        hcolor = accent if stype == "stat_card" else HEADLINE_COLOR

        filters = ["vignette=PI/4.5"]
        if headline:
            filters.append(
                f"drawbox=x=(iw-64)/2:y={int(H * 0.40)}:w=64:h=4:color={accent}@1:t=fill"
            )
        if title:
            kf = work / f"kick_{i}.txt"
            kf.write_text(title.upper(), encoding="utf-8")
            filters.append(
                f"drawtext=fontfile={FONT}:textfile={kf}:fontcolor={accent}:fontsize=22:"
                f"x=(w-text_w)/2:y={int(H * 0.33)}:alpha='if(lt(t,0.3),t/0.3,1)'"
            )
        if headline:
            hf = work / f"head_{i}.txt"
            hf.write_text(headline, encoding="utf-8")
            filters.append(
                f"drawtext=fontfile={FONT}:textfile={hf}:fontcolor={hcolor}:fontsize={hsize}:"
                f"x=(w-text_w)/2:y={int(H * 0.45)}:alpha='if(lt(t,0.45),t/0.45,1)':"
                f"shadowcolor=black@0.6:shadowx=0:shadowy=2"
            )
        if subtitle:
            sf = work / f"sub_{i}.txt"
            sf.write_text(subtitle, encoding="utf-8")
            filters.append(
                f"drawtext=fontfile={FONT}:textfile={sf}:fontcolor={SUBTITLE_COLOR}:fontsize=30:"
                f"x=(w-text_w)/2:y={int(H * 0.45) + hsize + 22}:"
                f"alpha='if(lt(t,0.35),0,if(lt(t,0.75),(t-0.35)/0.4,1))'"
            )
        if i == 0:
            filters.append("fade=t=in:st=0:d=0.5")
        if i == len(scenes) - 1:
            filters.append(f"fade=t=out:st={max(0.0, duration - 0.6):.2f}:d=0.6")

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
        maps = ["-map", "0:v:0"]
        if narration:
            cmd += ["-i", str(narr_path)]
            maps += ["-map", "1:a:0"]
        if filters:
            cmd += ["-vf", ",".join(filters)]
        cmd += maps + [
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-t",
            f"{duration}",
            str(clip),
        ]
        subprocess.run(cmd, check=True, capture_output=True, timeout=120)
        clip_paths.append(clip)

    list_file = work / "concat.txt"
    list_file.write_text(
        "".join(f"file '{c}'\n" for c in clip_paths), encoding="utf-8"
    )
    final = work / "render.mp4"
    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(list_file),
            "-c",
            "copy",
            str(final),
        ],
        check=True,
        capture_output=True,
        timeout=120,
    )
    return {
        "path": str(final),
        "scenes": len(clip_paths),
        "seconds": round(total, 2),
        "bytes": final.stat().st_size,
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
                self._send(200, _render(scenes, data.get("voice") or DEFAULT_VOICE))
            elif self.path == "/open":
                path = data.get("path")
                if not path or not Path(path).exists():
                    return self._send(400, {"error": "valid path is required"})
                subprocess.Popen(["open", path])  # opens in the default player
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

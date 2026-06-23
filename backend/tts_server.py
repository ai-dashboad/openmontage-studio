#!/usr/bin/env python3
"""Local text-to-speech provider for OpenMontage Studio.

A tiny stdlib-only HTTP service that wraps the macOS `say` engine, so the app
can produce real narration audio over localhost with no install and no API key —
the same "localhost provider" boundary used for the local LLM (Ollama).

Endpoints:
  GET  /health              -> {"ok": true, "engine": "macos-say", "voice": ...}
  POST /tts    {text,voice} -> writes an AIFF clip, returns {path, bytes, seconds}
  POST /tts/play {path}     -> plays a clip through the speakers (afplay)

Run with: python3 backend/tts_server.py  (listens on 127.0.0.1:8765)
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

_clip_index = 0


def _duration_seconds(path: Path) -> float:
    """Reads clip duration from afinfo; returns 0.0 if it can't be parsed."""
    try:
        out = subprocess.run(
            ["afinfo", str(path)], capture_output=True, text=True, timeout=10
        ).stdout
        match = re.search(r"estimated duration:\s*([\d.]+)", out)
        return round(float(match.group(1)), 2) if match else 0.0
    except Exception:
        return 0.0


def _synthesize(text: str, voice: str) -> dict:
    global _clip_index
    _clip_index += 1
    out_path = OUT_DIR / f"narration_{_clip_index}.aiff"
    subprocess.run(
        ["say", "-v", voice, "-o", str(out_path), text],
        check=True,
        timeout=60,
    )
    return {
        "path": str(out_path),
        "voice": voice,
        "bytes": out_path.stat().st_size,
        "seconds": _duration_seconds(out_path),
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
            self._send(200, {"ok": True, "engine": "macos-say", "voice": DEFAULT_VOICE})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802 (http.server API)
        try:
            data = self._read_json()
            if self.path == "/tts":
                text = (data.get("text") or "").strip()
                if not text:
                    return self._send(400, {"error": "text is required"})
                voice = data.get("voice") or DEFAULT_VOICE
                self._send(200, _synthesize(text, voice))
            elif self.path == "/tts/play":
                path = data.get("path")
                if not path or not Path(path).exists():
                    return self._send(400, {"error": "valid path is required"})
                subprocess.Popen(["afplay", path])
                self._send(200, {"ok": True})
            else:
                self._send(404, {"error": "not found"})
        except Exception as exc:  # surface failures as JSON, never crash the loop
            self._send(500, {"error": str(exc)})

    def log_message(self, *args) -> None:  # keep the console quiet
        pass


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"OpenMontage TTS provider on http://{HOST}:{PORT} (engine: macos-say)")
    print(f"Clips: {OUT_DIR}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()

# Handoff

Where the project stands and how to pick it up. Pairs with `README.md`
(overview), `CLAUDE.md` (architecture/commands), and `QA_CHECKLIST.md` (manual
acceptance).

## What this is

A macOS desktop studio (Flutter) for AI-orchestrated video production. You type
a brief, an agent drafts a scene plan, you edit each scene and approve stages,
and the app renders a real MP4 — entirely on-device, free, no API keys.

## Current state

- **Editing loop is real:** edit headline/subtitle/duration/accent/chart-data
  live, agent **Revise**, undo/redo, add/delete/reorder scenes, preview
  playback (cross-fades), dual-track timeline (video + audio).
- **Dual render runtime:** `ffmpeg` (fast designed cards, default) and
  **Remotion** (cinematic motion graphics — the vendored `remotion-composer/`).
  Selectable Fast/Cinematic, persisted per project, with graceful fallback.
- **Charts** are data-driven (editable label/value table → Remotion
  Bar/Pie/Line), not synthesized from text.
- **Projects persist** (scene plan, stage, voice, runtime, render) across
  restarts; Home lists them.
- **Auth:** Cloudflare Worker + D1 + KV. The desktop OAuth handshake uses D1
  (strongly consistent) — fixed the "waiting for the browser" hang.
- **No Python:** the app drives `say`/ffmpeg/`npx remotion` directly from Dart
  (`CommandRunner`), with an augmented PATH so a Finder-launched `.app` finds
  Homebrew tools. Unsandboxed for Developer-ID/`.dmg` distribution.

## How to run / build / test

```bash
flutter run -d macos                 # dev
flutter analyze && flutter test      # 29 widget/unit tests + analyze
RUN_RENDER_SMOKE=1 flutter test test/render_smoke_test.dart  # real renders
scripts/package_macos.sh             # -> dist/OpenMontageStudio-<v>.dmg
```

For the cinematic runtime in dev: `cd remotion-composer && npm install` once.
For the agent: `ollama serve` + `ollama pull qwen2.5`.

## Testability map (what's automated vs not)

| Layer | How | Covers |
| --- | --- | --- |
| Automated (`flutter test`, 29) | always, fast | navigation, home, scene select/edit/undo-redo, add/delete scenes, chart data, preview play/pause, Revise (mock agent), approve→compose, render dialog, narration, persistence roundtrip, auth client, update checker, settings |
| Gated integration (`RUN_RENDER_SMOKE=1`, 2) | real ffmpeg + Remotion | both runtimes produce a valid 1080p MP4 |
| Manual only (`QA_CHECKLIST.md`) | human | real GitHub/Google login, native save dialog, Reveal in Finder, finished-video quality + A/V sync, real email (verify/reset), missing-tool degradation, `.dmg` install on a 2nd Mac |

Anything that crosses into a real browser, an OS dialog, real email, or
subjective audio/video quality is inherently manual — see `QA_CHECKLIST.md`.

## Next steps (need the owner)

1. **Apple Developer ID ($99/yr)** — unblocks code-signing/notarization (no
   Gatekeeper warning) and one-click auto-update (Sparkle). Everything else for
   updates is in place (the in-app banner already detects newer `version.json`).
2. **Bundle Node + composer into the `.dmg`** so the cinematic runtime works
   from a plain install (today a `.dmg` install falls back to Fast unless Node +
   the composer are set up). Feasible but adds ~1 GB — decide if it's worth it.
3. **Rotate** any credentials shared during development (OAuth secrets, Resend
   key, deploy token) as hygiene.

## Repo pointers

- `lib/services/render_client.dart` — both render runtimes (ffmpeg + Remotion).
- `lib/services/command_runner.dart` — how the app spawns local tools.
- `lib/screens/studio_screen.dart` — the editor state (scenes, undo/redo,
  playback, render/export).
- `remotion-composer/src/Explainer.tsx` — the cinematic composition + props.
- `cloudflare/src/index.ts` — auth Worker (D1 OAuth handshake).

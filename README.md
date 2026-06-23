# OpenMontage Studio

A desktop studio for **AI-orchestrated video production**, built with Flutter for
macOS (and, later, the other desktop targets).

OpenMontage Studio treats video creation as a guided pipeline rather than a blank timeline:
an agent proposes a plan, you review and approve each creative stage, and the app
composes the result. The interface is **studio-first** — the preview and a
dual-layer timeline take center stage, the agent conversation docks to the side,
and every stage ends at an explicit approval gate.

> **Status: interactive UI prototype.** This is the layout and interaction shell
> with mock data. It does **not** yet talk to a generation backend, an agent loop,
> or any provider. See [Roadmap](#roadmap).

## The pipeline

Productions move through a fixed set of stages, each emitting one artifact that
becomes the contract for the next:

```
idea → script → scene_plan → assets → edit → compose → publish
```

Creative stages pause for approval; technical stages run through.

## What's here

The main editor:

```
┌──────────────────────────────────────────────────────────────┐
│ Top bar    project · online/offline · Render · budget meter   │
├────┬───────────┬──────────────────────────────┬──────────────┤
│ B  │ Side panel │ Preview stage                │ Inspector     │
│ a  │ agent chat │   selected scene + transport  │ scene props + │
│ il │ or assets  │                              │ approval gate │
├────┴───────────┴──────────────────────────────┴──────────────┤
│ Timeline   stage track (7 stages) + scene strip + playhead    │
├──────────────────────────────────────────────────────────────┤
│ Capability bar   "X of Y configured" per family · runtime      │
└──────────────────────────────────────────────────────────────┘
```

Wired into the core **see → tweak → approve → advance** loop:

- Click a scene block in the timeline → the preview jumps to it and the inspector
  loads its editable properties.
- Scrub the transport → the selected scene follows the playhead.
- The side panel hosts the agent conversation (with an openable artifact card) and
  the asset galleries; the rail toggles between them and collapses the panel.
- **Approve & continue** is the stage checkpoint gate.
- The top bar toggles **online/offline**; the footer shows the capability rollup
  with a `💻` marker on families that work offline.

## Design system

Dark slate base with a single bright accent:

| Token | Value | Use |
| --- | --- | --- |
| Background | `#0F172A` | App base |
| Surface | `#1E293B` | Panels |
| Accent (cyan) | `#22D3EE` | Active state, primary action |
| Accent (purple) | `#A78BFA` | Agent, secondary |
| Approve (green) | `#34D399` | Checkpoint gate, "done" status |
| Awaiting (amber) | `#F59E0B` | Stage awaiting approval |

See `lib/theme/app_theme.dart`.

## Project layout

```
lib/
├── main.dart                  App entry + MaterialApp theme
├── theme/app_theme.dart       Color tokens + dark theme
├── models/studio_models.dart  Stage/Scene/Capability/Chat/Asset models + fixtures
├── screens/                   One file per top-level screen
└── widgets/                   Region widgets (top bar, rail, preview, inspector, …)
```

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) with
macOS desktop support enabled (`flutter config --enable-macos-desktop`).

```bash
flutter pub get
flutter run -d macos      # launch the app
flutter test              # widget tests
flutter analyze           # static analysis
```

## Local agent (live)

The agent chat in the studio is wired to a real **local LLM via
[Ollama](https://ollama.com)** — no API key, fully offline. This is the first
real backend connection: `OllamaClient` talks to `http://localhost:11434`,
which is the "localhost provider" boundary the rest of the engine will follow.

To use it:

```bash
# one-time: install Ollama and pull a model
brew install ollama
ollama serve            # starts the local server on :11434
ollama pull qwen2.5     # ~4.7 GB

# verify the app's client can reach it
dart run tool/agent_smoke.dart
```

With Ollama running, the chat header shows the connected model (e.g.
`qwen2.5:latest`) and messages get real replies. If Ollama is down, the chat
degrades gracefully and the header shows `agent offline`. The macOS sandbox
needs the `com.apple.security.network.client` entitlement (already set) to reach
localhost.

Beyond chat, the agent also produces **structured output**: typing a brief on the
home screen and pressing **Create** asks the local model for a JSON scene plan
(`AgentService.planScenes`), which is parsed into scenes that drive the studio's
timeline, preview, and inspector. If the model is unreachable or the response
isn't usable, the studio opens with the sample plan instead.

## Local media providers (live)

A second localhost service, `backend/provider_server.py` — stdlib-only, wrapping
macOS `say` and ffmpeg — gives the app real narration and real video, offline,
no install, no API key:

```bash
python3 backend/provider_server.py     # listens on 127.0.0.1:8765
```

- **Generate narration** (inspector) synthesizes the selected scene's headline +
  subtitle to an audio clip via `say`, plays it, and reports voice/duration/size.
- **Render** (top bar) composites the whole scene plan into a real **MP4** —
  ffmpeg color cards with the scene text drawn on top, each with its `say`
  narration, concatenated — then offers to play it. A 1280×720 H.264 + AAC file
  on disk, produced entirely locally.

If the provider is down, the studio says how to start it. `TtsClient` and
`RenderClient` are the Dart sides; every provider (LLM, TTS, render) follows the
same `localhost`-endpoint shape, so adding more is uniform.

## Roadmap

1. **Agent tool-calling** — extend structured output from scene plans to the
   rest of the pipeline (edit decisions, asset prompts), with the approval gates
   feeding results back to the agent. (Started: brief → scene_plan.)
2. **Engine bridge** — reach cloud and local generators uniformly over `localhost`
   endpoints, so online/offline is just "which endpoint." (Started: Ollama, TTS,
   render.)
3. **Richer render** — per-scene images/clips and motion instead of color cards.
4. **Packaging** — bundle the render toolchain, download models on demand.

## License

[MIT](LICENSE) © AI Dashboard.

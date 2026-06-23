# Stage: compose

Render the final deliverable — the `render_report` artifact.

## Quality bar

- **Execute the edit decisions exactly.** Compose is not where creative choices
  change; it's where they're realized.
- **Standard profile.** Default to 1280×720 (or 1080p) H.264 video with AAC audio,
  30 fps, unless a platform needs otherwise.
- **Verify the output.** Confirm the file exists, has the expected duration, and
  has audible narration — not a silent track.
- **Report concretely.** Return the output path, duration, and size so the person
  can find and play the result.

The local ffmpeg renderer composes the scene cards, draws the scene text, mixes in
the per-scene narration, and concatenates everything into one MP4 — all offline.

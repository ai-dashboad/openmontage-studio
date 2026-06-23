# Stage: compose

Render the final deliverable — the `render_report` artifact.

## Quality bar

- **Execute the edit decisions exactly.** Compose realizes choices; it does not
  change them. No new creative decisions here.
- **Standard profile.** Default to 1280×720 (or 1080p) H.264 video, AAC audio,
  30 fps, unless a platform needs otherwise.

## Validate before and after (validated — cheap check, expensive miss)

Rendering is the slowest, most expensive step; catching a problem at preview costs
seconds, catching it after a render costs the whole render.

- **Before render:** check that every referenced asset exists, that no scene's
  narration is longer than the scene's window (clipped audio), and that the cut
  timings are valid. If a narration clip overruns, shorten the line or extend the
  scene first.
- **After render:** confirm the file exists, has the expected duration, and has
  **audible** narration — verify the audio track isn't silent, not just present. A
  silent track that "renders fine" is the trap.
- **Report concretely.** Return the output path, duration, and size so the person
  can find and play the result.

The local ffmpeg renderer composes the scene cards, draws the scene text, mixes in
the per-scene narration, and concatenates everything into one MP4 — all offline.

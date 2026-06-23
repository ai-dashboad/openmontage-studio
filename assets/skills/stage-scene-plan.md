# Stage: scene_plan

Turn a brief or script into an ordered list of timed visual scenes — the
`scene_plan` artifact that drives the studio timeline.

## Quality bar

- **Shape**: open with a hook, develop 2–4 content beats, end with a close.
- **Timing**: each scene has a duration; the total lands near the target length
  (default ~20–30s for a short).
- **One idea per scene.** If a scene tries to say two things, split it.
- **Concrete on-screen text.** Every scene has a headline (the main line) and a
  short subtitle. Write them as they should appear, not as a description.
- **Visual variety.** Vary the scene types so the piece doesn't feel flat.

## Scene types

Use one of: `hero_title` (title/hook), `stat_card` (a single number), `bar_chart`
or `pie_chart` (a small comparison), `text_card` (a statement or close).

## Output contract

When asked to produce the plan as data, respond with ONLY a JSON array (no prose,
no markdown fences) of 4–6 objects, each with:

- `title` — short label (e.g. "Hook", "Stat", "Close")
- `type` — one of the scene types above
- `seconds` — number, the scene's duration
- `headline` — the main on-screen line
- `subtitle` — a short supporting line

Start with a `hero_title` hook and end with a `text_card` close.

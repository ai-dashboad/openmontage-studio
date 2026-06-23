# Stage: scene_plan

Turn a brief or script into an ordered list of timed visual scenes — the
`scene_plan` artifact that drives the studio timeline. This is where most videos
are won or lost.

## Quality bar (validated)

- **Earn the first 3 seconds.** Most viewers decide to stay or leave within ~3s.
  Scene 1 is a hook: a concrete image, a surprising number, or a question with
  stakes — never a logo, a title-only card, or a slow build. Put the headline on
  screen immediately.
- **One idea per scene.** If a scene says two things, split it. A script section
  usually needs 2–3 scenes, not one — a single static card over 10s reads as dead
  air.
- **Keep something changing.** Static holds over ~3s feel frozen on a phone. Vary
  the pacing: alternate dense scenes (a stat, a chart) with breathing-room scenes
  (a plain statement).
- **Visual variety.** No more than 3 scenes of the same `type` in a row, and use
  at least 3 different types across the piece. Sameness is the "every AI video
  looks identical" failure.
- **Concrete on-screen text.** Each scene has a headline (the line as it should
  appear) and a short subtitle. Write the words, not a description of them. Replace
  mood adjectives with the actual content ("8.1 billion people", not "an
  impactful stat").
- **Fit the narration.** Each scene's spoken line should fit its duration at
  ~2.0–2.5 words/second (calmer) up to ~3.0 (energetic). A 4s scene ≈ 8–12 words.
  Aim for narration to fill ~85–90% of each scene so lines never get clipped and
  there's a breath at the open and close.
- **Exact text → text card.** If a scene must show precise words (a name, a
  number, a call to action), keep it a `text_card`; never hand exact text to an
  image generator, which will misspell it.
- **Cover the whole video.** Scenes run start to finish with no unexplained gaps;
  the durations sum to the target length (default ~20–30s for a short).

## Scene types

`hero_title` (title/hook), `stat_card` (a single number), `bar_chart` /
`pie_chart` (a small comparison), `text_card` (a statement or close).

## Output contract

When asked to produce the plan as data, respond with ONLY a JSON array (no prose,
no markdown fences) of 4–6 objects, each with:

- `title` — short label (e.g. "Hook", "Stat", "Close")
- `type` — one of the scene types above
- `seconds` — number, the scene's duration
- `headline` — the main on-screen line
- `subtitle` — a short supporting line

Open with a `hero_title` hook and end with a `text_card` close.

# Stage: assets

Decide what each scene needs generated — the `asset_manifest` artifact.

## Quality bar

- **One pass per scene.** For each scene, name what it needs: narration, a
  background, a chart, an image, or nothing beyond its text card.
- **Prefer the cheapest path that meets the bar.** A text card on a color field
  costs nothing; an AI image or clip costs time and money. Justify the spend.
- **Record provenance.** For every generated asset, keep the provider, the seed,
  and the cost, so a result can be reproduced or explained.
- **Reuse.** If two scenes can share a background or a voice, share it.

Narration runs on the local TTS provider; it's free and offline. Lean on it before
reaching for paid generation.

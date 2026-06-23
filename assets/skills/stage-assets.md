# Stage: assets

Decide what each scene needs generated — the `asset_manifest` artifact.

## Quality bar

- **One pass per scene.** Name what each scene needs: narration, a background, a
  chart, an image, or nothing beyond its text card.
- **Cheapest path that meets the bar.** A text card on a color field costs nothing;
  an AI image or clip costs time and money. Justify the spend.
- **Record provenance.** For every generated asset keep the provider, the seed, and
  the cost, so a result can be reproduced or explained.

## Hard-won rules

- **Sample before you batch.** Generate ONE asset of each kind first — one
  narration line, one image in the chosen style — and confirm it before producing
  the rest. A bad voice or style replicated across ten scenes is wasted money found
  too late. A few cents up front saves dollars of regeneration.
- **Never AI-generate text that must be exact.** Image and video models reliably
  misspell names, numbers, and CTAs. Any scene whose text must be verbatim stays a
  `text_card` rendered natively — don't send it to a generator.
- **Vary the consistency anchor.** Keep the same character/world/palette across
  scenes, but rewrite the prompt for *this* scene's subject and action. Pasting one
  style prefix into every prompt makes the video feel machine-stamped.
- **Check narration length against its slot.** After TTS, compare the clip's real
  duration to the scene's window (the local provider returns it). If it overruns by
  more than ~15%, trim the line and regenerate before moving on — don't push the
  problem into the edit.
- **Surface music early.** Decide the music source at proposal time (a track the
  person provides, a generator, or none) and say which. A missing music source
  discovered at this stage is an expensive surprise.

## Generation prompts (when you do generate)

When prompting an image/video model, specify all five aspects — omitting any is the
top cause of off-target results: **subject** (and how to tell it apart),
**subject motion**, **scene** (setting, overlays listed separately from depth),
**spatial framing** (shot size, position, foreground/background), and **camera**
(angle, movement, focus). For recurring characters, repeat the same few
disambiguating attributes verbatim in every shot — pronouns and "the same
character" don't survive a cut. Mark any aspect that's deliberately N/A rather than
leaving it silent.

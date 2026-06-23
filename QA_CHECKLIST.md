# Manual QA Checklist

A human acceptance pass for the things automated tests can't cover: real
third-party login, the native save dialog, finished-video quality, and
graceful degradation on a machine that's missing tools. Run this before
tagging a release.

Automated coverage (already green, not repeated here): `flutter analyze`,
`flutter test` (27 widget/unit tests), and the gated real-render checks
(`RUN_RENDER_SMOKE=1 flutter test test/render_smoke_test.dart`).

## Prerequisites

- [ ] Build & launch the app: `flutter run -d macos` (dev), or open the
      packaged `.app`/`.dmg`.
- [ ] **Agent (optional):** `ollama serve` running with a model pulled
      (`ollama pull qwen2.5`). Without it, the agent chat and Revise degrade
      gracefully — verify that path in Section E.
- [ ] **Media tools:** `ffmpeg` on PATH (Fast render + all narration) and,
      for the cinematic runtime, `node`/`npx` plus the installed
      `remotion-composer/` (run `npm install` in it once).
- [ ] Note the test build is unsigned — first launch may need
      right-click → Open to pass Gatekeeper.

## A. Authentication (human-only: real OAuth round-trip)

- [ ] **Email/password sign-up:** create an account → lands in the app; a
      verification email arrives (check inbox).
- [ ] **Email verification:** click the emailed link → app/account shows
      verified on next load.
- [ ] **Sign out / sign in** with the same credentials → returns to the app.
- [ ] **Session restore:** quit and relaunch → opens straight to Home (no
      re-login).
- [ ] **GitHub login:** "Continue with GitHub" → browser → authorize → the
      app leaves "Waiting for the browser…" and enters Home within a few
      seconds (this is the KV→D1 fix; it must not hang).
- [ ] **Google login:** same, with a Google account.
- [ ] **Forgot password:** request reset → email arrives → set a new password
      → sign in with it.
- [ ] **Change password** (Settings) → sign out → sign in with the new one.
- [ ] **Delete account** (Settings) → confirm → returns to sign-in; the
      account no longer logs in.

## B. Studio core loop

- [ ] **Brief → plan:** type a brief on Home → Create → studio opens with a
      generated scene plan (or the sample if the agent is offline).
- [ ] **Continuity:** the brief appears as the first message in the side
      panel's agent chat.
- [ ] **Select a scene** in the timeline → preview + inspector update to it.
- [ ] **Edit** headline/subtitle (text), duration (− / +), accent (swatches)
      → preview updates live.
- [ ] **Undo / Redo** revert and reapply the edits.
- [ ] **Revise with agent:** enter an instruction → the selected scene's
      headline/subtitle update, and a line is posted to the chat.
- [ ] **Add / Delete / Move** scenes (inspector ◀ ▶ ＋ 🗑) → timeline + count
      update; duration re-flows.
- [ ] **Play / Pause** in the preview transport → the playhead advances and
      cross-fades between scenes; scrubbing pauses.
- [ ] **Approve & continue** through the stages → each posts a visible
      artifact to the chat (not just a toast); the stage track advances.

## C. Render, export, and recents

- [ ] **Fast render (ffmpeg):** runtime = Fast → Render → an MP4 is produced;
      Play opens it; it looks like the designed cards with cross-fades.
- [ ] **Cinematic render (Remotion):** runtime = Cinematic (shown only when
      available) → Render → the MP4 has real motion graphics (animated
      hero/stat/bar-chart) and narration; **watch it end-to-end** and confirm
      audio/video stay in sync.
- [ ] **Save a copy:** the native save dialog opens → choose a location →
      the file is written there and plays.
- [ ] **Reveal:** opens Finder with the file selected.
- [ ] **Recents:** the project appears under "Your projects" with a ▶ that
      plays the render.

## D. Persistence

- [ ] Make edits, then go Home and reopen the project → edits are intact.
- [ ] Quit the app entirely, relaunch, reopen the project → edits, stage,
      chosen voice, and chosen runtime all persisted.

## E. Status & graceful degradation

- [ ] **Agent offline:** stop Ollama → the chat header shows "agent offline";
      sending a message and Revise show a friendly hint, no crash.
- [ ] **Media tools present:** Home "Local engine" shows Agent + Voice +
      Render; the top-bar status lights match reality.
- [ ] **ffmpeg missing** (rename/hide it, or test on a clean machine):
      Render surfaces a clear "install ffmpeg" message rather than hanging.
- [ ] **Remotion unavailable** (no `node`/composer): the Cinematic option is
      hidden and Fast still works — no error.

## F. Distribution

- [ ] `scripts/package_macos.sh` produces `dist/OpenMontageStudio-<v>.dmg`.
- [ ] Install from the `.dmg` on a second Mac (or a fresh user account):
      drag to Applications, launch, sign in, run a Fast render.
- [ ] Confirm the in-app update banner appears when `version.json` advertises
      a newer version.

## Known limitations to confirm, not fix

- [ ] Cinematic (Remotion) needs Node + the composer present; a plain `.dmg`
      install falls back to Fast unless those are set up.
- [ ] The app is unsigned/unnotarized until an Apple Developer ID is
      configured (Gatekeeper warning on first open).
- [ ] Chart scenes use illustrative values synthesized from the subtitle —
      there is no numeric data model yet.

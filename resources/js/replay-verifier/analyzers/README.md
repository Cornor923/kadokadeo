# Analyzers of the moves (replay verifier)

ANTI CHEAT: a run played with help (a script of the page showing the best move) has a legit replay: its score is
right. An analyzer of the game looks at the moves of the replay while `verify.mjs` plays it, and says whether they
look like the moves of a player or of a solver. Its result goes to `replay_verifications.analysis` and, when
`kado.replay_analysis.flag` is on, in the queue of the suspicious runs of the admin (App\Services\SuspicionService).

One file by game, `<game_key>.mjs` (the game has none: no analysis), its own modules in `<game_key>/` (pure functions:
tested with `node --test`). It runs in the page of the verifier, served at `/__analyzers/`:

```js
export const meta = { game: 'binary', version: 1 }
// once the replay is playing; config: config('kado.replay_analysis.games.<game_key>')
export function create({ kk, config }) {
  return {
    beforeFrame(frame) {},              // before each frame (kk.updatePhysics); frame = kk.replay.getCurrentFrame()
    finish({ score, frames }) {         // after the end screen
      return { metrics: {}, suspicious: false, reasons: [] }
    },
  }
}
```

Rules:
- Read only: read the fields of the game (`kk.game`, `kk.replay.playFrames` / `playRecords`...), never call its methods
  (nor `Seed`): the replay must play exactly as without the analyzer. Copy the arrays of the game before working on them.
- An error (thrown by `create`, `beforeFrame` or `finish`) ends the analysis (`{ analyzer, error }`), never the
  verification. A version of the game whose fields differ (archived builds): throw `unsupported build`.
- `reasons` are in French: the admin shows them as they are.
- The thresholds come from the config (`config/kado.php`, `replay_analysis.games`), calibrated with
  `php artisan kado:replays:analyze <game>` before `KADO_REPLAY_ANALYSIS_FLAG` is turned on.

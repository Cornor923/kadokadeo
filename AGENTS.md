# AGENTS.md

## Fast Start (avoid destructive mistakes)

- Use `make` only for first-time setup: it copies `.env.example` -> `.env`, `compose.override.yaml.example` -> `compose.override.yaml`, `eternaltwin/etwin.toml.example` -> `eternaltwin/etwin.toml`, regenerates RSA keys, and runs `migrate:fresh --seed`.
- For normal day-to-day work, use `make docker-start` / `make docker-watch` and avoid re-running `make` unless you want setup/reset behavior.
- `make compile-games` requires running containers (`kadokadeo_app` and `kadokadeo_front`) because it uses `docker exec`.

## Repo Shape

- Main app is Laravel + Vue in this root.
- `resources/hx/` = Haxe game sources; `resources/js/games/*.js` = Haxe-generated JS intermediates (tracked); `public/gamesdata/*` = bundled runtime artifacts + `manifest.json`.
- `eternaltwin/` is a separate local service package used by Docker (`yarn etwin`). Treat it as its own boundary.

## Build and Verification Commands

- Frontend dev: `npm run dev`.
- Frontend lint/format (JS/Vue only): `npm run lint`, `npm run format` (operate on `resources/js`).
- Production build: `npm run build` (installs Haxe libs, compiles all games, bundles games, then Vite build).
- Game bundle only: `make compile-games`.
- Backend tests: `docker exec kadokadeo_app php artisan test` (configured for SQLite in-memory via `phpunit.xml`).
- DB sync/reset in Docker context: `make sync-database`, `make reset-database`.

## Game Pipeline Gotchas

- Do not hand-edit generated files in `resources/js/games/*.js` or `public/gamesdata/*.js`; edit Haxe in `resources/hx/games/*` then rebuild.
- Add/remove a game in both `compile.hxml` and `compile-dev.hxml`.
- `resources/js/games/build-games.mjs` bundles **every** non-`tmp*.js` file in `resources/js/games`; stale JS files are still shipped unless removed.
- `build-games.mjs` also archives the previous version of every bundle that changed in `storage/app/game-builds` (replays are played by the version they were recorded with, see `.opencode/skills/replay-system/SKILL.md`): never delete that folder; `GAME_BUILDS=off` skips it. Currently off on the Laravel side (`KADO_GAME_BUILDS_ENABLED`, the production wipes `storage/` at each deploy): runs remember no version, replays use the current bundle.
- Bundles are minified ES modules that do **not** put the game classes on `window`: `resources/js/games/builds/bundle.mjs` gives them once through the default export (`format: 'esm'` in `manifest.json` / the archive, `gamedata.module`); `useGame.js` imports the bundle with a random URL fragment (a module of its own). Archived bundles built before (classic scripts) still put their classes on `window`. Source maps go to `storage/app/game-sourcemaps` (not public).
- Anti-cheat (client): outside the daily game the gameplay RNG is stirred every frame by the frame, the inputs and the time of each input in its frame (`Seed.stir`, replay v4 « phases », see `.opencode/skills/determinism/SKILL.md`); input events made by a script (`isTrusted` false) are ignored (`kac.Natives`, browser functions snapshotted at page load by `resources/js/anticheat/natives.js`). In a live game `kac.Integrity` freezes the prototypes of the Haxe classes (methods the game assigns to instances, found by the bundler, become accessors; emergency switch: Haxe define `-D kado_no_freeze`) and reports what a page script did in the `ac` mask (`App\Enums\AntiCheatBit`: hard bits mark the run as cheated, soft bits `kado.anticheat.soft_bits` go to the admin queue, ignored bits `kado.anticheat.ignored_bits` (default: browser functions replaced, untrusted inputs, frequent on mobile) are only kept on the run).
- Anti-cheat (server): every finished run is evaluated by `App\Services\SuspicionService` (new record of the game, replay longer than the real time, soft `ac` bits; a high score alone is not flagged) into the admin queue « Modération > Runs suspectes » (`run_flags`, nothing sanctioned automatically). Per-game move analyzers run inside the replay verifier: `resources/js/replay-verifier/analyzers/<game_key>.mjs` (see its README: Binary, Kaskade 2; new analyzer: `.opencode/skills/replay-analyzer/SKILL.md`), thresholds in `kado.replay_analysis`, calibration with `php artisan kado:replays:analyze <game>` before `KADO_REPLAY_ANALYSIS_FLAG`. The replays of the runs that count are replayed on the server (`App\Jobs\VerifyRunReplay`, `resources/js/replay-verifier/verify.mjs`: Node 22+ and Chrome, `KADO_REPLAY_VERIFIER*` in `config/kado.php`). Without a system Chrome/Chromium, `browser.mjs` downloads chrome-headless-shell (`@puppeteer/browsers`) into `storage/app/replay-verifier/browser`; it still needs Chrome's system libraries and a font. Admin page « Paramètres > Vérificateur de replays »: stats and history of the verifications (`replay_verifications`, the verified ones pruned after 30 days), replays in a modal (`RunReplayController`, Vite entry `resources/js/replay-player.js`), diagnostic of a server (`check.mjs`).
- Runtime game loading depends on DB game name -> `game_key` mapping (`App\Models\Game::getGameKeyAttribute`), so filenames must match sanitized lowercase game names (e.g. `Opalus 2` -> `opalus2.js`).

## Backend/API Conventions That Matter

- API auth is enforced per-controller with `HasMiddleware`/`Middleware` (not one global auth group in `routes/api.php`).
- Run submission crypto depends on RSA key files from `config/kado.php` (`KADO_RSA_PRIVATE_KEY_PATH`, `KADO_RSA_PUBLIC_KEY_PATH`).
- Public RSA key is injected into `window.Kado.public_key` in `resources/views/layouts/default.blade.php`; game clients use it to encrypt run payloads.
- Admin panel (Filament, `/admin`) UI must be in **French**: every user-facing string in `app/Filament/`, `app/Livewire/` admin widgets and `resources/views/filament/` (labels, headings, notifications, options, tabs). Always set an explicit French `->label()` on fields/columns (Filament otherwise derives English labels from column names) and `$modelLabel`/`$pluralModelLabel` on resources. Code identifiers stay in English.
- Forum of the site = the forum of Eternaltwin (category `ETERNALTWIN_FORUM_CATEGORY`, `/forum`): called server-side through `App\Http\Controllers\Api\EtwinForumController` (Eternaltwin sends no CORS headers) with the player's Eternaltwin token stored at login (`users.etwin_access_token`, encrypted; scope `ETERNALTWIN_SCOPE`, `forum:write` only once the app is allowed it on Eternaltwin or the login is refused). Posts come as HTML rendered by Eternaltwin; the editor previews with the grammar it serves (`section.self.grammar`), icons in `public/gfx/forum/etwin`. Local Eternaltwin = upstream `main` built by `docker/eternaltwin/Dockerfile` (`ETERNALTWIN_REF` in compose.yaml, DB `etwin_main.dev`).
- Scheduled commands are defined in `routes/console.php` and executed by container cron (`docker/app/conf/crontab` runs `artisan schedule:run` every minute).
- Clan forum (`App\Services\ClanForumService`, `/api/clans/{clan}/forum`) and private messages (`App\Services\MessageService`): texts are stored as raw Marktwin and rendered client-side only (`resources/js/marktwin/render.js`: `useMarktwin` on the site, `<kado-marktwin text>` in the admin via `resources/js/admin/marktwin.js` loaded by a Filament render hook; grammar in `resources/js/marktwin/grammar.js`). Admin « Modération > Messages privés »: every message, and the system messages (signed KadoKado) to a player or to all. The `@eternaltwin/marktwin` 0.6.0 WASM panics (and corrupts its memory) on non-ASCII input: `useMarktwin` sends it ASCII only (entities put back after). It is loaded through `vite-plugin-wasm`, whose dev helper `/__vite-plugin-wasm-helper` must be proxied to Vite (`docker/app/conf/kadokadeo.conf`).

## Existing Agent Guidance

- Keep `CLAUDE.md` as the companion high-level map; this file is the short, high-signal checklist.
- For Flash-to-Haxe porting or replay/scale/determinism tasks, check `.opencode/skills/*/SKILL.md` before changing game code.
- Porting a KadoKado Flash game (or redoing / fixing a port): start with `.opencode/skills/flash-port/SKILL.md` (method, tools in `scripts/`, K-Slash walkthrough). The `scale` skill is legacy: new ports scale the root container x2.

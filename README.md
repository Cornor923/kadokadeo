# Summary

- Kadokadeo
    - [Configuration](#configuration)
    - [Project commands](#project-commands)
    - [Updating games](#installing--updating-games)
    - [Installing with Docker](#installing-with-docker)
        - [Windows Users](#windows-users)
        - [Install build tools and Docker](#install-build-tools-and-docker)
        - [Install the project](#install-the-project)
        - [Troubleshooting](#troubleshooting)
    - [Some useful commands](#some-useful-commands)

# Kadokadéo

## Configuration

Go to [Install the project](#install-the-project) if you need to install the project first.

Here are the configuration variables specific to the project (the standard Laravel ones, `APP_*`, `DB_*`, `QUEUE_*`..., are not listed). Most of the `KADO_*` ones are read in [`config/kado.php`](config/kado.php), whose comments give more details. They only hold what depends on the server (paths, binaries, queues): the settings of the site (games per day, anti-cheat, replays, clans...) are in the `settings` table (`App\Settings\*`, [spatie/laravel-settings](https://github.com/spatie/laravel-settings)), changed in the admin, « Paramètres », with their default values in [`database/settings`](database/settings).

### Settings of the admin

| Page                      | Class                           | What                                                                                       |
| ------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------ |
| « Paramètres > Site »       | `App\Settings\SiteSettings`      | Announcement, games per day (`-1`: unlimited), games in parallel, achievements, versions of the games for the replays, prices of the themes, Poids plume |
| « Paramètres > Anti-triche » | `App\Settings\AntiCheatSettings` | What the replays must hold, the detections of the game (marked as cheated / to examine / ignored), the queue « Runs suspectes », the replay verifier, the analyzers of the moves and their thresholds by game |
| « Paramètres > Replays »    | `App\Settings\ReplaySettings`    | Comments, views, longest replay accepted                                                    |
| « Paramètres > Clans »      | `App\Settings\ClanSettings`      | All the rules of the clans (see [Clans](#clans))                                            |

The settings that were variables of the env until 2026-10 (`KADO_GAMES_PER_DAY`, `KADO_REPLAY_VERIFIER`...) take their first value from them when their migration runs (`kado.legacy` in [`config/kado.php`](config/kado.php)); then the variables can be removed.

### General

| Variable                    | Description                                                                         | Default                 |
| --------------------------- | ----------------------------------------------------------------------------------- | ----------------------- |
| `SELF_URL`                  | Public URL of the site (Laravel `app.url`)                                          | `http://localhost`      |
| `KADO_GAME_BUILDS_PATH`     | Folder of the archive of the old game bundles (written by `build-games.mjs`, used once « Paramètres > Site » turns the versions of the games on: off for now, the production wipes `storage/` at each deploy) | `storage/app/game-builds` |
| `KADO_DEBUG_TOOLS`          | Tools to try the clans alone (`/clans/debug`), never in production                  | `false`                 |

### Themes

The players can change the look of the site in « Mon compte »: the KadoKado theme for everyone, the Karbon theme (the second theme of KadoKado, `resources/css/themes/karbon.css`, images in `public/gfx/themes/karbon`) bought once with Kado points (`kado.themes` in [`config/kado.php`](config/kado.php), its price in « Paramètres > Site »).

### Clans

The tournament of the clans lasts a period (`App\Services\ClanService`), with two rankings at the same time as on KadoKado since 2011: the attacks (the score of a run becomes an attack, the attacked clan has some hours to beat it) and the missions (a series of games to complete in a given time, more games in a bigger clan, harder scores with each mission: a completed mission gives points and opens the next one, a mission not finished in time loses a point by game not completed, minus one). Clan runs of missions are free, attacks and defenses have their own free games each day (given again by `kado:reset-daily-games`), then a paid clan game (bought by packs with Kado points, which their owner uses or gives to his clan, distributed by the leader and the right hands). The scores, the missions and the options start again from 0 on the first day of the next period (the clans and their members stay). It is closed with the period by `kado:prepare-new-period`, and `kado:clans:resolve-attacks` (scheduled every 5 minutes) gives their points to the attacks not repelled in time.

All the rules (durations, points, steps, options, packs of paid games, rewards...) are settings of `App\Settings\ClanSettings` changed in the admin, « Paramètres > Clans », with their default values in [`database/settings`](database/settings). The help page shows them as they are set (`GET /api/clans/overview`, `rules`).

### Security and anti-cheat

| Variable                    | Description                                                                         | Default                           |
| --------------------------- | ----------------------------------------------------------------------------------- | --------------------------------- |
| `KADO_RSA_PRIVATE_KEY_PATH` | Private RSA key path of the server. Should be kept **private**.                     | `storage/app/private/privkey.pem` |
| `KADO_RSA_PUBLIC_KEY_PATH`  | Public key path associated with the private key                                     | `storage/app/private/pubkey.pem`  |

The rest of the anti-cheat is set in « Paramètres > Anti-triche »: a replay outside the daily game must have its RNG stirred by the frames and inputs, and the time of the inputs in their frame (replay v4), otherwise the run is marked as cheated (turn them on a day or two after deploying the games that record them); the bits of the client mask (`App\Enums\AntiCheatBit`) that only send the run to the queue « Runs suspectes » or are ignored; the evaluation of every finished run for that queue (`App\Services\SuspicionService`, nothing is sanctioned automatically).

### Replay verifier

The replays of the runs that count (personal best, contract, daily game, clan) are played again on the server in a headless Chrome (`App\Jobs\VerifyRunReplay`, needs Node 22+ and Chrome or its system libraries). It is turned on, with its timeout and the games whose replays are not trusted, in « Paramètres > Anti-triche ».

| Variable                               | Description                                                                         | Default                         |
| -------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------- |
| `KADO_REPLAY_VERIFIER_NODE`            | Node binary used to run `resources/js/replay-verifier/verify.mjs`                  | `node`                          |
| `KADO_REPLAY_VERIFIER_BROWSER`         | Path of Chrome / Chromium. Empty: looked for at the usual places, then a chrome-headless-shell is downloaded | (auto)  |
| `KADO_VERIFIER_CACHE`                  | Cache folder of the Node scripts (PIXI, downloaded browser)                         | `storage/app/replay-verifier`   |

### Replay analysis

Per-game analyzers of the moves (`resources/js/replay-verifier/analyzers/<game_key>.mjs`), run by the replay verifier. Turned on, with their thresholds by game, in « Paramètres > Anti-triche » (« Analyse des coups »). Calibrate the thresholds with `php artisan kado:replays:analyze <game>` before turning on « Signaler les parties suspectes ».

| Variable                           | Description                                                                         | Default   |
| ---------------------------------- | ----------------------------------------------------------------------------------- | --------- |
| `KADO_REPLAY_ANALYSIS_QUEUE`       | Queue of these analysis jobs                                                        | `default` |

### External services

| Variable                    | Description                                         | Default                             |
| --------------------------- | --------------------------------------------------- | ----------------------------------- |
| `ETERNALTWIN_URL`           | URL of Eternaltwin (OAuth login)                    | `https://eternaltwin.com/`          |
| `ETERNALTWIN_CLIENT_ID`     | OAuth client id of the site on Eternaltwin          |                                     |
| `ETERNALTWIN_CLIENT_SECRET` | OAuth client secret                                 |                                     |
| `ETERNALTWIN_PUBLIC_URL`    | URL of Eternaltwin for the browser (embedded forum) | `ETERNALTWIN_URL`                   |
| `ETERNALTWIN_SCOPE`         | Scope asked at the login (`forum:read forum:write`) | `base`                              |
| `ETERNALTWIN_FORUM_CATEGORY`| Groupement the forum of the site opens on           | `kadokadeo`                         |
| `DISCORD_WEBHOOK`           | Webhook url for error reporting                     |                                     |
| `DISCORD_SCORE`             | Webhook url for daily score recap                   |                                     |
| `DISCORD_ALERT_QUEUE`       | Queue of the Discord messages                       | `default`                           |

### Build

Read by `npm run build` / `make compile-games`, not by Laravel.

| Variable      | Description                                                                              | Default |
| ------------- | ---------------------------------------------------------------------------------------- | ------- |
| `GAME_BUILDS` | `off`: the build does not archive the previous version of the game bundles               | (on)    |

You can generate keys with :

```bash
openssl genrsa -out keypair.pem
openssl rsa -in keypair.pem -pubout -out public.pem
```

## Project commands

> [!NOTE]
> All the below commands are meant to be ran on docker, with :
>
> `docker exec -u dev -it kadokadeo_app php artisan`
>
> Example: `docker exec -u dev -it kadokadeo_app php artisan migrate`

| Command                                          | Description                                                                                                                                                          | Ran in CRON                                                    |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `migrate`                                        | Synchronises the database                                                                                                                                            | ❌                                                             |
| `kado:prepare-new-period`                        | Close current period and begin a new one.                                                                                                                            | ✅ Every week on monday, but it still makes periods of 2 weeks |
| `kado:reset-daily-games`                         | Resets the daily games for every user to the configured value (« Paramètres > Site »)                                                                                 | ✅ Everyday at 00:00                                           |
| `kado:prepare-daily-game`                        | Picks the daily game of today (a random active game, its seed and contract). Does nothing if it already exists                                                       | ✅ Everyday at 00:00                                           |
| `kado:game-builds:keep`                          | Lists the game versions still used by replays in `storage/app/game-builds/keep.json`: the next build removes the others (see « Paramètres > Site »)              | ✅ Everyday at 00:00                                           |
| `model:prune --model="App\Models\ReplayVerification"` | Removes the replay verifications that went well after 30 days                                                                                                 | ✅ Everyday at 00:00                                           |
| `kado:replays:analyze {game}`                    | Runs the move analyzer of a game on the replays of its runs and shows its metrics, to calibrate the thresholds (nothing is stored). Options: `--since=`, `--limit=50`, `--user=` | ❌                                                             |
| `kado:clean-old-runs`                            | Deletes for good the runs older than two months without a score                                                                                                       | ❌ (disabled in `routes/console.php`)                          |
| `kado:reset-scores {gameId?}`                    | ⚠️ Soft-deletes the runs of every game, or of one game, and erases their replays                                                                                                | ❌                                                             |
| `kado:worker`                                    | The only worker of the production: runs `queue:work` and `reverb:start` as children and starts again the one that stops. Options: `--queue-args=`, `--reverb-args=` | ❌ (a systemd service)                                         |

The schedule is defined in [`routes/console.php`](routes/console.php) and run by the cron of the app container ([`docker/app/conf/crontab`](docker/app/conf/crontab): `artisan schedule:run` every minute). Times are in UTC.

## Installing / Updating games

To update/compile every game (resources/hx):

```
make compile-games
```

## Installing with Docker

### Install the project

Everything in one copy/paste :

```bash
git clone git@gitlab.com:eternaltwin/kadokadeo/kadokadeo.git
cd kadokadeo
git checkout main
make
```

If everything goes well you should be able to access to :

- KadoKadéo on http://kadokadeo.localhost/
- Eternaltwin on http://localhost:50320

> [!WARNING]  
> When logging in for the first time, you should create a local EternalTwin account.
> But the redirect URL is something like http://kadokadeo-eternaltwin:50320/....
> You need to manually replace by http://localhost:50320/...

## Some useful commands

- `make docker-watch` : Start the project with logs
- `make docker-start` : Start the project in the background
- `make bash-app` : Enter the application container to run `composer` or `php` commands
- `make reset-database` : Reset the database
- `make sync-database` : Update the database with the migrations

Please see more commands in the [`Makefile`](Makefile) or the [`composer.json`](composer.json#L56-L66) file.

## Porting a game

Some useful documents are located in `.opencode/skills` folder, depending or what you are trying to achieve.
Please read them.

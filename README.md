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

Here are the configuration variables specific to the project (the standard Laravel ones, `APP_*`, `DB_*`, `QUEUE_*`..., are not listed). Most of the `KADO_*` ones are read in [`config/kado.php`](config/kado.php), whose comments give more details.

### General

| Variable                    | Description                                                                         | Default                 |
| --------------------------- | ----------------------------------------------------------------------------------- | ----------------------- |
| `SELF_URL`                  | Public URL of the site (Laravel `app.url`)                                          | `http://localhost`      |
| `KADO_GAMES_PER_DAY`        | Games allowed to play per user per day (`-1`: unlimited)                            | 100                     |
| `KADO_RUNS_MAX_CONCURRENCY` | Maximum amount of games a user can play in parallel before being throttled          | 50                      |
| `KADO_ACHIEVEMENTS_ENABLED` | Achievements. Off: nothing is evaluated nor shown to the players (the admin stays) | `false`                 |
| `KADO_GAME_BUILDS_ENABLED`  | Replays played by the version of the game they were recorded with (archive of the old bundles). Off for now: the production wipes `storage/` at each deploy, so every replay is played by the current bundle | `false` |
| `KADO_GAME_BUILDS_PATH`     | Folder of the archive of the old game bundles (written by `build-games.mjs`)        | `storage/app/game-builds` |

### Themes

The players can change the look of the site in « Mon compte »: the KadoKado theme for everyone, the Karbon theme (the second theme of KadoKado, `resources/css/themes/karbon.css`, images in `public/gfx/themes/karbon`) bought once with Kado points (`kado.themes` in [`config/kado.php`](config/kado.php)).

| Variable                   | Description                                  | Default |
| -------------------------- | -------------------------------------------- | ------- |
| `KADO_THEME_KARBON_PRICE`  | Price of the Karbon theme in Kado points     | 10000   |

### Clans

The tournament of the clans lasts a period (`App\Services\ClanService`), with two rankings at the same time as on KadoKado since 2011: the attacks (the score of a run becomes an attack, the attacked clan has some hours to beat it) and the missions (a series of games to complete in a given time, more games in a bigger clan, harder scores with each mission: a completed mission gives points and opens the next one, a mission not finished in time loses a point by game not completed, minus one). Clan runs of missions are free, attacks and defenses have their own free games each day (given again by `kado:reset-daily-games`), then a paid clan game (bought by packs with Kado points, which their owner uses or gives to his clan, distributed by the leader and the right hands). The scores, the missions and the options start again from 0 on the first day of the next period (the clans and their members stay). It is closed with the period by `kado:prepare-new-period`, and `kado:clans:resolve-attacks` (scheduled every 5 minutes) gives their points to the attacks not repelled in time.

All the rules (durations, points, steps, options, packs of paid games, rewards...) are settings of `App\Settings\ClanSettings` changed in the admin, « Paramètres > Clans », with their default values in [`database/settings`](database/settings). The help page shows them as they are set (`GET /api/clans/overview`, `rules`).

### Security and anti-cheat

| Variable                    | Description                                                                         | Default                           |
| --------------------------- | ----------------------------------------------------------------------------------- | --------------------------------- |
| `KADO_RSA_PRIVATE_KEY_PATH` | Private RSA key path of the server. Should be kept **private**.                     | `storage/app/private/privkey.pem` |
| `KADO_RSA_PUBLIC_KEY_PATH`  | Public key path associated with the private key                                     | `storage/app/private/pubkey.pem`  |
| `KADO_REQUIRE_RNG_STIR`     | A replay outside the daily game must have its RNG stirred by the frames and inputs, otherwise the run is marked as cheated. Turn on a day or two after deploying the games that record it | `false` |
| `KADO_REQUIRE_INPUT_PHASES` | Same, for the time of the inputs in their frame (replay v4)                         | `false`                           |
| `KADO_ANTICHEAT_SOFT_BITS`  | Bits of the client anti-cheat mask (`App\Enums\AntiCheatBit`) that only send the run to the suspicious runs queue instead of marking it as cheated (`0`: every bit marks it as cheated) | `0x3F0` |
| `KADO_SUSPICION`            | Evaluation of every finished run for the admin queue « Runs suspectes » (`App\Services\SuspicionService`, nothing is sanctioned automatically) | `true` |
| `KADO_SUSPICION_WORLD_RECORD` | A run above the record of the game goes to that queue (a high score alone does not) | `true` |

### Replay verifier

The replays of the runs that count (personal best, contract, daily game) are played again on the server in a headless Chrome (`App\Jobs\VerifyRunReplay`, needs Node 22+ and Chrome or its system libraries).

| Variable                               | Description                                                                         | Default                         |
| -------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------- |
| `KADO_REPLAY_VERIFIER`                 | Turns the verification on                                                           | `false`                         |
| `KADO_REPLAY_VERIFIER_NODE`            | Node binary used to run `resources/js/replay-verifier/verify.mjs`                  | `node`                          |
| `KADO_REPLAY_VERIFIER_BROWSER`         | Path of Chrome / Chromium. Empty: looked for at the usual places, then a chrome-headless-shell is downloaded | (auto)  |
| `KADO_REPLAY_VERIFIER_TIMEOUT`         | Timeout of a verification, in seconds                                               | 300                             |
| `KADO_REPLAY_VERIFIER_UNTRUSTED_GAMES` | Comma-separated game keys whose replays sometimes end differently from the live game: a different score is only reported, not sanctioned | |
| `KADO_VERIFIER_CACHE`                  | Cache folder of the Node scripts (PIXI, downloaded browser)                         | `storage/app/replay-verifier`   |

### Replay analysis

Per-game analyzers of the moves (`resources/js/replay-verifier/analyzers/<game_key>.mjs`), run by the replay verifier. Calibrate the thresholds (`kado.replay_analysis.games` in [`config/kado.php`](config/kado.php)) with `php artisan kado:replays:analyze <game>` before turning `KADO_REPLAY_ANALYSIS_FLAG` on.

| Variable                           | Description                                                                         | Default   |
| ---------------------------------- | ----------------------------------------------------------------------------------- | --------- |
| `KADO_REPLAY_ANALYSIS`             | Runs the analyzers and keeps their result with the verification                     | `true`    |
| `KADO_REPLAY_ANALYSIS_FLAG`        | A suspicious analysis puts the run in the suspicious runs queue                     | `false`   |
| `KADO_REPLAY_ANALYSIS_SAMPLE_RATE` | Share (0 to 1) of the other runs of the games with an analyzer verified anyway for their analysis | 0 |
| `KADO_REPLAY_ANALYSIS_QUEUE`       | Queue of these analysis jobs                                                        | `default` |

### External services

| Variable                    | Description                                         | Default                             |
| --------------------------- | --------------------------------------------------- | ----------------------------------- |
| `ETERNALTWIN_URL`           | URL of Eternaltwin (OAuth login)                    | `https://eternaltwin.com/`          |
| `ETERNALTWIN_CLIENT_ID`     | OAuth client id of the site on Eternaltwin          |                                     |
| `ETERNALTWIN_CLIENT_SECRET` | OAuth client secret                                 |                                     |
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
| `kado:reset-daily-games`                         | Resets the daily games for every user to the configured value (`KADO_GAMES_PER_DAY`)                                                                                 | ✅ Everyday at 00:00                                           |
| `kado:prepare-daily-game`                        | Picks the daily game of today (a random active game, its seed and contract). Does nothing if it already exists                                                       | ✅ Everyday at 00:00                                           |
| `kado:game-builds:keep`                          | Lists the game versions still used by replays in `storage/app/game-builds/keep.json`: the next build removes the others (see `KADO_GAME_BUILDS_ENABLED`)              | ✅ Everyday at 00:00                                           |
| `model:prune --model="App\Models\ReplayVerification"` | Removes the replay verifications that went well after 30 days                                                                                                 | ✅ Everyday at 00:00                                           |
| `kado:replays:analyze {game}`                    | Runs the move analyzer of a game on the replays of its runs and shows its metrics, to calibrate the thresholds (nothing is stored). Options: `--since=`, `--limit=50`, `--user=` | ❌                                                             |
| `kado:clean-old-runs`                            | Deletes for good the runs older than two months without a score                                                                                                       | ❌ (disabled in `routes/console.php`)                          |
| `kado:reset-scores {gameId?}`                    | ⚠️ Soft-deletes the runs of every game, or of one game, and erases their replays                                                                                                | ❌                                                             |

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

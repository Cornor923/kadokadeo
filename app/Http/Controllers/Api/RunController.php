<?php

namespace App\Http\Controllers\Api;

use App\Achievements\Events\GameRunCompleted;
use App\Enums\RunVerification;
use App\Events\DailyScoresChanged;
use App\Events\UserCountersChanged;
use App\Exceptions\RunAlreadyCompletedException;
use App\Http\Controllers\Controller;
use App\Http\Requests\RunEndRequest;
use App\Http\Requests\RunRerollRequest;
use App\Http\Requests\RunStartRequest;
use App\Http\Resources\RunBeginResource;
use App\Http\Resources\RunResource;
use App\Jobs\EvaluateRunSuspicion;
use App\Jobs\VerifyRunReplay;
use App\Models\ClanAction;
use App\Models\Game;
use App\Models\GameBuild;
use App\Models\Period;
use App\Models\Run;
use App\Models\User;
use App\Policies\GamePolicy;
use App\Policies\RunPolicy;
use App\Services\AchievementService;
use App\Services\ClanRunService;
use App\Services\GameService;
use App\Services\LeagueService;
use App\Services\ReplayVerifier;
use App\Services\RunService;
use App\Services\ScoreService;
use App\Settings\ClanSettings;
use App\Settings\SiteSettings;
use App\Support\Realtime;
use App\Support\ScoreBoards;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Symfony\Component\HttpFoundation\Exception\BadRequestException;

class RunController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum', except: ['publicKey']),
            new Middleware('throttle:4,1,run-begin', only: ['begin']), // 4 requests per minute
            // (its own counter: the runs finished in a row, and their retries, do not use up the begins)
            new Middleware('throttle:30,1,run-end', only: ['end']),
            // its own counter (not the one of begin)
            new Middleware('throttle:60,1,run-reroll', only: ['reroll']),
        ];
    }

    public function begin(RunStartRequest $request, GameService $gameService, LeagueService $leagueService, ClanRunService $clanRunService, Game $game)
    {
        // a game that can't be opened (turned off, no bundle) can't be played either
        Gate::authorize('view', $game);
        $user = $request->user();
        $isDaily = $request->validated('daily', false);
        // (prepared on demand, before the policy looks for it)
        $dailyGame = $isDaily ? $gameService->getDailyGame() : null;
        // an attack, a defense or a mission step asked on the clan pages: the runs of the missions are free, the attacks
        // and the defenses have their own games (attack games of the day, then paid clan games): the one of the page of the
        // game (/clans/play/{action}), else the one asked last on the game. None while the clans are turned off
        // (ClanSettings::$enabled)
        $clanAction = $isDaily || !app(ClanSettings::class)->enabled
            ? null
            : $clanRunService->pageAction($user, $game->id, $request->filled('clan_action') ? (int) $request->validated('clan_action') : null);
        $cost = $clanRunService->runCost($clanAction);

        if ($dailyGame) {
            $score = $dailyGame->contract_score;
            $points = $dailyGame->contract_points;
            $seed = $dailyGame->seed;
        } else {
            $score = 0;
            $points = 0;
            $seed = $gameService->generateSeed();
        }

        $build = GameBuild::resolve($game, $request->validated('build'));
        // the games are taken back if the run is not created
        $run = DB::transaction(function () use ($build, $clanRunService, $leagueService, $game, $user, $isDaily, $dailyGame, $clanAction, $cost, $score, $points, $seed) {
            // the daily game: refused when the game is not the one of the day, or when it was already played today (outside
            // the production it can be played again, 0fe63e9c). The message is shown in the game. The player is locked
            // until their run is created: two daily runs begun at once would both find none played (the check is done again
            // by the second one once the first one is created)
            if ($isDaily) {
                User::query()->whereKey($user->id)->lockForUpdate()->first();
                $dailyGate = Gate::inspect('playDaily', $game);
                if ($dailyGate->denied() && ($dailyGate->code() !== GamePolicy::DAILY_ALREADY_PLAYED || app()->environment('production'))) {
                    abort(403, $dailyGate->message());
                }
            }
            $this->takeCost($cost, $user, $clanRunService);

            // (the daily game of this game, checked by GamePolicy::playDaily)
            $run = $this->createRun($user, $game, $seed, $score, $points, $build, $leagueService, $dailyGame?->id);

            // only the clan run chosen above (none for the daily game, even when it is played again outside the production)
            if ($clanAction) {
                $clanRunService->bindRun($run, $clanAction);
            }

            return $run;
        });

        // the goal of the clan run and the clan games left, in the bottom bar of the game
        return (new RunBeginResource($run))->withClan($clanAction ? $clanRunService->goal($clanAction, $user->refresh()) : null);
    }

    // "Changer de partie": the run begun is deleted and replaced by a new one (new seed), paid like a run begun (a game of
    // the day, a clan game for an attack or a defense, free for a mission step). The clan run goes on with the new run.
    // Not for the daily game (the same seed for every player, one run a day).
    public function reroll(RunRerollRequest $request, Run $run, GameService $gameService, LeagueService $leagueService, ClanRunService $clanRunService)
    {
        if ($run->completed_at !== null) {
            throw new RunAlreadyCompletedException();
        }
        if ($run->daily_game_id !== null) {
            abort(403, 'Impossible de changer la partie du jour.');
        }
        Gate::authorize('view', $run->game);

        $user = $request->user();
        $clanAction = app(ClanSettings::class)->enabled
            ? ClanAction::query()->where('run_id', $run->id)->whereNull('completed_at')->first()
            : null;
        $cost = $clanRunService->runCost($clanAction);
        $build = GameBuild::resolve($run->game, $request->validated('build'));

        $newRun = DB::transaction(function () use ($run, $user, $cost, $clanAction, $build, $gameService, $leagueService, $clanRunService) {
            // (a run finished meanwhile, RunService::confirmRun holds the same lock: not replaced)
            $run = Run::query()->whereKey($run->id)->lockForUpdate()->firstOrFail();
            if ($run->completed_at !== null) {
                throw new RunAlreadyCompletedException();
            }
            // refused before anything is deleted: the run begun goes on
            $this->takeCost($cost, $user, $clanRunService);

            // (run_flags, replay_verifications, comments, views: cascade; leagues and clans: set null)
            $run->forceDelete();
            $newRun = $this->createRun($user, $run->game, $gameService->generateSeed(), 0, 0, $build, $leagueService);
            if ($clanAction) {
                $clanRunService->bindRun($newRun, $clanAction->refresh());
            }

            return $newRun;
        });

        return (new RunBeginResource($newRun))->withClan($clanAction ? $clanRunService->goal($clanAction, $user->refresh()) : null);
    }

    // what a run costs, taken (or refused) before it is created: a game of the day, or a clan game for an attack or a
    // defense (a mission step is free)
    private function takeCost(string $cost, User $user, ClanRunService $clanRunService): void
    {
        if ($cost === ClanRunService::COST_GAME) {
            Gate::forUser($user)->authorize('create', Run::class);
            // (checked on the player loaded by the auth: taken in one query, two runs begun at once can't both take the
            // last game)
            abort_unless($this->useGame($user), 403, RunPolicy::NO_GAMES_LEFT);
        } elseif ($cost === ClanRunService::COST_CLAN && !$clanRunService->useClanGame($user)) {
            abort(403, 'Vous n\'avez plus de parties de clan. Vous pouvez en acheter avec vos points Kado.');
        }
    }

    // one of the games of the day of the player, only while they have one left. Unlimited games: the counter goes down to 0
    // and the runs go on
    private function useGame(User $user): bool
    {
        $used = User::query()->whereKey($user->id)->where('kado_games', '>', 0)->decrement('kado_games') > 0;
        if ($used) {
            Realtime::send(new UserCountersChanged($user->id));
        }

        return $used || app(SiteSettings::class)->games_per_day <= 0;
    }

    private function createRun(User $user, Game $game, string $seed, int $contractScore, int $contractPoints, ?GameBuild $build, LeagueService $leagueService, ?int $dailyGameId = null): Run
    {
        $period = Period::current()->first();
        $membership = $period ? $leagueService->resolveMembership($user, $game, $period) : null;

        return $game->runs()->create([
            'user_id' => $user->id,
            'period_id' => $period?->id,
            'league_id' => $membership?->league_id,
            'seed' => $seed,
            'contract_score' => $contractScore,
            'contract_points' => $contractPoints,
            'daily_game_id' => $dailyGameId,
            'game_build_id' => $build?->id,
        ]);
    }

    public function end(RunEndRequest $request, Run $run, RunService $runService, ScoreService $scoreService, ReplayVerifier $replayVerifier, AchievementService $achievementService, ClanRunService $clanRunService)
    {
        // only the player of the run finishes it
        abort_unless((int) $run->user_id === (int) $request->user()->id, 404);
        // a run sent again (offline retry, lost response) must not be rewarded twice (checked again under a lock by
        // RunService::confirmRun, for two requests sent at once)
        if ($run->completed_at !== null) {
            throw new RunAlreadyCompletedException();
        }

        $user = $request->user();
        $periodId = $run->period_id ?? Period::current()->first()?->id;
        $payload = $request->validated('payload');
        $key = $request->validated('key');
        $sign = $request->validated('sign');

        $previousBest = $scoreService->getUserBestScore($run->game, $user->id, $periodId);
        $previousBestScore = ($previousBest?->score ?? 0);

        // a payload the server can't read (bad signature, old key, invalid data): refused, the fault of the client
        try {
            $decoded = $runService->decodeRun($payload, $key, $sign);
        } catch (\Throwable $e) {
            info(sprintf('RunController@end: user %d run end refused: %s', Auth::id(), $e->getMessage()));
            throw new BadRequestException($e->getMessage());
        }

        try {
            $run = $runService->confirmRun($run, $decoded);
            $runService->rewardStars($run);
            if (!$run->is_cheat) {
                $achievementUpdates = $achievementService->handleGameRunCompleted(new GameRunCompleted(
                    user: $user,
                    game: $run->game,
                    run: $run,
                    stats: $run->score_details ?? [],
                ));
            } else {
                $achievementUpdates = [];
            }
        } catch (RunAlreadyCompletedException $e) {
            throw $e;
        } catch (\Throwable $e) {
            // not expected: reported (a BadRequestException is not), the game still gets its 400
            report($e);
            throw new BadRequestException($e->getMessage());
        }

        // the score of an attack, a defense or a mission step of the clan of the player
        // (the run is saved: a problem there must not lose it)
        try {
            $clanResult = $clanRunService->handleRunCompleted($run);
        } catch (\Throwable $e) {
            report($e);
            $clanResult = null;
        }

        // the score is sent by the game: the replay of a run that counts is played again on the server
        if ($replayVerifier->shouldVerify($run, $previousBestScore)) {
            $run->update(['verification' => RunVerification::PENDING]);
            VerifyRunReplay::dispatch($run->id);
        } elseif ($replayVerifier->shouldSampleForAnalysis($run)) {
            // (and some others, for the analysis of their moves)
            $run->update(['verification' => RunVerification::PENDING]);
            VerifyRunReplay::dispatch($run->id)->onQueue(config('kado.replay_analysis.queue'));
        }
        // a run played with help (a script showing the moves...): in the queue of the suspicious runs of the admin
        if (!$run->is_cheat) {
            EvaluateRunSuspicion::dispatch($run->id);
        }

        // a new best score of the player: the promotions of the leagues may change (cached otherwise)
        if (!$run->is_cheat && $run->score >= $previousBestScore) {
            $runService->forgetPromotionScores($run);
        }

        $toBeatCount = $scoreService->countPlayersAbove($run->game, $periodId, $run->league_id, $run->score);
        $previousStar = $run->game->getStarFromScore($previousBestScore);

        // the pages showing the leaderboards: a new best of the player in the top 10 of his league, or a record of the game
        // (realtime, App\Support\ScoreBoards); the top 10 of the daily game
        if (!$run->is_cheat && $run->score > $previousBestScore) {
            $worldBest = $scoreService->countPlayersAbove($run->game, null, null, $run->score) === 0;
            if ($toBeatCount < 10 || $worldBest) {
                ScoreBoards::changed($run, $worldBest, daily: false);
            }
        }
        if (!$run->is_cheat && $run->daily_game_id
            && Run::query()->where('daily_game_id', $run->daily_game_id)->where('is_cheat', false)->where('score', '>', $run->score)->count() < 10) {
            Realtime::send(new DailyScoresChanged($run->daily_game_id));
        }

        return [
            'data' => [
                'is_best' => !$run->is_cheat && $run->score > $previousBestScore,
                'previous_star' => $previousStar,
                'current_star' => $run->is_cheat ? $previousStar : $run->game->getStarFromScore($run->score),
                'people_to_beat' => $toBeatCount,
                'achievement_updates' => $achievementUpdates,
                'clan' => $clanResult,
            ],
        ];
    }

    /**
     * The key changes with each deployment: a page opened before it asks for it again when a run cannot be sent.
     */
    public function publicKey(RunService $runService)
    {
        return response()
            ->json(['data' => ['public_key' => $runService->getPublicKey()]])
            ->header('Cache-Control', 'no-store');
    }

    public function show(Run $run)
    {
        Gate::authorize('view', $run);
        $run->load('game', 'user', 'gameBuild');
        Gate::authorize('view', $run->game);

        return RunResource::make($run)->withReplay();
    }
}

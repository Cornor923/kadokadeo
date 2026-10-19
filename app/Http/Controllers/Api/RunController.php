<?php

namespace App\Http\Controllers\Api;

use App\Achievements\Events\GameRunCompleted;
use App\Enums\RunVerification;
use App\Http\Controllers\Controller;
use App\Http\Requests\RunEndRequest;
use App\Http\Requests\RunStartRequest;
use App\Http\Resources\RunBeginResource;
use App\Http\Resources\RunResource;
use App\Jobs\EvaluateRunSuspicion;
use App\Jobs\VerifyRunReplay;
use App\Models\Game;
use App\Models\GameBuild;
use App\Models\Period;
use App\Models\Run;
use App\Policies\GamePolicy;
use App\Services\AchievementService;
use App\Services\ClanRunService;
use App\Services\GameService;
use App\Services\LeagueService;
use App\Services\ReplayVerifier;
use App\Services\RunService;
use App\Services\ScoreService;
use App\Settings\ClanSettings;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;
use Symfony\Component\HttpFoundation\Exception\BadRequestException;

class RunController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum', except: ['publicKey']),
            new Middleware('throttle:10,1', only: ['begin']), // 10 requests per minute
        ];
    }

    public function begin(RunStartRequest $request, GameService $gameService, LeagueService $leagueService, ClanRunService $clanRunService, Game $game)
    {
        $isDaily = $request->validated('daily', false);
        // (prepared on demand, before the policy looks for it)
        $dailyGame = $isDaily ? $gameService->getDailyGame() : null;
        // the daily game: refused when the game is not the one of the day, or when it was already played today (outside
        // the production it can be played again, 0fe63e9c). The message is shown in the game.
        if ($isDaily) {
            $dailyGate = Gate::inspect('playDaily', $game);
            if ($dailyGate->denied() && ($dailyGate->code() !== GamePolicy::DAILY_ALREADY_PLAYED || app()->environment('production'))) {
                abort(403, $dailyGate->message());
            }
        }
        // an attack, a defense or a mission step asked on the clan pages: the runs of the missions are free, the attacks
        // and the defenses have their own games (attack games of the day, then paid clan games). None while the clans are
        // turned off (ClanSettings::$enabled)
        $clanAction = $isDaily || !app(ClanSettings::class)->enabled ? null : $clanRunService->pendingAction($request->user()->id, $game->id);
        $cost = $clanRunService->runCost($clanAction);
        if ($cost === ClanRunService::COST_GAME) {
            Gate::authorize('create', Run::class);
        } elseif ($cost === ClanRunService::COST_CLAN && !$clanRunService->useClanGame($request->user())) {
            abort(403, 'Vous n\'avez plus de parties de clan. Vous pouvez en acheter avec vos points Kado.');
        }

        if ($dailyGame) {
            $score = $dailyGame->contract_score;
            $points = $dailyGame->contract_points;
            $seed = $dailyGame->seed;
        } else {
            $score = 0;
            $points = 0;
            $seed = $gameService->generateSeed();
        }

        $user = $request->user();
        $period = Period::current()->first();
        $membership = $period ? $leagueService->resolveMembership($user, $game, $period) : null;
        $run = $game->runs()->create([
            'user_id' => $user->id,
            'period_id' => $period?->id,
            'league_id' => $membership?->league_id,
            'seed' => $seed,
            'contract_score' => $score,
            'contract_points' => $points,
            'game_build_id' => GameBuild::resolve($game, $request->validated('build'))?->id,
        ]);

        if ($dailyGame?->seed === $run->seed && $dailyGame?->game_id === $run->game_id) {
            $run->daily_game_id = $dailyGame->id;
            $run->save();
        }

        // only the clan run chosen above (none for the daily game, even when it is played again outside the production)
        if ($clanAction) {
            $clanRunService->bindRun($run, $clanAction);
        }

        if ($cost === ClanRunService::COST_GAME && $user->kado_games > 0) {
            $user->kado_games -= 1;
            $user->save();
        }

        // the goal of the clan run and the clan games left, in the bottom bar of the game
        return (new RunBeginResource($run))->withClan($clanAction ? $clanRunService->goal($clanAction, $user->refresh()) : null);
    }

    public function end(RunEndRequest $request, Run $run, RunService $runService, ScoreService $scoreService, ReplayVerifier $replayVerifier, AchievementService $achievementService, ClanRunService $clanRunService)
    {
        // a run sent again (offline retry, lost response) must not be rewarded twice
        if ($run->completed_at !== null) {
            abort(409, 'Partie déjà terminée.');
        }

        $user = $request->user();
        $periodId = $run->period_id ?? Period::current()->first()?->id;
        $payload = $request->validated('payload');
        $key = $request->validated('key');
        $sign = $request->validated('sign');

        $previousBest = $scoreService->getUserBestScore($run->game, $user->id, $periodId);
        $previousBestScore = ($previousBest?->score ?? 0);

        try {
            $decoded = $runService->decodeRun($payload, $key, $sign);
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
        } catch (\Throwable $e) {
            info(sprintf('RunController@end: user %d run end failed: %s', Auth::id(), $e->getMessage()));
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

        $leaderBoardQuery = $scoreService->getLeaderBoard($run->game, $periodId, $run->league_id);
        $toBeatCount = $leaderBoardQuery->where('runs.score', '>', $run->score)->count();
        $previousStar = $run->game->getStarFromScore($previousBestScore);

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

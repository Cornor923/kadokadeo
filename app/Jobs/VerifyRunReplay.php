<?php

namespace App\Jobs;

use App\Enums\RunVerification;
use App\Models\ReplayVerification;
use App\Models\Run;
use App\Services\ReplayVerifier;
use App\Services\RunService;
use App\Services\SuspicionService;
use App\Settings\AntiCheatSettings;
use App\Support\ReplayHeader;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use Spatie\DiscordAlerts\Facades\DiscordAlert;

/**
 * ANTI CHEAT: the score of a run is sent by the game, which a player can modify. Its replay is played again on the
 * server: a run whose replay ends with another score (or without replay) is flagged as cheated.
 */
class VerifyRunReplay implements ShouldQueue
{
    use Queueable;

    public $tries = 1;

    // the same failure of the verifier (no browser...) fails every run: one alert on Discord for it per period
    private const FAILURE_ALERT_EVERY_SECONDS = 3600;

    // the verifier has its own timeout (AntiCheatSettings::$verifier_timeout): a bit more for the job
    public $timeout;

    public function __construct(public string $runId)
    {
        $this->timeout = ReplayVerifier::timeout() + 60;
    }

    public function handle(ReplayVerifier $verifier, RunService $runService, SuspicionService $suspicion): void
    {
        $run = Run::with('game', 'gameBuild', 'user')->find($this->runId);
        if (!$run || $run->completed_at === null) {
            return;
        }

        // the game always sends a replay it can read
        if (ReplayHeader::parse($run->replay) === null) {
            $this->finish($run, RunVerification::NO_REPLAY);
            $runService->flagAsCheat($run);
            $this->alert($run, 'partie sans replay valide : marquée comme triche');

            return;
        }

        $start = hrtime(true);
        $result = $verifier->verify($run);
        $durationMs = intdiv(hrtime(true) - $start, 1_000_000);
        if (!$result['ok']) {
            $this->finish($run, RunVerification::FAILED, ['error' => $result['error'], 'duration_ms' => $durationMs]);
            // a replay that makes the game crash proves nothing: in the queue of the suspicious runs
            $suspicion->recordUnverifiable($run, (string) $result['error']);
            $this->alert($run, "vérification impossible : {$result['error']}", $this->failureKey($result['error']));

            return;
        }

        $details = [
            'replay_score' => $result['score'],
            'frames' => $result['frames'] ?? null,
            'duration_ms' => $durationMs,
            // the analyzer of the moves of the game (resources/js/replay-verifier/analyzers)
            'analysis' => $result['analysis'] ?? null,
        ];
        if ((int) $result['score'] !== (int) $run->score) {
            $this->finish($run, RunVerification::MISMATCH, $details);
            $scores = "score envoyé {$run->score}, score du replay {$result['score']}";
            // a game whose replays can end differently: an admin decides
            if (app(AntiCheatSettings::class)->isUntrustedGame($run->game->game_key)) {
                $this->alert($run, "{$scores} (jeu aux replays non fiables : à vérifier à la main)");

                return;
            }
            $runService->flagAsCheat($run);
            $this->alert($run, "{$scores} : marquée comme triche");

            return;
        }

        $this->finish($run, RunVerification::VERIFIED, $details);
        // the right score, but moves of a solver?
        $suspicion->recordAnalysis($run, $result['analysis'] ?? null);
    }

    private function finish(Run $run, RunVerification $verification, array $details = []): void
    {
        $run->update(['verification' => $verification, 'verified_at' => now()]);
        ReplayVerification::create([
            'run_id' => $run->id,
            'game_id' => $run->game_id,
            'status' => $verification,
            'score' => $run->score,
            ...$details,
        ]);
    }

    // a failure without what changes from one run to another (numbers, temporary paths): the same cause, the same key
    private function failureKey(string $error): string
    {
        return 'replay-verifier:failure-alert:'.md5(preg_replace('/[0-9A-Za-z]{16,}|\d+/', '#', Str::limit($error, 300)));
    }

    // logged, and sent on Discord: with a $throttleKey, once per FAILURE_ALERT_EVERY_SECONDS only
    private function alert(Run $run, string $message, ?string $throttleKey = null): void
    {
        $message = sprintf('Partie %s de %s (%s) : %s', $run->id, $run->user?->display_name, $run->game?->name, $message);
        info($message);
        if (!config('discord-alerts.webhook_urls.default')) {
            return;
        }
        if ($throttleKey !== null) {
            if (!Cache::add($throttleKey, true, self::FAILURE_ALERT_EVERY_SECONDS)) {
                return;
            }
            $message .= ' (les échecs identiques de la prochaine heure ne sont pas envoyés ici : voir Paramètres > Vérificateur de replays)';
        }
        DiscordAlert::message($message);
    }
}

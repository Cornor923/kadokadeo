<?php

namespace App\Services;

use App\Enums\AntiCheatBit;
use App\Events\UserRefresh;
use App\Exceptions\RunAlreadyCompletedException;
use App\Models\GamePeriodStar;
use App\Models\Run;
use App\Models\UserPoint;
use App\Settings\AntiCheatSettings;
use App\Settings\ReplaySettings;
use App\Support\Realtime;
use App\Support\ReplayHeader;
use App\Support\ScoreBoards;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * le client génère une clé AES
 * il chiffre le message (= score, timestamp, replay) avec cette clé
 * il envoie au serveur :
 * le message chiffré avec AES
 * la clé AES chiffrée avec la public key du serveur
 * la signature du message avec la clé AES
 *
 * le back :
 * déchiffre la clé AES grace à sa clé privée
 * déchiffre le message chiffré AES
 * vérifie la signature
 */
class RunService
{
    private string $publicKey;

    private string $privateKey;

    public function __construct($config)
    {
        $this->publicKey = file_get_contents(data_get($config, 'public_key_path'));
        $this->privateKey = file_get_contents(data_get($config, 'private_key_path'));
    }

    public function getPublicKey()
    {
        return $this->publicKey;
    }

    public function decodeRun(string $payload, string $key, string $sign): array
    {
        $aesKey = $this->getAesKeyFromEncrypted($key);
        $decryptedPayload = $this->getDecryptedPayload($payload, $aesKey);

        // Check signature
        $expectedSign = base64_encode(hash_hmac('sha256', $decryptedPayload, $aesKey, true));

        if (!hash_equals($expectedSign, $sign)) {
            throw new \Exception('Signature invalide.');
        }

        $json = json_decode($decryptedPayload, true);

        // Validate json from Laravel Validator
        $validator = Validator::make($json, [
            'run_id' => 'required|exists:runs,id',
            'score' => 'required|integer|min:0',
            'timestamp' => 'required|integer',
            // (base64 of the deflated replay, App\Support\ReplayHeader)
            'replay' => 'nullable|string|max:'.app(ReplaySettings::class)->max_length,
            'data' => 'nullable|array',
            'ac' => 'nullable|integer|min:0|max:1000000',
        ]);

        if ($validator->fails()) {
            throw new \Illuminate\Validation\ValidationException($validator);
        }

        return $validator->validated();
    }

    // the run finished with the decoded payload, once: the run is locked, a second request sent meanwhile (the same
    // payload sent twice at once) waits, then finds it finished (RunAlreadyCompletedException)
    public function confirmRun(Run $run, $decoded): Run
    {
        if ($run->id !== data_get($decoded, 'run_id')) {
            throw new \Error(sprintf('Run ID mismatch. Expected %s, got %s', $run->id, data_get($decoded, 'run_id')));
        }
        $score = data_get($decoded, 'score');
        $timestamp = data_get($decoded, 'timestamp');
        $replay = data_get($decoded, 'replay');
        $data = data_get($decoded, 'data');
        $antiCheat = (int) data_get($decoded, 'ac', 0);

        $end = Carbon::createFromTimestamp($timestamp);
        // (inflated once, outside the lock)
        $header = ReplayHeader::parse($replay);

        // if ($end->clone()->diffInSeconds($realEnd, true) > 30) {
        //     throw new \Error('Invalid timestamp');
        // }
        return DB::transaction(function () use ($run, $score, $replay, $header, $data, $antiCheat) {
            $run = Run::query()->whereKey($run->id)->lockForUpdate()->firstOrFail();
            if ($run->completed_at !== null) {
                throw new RunAlreadyCompletedException();
            }

            $realEnd = now();
            $run->play_time_seconds = (int) $realEnd->diffInSeconds($run->created_at, true);
            $run->completed_at = $realEnd;
            $run->score = $score;
            $run->replay = $replay;
            $run->score_details = $data;
            $run->is_cheat = AntiCheatBit::hardBits($antiCheat) !== 0 || !$this->hasExpectedRngStir($run, $header);
            $run->anticheat_flags = $antiCheat;
            $run->replay_frames = $header?->frames;
            $run->save();
            if (!$run->is_cheat && $run->contract_score > 0 && $run->score >= $run->contract_score) {
                $user = $run->user;
                $user->increment('kado_points', $run->contract_points);
                $user->userPoints()->create([
                    'period_id' => $run->period_id,
                    'delta' => $run->contract_points,
                    'reason' => 'contract completed',
                    'source_type' => Run::class,
                    'source_id' => $run->id,
                ]);
            }

            return $run;
        });
    }

    // the promotions of the leagues of the game in the period of the run (ScoreService::getLeagueScoresForPromotion):
    // they only change with a new best score of a player, or a run taken out of the leaderboards
    public function forgetPromotionScores(Run $run): void
    {
        if ($run->period_id) {
            cache()->forget("promotion_scores_{$run->game_id}_{$run->period_id}");
        }
    }

    // a run found cheated after it was rewarded (App\Jobs\VerifyRunReplay): out of the leaderboards, its contract
    // points taken back (the sum of its points: called again, it takes nothing more), its stars and its effects on the
    // clan undone. The progress of the achievements stays (a rule keeps its own state: it can't be replayed without it)
    public function flagAsCheat(Run $run): void
    {
        DB::transaction(function () use ($run) {
            $run->update(['is_cheat' => true]);
            $reward = (int) UserPoint::where('source_type', Run::class)->where('source_id', $run->id)->sum('delta');
            if ($reward > 0) {
                $user = $run->user;
                $user->decrement('kado_points', $reward);
                $user->userPoints()->create([
                    'period_id' => $run->period_id,
                    'delta' => -$reward,
                    'reason' => 'cheated run',
                    'source_type' => Run::class,
                    'source_id' => $run->id,
                ]);
            }
        });
        // its stars (those of the best run left of the player), and what it did for the clan
        app(ModerationService::class)->recomputeStars($run);
        try {
            app(ClanRunService::class)->revertCheatedRun($run);
        } catch (\Throwable $e) {
            report($e);
        }
        $this->forgetPromotionScores($run);
        // out of the leaderboards shown, the stars of the player read again
        ScoreBoards::changed($run);
        Realtime::send(new UserRefresh($run->user_id));
    }

    public function rewardStars(Run $run)
    {
        // (a player banned while their run was finishing: the ban took their stars back, the run gives none)
        if ($run->is_cheat || $run->user->isBanned()) {
            return;
        }

        if (!$run->period_id) {
            return;
        }
        $game = $run->game;
        $user = $run->user;
        $gainedStar = $game->getStarFromScore($run->score);
        // no star gained
        if ($gainedStar === -1) {
            return;
        }
        // (createOrFirst when it is missing: two runs at once create it once)
        $userPeriodStars = $user->stars()->firstOrCreate(['period_id' => $run->period_id]);

        // Reward each star up to the gained star. Each star once (unique index): two runs of the player finished at
        // once count it once, and the counters are incremented by what was really inserted
        $now = now();
        $increments = [];
        for ($i = 0; $i <= $gainedStar; $i++) {
            $inserted = GamePeriodStar::query()->insertOrIgnore([
                'game_id' => $game->id,
                'period_id' => $run->period_id,
                'user_id' => $user->id,
                'star' => $i,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            if ($inserted > 0) {
                $increments[match ($i) {
                    0 => 'green_stars',
                    1 => 'orange_stars',
                    2 => 'red_stars',
                    3 => 'purple_stars',
                }] = 1;
            }
        }
        if ($increments) {
            $userPeriodStars->newQuery()->whereKey($userPeriodStars->getKey())->incrementEach($increments);
        }
    }

    // apart from the daily game, the game stirs its draws with the frames and the inputs, and the time of the inputs
    // (the coming pieces can't be listed from the seed, nor predicted before an input): a replay without it comes from a
    // modified game. Replays of older versions (no header flag) are accepted while their game version is still the
    // one sent by the page.
    private function hasExpectedRngStir(Run $run, ?ReplayHeader $header): bool
    {
        if ($run->daily_game_id !== null || $header === null) {
            return true;
        }

        $settings = app(AntiCheatSettings::class);

        return ($header->hasRngStir() || !$settings->require_rng_stir)
            && ($header->hasInputPhases() || !$settings->require_input_phases);
    }

    private function getAesKeyFromEncrypted(string $key): string
    {
        // Decrypt AES key with server's private key
        $privateKey = openssl_pkey_get_private($this->privateKey);
        if (!$privateKey) {
            throw new \Exception('Impossible de charger la clé privée du serveur.');
        }

        $decryptedAesKey = null;
        $decodeResult = openssl_private_decrypt(base64_decode($key), $decryptedAesKey, $privateKey);

        if (!$decodeResult || !$decryptedAesKey) {
            throw new \Exception('Échec du déchiffrement de la clé AES.');
        }

        $saveDecrypted = base64_encode($decryptedAesKey);
        $decryptedAesKey = base64_decode($decryptedAesKey, true);
        if ($decryptedAesKey === false) {
            throw new \Exception("Clé AES invalide : base64 incorrect: $saveDecrypted");
        }

        // Check that the decrypted AES key is a binary chain of 16, 24 or 32 bytes (AES-128, 192, 256)
        $aesKeyLength = strlen($decryptedAesKey);
        if (!in_array($aesKeyLength, [16, 24, 32])) {
            throw new \Exception("Clé AES invalide : longueur incorrecte ($aesKeyLength octets).");
        }

        return $decryptedAesKey;
    }

    private function getDecryptedPayload(string $payload, string $aesKey): string
    {
        $aesKeyLength = strlen($aesKey);

        $algo = match ($aesKeyLength) {
            16 => 'aes-128-ctr',
            24 => 'aes-192-ctr',
            32 => 'aes-256-ctr',
        };

        // Decrypt payload
        $ivLength = openssl_cipher_iv_length($algo);
        $payloadRaw = base64_decode($payload, true);

        if ($payloadRaw === false) {
            throw new \Exception("Le payload n'est pas un base64 valide.");
        }
        if (strlen($payloadRaw) < $ivLength) {
            throw new \Exception('Payload trop court pour contenir un IV.');
        }

        $iv = substr($payloadRaw, 0, $ivLength);
        $cipherText = substr($payloadRaw, $ivLength);

        $decryptedPayload = openssl_decrypt($cipherText, $algo, $aesKey, OPENSSL_RAW_DATA, $iv);

        if ($decryptedPayload === false) {
            throw new \Exception('Échec du déchiffrement du payload.');
        }

        return $decryptedPayload;
    }
}

<?php

namespace App\Services;

use App\Models\Game;
use App\Settings\ClanSettings;

// the scores to reach of the steps of a mission, by their difficulty in stars (difficulty() and scoreAt()): 1 at the first
// star, 2 at the second, 3 at the third (linear between them, from 0), then 3 + x at x of the way from the last star to
// the "Score 1500" of the game (games.score_rankv1), at most 4. The top difficulty of a mission starts at half the first
// star and goes up by `starsPerMission` with each mission, then by `beyondPerMission` beyond the last star. A share of the
// steps is at the top difficulty (bigger with the missions), the others are spread on all the difficulties from half the
// first star: the missions keep easy steps. Used by ClanMissionService::generateMission and the preview of the admin.
final class ClanMissionPaliers
{
    // the easiest steps: half the first star
    public const START = 0.5;

    public function __construct(
        public readonly float $starsPerMission,
        public readonly float $beyondPerMission,
        public readonly float $hardShareMin,
        public readonly float $hardShareStep,
        public readonly float $hardShareMax,
    ) {}

    public static function fromSettings(ClanSettings $settings): self
    {
        return self::fromArray((array) $settings->toArray());
    }

    // the settings (the form of the admin while it is edited)
    public static function fromArray(array $values): self
    {
        return new self(
            starsPerMission: max(0, (float) ($values['mission_stars_per_mission'] ?? 0)),
            beyondPerMission: max(0, (float) ($values['mission_beyond_last_star'] ?? 0)),
            hardShareMin: (float) ($values['mission_hard_share_min'] ?? 0),
            hardShareStep: (float) ($values['mission_hard_share_step'] ?? 0),
            hardShareMax: (float) ($values['mission_hard_share_max'] ?? 1),
        );
    }

    // the top difficulty of a mission
    public function topDifficulty(int $number, int $starsCount = 3): float
    {
        $top = self::START + $this->starsPerMission * max(0, $number - 1);
        if ($top <= $starsCount) {
            return $top;
        }
        // the missions since the last star was reached
        $beyond = ($top - $starsCount) / $this->starsPerMission;

        return $starsCount + min(1, $beyond * $this->beyondPerMission);
    }

    // the highest top difficulty (reached after enough missions)
    public function maxDifficulty(int $starsCount = 3): float
    {
        return $starsCount + ($this->beyondPerMission > 0 ? 1 : 0);
    }

    /**
     * The difficulties of the steps of a mission, the easiest first (to shuffle).
     *
     * @return list<float>
     */
    public function levels(int $number, int $steps, int $starsCount = 3): array
    {
        if ($steps <= 0) {
            return [];
        }
        $top = $this->topDifficulty($number, $starsCount);
        $share = min($this->hardShareMax, $this->hardShareMin + $this->hardShareStep * max(0, $number - 1));
        $hard = max(1, (int) round($steps * $share));
        $rest = $steps - $hard;
        // the others, from half the first star up to the top difficulty
        $others = [];
        for ($i = 0; $i < $rest; $i++) {
            $others[] = self::START + ($top - self::START) * $i / $rest;
        }

        return [...$others, ...array_fill(0, $hard, $top)];
    }

    // the score of a difficulty on a game (the inverse of difficulty()), at most its last star without a "Score 1500"
    // above it
    public static function scoreAt(array $stars, ?int $scoreRankV1, float $difficulty): float
    {
        $stars = collect($stars)->map(fn ($star) => (float) $star)->sort()->values();
        if ($stars->isEmpty()) {
            return 0;
        }
        $previous = 0.0;
        foreach ($stars as $index => $star) {
            if ($difficulty <= $index + 1) {
                return $previous + ($star - $previous) * max(0, $difficulty - $index);
            }
            $previous = $star;
        }
        if ($scoreRankV1 === null || $scoreRankV1 <= $previous) {
            return $previous;
        }

        return $previous + ($scoreRankV1 - $previous) * min(1, $difficulty - $stars->count());
    }

    // the score to reach on a game at a difficulty
    public function targetScore(Game $game, float $difficulty): int
    {
        return max(1, (int) round(self::scoreAt($game->stars ?? [], $game->score_rankv1, $difficulty)));
    }

    // the difficulty of a score to reach on a game, to sort the steps of a mission (the hardest first): 1 at the first star,
    // 2 at the second... (linear between them), then one more at the "Score 1500" of the game (games.score_rankv1). The
    // palier of a step is not kept, and its score says it whatever the settings were.
    public static function difficulty(array $stars, ?int $scoreRankV1, int $score): float
    {
        $stars = collect($stars)->map(fn ($star) => (float) $star)->sort()->values();
        $previous = 0.0;
        foreach ($stars as $index => $star) {
            if ($score <= $star) {
                return $index + ($star > $previous ? ($score - $previous) / ($star - $previous) : 1);
            }
            $previous = $star;
        }
        // beyond the last star (without a "Score 1500" above it: one more at twice the last star)
        $scale = $scoreRankV1 !== null && $scoreRankV1 > $previous ? $scoreRankV1 - $previous : max(1, $previous);

        return $stars->count() + ($score - $previous) / $scale;
    }

    // the star of a difficulty, in the preview of the admin (3 stars)
    public static function label(float $difficulty): string
    {
        return match (true) {
            $difficulty < 1 => 'grise',
            $difficulty < 2 => 'verte',
            $difficulty < 3 => 'orange',
            $difficulty < 3.005 => 'rouge',
            default => 'rouge +'.round(($difficulty - 3) * 100).' %',
        };
    }
}

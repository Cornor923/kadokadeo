<?php

namespace App\Settings;

use App\Enums\ClanBonusType;
use Spatie\LaravelSettings\Settings;

// the rules of the clans, changed from the admin panel (App\Filament\Pages\ManageClanSettings) and shown on the help page
// (App\Services\ClanService::rules)
class ClanSettings extends Settings
{
    public int $max_members;

    // ---------------------------------------------------------------- attacks and defenses

    // the free games of the attacks and defenses given to every player each day (users.clan_attack_games); then the paid
    // clan games. The missions are free and unlimited.
    public int $attack_games_per_day;

    // the attacked clan has this time to beat the score of an attack
    public int $attack_hours;

    // a successful attack wins from 1 to this, taken from the defender: this against a clan with as many points or more,
    // one less by palier of protection_range / attack_max_points points it has below the attacker
    public int $attack_max_points;

    // the clans too far from your score are protected from your attacks (and you from theirs)
    public int $protection_range;

    // the seats of "Attaquant" and "Défenseur": this share of the members (0 to 1), at least 1 each
    public float $attacker_seats_share;

    public float $defender_seats_share;

    // ---------------------------------------------------------------- missions

    public int $mission_hours;

    // "Plus de temps"
    public int $mission_more_time_hours;

    // the steps (games) of a mission: base for a lone player + per_member for each other member, at most max, times
    // ratio^(number - 1) for the next missions, at least min
    public int $mission_steps_base;

    public float $mission_steps_per_member;

    public int $mission_steps_max;

    public int $mission_steps_min;

    public float $mission_steps_ratio;

    // the scores to reach (App\Services\ClanMissionPaliers), by difficulty in stars: the top difficulty of a mission goes up
    // by this many stars with each mission from half the first star, then beyond the last star by this share of the way
    // up to the "Score 1500" of the game with each mission; this share of the steps at the top difficulty (min + step by
    // mission, at most max), the others spread from half the first star up to it
    public float $mission_stars_per_mission;

    public float $mission_beyond_last_star;

    public float $mission_hard_share_min;

    public float $mission_hard_share_step;

    public float $mission_hard_share_max;

    // the points of a completed mission: first, one less every `every` missions, at least min
    public int $mission_points_first;

    public int $mission_points_every;

    public int $mission_points_min;

    // chance (0 to 1) to win an option with each completed mission, then the chances of each option [type => weight]
    // (the types of the properties are read by spatie/laravel-settings: no detailed @var on them)
    public float $bonus_chance;

    public array $bonus_weights;

    // ---------------------------------------------------------------- paid clan games and rewards

    // the packs of paid clan games bought with Kado points: [{count, price}]
    public array $game_packs;

    // Kado points shared between the members at the end of the period, by rank: [{last_rank, points}]
    public array $war_rewards;

    public array $mission_rewards;

    public static function group(): string
    {
        return 'clans';
    }

    /**
     * @return array<int, int> [games => Kado points], the smallest pack first
     */
    public function gamePacks(): array
    {
        $packs = collect($this->game_packs)
            ->mapWithKeys(fn (array $pack) => [(int) $pack['count'] => (int) $pack['price']])
            ->filter(fn (int $price, int $count) => $count > 0)
            ->all();
        ksort($packs);

        return $packs;
    }

    /**
     * @param  'war'|'missions'  $ranking
     * @return array<int, int> [last rank => Kado points], the best ranks first
     */
    public function rewards(string $ranking): array
    {
        $rewards = collect($ranking === 'missions' ? $this->mission_rewards : $this->war_rewards)
            ->mapWithKeys(fn (array $reward) => [(int) $reward['last_rank'] => (int) $reward['points']])
            ->all();
        ksort($rewards);

        return $rewards;
    }

    public function bonusWeight(ClanBonusType $type): int
    {
        return max(0, (int) ($this->bonus_weights[$type->value] ?? 0));
    }
}

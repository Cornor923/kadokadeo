<?php

use Spatie\LaravelSettings\Migrations\SettingsMigration;

// the rules of the clans that were in config/kado.php (kado.clans), changed from the admin panel since
return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('clans.max_members', 20);

        $this->migrator->add('clans.attack_hours', 12);
        $this->migrator->add('clans.attack_max_points', 10);
        $this->migrator->add('clans.protection_range', 100);
        $this->migrator->add('clans.attacker_seats_share', 0.2);
        $this->migrator->add('clans.defender_seats_share', 0.2);

        $this->migrator->add('clans.mission_hours', 24);
        $this->migrator->add('clans.mission_more_time_hours', 6);
        $this->migrator->add('clans.mission_steps_base', 5);
        $this->migrator->add('clans.mission_steps_per_member', 0.38);
        $this->migrator->add('clans.mission_steps_max', 24);
        $this->migrator->add('clans.mission_steps_min', 1);
        $this->migrator->add('clans.mission_steps_ratio', 1.0);
        $this->migrator->add('clans.mission_paliers_every', 2);
        $this->migrator->add('clans.mission_points_first', 10);
        $this->migrator->add('clans.mission_points_every', 10);
        $this->migrator->add('clans.mission_points_min', 1);
        $this->migrator->add('clans.bonus_chance', 0.07);
        $this->migrator->add('clans.bonus_weights', ['more_time' => 30, 'skip_step' => 30, 'next_mission' => 20, 'ban_game' => 10, 'force_game' => 10]);

        $this->migrator->add('clans.game_packs', [
            ['count' => 1, 'price' => 50],
            ['count' => 5, 'price' => 225],
            ['count' => 10, 'price' => 400],
            ['count' => 50, 'price' => 1750],
        ]);
        $rewards = [[1, 150000], [2, 100000], [5, 75000], [10, 25000], [20, 12500], [30, 7500], [40, 5000], [50, 2500], [100, 1250]];
        $rewards = array_map(fn (array $reward) => ['last_rank' => $reward[0], 'points' => $reward[1]], $rewards);
        $this->migrator->add('clans.war_rewards', $rewards);
        $this->migrator->add('clans.mission_rewards', $rewards);
    }

    public function down(): void
    {
        foreach ([
            'max_members', 'attack_hours', 'attack_max_points', 'protection_range', 'attacker_seats_share',
            'defender_seats_share', 'mission_hours', 'mission_more_time_hours', 'mission_steps_base',
            'mission_steps_per_member', 'mission_steps_max', 'mission_steps_min', 'mission_steps_ratio',
            'mission_paliers_every', 'mission_points_first', 'mission_points_every', 'mission_points_min', 'bonus_chance',
            'bonus_weights', 'game_packs', 'war_rewards', 'mission_rewards',
        ] as $name) {
            $this->migrator->delete("clans.{$name}");
        }
    }
};

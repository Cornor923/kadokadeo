<?php

use Spatie\LaravelSettings\Migrations\SettingsMigration;

return new class() extends SettingsMigration
{
    public function up(): void
    {
        // kado points of the players with the most feathers (shared between the tied ones)
        $this->migrator->add('site.poids_plume_jackpot', 10000);
        // kado points shared equally between the other players with at least 2 feathers
        $this->migrator->add('site.poids_plume_shared_pool', 10000);
    }

    public function down(): void
    {
        $this->migrator->delete('site.poids_plume_jackpot');
        $this->migrator->delete('site.poids_plume_shared_pool');
    }
};

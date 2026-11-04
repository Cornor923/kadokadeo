<?php

use Spatie\LaravelSettings\Migrations\SettingsMigration;

return new class() extends SettingsMigration
{
    public function up(): void
    {
        // kado points of a point of the daily ranking, paid at the close of the period
        $this->migrator->add('site.daily_ranking_kado_per_point', 10);
    }

    public function down(): void
    {
        $this->migrator->delete('site.daily_ranking_kado_per_point');
    }
};

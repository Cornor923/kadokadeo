<?php

use Spatie\LaravelSettings\Migrations\SettingsMigration;

return new class() extends SettingsMigration
{
    public function up(): void
    {
        // off: a replay that ends with another score marks its run as cheated, and more runs would be exposed. To turn on
        // once the games whose replays diverge are in verifier_untrusted_games
        $this->migrator->add('anticheat.verifier_achievements', false);
    }

    public function down(): void
    {
        $this->migrator->delete('anticheat.verifier_achievements');
    }
};

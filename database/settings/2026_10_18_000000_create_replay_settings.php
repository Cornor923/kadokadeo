<?php

use Spatie\LaravelSettings\Migrations\SettingsMigration;

return new class() extends SettingsMigration
{
    public function up(): void
    {
        $this->migrator->add('replays.comments_enabled', true);
        $this->migrator->add('replays.comment_max_length', 280);
        $this->migrator->add('replays.comments_max_per_run', 500);
        $this->migrator->add('replays.comments_max_per_user_per_run', 30);
        $this->migrator->add('replays.view_after_seconds', 10);
    }

    public function down(): void
    {
        $this->migrator->delete('replays.comments_enabled');
        $this->migrator->delete('replays.comment_max_length');
        $this->migrator->delete('replays.comments_max_per_run');
        $this->migrator->delete('replays.comments_max_per_user_per_run');
        $this->migrator->delete('replays.view_after_seconds');
    }
};

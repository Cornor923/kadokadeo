<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Settings\ClanSettings;
use Illuminate\Console\Command;

class ResetDailyGames extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'kado:reset-daily-games';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Reset daily games for all users';

    /**
     * Execute the console command.
     */
    public function handle(ClanSettings $clanSettings)
    {
        User::query()->update([
            'kado_games' => config('kado.games_per_day'),
            // the attacks and the defenses of the clans have their own games
            'clan_attack_games' => $clanSettings->attack_games_per_day,
        ]);

        $this->info('Daily games have been reset successfully.');
    }
}

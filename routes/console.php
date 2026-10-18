<?php

// use App\Console\Commands\CleanOldRuns;

use App\Console\Commands\KeepGameBuilds;
use App\Console\Commands\PrepareDailyGame;
use App\Console\Commands\PrepareNewPeriod;
use App\Console\Commands\ResetDailyGames;
use App\Console\Commands\ResolveClanAttacks;
use App\Models\ReplayVerification;
use Illuminate\Support\Facades\Schedule;

Schedule::command(ResetDailyGames::class)->daily();
Schedule::command(PrepareDailyGame::class)->daily();
// Schedule::command(CleanOldRuns::class)->twiceDailyAt(6, 18);
Schedule::command(PrepareNewPeriod::class)->weeklyOn(1);
// the clan attacks not repelled within 12 hours give their points (they are also resolved when the clan pages are read)
Schedule::command(ResolveClanAttacks::class)->everyFiveMinutes();
// versions of the games still used by replays (the next build removes the others)
Schedule::command(KeepGameBuilds::class)->daily();
// the verifications of replays that went well, after 30 days (App\Models\ReplayVerification)
Schedule::command('model:prune', ['--model' => [ReplayVerification::class]])->daily();

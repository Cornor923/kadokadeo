<?php

// use App\Console\Commands\CleanOldRuns;

use App\Console\Commands\ExpireClanMissions;
use App\Console\Commands\KeepGameBuilds;
use App\Console\Commands\PrepareDailyGame;
use App\Console\Commands\PrepareNewPeriod;
use App\Console\Commands\ReapVerifierBrowsers;
use App\Console\Commands\ResetDailyGames;
use App\Console\Commands\ResolveClanAttacks;
use App\Models\ReplayVerification;
use App\Models\UserNotification;
use Illuminate\Support\Facades\Schedule;

// (withoutOverlapping: a run still going when the next one starts is not doubled; the lock expires after the minutes
// given, for a run killed before releasing it)
Schedule::command(ResetDailyGames::class)->daily()->withoutOverlapping(60);
Schedule::command(PrepareDailyGame::class)->daily()->withoutOverlapping(60);
// Schedule::command(CleanOldRuns::class)->twiceDailyAt(6, 18);
Schedule::command(PrepareNewPeriod::class)->weeklyOn(1)->withoutOverlapping(120);
// the clan attacks not repelled within 12 hours give their points (they are also resolved when the clan pages are read)
Schedule::command(ResolveClanAttacks::class)->everyFiveMinutes()->withoutOverlapping(10);
// the clan missions not finished in time are failed (also when the missions are read): the members are told at once
Schedule::command(ExpireClanMissions::class)->everyFiveMinutes()->withoutOverlapping(10);
// versions of the games still used by replays (the next build removes the others)
Schedule::command(KeepGameBuilds::class)->daily()->withoutOverlapping(60);
// the verifications of replays that went well, after 30 days (App\Models\ReplayVerification); the notifications of the
// players two months after their last change (App\Models\UserNotification)
Schedule::command('model:prune', ['--model' => [ReplayVerification::class, UserNotification::class]])->daily()->withoutOverlapping(60);
// the browsers of the replay verifier left running by a script killed (each one takes a CPU)
Schedule::command(ReapVerifierBrowsers::class)->everyFiveMinutes()->withoutOverlapping(10);

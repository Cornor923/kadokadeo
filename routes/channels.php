<?php

use App\Models\ClanMember;
use App\Models\Run;
use App\Models\User;
use App\Settings\ClanSettings;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Gate;

// the channels of the realtime (App\Support\Realtime), authorized by /api/broadcasting/auth (the session of the site, banned
// users refused by the api group). "site", "games.{id}" and "daily" are public.

Broadcast::channel('App.Models.User.{id}', fn (User $user, $id) => (int) $user->id === (int) $id);

// the comments of a replay: the players who can watch it
Broadcast::channel('runs.{runId}', function (User $user, string $runId) {
    $run = Run::query()->find($runId);

    return $run !== null && Gate::forUser($user)->allows('view', $run);
});

// the members of a clan, while the clans are open (App\Settings\ClanSettings::$enabled)
Broadcast::channel('clans.{clanId}', fn (User $user, $clanId) => app(ClanSettings::class)->enabled
    && ClanMember::where('clan_id', $clanId)->where('user_id', $user->id)->exists());

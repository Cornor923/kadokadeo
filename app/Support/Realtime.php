<?php

namespace App\Support;

use App\Events\RealtimeEvent;
use App\Models\User;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Support\Facades\DB;

// the realtime of the site (Reverb, channels in routes/channels.php): an event kept once the transaction around is
// committed (nothing for a rollback), sent after the response of the request (RealtimeOutbox: once, what it sends is
// read then). A Reverb down or slow (timeouts in config/broadcasting.php) never makes the action of a player fail: the
// front reloads what it shows when its socket connects again, and polls while it is not connected
class Realtime
{
    public static function send(RealtimeEvent $event): void
    {
        DB::afterCommit(fn () => app(RealtimeOutbox::class)->push($event));
    }

    // where the browsers connect (window.Kado.reverb), null when the server does not broadcast (the front polls)
    public static function clientConfig(): ?array
    {
        if (config('broadcasting.default') !== 'reverb' || !config('broadcasting.connections.reverb.key')) {
            return null;
        }
        $client = config('broadcasting.connections.reverb.client', []);

        return [
            'key' => config('broadcasting.connections.reverb.key'),
            'host' => $client['host'] ?? null,
            'port' => isset($client['port']) ? (int) $client['port'] : null,
            'scheme' => $client['scheme'] ?? null,
        ];
    }

    // everyone, logged in or not: announcement, new period, new daily game...
    public static function site(): Channel
    {
        return new Channel('site');
    }

    // the player alone: messages, notifications, his counters
    public static function user(User|int $user): PrivateChannel
    {
        return new PrivateChannel('App.Models.User.'.($user instanceof User ? $user->id : $user));
    }

    // the scores of a game: public, its events only say which leaderboard to read again (no authorization for each page
    // of a game)
    public static function game(int $gameId): Channel
    {
        return new Channel("games.{$gameId}");
    }

    // the scores of the daily game: public, as the games
    public static function daily(): Channel
    {
        return new Channel('daily');
    }

    // the page of a replay (its comments), for the players who can watch it (App\Policies\RunPolicy::view)
    public static function run(string $runId): PrivateChannel
    {
        return new PrivateChannel("runs.{$runId}");
    }

    // the members of a clan
    public static function clan(int $clanId): PrivateChannel
    {
        return new PrivateChannel("clans.{$clanId}");
    }
}

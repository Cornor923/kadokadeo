<?php

namespace App\Services;

use App\Models\Session;
use App\Models\SiteVisit;
use App\Models\User;
use App\Support\GeoIp;
use App\Support\UserAgent;
use Carbon\CarbonPeriod;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Broadcast;
use Throwable;

// The audience of the site, for the admin page App\Filament\Pages\AudienceDashboard. Read from what the site does anyway (its API, its sessions, its
// sockets), with no script or request of its own: an ad blocker has nothing to block.
class VisitService
{
    // App\Support\Realtime::user: every logged in player has one channel, whatever his number of tabs
    private const USER_CHANNEL_PREFIX = 'private-App.Models.User.';

    public function __construct(private readonly GeoIp $geoIp) {}

    public function record(User $user, Request $request): void
    {
        $agent = new UserAgent((string) $request->userAgent());

        SiteVisit::query()->insertOrIgnore([
            'date' => today()->toDateString(),
            'user_id' => $user->id,
            'device' => $agent->deviceType((int) $request->header('X-Kado-Touch'))->value,
            'browser' => $agent->browser() ?? SiteVisit::UNKNOWN_BROWSER,
            'country' => $this->geoIp->country($request->ip()) ?? SiteVisit::UNKNOWN_COUNTRY,
        ]);
    }

    // the players with a page of the site open, null without Reverb
    public function connectedNow(): ?int
    {
        if (config('broadcasting.default') !== 'reverb') {
            return null;
        }
        try {
            $channels = Broadcast::connection('reverb')->getPusher()->getChannels(['filter_by_prefix' => self::USER_CHANNEL_PREFIX]);

            return count($channels->channels);
        } catch (Throwable) {
            return null;
        }
    }

    // the players who made a request in the last minutes
    public function activeSince(int $minutes): int
    {
        return Session::query()
            ->whereNotNull('user_id')
            ->where('last_activity', '>=', now()->subMinutes($minutes)->getTimestamp())
            ->distinct()
            ->count('user_id');
    }

    // the players seen between these days (the last one by default today), each once
    public function visitorsBetween(Carbon $from, ?Carbon $to = null): int
    {
        return SiteVisit::query()
            ->where('date', '>=', $from->toDateString())
            ->when($to, fn ($query) => $query->where('date', '<=', $to->toDateString()))
            ->distinct()
            ->count('user_id');
    }

    // the players of each day between these days, the days without any at 0: ['2026-11-04' => players]
    public function visitorsPerDay(Carbon $from, Carbon $to): array
    {
        $visitors = SiteVisit::query()->toBase()
            ->whereBetween('date', [$from->toDateString(), $to->toDateString()])
            ->selectRaw('date, count(distinct user_id) as total')
            ->groupBy('date')
            ->pluck('total', 'date');

        $days = [];
        foreach (CarbonPeriod::create($from->copy()->startOfDay(), '1 day', $to->copy()->startOfDay()) as $day) {
            $days[$day->toDateString()] = (int) ($visitors[$day->toDateString()] ?? 0);
        }

        return $days;
    }

    // the players of the last days by device, browser or country, the most seen first: [value => players]. A player on a
    // phone and a computer counts once in each.
    public function visitorsBy(string $column, int $days): array
    {
        return SiteVisit::query()->toBase()
            ->where('date', '>=', today()->subDays($days - 1)->toDateString())
            ->selectRaw("{$column}, count(distinct user_id) as total")
            ->groupBy($column)
            ->orderByDesc('total')
            ->pluck('total', $column)
            ->all();
    }
}

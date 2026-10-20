<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\AchievementResource;
use App\Models\Achievement;
use App\Models\User;
use App\Settings\SiteSettings;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;

class AchievementController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum', only: ['index']),
        ];
    }

    public function index(Request $request)
    {
        if (!app(SiteSettings::class)->achievements_enabled) {
            return AchievementResource::collection([]);
        }

        $usersCount = User::count();

        $achievements = Achievement::where('achievements.is_active', true)
            ->where(fn ($query) => $query->whereNull('achievements.game_id')->orWhere('g.is_active', true))
            ->select('achievements.*')
            ->addSelect(DB::raw('
                array[
                    count(uap.user_id) filter (where uap.completed_level >= 1),
                    count(uap.user_id) filter (where uap.completed_level >= 2),
                    count(uap.user_id) filter (where uap.completed_level >= 3)
                ] as level_user_counts
            '))
            ->leftJoin('user_achievement_progress as uap', 'achievements.id', '=', 'uap.achievement_id')
            ->leftJoin('games as g', 'achievements.game_id', '=', 'g.id')
            ->groupBy('achievements.id')
            ->with('levels', 'game')
            ->get();

        $achievements->each(function ($a) use ($usersCount) {
            $a->level_user_counts = json_decode(str_replace('{', '[', str_replace('}', ']', $a->level_user_counts)), true);
            $a->levels->each(function ($level, $k) use ($usersCount, $a) {
                $level->obtained_percentage = round(($a->level_user_counts[$k] / $usersCount) * 100, 2);
            });
        });

        return AchievementResource::collection($achievements);
    }
}

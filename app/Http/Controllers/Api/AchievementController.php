<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\AchievementResource;
use App\Models\Achievement;
use App\Settings\SiteSettings;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

class AchievementController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum', only: ['index']),
        ];
    }

    public function index()
    {
        if (!app(SiteSettings::class)->achievements_enabled) {
            return AchievementResource::collection([]);
        }

        $achievements = Achievement::query()
            ->where('is_active', true)
            ->where(fn ($query) => $query->whereNull('game_id')->orWhereHas('game', fn ($game) => $game->where('is_active', true)))
            ->with('levels', 'game')
            ->get();

        return AchievementResource::collection($achievements);
    }
}

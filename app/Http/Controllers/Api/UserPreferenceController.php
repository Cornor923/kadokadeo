<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserPreference;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

// the preferences of the player (App\Enums\UserPreference), on his account page
class UserPreferenceController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:30,1'),
        ];
    }

    // only the preferences sent change: { "notify_run_comments": false }
    public function update(Request $request)
    {
        $keys = array_map(fn (UserPreference $preference) => $preference->value, UserPreference::cases());
        $rules = array_fill_keys($keys, ['sometimes', 'boolean']);
        $validated = $request->validate($rules);
        $unknown = array_diff(array_keys($request->all()), $keys);
        abort_if($unknown !== [], 422, 'Préférence inconnue : '.implode(', ', $unknown).'.');

        $user = $request->user();
        $user->preferences = [...($user->preferences ?? []), ...array_map(fn ($value) => (bool) $value, $validated)];
        $user->save();

        return ['data' => $user->preferenceValues()];
    }
}

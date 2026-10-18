<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

// the looks of the site (kado.themes): "base" for everyone, the others bought once with Kado points
class ThemeController extends Controller implements HasMiddleware
{
    public static function middleware()
    {
        return [
            new Middleware('auth:sanctum'),
            new Middleware('throttle:10,1', only: ['buy']),
        ];
    }

    public function index(Request $request)
    {
        $user = $request->user();

        return [
            'data' => collect(config('kado.themes'))->map(fn (array $theme, string $key) => [
                'key' => $key,
                'name' => $theme['name'],
                'price' => (int) $theme['price'],
                'owned' => $user->hasTheme($key),
                'active' => ($user->theme ?? 'base') === $key,
            ])->values(),
        ];
    }

    public function buy(Request $request, string $theme)
    {
        abort_unless(array_key_exists($theme, config('kado.themes')), 404, 'Thème introuvable.');
        $price = (int) config("kado.themes.{$theme}.price");

        DB::transaction(function () use ($request, $theme, $price) {
            $user = User::query()->lockForUpdate()->findOrFail($request->user()->id);
            if ($user->hasTheme($theme)) {
                abort(422, 'Vous possédez déjà ce thème.');
            }
            if ($user->kado_points < $price) {
                abort(422, 'Vous n\'avez pas assez de points Kado pour acheter ce thème.');
            }

            $user->kado_points -= $price;
            $user->unlocked_themes = [...($user->unlocked_themes ?? []), $theme];
            // used right away
            $user->theme = $theme;
            $user->save();
            $user->userPoints()->create([
                'delta' => -$price,
                'reason' => 'theme purchase',
                'source_type' => 'theme',
                'source_id' => $theme,
            ]);
        });

        return response()->noContent();
    }

    public function select(Request $request)
    {
        $validated = $request->validate(['theme' => ['required', 'string', Rule::in(array_keys(config('kado.themes')))]]);
        $user = $request->user();
        abort_unless($user->hasTheme($validated['theme']), 422, 'Vous devez d\'abord acheter ce thème.');

        $user->update(['theme' => $validated['theme']]);

        return response()->noContent();
    }
}

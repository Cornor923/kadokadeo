<?php

namespace Tests\Concerns;

use App\Models\Game;
use Illuminate\Support\Facades\Gate;

// a run begins only on a game that can be opened (GamePolicy::view: active, with its bundle in public/gamesdata, not
// built in the tests): the bundle is taken as there for the active games of the factory
trait PlayableGames
{
    protected function setUpPlayableGames(): void
    {
        Gate::before(fn ($user, string $ability, array $arguments) => $ability === 'view' && ($arguments[0] ?? null) instanceof Game && $arguments[0]->is_active
            ? true
            : null);
    }
}

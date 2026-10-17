<?php

namespace App\Policies;

use App\Models\User;
use Illuminate\Auth\Access\HandlesAuthorization;

class RunPolicy
{
    use HandlesAuthorization;

    /**
     * Create a new policy instance.
     */
    public function create(User $user)
    {
        if (config('kado.games_per_day') > 0 && $user->kado_games <= 0) {
            return $this->deny('Vous n\'avez plus de parties aujourd\'hui : revenez demain !');
        }

        return $this->allow();
    }

    public function view(User $user, $run)
    {
        if (!$run->replay) {
            return $this->deny('No replay for this run');
        }

        if ($run->isHiddenDailyFor($user)) {
            return $this->deny('The replays of the daily game are shown the next day');
        }

        return $this->allow();
    }
}

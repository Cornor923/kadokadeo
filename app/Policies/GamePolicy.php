<?php

namespace App\Policies;

use App\Models\DailyGame;
use App\Models\Game;
use App\Models\User;
use Illuminate\Auth\Access\HandlesAuthorization;

class GamePolicy
{
    use HandlesAuthorization;

    // playDaily: the daily game was already played today (it can be played again outside the production)
    public const DAILY_ALREADY_PLAYED = 'daily_already_played';

    public function view(User $user, Game $game)
    {
        if (!$game->is_active) {
            return $this->deny('Game not active');
        }

        if (!$game->gamedata) {
            return $this->deny('Game data not available');
        }

        return $this->allow();
    }

    public function playDaily(User $user, Game $game)
    {
        $dailyGame = DailyGame::where('day', now()->today())
            ->where('game_id', $game->id)
            ->first();

        if (!$dailyGame) {
            return $this->deny('Ce jeu n\'est pas la partie du jour.');
        }

        $alreadyPlayed = $dailyGame->runs()
            ->where('user_id', $user->id)
            ->exists();

        if ($alreadyPlayed) {
            return $this->deny('Vous avez déjà joué la partie du jour : revenez demain !', self::DAILY_ALREADY_PLAYED);
        }

        return $this->allow();
    }
}

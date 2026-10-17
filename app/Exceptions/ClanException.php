<?php

namespace App\Exceptions;

use Illuminate\Http\JsonResponse;
use RuntimeException;

// a rule of the clans not respected (App\Services\ClanService): its message is shown to the player
class ClanException extends RuntimeException
{
    // a rule of the game, not an error to log
    public function report(): void {}

    public function render(): JsonResponse
    {
        return response()->json(['message' => $this->getMessage()], 422);
    }
}

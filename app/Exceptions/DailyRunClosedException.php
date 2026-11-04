<?php

namespace App\Exceptions;

use Illuminate\Http\JsonResponse;
use RuntimeException;

// a run of the daily game finished after the end of its period: the ranking is frozen (App\Services\DailyRankingService).
// A 409 as RunAlreadyCompletedException: the site drops it from the runs to send again (stores/pendingRuns.js)
class DailyRunClosedException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('La période de ce jeu du jour est terminée.');
    }

    // not an error to log
    public function report(): void {}

    public function render(): JsonResponse
    {
        return response()->json(['message' => $this->getMessage()], 409);
    }
}

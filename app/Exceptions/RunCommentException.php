<?php

namespace App\Exceptions;

use Illuminate\Http\JsonResponse;
use RuntimeException;

// a rule of the comments of the replays or of the reports not respected (App\Services\RunCommentService,
// App\Services\ReportService): its message is shown to the player
class RunCommentException extends RuntimeException
{
    // a rule, not an error to log
    public function report(): void {}

    public function render(): JsonResponse
    {
        return response()->json(['message' => $this->getMessage()], 422);
    }
}

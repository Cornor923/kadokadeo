<?php

namespace App\Exceptions;

use Illuminate\Http\JsonResponse;
use RuntimeException;

// a run sent again (offline retry, lost response, two requests at once) once it is finished (App\Services\RunService)
class RunAlreadyCompletedException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Partie déjà terminée.');
    }

    // not an error to log
    public function report(): void {}

    public function render(): JsonResponse
    {
        return response()->json(['message' => $this->getMessage()], 409);
    }
}

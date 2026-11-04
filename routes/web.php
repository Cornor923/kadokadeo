<?php

use App\Http\Controllers\GameBuildController;
use App\Http\Controllers\LoginController;
use Illuminate\Support\Facades\Route;

Route::get('/login', [LoginController::class, 'login'])->name('login');

// bundle of an old version of a game, for the replays recorded with it (rebuilt from the archive)
Route::get('/gamesdata/builds/{game}/{file}', [GameBuildController::class, 'bundle'])
    ->where(['game' => '[a-z0-9]+', 'file' => '[0-9a-f]{12}\.js'])
    ->name('game-builds.bundle');

Route::fallback(fn () => view('layouts.default'));

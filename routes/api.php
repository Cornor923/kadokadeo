<?php

use Illuminate\Support\Facades\Route;

Route::get('/oauth/callback', [App\Http\Controllers\LoginController::class, 'loginCallback']);
Route::post('/logout', [App\Http\Controllers\LoginController::class, 'logout']);

Route::get('/user', [App\Http\Controllers\Api\UserController::class, 'index']);
Route::get('/users/{user:etwin_id}', [App\Http\Controllers\Api\UserController::class, 'show'])->whereUuid('etwin_id');
Route::get('/users/{user:etwin_id}/history', [App\Http\Controllers\Api\UserController::class, 'showHistory'])->whereUuid('etwin_id');

Route::get('/announcement', [App\Http\Controllers\Api\AnnouncementController::class, 'show'])
    ->middleware('cache.headers:public;max_age=60;etag');
Route::get('/achievements', [App\Http\Controllers\Api\AchievementController::class, 'index']);

Route::get('/period/current', [App\Http\Controllers\Api\PeriodController::class, 'current']);
Route::get('/competition', [App\Http\Controllers\Api\GameScoreController::class, 'competition']);
Route::get('/competition/poids-plumes', [App\Http\Controllers\Api\GameScoreController::class, 'poidsPlumes']);

Route::get('/daily/game', [App\Http\Controllers\Api\GameController::class, 'daily']);
Route::get('/daily/scores', [App\Http\Controllers\Api\GameScoreController::class, 'dailyScores']);
Route::get('/site-records', [App\Http\Controllers\Api\GameScoreController::class, 'siteRecords']);
Route::get('/user-records', [App\Http\Controllers\Api\GameScoreController::class, 'personalRecords']);

Route::resource('/games', App\Http\Controllers\Api\GameController::class)->only(['index', 'show'])->whereNumber('game');
Route::put('/games/{game}/favorite', [App\Http\Controllers\Api\GameController::class, 'setFavorite'])->whereNumber('game');
Route::get('/games/{game}/scores', [App\Http\Controllers\Api\GameScoreController::class, 'index'])->whereNumber('game');
Route::get('/games/{game}/period-records', [App\Http\Controllers\Api\GameScoreController::class, 'userPeriodRecords'])->whereNumber('game');
Route::get('/games/{game}/ranking', [App\Http\Controllers\Api\GameScoreController::class, 'search'])->whereNumber('game');

// tools to try the clans alone (kado.debug_tools, never in production)
Route::prefix('/debug/clans')->group(function () {
    Route::get('/', [App\Http\Controllers\Api\DebugClanController::class, 'index']);
    Route::post('/attack', [App\Http\Controllers\Api\DebugClanController::class, 'attack']);
    Route::post('/attacks/{attack}/defend', [App\Http\Controllers\Api\DebugClanController::class, 'defend'])->whereNumber('attack');
    Route::post('/mission-steps/{step}', [App\Http\Controllers\Api\DebugClanController::class, 'missionStep'])->whereNumber('step');
    Route::post('/time', [App\Http\Controllers\Api\DebugClanController::class, 'time']);
    Route::post('/end-period', [App\Http\Controllers\Api\DebugClanController::class, 'endPeriod']);
});

// the private messages
Route::get('/messages', [App\Http\Controllers\Api\MessageController::class, 'index']);
Route::get('/messages/unread', [App\Http\Controllers\Api\MessageController::class, 'unread']);
Route::post('/messages', [App\Http\Controllers\Api\MessageController::class, 'store']);
Route::get('/messages/{message}', [App\Http\Controllers\Api\MessageController::class, 'show'])->whereNumber('message');
Route::delete('/messages/{message}', [App\Http\Controllers\Api\MessageController::class, 'destroy'])->whereNumber('message');

// the forum of Eternaltwin, called as the player (Eternaltwin sends no CORS headers)
Route::prefix('/etwin-forum')->group(function () {
    Route::get('/status', [App\Http\Controllers\Api\EtwinForumController::class, 'status']);
    Route::get('/config', [App\Http\Controllers\Api\EtwinForumController::class, 'config']);
    Route::get('/{path}', [App\Http\Controllers\Api\EtwinForumController::class, 'read'])->where('path', '.+');
    Route::post('/{path}', [App\Http\Controllers\Api\EtwinForumController::class, 'write'])->where('path', '.+');
    Route::patch('/{path}', [App\Http\Controllers\Api\EtwinForumController::class, 'write'])->where('path', '.+');
});

// the looks of the site, bought with Kado points
Route::get('/themes', [App\Http\Controllers\Api\ThemeController::class, 'index']);
Route::post('/themes/{theme}/buy', [App\Http\Controllers\Api\ThemeController::class, 'buy'])->whereAlpha('theme');
Route::put('/user/theme', [App\Http\Controllers\Api\ThemeController::class, 'select']);

// the clans (App\Services\ClanService)
Route::get('/clans', [App\Http\Controllers\Api\ClanController::class, 'index']);
Route::post('/clans', [App\Http\Controllers\Api\ClanController::class, 'store']);
Route::get('/clans/overview', [App\Http\Controllers\Api\ClanController::class, 'overview']);
Route::get('/clan-games', [App\Http\Controllers\Api\ClanGameController::class, 'index']);
Route::post('/clan-games/buy', [App\Http\Controllers\Api\ClanGameController::class, 'buy']);
Route::post('/clans/leave', [App\Http\Controllers\Api\ClanMemberController::class, 'leave']);
Route::prefix('/clans/{clan}')->whereNumber('clan')->group(function () {
    Route::get('/', [App\Http\Controllers\Api\ClanController::class, 'show']);
    Route::put('/', [App\Http\Controllers\Api\ClanController::class, 'update']);
    Route::get('/members', [App\Http\Controllers\Api\ClanController::class, 'members']);
    Route::get('/status', [App\Http\Controllers\Api\ClanController::class, 'status']);
    Route::get('/history', [App\Http\Controllers\Api\ClanController::class, 'history']);
    Route::get('/missions', [App\Http\Controllers\Api\ClanMissionController::class, 'index']);
    Route::get('/applications', [App\Http\Controllers\Api\ClanMemberController::class, 'applications']);
    Route::post('/applications', [App\Http\Controllers\Api\ClanMemberController::class, 'apply']);
    Route::post('/members/{user:etwin_id}/kick', [App\Http\Controllers\Api\ClanMemberController::class, 'kick'])->whereUuid('user');
    Route::post('/members/{user:etwin_id}/leader', [App\Http\Controllers\Api\ClanMemberController::class, 'promote'])->whereUuid('user');
    Route::put('/members/{user:etwin_id}/role', [App\Http\Controllers\Api\ClanMemberController::class, 'role'])->whereUuid('user');
    Route::put('/members/{user:etwin_id}/combat-role', [App\Http\Controllers\Api\ClanMemberController::class, 'combatRole'])->whereUuid('user');
    Route::put('/members/{user:etwin_id}/status', [App\Http\Controllers\Api\ClanMemberController::class, 'status'])->whereUuid('user');
    Route::delete('/', [App\Http\Controllers\Api\ClanMemberController::class, 'dissolve']);
    Route::post('/games/donate', [App\Http\Controllers\Api\ClanGameController::class, 'donate']);
    Route::post('/members/{user:etwin_id}/games', [App\Http\Controllers\Api\ClanGameController::class, 'distribute'])->whereUuid('user');
    Route::post('/attacks', [App\Http\Controllers\Api\ClanWarController::class, 'attack']);
    Route::post('/war', [App\Http\Controllers\Api\ClanWarController::class, 'declareWar']);
    Route::delete('/war', [App\Http\Controllers\Api\ClanWarController::class, 'endWar']);
    // the private forum of the clan (App\Services\ClanForumService)
    Route::prefix('/forum')->group(function () {
        Route::get('/topics', [App\Http\Controllers\Api\ClanForumController::class, 'index']);
        Route::post('/topics', [App\Http\Controllers\Api\ClanForumController::class, 'store']);
        Route::get('/topics/{topic}', [App\Http\Controllers\Api\ClanForumController::class, 'show'])->whereNumber('topic');
        Route::patch('/topics/{topic}', [App\Http\Controllers\Api\ClanForumController::class, 'update'])->whereNumber('topic');
        Route::delete('/topics/{topic}', [App\Http\Controllers\Api\ClanForumController::class, 'destroy'])->whereNumber('topic');
        Route::post('/topics/{topic}/messages', [App\Http\Controllers\Api\ClanForumController::class, 'reply'])->whereNumber('topic');
        Route::patch('/messages/{message}', [App\Http\Controllers\Api\ClanForumController::class, 'updateMessage'])->whereNumber('message');
        Route::delete('/messages/{message}', [App\Http\Controllers\Api\ClanForumController::class, 'destroyMessage'])->whereNumber('message');
        Route::post('/messages/{message}/restore', [App\Http\Controllers\Api\ClanForumController::class, 'restoreMessage'])->whereNumber('message');
    });
});
Route::delete('/clan-applications/{application}', [App\Http\Controllers\Api\ClanMemberController::class, 'cancel'])->whereNumber('application');
Route::post('/clan-applications/{application}/accept', [App\Http\Controllers\Api\ClanMemberController::class, 'accept'])->whereNumber('application');
Route::post('/clan-applications/{application}/refuse', [App\Http\Controllers\Api\ClanMemberController::class, 'refuse'])->whereNumber('application');
Route::post('/clan-attacks/{attack}/improve', [App\Http\Controllers\Api\ClanWarController::class, 'improve'])->whereNumber('attack');
Route::post('/clan-attacks/{attack}/defend', [App\Http\Controllers\Api\ClanWarController::class, 'defend'])->whereNumber('attack');
Route::post('/clan-attacks/{attack}/reserve', [App\Http\Controllers\Api\ClanWarController::class, 'reserve'])->whereNumber('attack');
Route::post('/clan-attacks/{attack}/cancel', [App\Http\Controllers\Api\ClanWarController::class, 'cancel'])->whereNumber('attack');
Route::post('/clan-mission-steps/{step}/reserve', [App\Http\Controllers\Api\ClanMissionController::class, 'reserve'])->whereNumber('step');
Route::post('/clan-mission-steps/{step}/play', [App\Http\Controllers\Api\ClanMissionController::class, 'play'])->whereNumber('step');
Route::post('/clan-bonuses/{bonus}/use', [App\Http\Controllers\Api\ClanMissionController::class, 'useBonus'])->whereNumber('bonus');
Route::get('/clan-actions/{action}', [App\Http\Controllers\Api\ClanActionController::class, 'show'])->whereNumber('action');
Route::post('/clan-actions/{action}/cancel', [App\Http\Controllers\Api\ClanActionController::class, 'cancel'])->whereNumber('action');
Route::post('/clan-actions/{action}/again', [App\Http\Controllers\Api\ClanActionController::class, 'again'])->whereNumber('action');

Route::prefix('/runs')->group(function () {
    Route::get('/public-key', [App\Http\Controllers\Api\RunController::class, 'publicKey']);
    Route::get('/{run}', [App\Http\Controllers\Api\RunController::class, 'show'])->whereUlid('run');
    Route::post('/games/{game}', [App\Http\Controllers\Api\RunController::class, 'begin'])->whereNumber('game');
    Route::post('/{run}/finish', [App\Http\Controllers\Api\RunController::class, 'end'])->whereUlid('run');
});

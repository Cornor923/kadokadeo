<?php

use App\Http\Controllers\Api\AchievementController;
use App\Http\Controllers\Api\AnnouncementController;
use App\Http\Controllers\Api\ClanActionController;
use App\Http\Controllers\Api\ClanController;
use App\Http\Controllers\Api\ClanForumController;
use App\Http\Controllers\Api\ClanGameController;
use App\Http\Controllers\Api\ClanMemberController;
use App\Http\Controllers\Api\ClanMissionController;
use App\Http\Controllers\Api\ClanWarController;
use App\Http\Controllers\Api\DebugClanController;
use App\Http\Controllers\Api\EtwinForumController;
use App\Http\Controllers\Api\GameController;
use App\Http\Controllers\Api\GameScoreController;
use App\Http\Controllers\Api\MessageController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PeriodController;
use App\Http\Controllers\Api\RunCommentController;
use App\Http\Controllers\Api\RunController;
use App\Http\Controllers\Api\ThemeController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\UserPreferenceController;
use App\Http\Controllers\LoginController;
use App\Http\Middleware\EnsureClansAreEnabled;
use Illuminate\Support\Facades\Route;

Route::get('/oauth/callback', [LoginController::class, 'loginCallback']);
Route::post('/logout', [LoginController::class, 'logout']);

Route::get('/user', [UserController::class, 'index']);
Route::get('/users/{user:etwin_id}', [UserController::class, 'show'])->whereUuid('etwin_id');
Route::get('/users/{user:etwin_id}/history', [UserController::class, 'showHistory'])->whereUuid('etwin_id');
Route::get('/users/{user:etwin_id}/records', [GameScoreController::class, 'userRecords'])->whereUuid('etwin_id');
Route::get('/users/{user:etwin_id}/periods/{period?}', [UserController::class, 'showPeriod'])->whereUuid('etwin_id')->whereNumber('period');

Route::get('/announcement', [AnnouncementController::class, 'show'])
    ->middleware('cache.headers:public;max_age=60;etag');
Route::get('/achievements', [AchievementController::class, 'index']);

Route::get('/period/current', [PeriodController::class, 'current']);
Route::get('/competition', [GameScoreController::class, 'competition']);
Route::get('/competition/poids-plumes', [GameScoreController::class, 'poidsPlumes']);

Route::get('/daily/game', [GameController::class, 'daily']);
Route::get('/daily/scores', [GameScoreController::class, 'dailyScores']);
Route::get('/daily/standings', [GameScoreController::class, 'dailyStandings']);
Route::get('/site-records', [GameScoreController::class, 'siteRecords']);

Route::resource('/games', GameController::class)->only(['index', 'show'])->whereNumber('game');
Route::put('/games/{game}/favorite', [GameController::class, 'setFavorite'])->whereNumber('game');
Route::get('/games/{game}/scores', [GameScoreController::class, 'index'])->whereNumber('game');
Route::get('/games/{game}/period-records', [GameScoreController::class, 'userPeriodRecords'])->whereNumber('game');
Route::get('/games/{game}/ranking', [GameScoreController::class, 'search'])->whereNumber('game');

// tools to try the clans alone (kado.debug_tools, never in production)
Route::prefix('/debug/clans')->middleware(EnsureClansAreEnabled::class)->group(function () {
    Route::get('/', [DebugClanController::class, 'index']);
    Route::post('/attack', [DebugClanController::class, 'attack']);
    Route::post('/attacks/{attack}/defend', [DebugClanController::class, 'defend'])->whereNumber('attack');
    Route::post('/mission-steps/{step}', [DebugClanController::class, 'missionStep'])->whereNumber('step');
    Route::post('/time', [DebugClanController::class, 'time']);
    Route::post('/end-period', [DebugClanController::class, 'endPeriod']);
});

// the private messages
Route::get('/messages', [MessageController::class, 'index']);
Route::get('/messages/unread', [MessageController::class, 'unread']);
Route::post('/messages', [MessageController::class, 'store']);
Route::get('/messages/{message}', [MessageController::class, 'show'])->whereNumber('message');
Route::delete('/messages/{message}', [MessageController::class, 'destroy'])->whereNumber('message');

// the notifications of the player (the tab « Notifications » of the messages) and his preferences
Route::get('/notifications', [NotificationController::class, 'index']);
Route::get('/notifications/unread', [NotificationController::class, 'unread']);
Route::post('/notifications/read', [NotificationController::class, 'read']);
Route::delete('/notifications', [NotificationController::class, 'destroyAll']);
Route::delete('/notifications/{notification}', [NotificationController::class, 'destroy'])->whereNumber('notification');
Route::put('/user/preferences', [UserPreferenceController::class, 'update']);

// the forum of Eternaltwin, called as the player (Eternaltwin sends no CORS headers)
Route::prefix('/etwin-forum')->group(function () {
    Route::get('/status', [EtwinForumController::class, 'status']);
    Route::get('/config', [EtwinForumController::class, 'config']);
    Route::get('/{path}', [EtwinForumController::class, 'read'])->where('path', '.+');
    Route::post('/{path}', [EtwinForumController::class, 'write'])->where('path', '.+');
    Route::patch('/{path}', [EtwinForumController::class, 'write'])->where('path', '.+');
});

// the looks of the site, bought with Kado points
Route::get('/themes', [ThemeController::class, 'index']);
Route::post('/themes/{theme}/buy', [ThemeController::class, 'buy'])->whereAlpha('theme');
Route::put('/user/theme', [ThemeController::class, 'select']);

// the clans (App\Services\ClanService) (refused while they are turned off in the admin)
Route::middleware(EnsureClansAreEnabled::class)->group(function () {
    Route::get('/clans', [ClanController::class, 'index']);
    Route::post('/clans', [ClanController::class, 'store']);
    Route::get('/clans/overview', [ClanController::class, 'overview']);
    Route::get('/clan-games', [ClanGameController::class, 'index']);
    Route::post('/clan-games/buy', [ClanGameController::class, 'buy']);
    Route::post('/clans/leave', [ClanMemberController::class, 'leave']);
    Route::prefix('/clans/{clan}')->whereNumber('clan')->group(function () {
        Route::get('/', [ClanController::class, 'show']);
        Route::put('/', [ClanController::class, 'update']);
        Route::get('/members', [ClanController::class, 'members']);
        Route::get('/status', [ClanController::class, 'status']);
        Route::get('/history', [ClanController::class, 'history']);
        Route::get('/missions', [ClanMissionController::class, 'index']);
        Route::get('/applications', [ClanMemberController::class, 'applications']);
        Route::post('/applications', [ClanMemberController::class, 'apply']);
        Route::post('/members/{user:etwin_id}/kick', [ClanMemberController::class, 'kick'])->whereUuid('user');
        Route::post('/members/{user:etwin_id}/leader', [ClanMemberController::class, 'promote'])->whereUuid('user');
        Route::put('/members/{user:etwin_id}/role', [ClanMemberController::class, 'role'])->whereUuid('user');
        Route::put('/members/{user:etwin_id}/combat-role', [ClanMemberController::class, 'combatRole'])->whereUuid('user');
        Route::put('/members/{user:etwin_id}/status', [ClanMemberController::class, 'status'])->whereUuid('user');
        Route::delete('/', [ClanMemberController::class, 'dissolve']);
        Route::post('/games/donate', [ClanGameController::class, 'donate']);
        Route::post('/members/{user:etwin_id}/games', [ClanGameController::class, 'distribute'])->whereUuid('user');
        Route::post('/attacks', [ClanWarController::class, 'attack']);
        Route::post('/war', [ClanWarController::class, 'declareWar']);
        Route::delete('/war', [ClanWarController::class, 'endWar']);
        // the private forum of the clan (App\Services\ClanForumService)
        Route::prefix('/forum')->group(function () {
            Route::get('/topics', [ClanForumController::class, 'index']);
            Route::post('/topics', [ClanForumController::class, 'store']);
            Route::get('/topics/{topic}', [ClanForumController::class, 'show'])->whereNumber('topic');
            Route::patch('/topics/{topic}', [ClanForumController::class, 'update'])->whereNumber('topic');
            Route::delete('/topics/{topic}', [ClanForumController::class, 'destroy'])->whereNumber('topic');
            Route::post('/topics/{topic}/messages', [ClanForumController::class, 'reply'])->whereNumber('topic');
            Route::patch('/messages/{message}', [ClanForumController::class, 'updateMessage'])->whereNumber('message');
            Route::delete('/messages/{message}', [ClanForumController::class, 'destroyMessage'])->whereNumber('message');
            Route::post('/messages/{message}/restore', [ClanForumController::class, 'restoreMessage'])->whereNumber('message');
        });
    });
    Route::delete('/clan-applications/{application}', [ClanMemberController::class, 'cancel'])->whereNumber('application');
    Route::post('/clan-applications/{application}/accept', [ClanMemberController::class, 'accept'])->whereNumber('application');
    Route::post('/clan-applications/{application}/refuse', [ClanMemberController::class, 'refuse'])->whereNumber('application');
    Route::post('/clan-attacks/{attack}/improve', [ClanWarController::class, 'improve'])->whereNumber('attack');
    Route::post('/clan-attacks/{attack}/defend', [ClanWarController::class, 'defend'])->whereNumber('attack');
    Route::post('/clan-attacks/{attack}/reserve', [ClanWarController::class, 'reserve'])->whereNumber('attack');
    Route::post('/clan-attacks/{attack}/cancel', [ClanWarController::class, 'cancel'])->whereNumber('attack');
    Route::post('/clan-mission-steps/{step}/reserve', [ClanMissionController::class, 'reserve'])->whereNumber('step');
    Route::post('/clan-mission-steps/{step}/play', [ClanMissionController::class, 'play'])->whereNumber('step');
    Route::post('/clan-bonuses/{bonus}/use', [ClanMissionController::class, 'useBonus'])->whereNumber('bonus');
    Route::get('/clan-actions/{action}', [ClanActionController::class, 'show'])->whereNumber('action');
    Route::post('/clan-actions/{action}/cancel', [ClanActionController::class, 'cancel'])->whereNumber('action');
    Route::post('/clan-actions/{action}/again', [ClanActionController::class, 'again'])->whereNumber('action');
});

Route::prefix('/runs')->group(function () {
    Route::get('/public-key', [RunController::class, 'publicKey']);
    Route::get('/{run}', [RunController::class, 'show'])->whereUlid('run');
    Route::post('/games/{game}', [RunController::class, 'begin'])->whereNumber('game');
    Route::post('/{run}/finish', [RunController::class, 'end'])->whereUlid('run');
    Route::post('/{run}/reroll', [RunController::class, 'reroll'])->whereUlid('run');
    Route::get('/{run}/comments', [RunCommentController::class, 'index'])->whereUlid('run');
    Route::post('/{run}/comments', [RunCommentController::class, 'store'])->whereUlid('run');
    Route::post('/{run}/view', [RunCommentController::class, 'view'])->whereUlid('run');
});

Route::prefix('/run-comments/{comment}')->whereNumber('comment')->group(function () {
    Route::patch('/', [RunCommentController::class, 'update']);
    Route::delete('/', [RunCommentController::class, 'destroy']);
    Route::put('/like', [RunCommentController::class, 'like']);
    Route::delete('/like', [RunCommentController::class, 'unlike']);
    Route::post('/report', [RunCommentController::class, 'report']);
});

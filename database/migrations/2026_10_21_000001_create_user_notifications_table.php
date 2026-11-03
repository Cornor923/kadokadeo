<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class() extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // the notifications of a player (App\Services\NotificationService), next to his private messages, gone after two
        // months (App\Models\UserNotification::prunable)
        Schema::create('user_notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // App\Enums\NotificationType
            $table->string('type', 32);
            // the player who did it (the last one for the grouped ones)
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            // what it is about: gone with it
            $table->foreignUlid('run_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('comment_id')->nullable()->constrained('run_comments')->cascadeOnDelete();
            $table->foreignId('clan_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('clan_application_id')->nullable()->constrained()->cascadeOnDelete();
            // the likes of a comment in one notification: their count, the key it is found again by ("likes:<comment>")
            $table->unsignedInteger('count')->default(1);
            $table->string('group_key', 64)->nullable();
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'group_key']);
            $table->index(['user_id', 'updated_at']);
            $table->index('updated_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('user_notifications');
    }
};

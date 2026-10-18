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
        // the private forum of a clan (App\Services\ClanForumService): read and written by its members, moderated by its
        // leader and its right hands
        Schema::create('clan_forum_topics', function (Blueprint $table) {
            $table->id();
            $table->foreignId('clan_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('title', 100);
            // a "post-it": shown above the other topics
            $table->boolean('is_pinned')->default(false);
            // only the leader and the right hands can still answer
            $table->boolean('is_locked')->default(false);
            // the answers (the messages after the first one): the "Msg" column of the old forum
            $table->unsignedInteger('replies_count')->default(0);
            $table->unsignedBigInteger('last_message_id')->nullable();
            $table->foreignId('last_message_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('last_message_at')->nullable();
            $table->timestamps();

            $table->index(['clan_id', 'is_pinned', 'last_message_at']);
        });

        // the messages, written in Marktwin (rendered by the client): a message deleted by a moderator is kept, to be
        // restored
        Schema::create('clan_forum_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('topic_id')->constrained('clan_forum_topics')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->text('content');
            $table->timestamp('edited_at')->nullable();
            $table->foreignId('edited_by')->nullable()->constrained('users')->nullOnDelete();
            $table->softDeletes();
            $table->foreignId('deleted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['topic_id', 'id']);
        });

        // the last message read by a player in a topic: the topic is unread when a newer message was posted
        Schema::create('clan_forum_reads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('topic_id')->constrained('clan_forum_topics')->cascadeOnDelete();
            $table->unsignedBigInteger('last_read_message_id');
            $table->timestamps();

            $table->unique(['user_id', 'topic_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('clan_forum_reads');
        Schema::dropIfExists('clan_forum_messages');
        Schema::dropIfExists('clan_forum_topics');
    }
};

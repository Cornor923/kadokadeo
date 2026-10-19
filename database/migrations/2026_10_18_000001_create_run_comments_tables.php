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
        // the comments of a replay (App\Services\RunCommentService), each one at a frame of the replay; the answers (one
        // level) have the frame of the comment they answer. A deleted comment is kept, to be restored from the admin.
        Schema::create('run_comments', function (Blueprint $table) {
            $table->id();
            $table->foreignUlid('run_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('parent_id')->nullable()->constrained('run_comments')->cascadeOnDelete();
            $table->unsignedInteger('frame');
            $table->string('content', 1000);
            $table->unsignedInteger('likes_count')->default(0);
            // the answers not deleted
            $table->unsignedInteger('replies_count')->default(0);
            $table->timestamp('edited_at')->nullable();
            $table->softDeletes();
            $table->foreignId('deleted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['run_id', 'parent_id', 'frame']);
            $table->index(['user_id', 'run_id']);
        });

        // who likes a comment (run_comments.likes_count counts them)
        Schema::create('run_comment_likes', function (Blueprint $table) {
            $table->foreignId('comment_id')->constrained('run_comments')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamp('created_at')->nullable();

            $table->primary(['comment_id', 'user_id']);
            $table->index('user_id');
        });

        // who watched a replay (App\Services\RunViewService): one view by player, runs.views_count counts them
        Schema::create('run_views', function (Blueprint $table) {
            $table->foreignUlid('run_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->timestamp('created_at')->nullable();

            $table->primary(['run_id', 'user_id']);
            $table->index('user_id');
        });

        Schema::table('runs', function (Blueprint $table) {
            $table->unsignedInteger('views_count')->default(0);
            // the comments not deleted, answers included
            $table->unsignedInteger('comments_count')->default(0);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('runs', function (Blueprint $table) {
            $table->dropColumn(['views_count', 'comments_count']);
        });
        Schema::dropIfExists('run_views');
        Schema::dropIfExists('run_comment_likes');
        Schema::dropIfExists('run_comments');
    }
};

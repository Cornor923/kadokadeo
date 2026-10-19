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
        // the reports of the players on a content (App\Services\ReportService, App\Contracts\Reportable): the queue
        // « Modération > Signalements » of the admin. One report by player and content.
        Schema::create('reports', function (Blueprint $table) {
            $table->id();
            // the alias of the morph map (AppServiceProvider), e.g. "run_comment"
            $table->string('reportable_type', 32);
            $table->string('reportable_id', 36);
            $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
            // the author of the content when it was reported (the content can be deleted since)
            $table->foreignId('reported_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('reason', 32);
            $table->string('details', 500)->nullable();
            $table->string('status', 16)->default('open');
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();

            $table->unique(['reportable_type', 'reportable_id', 'reporter_id']);
            $table->index(['status', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('reports');
    }
};

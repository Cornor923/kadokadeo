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
        // the players seen each day (App\Models\SiteVisit)
        Schema::create('site_visits', function (Blueprint $table) {
            $table->id();
            $table->date('date');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('device', 16);
            $table->string('browser', 16);
            $table->char('country', 2);

            $table->unique(['date', 'user_id', 'device', 'browser', 'country']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('site_visits');
    }
};

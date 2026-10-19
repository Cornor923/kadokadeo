<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// the Kado points paid for an application (ClanSettings::$application_price when it was sent), given back once when the
// clan refuses it or it is cancelled
return new class() extends Migration
{
    public function up(): void
    {
        Schema::table('clan_applications', function (Blueprint $table) {
            $table->unsignedInteger('cost')->default(0)->after('status');
            $table->timestamp('refunded_at')->nullable()->after('cost');
        });
    }

    public function down(): void
    {
        Schema::table('clan_applications', function (Blueprint $table) {
            $table->dropColumn(['cost', 'refunded_at']);
        });
    }
};

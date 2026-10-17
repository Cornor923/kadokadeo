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
        // the access token of Eternaltwin given at the login (encrypted), and its scopes (/api/v1/auth/self): the forum
        // of Eternaltwin is called with it, as the player (App\Http\Controllers\Api\EtwinForumController)
        Schema::table('users', function (Blueprint $table) {
            $table->text('etwin_access_token')->nullable();
            $table->json('etwin_scopes')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['etwin_access_token', 'etwin_scopes']);
        });
    }
};

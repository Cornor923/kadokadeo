<?php

namespace App\Http\Requests;

use App\Models\Run;
use App\Settings\SiteSettings;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Auth;

class RunStartRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        $configConcurrency = app(SiteSettings::class)->runs_max_concurrency;
        if ($configConcurrency == -1) {
            return true;
        }

        $currentRunCount = Run::where('user_id', Auth::id())
            ->whereNull('completed_at')
            ->where('created_at', '>', now()->subMinutes(app(SiteSettings::class)->runs_open_minutes))
            ->count();

        return $currentRunCount < $configConcurrency;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'daily' => 'sometimes|required|accepted',
            // version of the game bundle (hash of the manifest), to play the replay with the same version
            'build' => ['sometimes', 'nullable', 'string', 'regex:/^[0-9a-f]{12}$/'],
            // the clan run of the page where the game is played (/clans/play/{action}): ClanRunService::pageAction
            'clan_action' => ['sometimes', 'nullable', 'integer'],
        ];
    }
}

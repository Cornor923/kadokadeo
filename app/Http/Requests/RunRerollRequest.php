<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

// "Changer de partie": no concurrency check (RunStartRequest), the run begun is replaced
class RunRerollRequest extends FormRequest
{
    public function authorize(): bool
    {
        return (int) $this->route('run')->user_id === (int) $this->user()->id;
    }

    /**
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            // version of the game bundle (hash of the manifest), to play the replay with the same version
            'build' => ['sometimes', 'nullable', 'string', 'regex:/^[0-9a-f]{12}$/'],
        ];
    }
}

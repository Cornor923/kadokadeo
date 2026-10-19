<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class RunEndRequest extends FormRequest
{
    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        // the payload: base64 of the IV and the encrypted JSON (the replay, kado.replay_max_length, and the score and
        // its data), a third more than what it holds
        $maxPayload = intdiv((int) config('kado.replay_max_length') * 4, 3) + 1_000_000;

        return [
            'payload' => 'required|string|max:'.$maxPayload, // encrypted with AES
            'key' => 'required|string|max:2048', // AES key, encrypted with server's public key (base64 of an RSA block)
            'sign' => 'required|string|max:255', // signed with AES key (base64 of a HMAC-SHA256)
        ];
    }
}

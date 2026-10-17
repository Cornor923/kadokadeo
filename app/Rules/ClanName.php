<?php

namespace App\Rules;

use App\Models\Clan;
use Closure;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Support\Facades\DB;

// the name of a clan: only the characters drawn with the letters of the old site (resources/js/components/clan/Name.vue,
// scripts/clan_letters.py): letters (the accents are dropped), digits, spaces and - ' . ! ?, at least a letter, and not
// the name of another clan whatever the case
class ClanName implements ValidationRule
{
    // after the accents are dropped and in lower case
    private const CHARACTERS = '/^[a-z0-9 \-\'’.!?]+$/u';

    public function __construct(private readonly ?int $ignoreClanId = null) {}

    // the spaces at the ends removed, several spaces in a row as one
    public static function normalize(mixed $name): mixed
    {
        return is_string($name) ? preg_replace('/\s+/u', ' ', trim($name)) : $name;
    }

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (!is_string($value)) {
            return;
        }

        $plain = mb_strtolower(preg_replace('/\p{Mn}/u', '', \Normalizer::normalize($value, \Normalizer::FORM_D)));
        if (!preg_match(self::CHARACTERS, $plain)) {
            $fail('Le nom du clan ne peut contenir que des lettres, des chiffres, des espaces et les signes - \' . ! ?');

            return;
        }
        if (!preg_match('/[a-z]/', $plain)) {
            $fail('Le nom du clan doit contenir au moins une lettre.');

            return;
        }

        $taken = Clan::query()
            ->where(DB::raw('lower(name)'), mb_strtolower($value))
            ->when($this->ignoreClanId, fn ($query) => $query->whereKeyNot($this->ignoreClanId))
            ->exists();
        if ($taken) {
            $fail('Ce nom de clan est déjà pris.');
        }
    }
}

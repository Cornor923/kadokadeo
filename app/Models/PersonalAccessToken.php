<?php

namespace App\Models;

use Laravel\Sanctum\PersonalAccessToken as SanctumPersonalAccessToken;

// the tokens of the players (Sanctum): Sanctum writes last_used_at at each request of the API (the pages poll it every
// minute), it is only written here when the time kept is LAST_USED_EVERY_SECONDS old
class PersonalAccessToken extends SanctumPersonalAccessToken
{
    private const LAST_USED_EVERY_SECONDS = 300;

    public function save(array $options = [])
    {
        if ($this->exists && array_keys($this->getDirty()) === ['last_used_at']) {
            $kept = $this->getOriginal('last_used_at');
            if ($kept !== null && $this->last_used_at !== null && $kept->diffInSeconds($this->last_used_at, true) < self::LAST_USED_EVERY_SECONDS) {
                return true;
            }
        }

        return parent::save($options);
    }
}

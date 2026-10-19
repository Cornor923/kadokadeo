<?php

namespace Tests\Concerns;

use App\Settings\ClanSettings;

// the clans are off until they open (App\Http\Middleware\EnsureClansAreEnabled): turned on for the tests of the clans
trait EnablesClans
{
    protected function setUpEnablesClans(): void
    {
        $this->setClansEnabled(true);
    }

    protected function setClansEnabled(bool $enabled): void
    {
        $settings = app(ClanSettings::class);
        $settings->enabled = $enabled;
        $settings->save();
    }
}

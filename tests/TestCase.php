<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Spatie\LaravelSettings\Settings;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        // what the app defers after the response (the events of the realtime, App\Support\RealtimeOutbox) runs at once:
        // the tests that call a service see them ($this->withDefer() to test the deferring)
        $this->withoutDefer();
    }

    /**
     * Changes settings of the site (App\Settings\*) for a test: saved, as from the admin panel.
     *
     * @param  class-string<Settings>  $class
     * @param  array<string, mixed>  $values
     */
    protected function setSettings(string $class, array $values): void
    {
        $settings = app($class);
        foreach ($values as $name => $value) {
            $settings->{$name} = $value;
        }
        $settings->save();
    }
}

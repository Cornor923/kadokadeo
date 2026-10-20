<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Spatie\LaravelSettings\Settings;

abstract class TestCase extends BaseTestCase
{
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

<?php

namespace App\Support;

use App\Enums\DeviceType;

// what a user agent says of the browser of a player (the main browsers and systems only)
class UserAgent
{
    public function __construct(private readonly string $agent) {}

    public function browser(): ?string
    {
        return match (true) {
            str_contains($this->agent, 'Edg/') => 'Edge',
            str_contains($this->agent, 'OPR/') || str_contains($this->agent, 'Opera') => 'Opera',
            str_contains($this->agent, 'Firefox/') => 'Firefox',
            str_contains($this->agent, 'Chrome/') || str_contains($this->agent, 'CriOS/') => 'Chrome',
            str_contains($this->agent, 'Safari/') => 'Safari',
            default => null,
        };
    }

    public function system(): ?string
    {
        return match (true) {
            str_contains($this->agent, 'iPhone') || str_contains($this->agent, 'iPad') => 'iOS',
            str_contains($this->agent, 'Android') => 'Android',
            str_contains($this->agent, 'Windows') => 'Windows',
            str_contains($this->agent, 'Mac OS X') => 'macOS',
            str_contains($this->agent, 'CrOS') => 'ChromeOS',
            str_contains($this->agent, 'Linux') => 'Linux',
            default => null,
        };
    }

    // an iPad says it is a Mac by default: only its touch points tell it apart (navigator.maxTouchPoints); an Android
    // tablet is an Android without « Mobile »
    public function deviceType(int $touchPoints = 0): DeviceType
    {
        $android = str_contains($this->agent, 'Android');

        return match (true) {
            str_contains($this->agent, 'iPad'),
            $android && !str_contains($this->agent, 'Mobile'),
            str_contains($this->agent, 'Macintosh') && $touchPoints > 1 => DeviceType::TABLET,
            $android, str_contains($this->agent, 'Mobi'), str_contains($this->agent, 'iPhone'), str_contains($this->agent, 'iPod') => DeviceType::MOBILE,
            default => DeviceType::DESKTOP,
        };
    }
}

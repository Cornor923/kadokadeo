<?php

namespace App\Events;

use App\Settings\SiteSettings;
use App\Support\Realtime;
use Illuminate\Broadcasting\Channel;

// the announcement of the site saved in the admin (« Paramètres > Site »): the banner of every page changes
class AnnouncementUpdated extends RealtimeEvent
{
    public function __construct(private readonly ?array $announcement) {}

    public static function of(SiteSettings $settings): self
    {
        return new self($settings->announcement());
    }

    public function broadcastOn(): Channel
    {
        return Realtime::site();
    }

    public function broadcastAs(): string
    {
        return 'announcement.updated';
    }

    public function broadcastWith(): array
    {
        return ['announcement' => $this->announcement];
    }

    // the last one saved
    public function dedupeKey(): ?string
    {
        return '';
    }
}

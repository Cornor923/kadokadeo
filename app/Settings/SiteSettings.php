<?php

namespace App\Settings;

use Illuminate\Support\Str;
use Spatie\LaravelSettings\Settings;

class SiteSettings extends Settings
{
    public bool $announcement_enabled;

    public string $announcement_level;

    public ?string $announcement_content;

    public static function group(): string
    {
        return 'site';
    }

    /**
     * Announcement displayed on every page, or null when there is nothing to display.
     *
     * @return array{level: string, html: string}|null
     */
    public function announcement(): ?array
    {
        if (!$this->announcement_enabled || blank($this->announcement_content)) {
            return null;
        }

        return [
            'level' => $this->announcement_level,
            // Inline markdown only (bold, italic, links): the front renders it inside a <p>.
            // Raw HTML is stripped so the result is safe to inject with v-html.
            'html' => Str::inlineMarkdown(trim($this->announcement_content), [
                'html_input' => 'strip',
                'allow_unsafe_links' => false,
                'renderer' => ['soft_break' => "<br />\n"],
            ]),
        ];
    }
}

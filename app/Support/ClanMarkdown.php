<?php

namespace App\Support;

use League\CommonMark\Environment\Environment;
use League\CommonMark\Extension\CommonMark\CommonMarkCoreExtension;
use League\CommonMark\Extension\ExternalLink\ExternalLinkExtension;
use League\CommonMark\MarkdownConverter;

// the presentation of a clan written in Markdown (titles, lists, links, images, bold...) turned into HTML. What the
// players write is not trusted: their HTML is escaped, the links other than http(s), mailto... (javascript:) are
// dropped, and the links open in a new tab without giving the page to the site
class ClanMarkdown
{
    private static ?MarkdownConverter $converter = null;

    public static function toHtml(?string $markdown): ?string
    {
        if ($markdown === null || trim($markdown) === '') {
            return null;
        }

        return (string) self::converter()->convert($markdown);
    }

    private static function converter(): MarkdownConverter
    {
        if (self::$converter === null) {
            $environment = new Environment([
                'html_input' => 'escape',
                'allow_unsafe_links' => false,
                'max_nesting_level' => 10,
                // a new line stays a new line, as before the Markdown
                'renderer' => ['soft_break' => "<br />\n"],
                'external_link' => [
                    'internal_hosts' => [],
                    'open_in_new_window' => true,
                    'nofollow' => 'external',
                    'noopener' => 'external',
                    'noreferrer' => 'external',
                ],
            ]);
            $environment->addExtension(new CommonMarkCoreExtension());
            $environment->addExtension(new ExternalLinkExtension());
            self::$converter = new MarkdownConverter($environment);
        }

        return self::$converter;
    }
}

<?php

namespace App\Support;

use App\Enums\LocalePreference;
use App\Models\User;
use App\Settings\SiteSettings;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\AcceptHeader;

// The language of a page and of the API: the choice of the account, then the browser.
// The admin panel stays in French: only App\Http\Middleware\UseLanguageOfThePlayer changes the language, on the API.
final class LocaleResolver
{
    // the texts are written in French: the language of the site when the languages are off
    private const SOURCE_LANGUAGE = 'fr';

    // French while English is in beta
    private const LANGUAGE_OF_OTHER_BROWSERS = 'fr';

    public static function forRequest(Request $request): string
    {
        $enabled = app(SiteSettings::class)->i18n_enabled;
        if (!$enabled) {
            return self::SOURCE_LANGUAGE;
        }
        /** @var User|null $player */
        $player = $request->user('web');

        return self::resolve(
            $enabled,
            $player->locale ?? LocalePreference::AUTO,
            $request->header('Accept-Language'),
        );
    }

    public static function resolve(bool $enabled, LocalePreference $account, ?string $acceptLanguage): string
    {
        if (!$enabled) {
            return self::SOURCE_LANGUAGE;
        }
        if ($account !== LocalePreference::AUTO) {
            return $account->value;
        }

        return self::browserLanguage($acceptLanguage) ?? self::LANGUAGE_OF_OTHER_BROWSERS;
    }

    private static function browserLanguage(?string $acceptLanguage): ?string
    {
        foreach (AcceptHeader::fromString($acceptLanguage ?? '')->all() as $accepted) {
            $language = LocalePreference::tryFrom(strtolower(explode('-', $accepted->getValue())[0]));
            if ($accepted->getQuality() > 0 && in_array($language, LocalePreference::languages(), true)) {
                return $language->value;
            }
        }

        return null;
    }
}

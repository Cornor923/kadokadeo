<?php

namespace Tests\Unit;

use App\Enums\LocalePreference;
use App\Support\LocaleResolver;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class LocaleResolverTest extends TestCase
{
    private function language(
        bool $enabled = true,
        LocalePreference $account = LocalePreference::AUTO,
        ?string $browser = null,
    ): string {
        return LocaleResolver::resolve($enabled, $account, $browser);
    }

    public function test_the_flag_off_means_french_whatever_was_chosen(): void
    {
        $this->assertSame('fr', $this->language(enabled: false, account: LocalePreference::EN, browser: 'en'));
    }

    public function test_the_account_wins_over_the_browser(): void
    {
        $this->assertSame('fr', $this->language(account: LocalePreference::FR, browser: 'en'));
        $this->assertSame('en', $this->language(account: LocalePreference::EN, browser: 'fr'));
    }

    #[DataProvider('browserLanguages')]
    public function test_the_browser_decides_last(?string $browser, string $expected): void
    {
        $this->assertSame($expected, $this->language(browser: $browser));
    }

    /** @return array<string, array{?string, string}> */
    public static function browserLanguages(): array
    {
        return [
            'French' => ['fr', 'fr'],
            'a region' => ['en-GB', 'en'],
            'another case' => ['EN-gb', 'en'],
            'the first one supported' => ['es, en-GB;q=0.8, fr;q=0.5', 'en'],
            'the weights decide, not the order' => ['fr;q=0.5, en;q=0.9', 'en'],
            'a refused language' => ['en;q=0, fr;q=0.5', 'fr'],
            'only refused languages' => ['en;q=0', 'fr'],
            'a language not supported: French during the beta' => ['de', 'fr'],
            'the automatic choice of an account is not a language' => ['auto, en;q=0.5', 'en'],
            'any language' => ['*', 'fr'],
            'no header' => [null, 'fr'],
            'an empty header' => ['', 'fr'],
            'a broken header' => [';;;=,,q=x', 'fr'],
        ];
    }

    public function test_a_huge_header_changes_nothing(): void
    {
        $this->assertSame('fr', $this->language(browser: str_repeat('xx-YY,', 2000)));
    }
}

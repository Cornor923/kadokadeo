<?php

namespace App\Enums;

// what the game detected during a run (the `ac` mask it sends, resources/hx/lib/common_haxe_avm1/kac/AntiCheat.hx):
// the hard bits mark the run as cheated, the soft ones (config kado.anticheat.soft_bits) put it in the queue of the
// suspicious runs (App\Services\SuspicionService), the ignored ones (kado.anticheat.ignored_bits) are only kept on the run
enum AntiCheatBit: int
{
    case PROTECTED_INT_CORRUPTED = 0x1;
    case CODE_PATCHED = 0x2;
    case INSTANCE_SHADOWED = 0x4;
    case FOREIGN_DISPLAY_OBJECT = 0x10;
    case PIXI_PATCHED = 0x20;
    case NATIVE_PATCHED = 0x40;
    case UNTRUSTED_INPUT = 0x80;
    case FORGED_EVENT = 0x100;
    case CHECK_FAILED = 0x200;

    public function getLabel(): string
    {
        return match ($this) {
            self::PROTECTED_INT_CORRUPTED => 'Variable modifiée en mémoire',
            self::CODE_PATCHED => 'Code du jeu remplacé',
            self::INSTANCE_SHADOWED => 'Méthode d’un objet du jeu remplacée',
            self::FOREIGN_DISPLAY_OBJECT => 'Affichage ajouté par un script',
            self::PIXI_PATCHED => 'PIXI modifié',
            self::NATIVE_PATCHED => 'Fonctions du navigateur modifiées',
            self::UNTRUSTED_INPUT => 'Actions générées par un script',
            self::FORGED_EVENT => 'Faux événements',
            self::CHECK_FAILED => 'Vérification impossible',
        };
    }

    public static function softMask(): int
    {
        return (int) config('kado.anticheat.soft_bits');
    }

    public static function ignoredMask(): int
    {
        return (int) config('kado.anticheat.ignored_bits');
    }

    public function isSoft(): bool
    {
        return self::softBits($this->value) !== 0;
    }

    public function isIgnored(): bool
    {
        return ($this->value & self::ignoredMask()) !== 0;
    }

    // the bits of a mask that mark a run as cheated
    public static function hardBits(int $mask): int
    {
        return $mask & ~self::softMask() & ~self::ignoredMask();
    }

    public static function softBits(int $mask): int
    {
        return $mask & self::softMask() & ~self::ignoredMask();
    }

    // the detections that mark a run as cheated / that put it in the queue of the suspicious runs (kado.anticheat.soft_bits)
    /** @return list<self> */
    public static function hardCases(): array
    {
        return array_values(array_filter(self::cases(), fn (self $bit) => !$bit->isSoft() && !$bit->isIgnored()));
    }

    /** @return list<self> */
    public static function softCases(): array
    {
        return array_values(array_filter(self::cases(), fn (self $bit) => $bit->isSoft()));
    }

    /** @return list<self> */
    public static function ignoredCases(): array
    {
        return array_values(array_filter(self::cases(), fn (self $bit) => $bit->isIgnored()));
    }

    /** @return list<self> */
    public static function in(int $mask): array
    {
        return array_values(array_filter(self::cases(), fn (self $bit) => ($mask & $bit->value) !== 0));
    }

    // "Code du jeu remplacé, Affichage ajouté par un script" (and the unknown bits)
    public static function describe(int $mask): string
    {
        $labels = array_map(fn (self $bit) => $bit->getLabel(), self::in($mask));
        $unknown = $mask & ~array_reduce(self::cases(), fn (int $all, self $bit) => $all | $bit->value, 0);
        if ($unknown !== 0) {
            $labels[] = sprintf('Inconnu (0x%x)', $unknown);
        }

        return implode(', ', $labels);
    }
}

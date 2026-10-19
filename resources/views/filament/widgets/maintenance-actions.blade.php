<x-filament-widgets::widget>
    <x-filament::section>
        <x-filament::button color="danger" icon="heroicon-o-trash" wire:click="resetScores" wire:confirm="Toutes les parties et tous les scores seront supprimés. Continuer ?" wire:loading.attr="disabled"
            wire:target="resetScores">
            Réinitialiser scores / parties
        </x-filament::button>
        <x-filament::button color="info" icon="heroicon-o-plus" wire:click="prepareNewPeriod" wire:loading.attr="disabled" wire:target="prepareNewPeriod">
            Préparer une nouvelle période
        </x-filament::button>
        <x-filament::button color="danger" icon="heroicon-o-trash" wire:click="deleteAchievements" wire:loading.attr="disabled" wire:target="deleteAchievements"
            wire:confirm="Tous les succès seront supprimés puis recréés. Continuer ?">
            Supprimer et recréer les succès
        </x-filament::button>
    </x-filament::section>
</x-filament-widgets::widget>

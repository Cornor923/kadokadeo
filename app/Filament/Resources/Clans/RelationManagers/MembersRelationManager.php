<?php

namespace App\Filament\Resources\Clans\RelationManagers;

use App\Enums\ClanRole;
use App\Filament\Resources\Users\UserResource;
use App\Models\ClanMember;
use App\Models\Period;
use Filament\Actions\Action;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

// the members of the clan with their stats of a period (clan_member_stats, the current period by default), as on the
// "Membres" page of the clan
class MembersRelationManager extends RelationManager
{
    protected static string $relationship = 'members';

    protected static ?string $title = 'Membres';

    protected static ?string $modelLabel = 'membre';

    protected static ?string $pluralModelLabel = 'membres';

    // the period of the stats: the one of the filter
    private function statsPeriodId(): ?int
    {
        $value = $this->getTableFilterState('period_id')['value'] ?? null;

        return $value ? (int) $value : Period::current()->value('id');
    }

    public function table(Table $table): Table
    {
        $leaderId = $this->getOwnerRecord()->leader_id;

        return $table
            ->modifyQueryUsing(fn ($query) => $query
                ->with('user')
                ->leftJoin('clan_member_stats as stats', function ($join) {
                    $join->on('stats.clan_id', '=', 'clan_members.clan_id')
                        ->on('stats.user_id', '=', 'clan_members.user_id')
                        ->where('stats.period_id', '=', $this->statsPeriodId());
                })
                ->select('clan_members.*')
                // 1 point by step of mission + the points of the attacks and the defenses
                ->selectRaw('COALESCE(stats.mission_steps, 0) + COALESCE(stats.performance, 0) as stat_points')
                ->selectRaw('COALESCE(stats.performance, 0) as stat_performance')
                ->selectRaw('COALESCE(stats.mission_steps, 0) as stat_mission_steps')
                ->selectRaw('COALESCE(stats.attacks, 0) as stat_attacks')
                ->selectRaw('COALESCE(stats.attacks_won, 0) as stat_attacks_won')
                ->selectRaw('COALESCE(stats.defenses, 0) as stat_defenses')
                ->selectRaw('COALESCE(stats.defenses_won, 0) as stat_defenses_won')
                ->selectRaw('COALESCE(stats.reward, 0) as stat_reward'))
            ->defaultSort('stat_points', 'desc')
            ->columns([
                TextColumn::make('user.display_name')
                    ->label('Membre')
                    ->searchable(),
                TextColumn::make('role')
                    ->label('Rôle')
                    ->state(fn (ClanMember $record) => $record->user_id === $leaderId ? ClanRole::LEADER : $record->role)
                    ->badge()
                    ->color(fn ($state) => match ($state) {
                        ClanRole::LEADER => 'warning',
                        ClanRole::RIGHT_HAND => 'info',
                        default => 'gray',
                    }),
                TextColumn::make('combat_role')
                    ->label('Siège')
                    ->placeholder('—'),
                TextColumn::make('stat_points')
                    ->label('Points')
                    ->tooltip('1 point par étape de mission réussie + les points de ses attaques et de ses défenses réussies')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('stat_performance')
                    ->label('Performance')
                    ->tooltip('Points rapportés par ses attaques + points sauvés par ses défenses')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('stat_mission_steps')
                    ->label('Étapes de mission')
                    ->numeric()
                    ->sortable(),
                TextColumn::make('stat_attacks_won')
                    ->label('Attaques réussies')
                    ->formatStateUsing(fn ($state, ClanMember $record) => "{$state} / {$record->stat_attacks}")
                    ->sortable(),
                TextColumn::make('stat_defenses_won')
                    ->label('Défenses réussies')
                    ->formatStateUsing(fn ($state, ClanMember $record) => "{$state} / {$record->stat_defenses}")
                    ->sortable(),
                TextColumn::make('stat_reward')
                    ->label('Récompense')
                    ->tooltip('Points Kado reçus à la fin de la période')
                    ->numeric()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('status')
                    ->label('Statut')
                    ->placeholder('—')
                    ->limit(30)
                    ->toggleable(),
                IconColumn::make('is_new')
                    ->label('Nouveau')
                    ->tooltip('Arrivé pendant la période en cours : il ne peut pas quitter le clan ni en être exclu avant la suivante')
                    ->state(fn (ClanMember $record) => $record->joined_period_id !== null && $record->joined_period_id === Period::current()->value('id'))
                    ->boolean()
                    ->toggleable(),
                TextColumn::make('created_at')
                    ->label('Membre depuis')
                    ->date()
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('period_id')
                    ->label('Stats de la période')
                    ->options(fn () => Period::query()->orderByDesc('id')->limit(30)->pluck('id', 'id')->map(fn ($id) => "Période {$id}")->all())
                    ->default(fn () => Period::current()->value('id'))
                    // (it chooses the stats joined above, not the members)
                    ->query(fn ($query) => $query),
            ])
            ->recordActions([
                Action::make('user')
                    ->label('Joueur')
                    ->icon(Heroicon::OutlinedUser)
                    ->color('gray')
                    ->url(fn (ClanMember $record) => UserResource::getUrl('edit', ['record' => $record->user_id])),
            ]);
    }
}

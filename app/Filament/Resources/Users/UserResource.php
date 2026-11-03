<?php

namespace App\Filament\Resources\Users;

use App\Filament\Resources\Users\Pages\CreateUser;
use App\Filament\Resources\Users\Pages\EditUser;
use App\Filament\Resources\Users\Pages\ListUsers;
use App\Filament\Resources\Users\RelationManagers\AchievementProgressRelationManager;
use App\Filament\Resources\Users\RelationManagers\RunsRelationManager;
use App\Filament\Resources\Users\RelationManagers\SessionsRelationManager;
use App\Filament\Resources\Users\Schemas\UserForm;
use App\Filament\Resources\Users\Tables\UsersTable;
use App\Models\User;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Auth\Access\Response;
use Illuminate\Database\Eloquent\Model;

class UserResource extends Resource
{
    protected static ?string $modelLabel = 'utilisateur';

    protected static ?string $pluralModelLabel = 'utilisateurs';

    protected static ?string $model = User::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedRectangleStack;

    protected static ?string $recordTitleAttribute = 'display_name';

    public static function form(Schema $schema): Schema
    {
        return UserForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return UsersTable::configure($table);
    }

    public static function getRelations(): array
    {
        return [
            RunsRelationManager::class,
            AchievementProgressRelationManager::class,
            SessionsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListUsers::route('/'),
            'create' => CreateUser::route('/create'),
            'edit' => EditUser::route('/{record}/edit'),
        ];
    }

    // a player is never deleted from the admin: the account would be created again, blank and not banned, at the
    // next login (and their stars, favorites... block it): banning is the sanction
    public static function getDeleteAuthorizationResponse(Model $record): Response
    {
        return Response::deny('Un joueur ne peut pas être supprimé : bannissez-le.');
    }

    public static function getDeleteAnyAuthorizationResponse(): Response
    {
        return Response::deny('Un joueur ne peut pas être supprimé : bannissez-le.');
    }

    public static function getForceDeleteAuthorizationResponse(Model $record): Response
    {
        return Response::deny('Un joueur ne peut pas être supprimé : bannissez-le.');
    }

    public static function getForceDeleteAnyAuthorizationResponse(): Response
    {
        return Response::deny('Un joueur ne peut pas être supprimé : bannissez-le.');
    }
}

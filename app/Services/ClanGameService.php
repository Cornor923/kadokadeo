<?php

namespace App\Services;

use App\Exceptions\ClanException;
use App\Models\Clan;
use App\Models\ClanGameTransfer;
use App\Models\User;
use App\Settings\ClanSettings;
use Illuminate\Support\Facades\DB;

// the paid clan games: bought with Kado points by packs (ClanSettings::$game_packs), used for the attacks and the defenses once
// the free attack games of the day are used (ClanRunService::useClanGame). Their owner uses them or gives them to his
// clan, whose leader and right hands distribute them to the members. The free games of the day can't be given.
class ClanGameService
{
    public function __construct(private readonly ClanService $clanService) {}

    /**
     * @return array<int, int> [games => Kado points]
     */
    public function packs(): array
    {
        return app(ClanSettings::class)->gamePacks();
    }

    public function buy(User $user, int $count): void
    {
        $price = $this->packs()[$count] ?? throw new ClanException('Ce lot de parties n\'existe pas.');

        DB::transaction(function () use ($user, $count, $price) {
            $user = User::query()->lockForUpdate()->findOrFail($user->id);
            if ($user->kado_points < $price) {
                throw new ClanException('Vous n\'avez pas assez de points Kado pour acheter ces parties.');
            }

            $user->kado_points -= $price;
            $user->clan_games += $count;
            $user->save();
            $user->userPoints()->create([
                'delta' => -$price,
                'reason' => 'clan games purchase',
                'source_type' => 'clan_games',
                'source_id' => $count,
            ]);
        });
    }

    public function donate(User $user, Clan $clan, int $count): void
    {
        $this->clanService->assertMember($user, $clan);

        DB::transaction(function () use ($user, $clan, $count) {
            $user = User::query()->lockForUpdate()->findOrFail($user->id);
            if ($count < 1 || $user->clan_games < $count) {
                throw new ClanException('Vous n\'avez pas assez de parties de clan achetées (les parties gratuites du jour ne peuvent pas être données).');
            }

            $user->decrement('clan_games', $count);
            Clan::query()->whereKey($clan->id)->increment('clan_games', $count);
            $clan->gameTransfers()->create(['type' => ClanGameTransfer::DONATION, 'from_user_id' => $user->id, 'count' => $count]);
        });
    }

    public function distribute(User $manager, Clan $clan, User $member, int $count): void
    {
        $this->clanService->assertManager($manager, $clan);
        $this->clanService->assertMember($member, $clan);

        DB::transaction(function () use ($manager, $clan, $member, $count) {
            $clan = Clan::query()->lockForUpdate()->findOrFail($clan->id);
            if ($count < 1 || $clan->clan_games < $count) {
                throw new ClanException('Le clan n\'a pas assez de parties à distribuer.');
            }

            $clan->decrement('clan_games', $count);
            User::query()->whereKey($member->id)->increment('clan_games', $count);
            $clan->gameTransfers()->create([
                'type' => ClanGameTransfer::DISTRIBUTION,
                'from_user_id' => $manager->id,
                'to_user_id' => $member->id,
                'count' => $count,
            ]);
        });
    }
}

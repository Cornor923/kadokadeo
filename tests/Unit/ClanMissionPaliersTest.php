<?php

namespace Tests\Unit;

use App\Services\ClanMissionPaliers;
use PHPUnit\Framework\TestCase;

// the scores to reach of the steps of the missions, by difficulty in stars: steps of all the difficulties, beyond the red
// star towards the "Score 1500" of the game
class ClanMissionPaliersTest extends TestCase
{
    private function paliers(array $values = []): ClanMissionPaliers
    {
        return ClanMissionPaliers::fromArray($values + [
            'mission_stars_per_mission' => 0.25,
            'mission_beyond_last_star' => 0.1,
            'mission_hard_share_min' => 0.2,
            'mission_hard_share_step' => 0.025,
            'mission_hard_share_max' => 0.5,
        ]);
    }

    public function test_the_score_of_a_difficulty_is_the_inverse_of_the_difficulty_of_a_score(): void
    {
        $stars = [3000, 1000, 2000];
        $this->assertEqualsWithDelta(500, ClanMissionPaliers::scoreAt($stars, 4000, 0.5), 1e-9);
        $this->assertEqualsWithDelta(1500, ClanMissionPaliers::scoreAt($stars, 4000, 1.5), 1e-9);
        $this->assertEqualsWithDelta(3000, ClanMissionPaliers::scoreAt($stars, 4000, 3), 1e-9);
        $this->assertEqualsWithDelta(3100, ClanMissionPaliers::scoreAt($stars, 4000, 3.1), 1e-9);
        $this->assertEqualsWithDelta(4000, ClanMissionPaliers::scoreAt($stars, 4000, 4.5), 1e-9);
        foreach ([0.5, 1.25, 2.7, 3.4] as $difficulty) {
            $this->assertEqualsWithDelta($difficulty, ClanMissionPaliers::difficulty($stars, 4000, (int) ClanMissionPaliers::scoreAt($stars, 4000, $difficulty)), 1e-9);
        }
        // without a "Score 1500" above the red star: the red star at most
        $this->assertEqualsWithDelta(3000, ClanMissionPaliers::scoreAt($stars, null, 3.5), 1e-9);
        $this->assertEqualsWithDelta(3000, ClanMissionPaliers::scoreAt($stars, 2500, 3.5), 1e-9);
    }

    public function test_the_top_difficulty_goes_up_with_the_missions_then_slower_beyond_the_red_star(): void
    {
        $paliers = $this->paliers();

        $this->assertSame(0.5, $paliers->topDifficulty(1));
        $this->assertSame(1.0, $paliers->topDifficulty(3));
        // the plain red star for a star of missions (4 missions at a quarter of star)
        $this->assertSame(3.0, $paliers->topDifficulty(11));
        $this->assertSame(3.0, $paliers->topDifficulty(14));
        // then 10 % of the way to the "Score 1500" by mission
        $this->assertSame(3.0, $paliers->topDifficulty(15));
        $this->assertEqualsWithDelta(3.1, $paliers->topDifficulty(16), 1e-9);
        $this->assertEqualsWithDelta(3.5, $paliers->topDifficulty(20), 1e-9);
        $this->assertSame(4.0, $paliers->topDifficulty(25));
        $this->assertSame(4.0, $paliers->topDifficulty(1000));
        $this->assertSame(4.0, $paliers->maxDifficulty());
        // nothing beyond the red star
        $this->assertSame(3.0, $this->paliers(['mission_beyond_last_star' => 0])->topDifficulty(1000));
    }

    public function test_a_mission_has_steps_of_all_the_difficulties_and_a_growing_share_of_hard_ones(): void
    {
        $paliers = $this->paliers();

        // the first mission: everything at half the green star
        $this->assertSame([0.5, 0.5, 0.5, 0.5, 0.5, 0.5], $paliers->levels(1, 6));
        // mission 9 (top: 2.5, 40 % of hard steps): from half the green star up to the top
        $this->assertSame([0.5, 1.0, 1.5, 2.0, 2.5, 2.5], $paliers->levels(9, 6));
        // much later: half of the steps at the top, the easiest one still there
        $levels = $paliers->levels(41, 6);
        $this->assertSame(0.5, $levels[0]);
        $this->assertSame(3, count(array_keys($levels, 4.0)));
        // a single step: the hard one
        $this->assertSame([2.5], $paliers->levels(9, 1));
        $this->assertSame([], $paliers->levels(9, 0));
    }

    // the easiest steps get harder with each mission, up to a maximum
    public function test_the_bottom_difficulty_goes_up_with_the_missions(): void
    {
        $paliers = $this->paliers(['mission_bottom_per_mission' => 0.025, 'mission_bottom_max' => 0.75]);

        $this->assertSame(0.5, $paliers->bottomDifficulty(1));
        $this->assertEqualsWithDelta(0.6, $paliers->bottomDifficulty(5), 1e-9);
        $this->assertSame(0.75, $paliers->bottomDifficulty(11));
        $this->assertSame(0.75, $paliers->bottomDifficulty(100));
        // mission 9 (top 2.5): from 0.7 up to the top
        $this->assertEqualsWithDelta([0.7, 1.15, 1.6, 2.05, 2.5, 2.5], $paliers->levels(9, 6), 1e-9);
        // the first missions: everything at the top, the bottom never above it
        $this->assertSame([0.5, 0.5], $paliers->levels(1, 2));
        // off: half the green star
        $this->assertSame(0.5, $this->paliers()->bottomDifficulty(100));
    }

    // the plain red star (its score exactly) takes a star of room in the spread of the steps, as the green and orange ones
    public function test_the_steps_at_the_plain_red_star(): void
    {
        $paliers = $this->paliers(['mission_hard_share_min' => 0.25, 'mission_hard_share_step' => 0, 'mission_hard_share_max' => 0.25]);

        // mission 21 (top 3.6 = 4.6 on the scale of the missions): from 0.5 to 4.6, the steps from 3 to 4 at the red star
        $levels = $paliers->levels(21, 8);
        $this->assertEqualsWithDelta([0.5, 1.18, 1.87, 2.55, 3.0, 3.0, 3.6, 3.6], $levels, 0.01);
        $this->assertSame(['grise', 'verte', 'verte', 'orange', 'rouge', 'rouge', 'rouge +60 %', 'rouge +60 %'], array_map(ClanMissionPaliers::label(...), $levels));
    }

    public function test_the_labels_are_the_stars_won(): void
    {
        $this->assertSame('grise', ClanMissionPaliers::label(0.5));
        $this->assertSame('verte', ClanMissionPaliers::label(1.5));
        $this->assertSame('orange', ClanMissionPaliers::label(2.99));
        $this->assertSame('rouge', ClanMissionPaliers::label(3.0));
        $this->assertSame('rouge +30 %', ClanMissionPaliers::label(3.3));
    }

    public function test_the_difficulty_of_a_score_follows_the_stars_then_the_score_1500(): void
    {
        $this->assertEqualsWithDelta(0.5, ClanMissionPaliers::difficulty([3000, 1000, 2000], 4000, 500), 1e-9);
        $this->assertEqualsWithDelta(1.5, ClanMissionPaliers::difficulty([3000, 1000, 2000], 4000, 1500), 1e-9);
        $this->assertEqualsWithDelta(3.1, ClanMissionPaliers::difficulty([3000, 1000, 2000], 4000, 3100), 1e-9);
        // beyond the red star without a "Score 1500" above it
        $this->assertEqualsWithDelta(3.5, ClanMissionPaliers::difficulty([1000, 2000, 3000], null, 4500), 1e-9);
        // the steps of different games: the red star of a game is harder than the orange one of another
        $this->assertGreaterThan(
            ClanMissionPaliers::difficulty([10000, 50000, 90000], null, 50000),
            ClanMissionPaliers::difficulty([100, 200, 300], null, 300),
        );
    }
}

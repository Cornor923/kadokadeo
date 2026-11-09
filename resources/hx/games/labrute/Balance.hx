package labrute;

// Every tunable value of the KadoKadeo game (shop prices, rewards, difficulty, speed of the fights, sudden death).
// LaBrute's own values (stats of the weapons, skills and pets, damage formulas) are in Data.hx and fight/FightGen.hx.
class Balance {
	// ---------------------------------------------------------------- frames
	// KadoKadeo steps the game 32 times a second: every duration of the game is counted in these frames
	public static inline var FPS = 32;

	// ---------------------------------------------------------------- the start
	public static inline var START_GOLD = 450;

	// ---------------------------------------------------------------- the shop
	// a stat: STAT_PRICE gold, then more at each purchase of that stat (each stat has its own counter), by less and less
	// toward STAT_PRICE_CAP (the gap to it multiplied by STAT_PRICE_DECAY at each purchase, by 5 gold), then, once that is
	// less than STAT_PRICE_STEP, STAT_PRICE_STEP more at each purchase, above the cap too
	public static inline var STAT_PRICE = 50;
	public static inline var STAT_PRICE_CAP = 250;
	public static inline var STAT_PRICE_DECAY = 0.85;
	public static inline var STAT_PRICE_STEP = 4;
	// what a purchase gives: +3 HP (hpStat, LaBrute's HP formula keeps 1 HP per point) or +1 strength / agility / speed
	public static inline var HP_PER_BUY = 2;
	public static inline var STAT_PER_BUY = 1;
	// a new weapon (random), a new skill (random, or a pet instead): 350 gold, then 50 more at each purchase
	public static inline var WEAPON_PRICE = 400;
	public static inline var WEAPON_PRICE_STEP = 75;
	public static inline var SKILL_PRICE = 400;
	public static inline var SKILL_PRICE_STEP = 75;
	// a weapon improved to its tier 2: this part of the price of a new weapon, to its tier 3: this part (the same for the
	// skills and the pets with the price of a new skill)
	public static inline var TIER2_FACTOR = 0.5;
	public static inline var TIER3_FACTOR = 1;
	// the ears (the money of the tiers only), by tier reached: 1 for the tier 2, 2 for the tier 3, with the gold
	public static var TIER_EARS:Array<Int> = [0, 0, 1, 2];

	// ---------------------------------------------------------------- the opponents
	// the level of the player's brute: the fights already played + 2 (Run.playerLevel); the hidden level of the opponents:
	// that one, and one more every EXTRA_LEVEL_WINS fights won (Run.hiddenLevel). An opponent gets one random bonus by level
	public static inline var LEVEL_BASE = 2;
	// easy, medium, hard: the hidden level + this offset (at least 0 bonus)
	public static var OPPONENT_OFFSETS:Array<Int> = [-5, -3, -1];
	// bonuses: +3 to one of strength / agility / speed, +12 HP (hpStat, like LaBrute's +2 HP of a level up), 2 tiers
	public static inline var LEVEL_STAT_POINTS = 3;
	public static inline var LEVEL_HP = 12;
	public static inline var LEVEL_UPGRADES = 1;
	// the backup called by the skill « Renforts »: an opponent this many levels below the hidden level
	public static inline var BACKUP_LEVEL_OFFSET = -3;
	// the hidden level goes up one level more every this many fights won (the whole run)
	public static inline var EXTRA_LEVEL_WINS = 3;
	// the pets come this many times less often than in LaBrute: the draws of the player (start, « Nouvelle compétence »)
	// and the bonus « 1 animal » of the levels of the opponents (the other bonuses weigh 1)
	public static inline var PET_ODDS_FACTOR = 0.3; // reduced

	// ---------------------------------------------------------------- the rewards (points = gold)
	public static var WIN_REWARD:Array<Int> = [400, 550, 700];
	// multiplied by the league multiplier (the damage points are not)
	public static inline var DISARM_BONUS = 10;
	public static inline var DOG_KILL_BONUS = 20;
	public static inline var PANTHER_KILL_BONUS = 75;
	public static inline var BEAR_KILL_BONUS = 250;
	public static inline var BACKUP_KILL_BONUS = 200;
	// « Victoire Parfaite ! »: the brute of the player ends the fight with all its HP (hit or not)
	public static inline var FULL_HP_BONUS = 200;
	// « One-shot ! »: the brute of the opponent killed by one hit
	public static inline var ONE_SHOT_BONUS = 300;
	// the ears: one by fight won (not a defeat saved by the bandage), one more by backup of the opponent killed
	public static inline var WIN_EARS = 1;
	public static inline var BACKUP_KILL_EARS = 1;
	public static inline var BEFORE_TIMER_BONUS = 50;
	public static inline var ONE_HP_BONUS = 500;
	// 1 point (and 1 gold) by damage dealt by the player's team
	public static inline var DAMAGE_POINTS = 1;

	// ---------------------------------------------------------------- the leagues
	// one league up every WINS_PER_LEAGUE fights won, until the last league (Data.LEAGUES); the multiplier of the rewards
	// grows by LEAGUE_MULTIPLIER_STEP at each league (0: the same in every league)
	public static inline var WINS_PER_LEAGUE = 3;
	public static inline var LEAGUE_MULTIPLIER_STEP = 0.00;

	// ---------------------------------------------------------------- the fights
	// LaBrute's fight played this many times faster; the throws of the weapons kept in hand (shuriken, Piou Piou, bowl)
	// even faster
	public static inline var FIGHT_SPEED = 2.2;
	public static inline var THROWN_SPEED = 3.5;
	// the countdown, then the sudden death: every fighter loses HP at each frame
	public static inline var TIMER_FRAMES = 21 * FPS;
	// its HP lost: half a HP a frame, half a HP more every DRAIN_LEVEL_FIGHTS fights (fights 1 to 5: 0.5, 6 to 10: 1...)
	public static inline var DRAIN_LEVEL_FIGHTS = 5;
	// and 1 HP more a frame every 5 seconds of sudden death
	public static inline var DRAIN_STEP_FRAMES = 5 * FPS;
	// the end of a fight: its last picture, then the results
	public static inline var END_FRAMES = 1.2 * FPS;
	// the results go on to the shop by themselves after this time (or a click)
	public static inline var RESULT_FRAMES = 5 * FPS;

	// (multiplications only: the same price in every browser)
	public static function statPrice(bought:Int):Int {
		var gap:Float = STAT_PRICE_CAP - STAT_PRICE;
		var price = STAT_PRICE;
		for (i in 0...bought) {
			if (gap * (1 - STAT_PRICE_DECAY) < STAT_PRICE_STEP) {
				price += STAT_PRICE_STEP;
				continue;
			}
			gap *= STAT_PRICE_DECAY;
			price = Math.round((STAT_PRICE_CAP - gap) / 5) * 5;
		}
		return price;
	}

	public static function weaponPrice(bought:Int):Int {
		return WEAPON_PRICE + WEAPON_PRICE_STEP * bought;
	}

	public static function skillPrice(bought:Int):Int {
		return SKILL_PRICE + SKILL_PRICE_STEP * bought;
	}

	// the price to take a perk from this tier to the next one (0: already at its last tier), from the price of a new
	// perk of its kind (weaponPrice, skillPrice)
	public static function upgradePrice(tier:Int, newPrice:Int):Int {
		return tier == 1 ? Math.round(newPrice * TIER2_FACTOR) : tier == 2 ? Math.round(newPrice * TIER3_FACTOR) : 0;
	}

	// the level of the sudden death of the fight number n (1-based)
	public static inline function drainLevel(n:Int):Int {
		return Std.int((n - 1) / DRAIN_LEVEL_FIGHTS);
	}

	public static function leagueMultiplier(league:Int):Float {
		return 1 + LEAGUE_MULTIPLIER_STEP * league;
	}

	// the HP lost by every fighter from the start of the sudden death to its frame `f` (frames since the end of the timer),
	// at its level (drainLevel)
	public static function drainTotal(f:Int, level:Int):Int {
		if (f <= 0)
			return 0;
		var total = (f * (level + 1)) >> 1;
		var k = 1;
		while (k * DRAIN_STEP_FRAMES < f) {
			total += f - k * DRAIN_STEP_FRAMES;
			k++;
		}
		return total;
	}
}

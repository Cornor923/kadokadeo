package labrute;

// the state of a run: the brute of the player, its gold, its purchases, its fights and its league
class Run {
	public var brute:Brute;
	public var gold:Int = Balance.START_GOLD;
	// the ears: only for the tiers of the perks (Balance.TIER_EARS), won by the fights
	public var ears:Int = 0;
	// fights won: the fights that count (a defeat saved by the bandage takes the player nowhere), the wins
	public var fights:Int = 0;
	public var wins:Int = 0;
	// purchases of hp, strength, agility, speed
	public var statsBought:Array<Int> = [0, 0, 0, 0];
	public var weaponsBought:Int = 0;
	public var skillsBought:Int = 0;
	// « Pansement »: the first lost fight is survived (once)
	public var bandageUsed:Bool = false;
	// the 3 opponents offered after the shop (easy, medium, hard), until the next fight
	public var opponents:Array<Brute> = null;
	// the last perk bought or upgraded (shown by the shop): what it is (weapon, skill, pet), its name, its tier now
	public var lastGain:String = null;
	public var lastGainName:String = null;
	public var lastGainTier:Int = 1;
	public var lastGainFrame:Int = -1000;

	public function new() {
		brute = Brute.createStarter();
		brute.name = "Vous";
		syncLevel();
	}

	public static inline function lastLeague():Int {
		return Data.LEAGUES.length - 1;
	}

	// the leagues stop at the last one
	public function league():Int {
		var l = Std.int(wins / Balance.WINS_PER_LEAGUE);
		return l > lastLeague() ? lastLeague() : l;
	}

	public inline function multiplier():Float {
		return Balance.leagueMultiplier(league());
	}

	// the level of the player's brute: the fights played + 2
	public function playerLevel():Int {
		return fights + Balance.LEVEL_BASE;
	}

	// the level of the opponents: the player's, and one level more every EXTRA_LEVEL_WINS fights won
	public function hiddenLevel():Int {
		return playerLevel() + Std.int(wins / Balance.EXTRA_LEVEL_WINS);
	}

	// after a fight won: the wins toward the next league (0...WINS_PER_LEAGUE), -1 in the last league
	public function leagueProgress():Int {
		return league() >= lastLeague() ? -1 : wins % Balance.WINS_PER_LEAGUE;
	}

	// LaBrute's HP formula counts the level: the level of the player (the opponents' grows faster)
	public function syncLevel():Void {
		brute.level = playerLevel();
		brute.recompute();
	}

	public function hasBandage():Bool {
		return brute.hasSkill("regeneration") && !bandageUsed;
	}

	public function reward(difficulty:Int):Int {
		return Math.round(Balance.WIN_REWARD[difficulty] * multiplier());
	}

	public function makeOpponents():Void {
		opponents = [];
		for (i in 0...3) {
			var levels = hiddenLevel() + Balance.OPPONENT_OFFSETS[i];
			opponents.push(Opponents.make(levels < 0 ? 0 : levels));
		}
	}
}

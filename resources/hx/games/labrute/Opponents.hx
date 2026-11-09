package labrute;

// The opponents of the arena: a LaBrute starter brute, then one random bonus by level (a weapon, a pet, a skill,
// +3 to one stat, +12 HP or two tiers more on its perks; the pet weighs Balance.PET_ODDS_FACTOR, the others 1).
class Opponents {
	static var BONUSES:Array<{id:Int, odds:Float}> = [
		{id: 0, odds: 1}, {id: 1, odds: Balance.PET_ODDS_FACTOR}, {id: 2, odds: 1}, {id: 3, odds: 1}, {id: 4, odds: 1}, {id: 5, odds: 1}
	];

	public static function make(levels:Int):Brute {
		var b = Brute.createStarter(true);
		b.level = levels < 1 ? 1 : levels;
		for (i in 0...levels)
			levelUp(b);
		b.recompute();
		return b;
	}

	static function levelUp(b:Brute):Void {
		var done = switch (Rng.weighted(BONUSES, (b) -> b.odds).id) {
			case 0: gainPerk(b, ["weapon"]);
			case 1: gainPerk(b, ["pet"]);
			case 2: gainPerk(b, ["skill"]);
			case 3: statPoints(b);
			case 4:
				b.hpStat += Balance.LEVEL_HP;
				true;
			default: upgrades(b);
		}
		if (!done)
			statPoints(b);
		b.recompute();
	}

	static function gainPerk(b:Brute, types:Array<String>):Bool {
		if (!Brute.canGetNew(b, types))
			return false;
		var perk = Brute.randomBonus(b, types, true, true, 200);
		// (no « Pansement »: its stat points instead)
		if (perk == null || perk.name == Brute.OPPONENT_EXCLUDED)
			return false;
		b.addPerk(perk.type, perk.name);
		return true;
	}

	// 3 points in one of strength, agility, speed
	static function statPoints(b:Brute):Bool {
		switch (Rng.between(0, 2)) {
			case 0:
				b.strengthStat += Balance.LEVEL_STAT_POINTS;
			case 1:
				b.agilityStat += Balance.LEVEL_STAT_POINTS;
			default:
				b.speedStat += Balance.LEVEL_STAT_POINTS;
		}
		return true;
	}

	// tiers more on the weapons / skills / pets it has
	static function upgrades(b:Brute):Bool {
		var done = false;
		for (i in 0...Balance.LEVEL_UPGRADES) {
			var choices:Array<{type:String, index:Int}> = [];
			for (i in 0...b.weapons.length)
				if (b.weapons[i].tier < 3)
					choices.push({type: "weapon", index: i});
			for (i in 0...b.skills.length)
				if (b.skills[i].tier < 3)
					choices.push({type: "skill", index: i});
			for (i in 0...b.pets.length)
				if (b.pets[i].tier < 3)
					choices.push({type: "pet", index: i});
			if (choices.length == 0)
				break;
			var c = Rng.item(choices);
			b.upgrade(c.type, c.index);
			done = true;
		}
		return done;
	}
}

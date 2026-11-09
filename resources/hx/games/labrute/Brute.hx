package labrute;

import labrute.Data;

// a weapon, a skill or a pet of a brute, and its tier (1 to 3)
class Perk {
	public var name:String;
	public var tier:Int;

	public function new(name:String, tier:Int) {
		this.name = name;
		this.tier = tier;
	}
}

// A brute of the run (the player's, an opponent, a backup): LaBrute's model (prisma Brute, core/src/brute), its stats
// written as stat * modifier, its perks with their tier, and its look (the parts and colors of labrute-pixi-fighter).
class Brute {
	public static var nextUid = 1;

	public static var PARTS_MALE = {p2: 7, p3: 11, p4: 5, p7: 6, p1: 1, p1a: 1, p1b: 1, p6: 1, p8: 4, p7b: 6, p5: 1};
	public static var PARTS_FEMALE = {p2: 0, p3: 11, p4: 3, p7: 6, p1: 1, p1a: 1, p1b: 1, p6: 0, p8: 4, p7b: 6, p5: 1};
	public static var SKIN_MALE = ["#996600", "#eccd57", "#cb841b", "#d79b75", "#fbe6c8", "#f8d198"];
	public static var SKIN_FEMALE = ["#996600", "#f8cdc2", "#cb841b", "#eaaca6", "#fbe6c8", "#f8d198"];
	public static var HAIR_MALE = [
		"#784129", "#fff9ae", "#b85f1d", "#4f677d", "#df7e37", "#fbcd15", "#ffaa1e", "#952f04", "#a2886f", "#fff2df"
	];
	public static var HAIR_FEMALE = [
		"#fff9ae", "#b85f1d", "#eea2c9", "#8e63ad", "#fbcd15", "#ffaa1e", "#952f04", "#a2886f", "#fff2df"
	];
	public static var CLOTHING = [
		"#7bad30", "#b78104", "#bb1111", "#559399", "#fae31f", "#784129", "#7a73c8", "#fff9ae", "#f0dc99", "#b6e7a9", "#d31818",
		"#b85f1d", "#97cbff", "#8ba3d7", "#df7e37", "#d5eaff", "#ffaa1e", "#cbff97", "#ffcc79", "#fff2df"
	];

	public var uid:Int;
	public var name:String = "";
	public var gender:String = "male";
	public var parts:Dynamic;
	public var colors:Dynamic;
	public var level:Int = 1;
	public var hpStat:Int = 0;
	public var hpModifier:Float = 1;
	public var hpValue:Int = 0;
	public var strengthStat:Int = 0;
	public var strengthModifier:Float = 1;
	public var strengthValue:Int = 0;
	public var agilityStat:Int = 0;
	public var agilityModifier:Float = 1;
	public var agilityValue:Int = 0;
	public var speedStat:Int = 0;
	public var speedModifier:Float = 1;
	public var speedValue:Int = 0;
	public var weapons:Array<Perk> = [];
	public var skills:Array<Perk> = [];
	public var pets:Array<Perk> = [];

	public function new() {
		uid = nextUid++;
	}

	// getHP.ts and the values of calculatedBrute.ts
	public function recompute():Void {
		hpValue = Std.int(Math.max(1, Math.floor(50 + hpStat * hpModifier + level * 2)));
		strengthValue = Math.floor(strengthStat * strengthModifier);
		agilityValue = Math.floor(agilityStat * agilityModifier);
		speedValue = Math.floor(speedStat * speedModifier);
	}

	static function find(list:Array<Perk>, name:String):Perk {
		for (p in list)
			if (p.name == name)
				return p;
		return null;
	}

	public function weaponTier(name:String):Int {
		var p = find(weapons, name);
		return p == null ? 0 : p.tier;
	}

	public function skillTier(name:String):Int {
		var p = find(skills, name);
		return p == null ? 0 : p.tier;
	}

	public function petTier(name:String):Int {
		var p = find(pets, name);
		return p == null ? 0 : p.tier;
	}

	public inline function hasSkill(name:String):Bool {
		return skillTier(name) > 0;
	}

	public function owns(type:String, name:String):Bool {
		return switch (type) {
			case "weapon": weaponTier(name) > 0;
			case "pet": petTier(name) > 0;
			default: skillTier(name) > 0;
		}
	}

	// applySkillModifiers.ts: the hp / strength / agility / speed changes of a skill at a tier (the previous tier removed)
	public function applySkillModifiers(name:String, tier:Int, removePrevious:Bool = true):Void {
		var skill = Data.skill(name);
		for (m in skill.mods) {
			if (m.stat != S.HP && m.stat != S.STRENGTH && m.stat != S.AGILITY && m.stat != S.SPEED)
				continue;
			if (m.flat != null) {
				var d = m.flat[tier - 1] - (tier > 1 && removePrevious ? m.flat[tier - 2] : 0);
				var v = Std.int(d);
				switch (m.stat) {
					case S.HP:
						hpStat += v;
					case S.STRENGTH:
						strengthStat += v;
					case S.AGILITY:
						agilityStat += v;
					default:
						speedStat += v;
				}
			}
			if (m.percent != null) {
				var d = m.percent[tier - 1] - (tier > 1 && removePrevious ? m.percent[tier - 2] : 0);
				switch (m.stat) {
					case S.HP:
						hpModifier += d;
					case S.STRENGTH:
						strengthModifier += d;
					case S.AGILITY:
						agilityModifier += d;
					default:
						speedModifier += d;
				}
			}
		}
		recompute();
	}

	public function addPerk(type:String, name:String):Void {
		switch (type) {
			case "weapon":
				weapons.push(new Perk(name, 1));
			case "pet":
				pets.push(new Perk(name, 1));
				// the HP malus of the pet (createRandomBruteStats.ts)
				hpModifier -= Data.pet(name).hpMalus[0];
				recompute();
			default:
				skills.push(new Perk(name, 1));
				applySkillModifiers(name, 1);
		}
	}

	// one tier more (no more than 3)
	public function upgrade(type:String, index:Int):Bool {
		var list = type == "weapon" ? weapons : type == "pet" ? pets : skills;
		var p = list[index];
		if (p == null || p.tier >= 3)
			return false;
		p.tier++;
		if (type == "skill") {
			applySkillModifiers(p.name, p.tier, true);
		} else if (type == "pet") {
			var pet = Data.pet(p.name);
			hpModifier += pet.hpMalus[p.tier - 2] - pet.hpMalus[p.tier - 1];
			recompute();
		}
		return true;
	}

	public function countSkills(supers:Bool):Int {
		var n = 0;
		for (s in skills)
			if ((Data.skill(s.name).type == "super") == supers)
				n++;
		return n;
	}

	// ---------------------------------------------------------------- creation

	// getRandomStartingStats.ts
	public static function startingStats():{hp:Int, strength:Int, agility:Int, speed:Int} {
		var available = Data.BRUTE_STARTING_POINTS;
		var hpPoints = Rng.between(2, 5);
		available -= hpPoints;
		var strength = Std.int(Math.min(Rng.between(2, 5), available - 2 * 2));
		available -= strength;
		var agility = Std.int(Math.min(Rng.between(2, 5), available - 2 * 1));
		available -= agility;
		return {
			hp: hpPoints * 6,
			strength: strength,
			agility: agility,
			speed: available
		};
	}

	public static inline var OPPONENT_EXCLUDED = "regeneration";

	// createRandomBruteStats.ts: the stats of a new brute and its random perk, with a random look and name
	// opponent: never « Pansement » (it forgives a defeat of the run: the player's only)
	public static function createStarter(?opponent:Bool = false):Brute {
		var b = new Brute();
		var perk = randomBonus(b, ["pet", "skill", "weapon"], true, false);
		while (opponent && perk != null && perk.name == OPPONENT_EXCLUDED)
			perk = randomBonus(b, ["pet", "skill", "weapon"], true, false);
		var stats = startingStats();
		b.hpStat += stats.hp;
		b.strengthStat += stats.strength;
		b.agilityStat += stats.agility;
		b.speedStat += stats.speed;
		if (perk != null)
			b.addPerk(perk.type, perk.name);
		b.recompute();
		b.randomLook();
		b.name = Names.random();
		return b;
	}

	// getRandomBody.ts, getRandomColors.ts
	public function randomLook():Void {
		gender = Rng.between(0, 1) == 0 ? "male" : "female";
		var avail:Dynamic = gender == "male" ? PARTS_MALE : PARTS_FEMALE;
		var outfit = Rng.between(0, avail.p7);
		parts = {
			p1: Rng.between(0, avail.p1),
			p1a: Rng.between(0, avail.p1a),
			p1b: Rng.between(0, avail.p1b),
			p2: Rng.between(0, avail.p2),
			p3: Rng.between(0, avail.p3),
			p4: Rng.between(0, avail.p4),
			p5: Rng.between(0, avail.p5),
			p6: Rng.between(0, avail.p6),
			p7: outfit,
			p7b: outfit,
			p8: Rng.between(0, avail.p8),
		};
		var skin = Rng.item(gender == "male" ? SKIN_MALE : SKIN_FEMALE);
		var hair = Rng.item(gender == "male" ? HAIR_MALE : HAIR_FEMALE);
		colors = {
			col0: skin,
			col0a: skin,
			col0c: skin,
			col1: hair,
			col1a: hair,
			col1b: hair,
			col1c: hair,
			col1d: hair,
			col2: Rng.item(CLOTHING),
			col2a: Rng.item(CLOTHING),
			col2b: Rng.item(CLOTHING),
			col3: Rng.item(CLOTHING),
			col3b: Rng.item(CLOTHING),
			col4: Rng.item(CLOTHING),
			col4a: Rng.item(CLOTHING),
			col4b: Rng.item(CLOTHING),
		};
	}

	// ---------------------------------------------------------------- random perks (getRandomBonus.ts)

	// preventSomeBonuses
	public static function preventPerk(b:Brute, type:String, name:String):Bool {
		if (type == "pet") {
			var tier = b.petTier(name);
			if (tier >= 3)
				return true;
			switch (name) {
				case "dog2":
					return b.petTier("dog1") == 0;
				case "dog3":
					return b.petTier("dog1") == 0 || b.petTier("dog2") == 0;
				case "panther":
					return tier == 0 && b.petTier("bear") > 0 && Rng.between(1, 1000) <= 1;
				case "bear":
					return tier == 0 && b.petTier("panther") > 0 && Rng.between(1, 1000) <= 1;
				default:
					return false;
			}
		}
		if (type == "skill") {
			var tier = b.skillTier(name);
			if (tier >= 3)
				return true;
			if (Data.skill(name).type == "booster" && tier == 0) {
				// fewer and fewer boosters
				var gotten = 0;
				for (s in b.skills)
					if (Data.skill(s.name).type == "booster")
						gotten++;
				return switch (gotten) {
					case 0: false;
					case 1: Rng.between(1, 100) < 95;
					case 2: Rng.between(1, 100) < 98;
					case 3, 4, 5: Rng.between(1, 1000) < 999;
					default: false;
				}
			}
			return false;
		}
		// some weapons are limited
		var limited = 0;
		for (w in b.weapons)
			if (Data.LIMITED_WEAPONS.indexOf(w.name) >= 0)
				limited++;
		if (Data.LIMITED_WEAPONS.indexOf(name) >= 0 && limited >= Data.MAX_LIMITED_WEAPONS)
			return true;
		return b.weaponTier(name) >= 3;
	}

	// getRandomBonus: a perk type drawn by the odds of its list, then a perk of that list by its odds. The shop and the
	// opponents only want new perks (excludeOwned); LaBrute gives a tier more for a perk already learned. KadoKadeo: the
	// pets weigh Balance.PET_ODDS_FACTOR times their odds.
	public static function randomBonus(b:Brute, types:Array<String>, rerollUntilFound:Bool, excludeOwned:Bool,
			maxTries:Int = 1000):{type:String, name:String} {
		var perkOdds:Array<{name:String, odds:Float}> = [];
		if (types.indexOf("pet") >= 0)
			perkOdds.push({name: "pet", odds: Data.PETS_TOTAL_ODDS * Balance.PET_ODDS_FACTOR});
		if (types.indexOf("skill") >= 0)
			perkOdds.push({name: "skill", odds: Data.SKILLS_TOTAL_ODDS});
		if (types.indexOf("weapon") >= 0)
			perkOdds.push({name: "weapon", odds: Data.WEAPONS_TOTAL_ODDS});
		if (perkOdds.length == 0)
			return null;
		var tries = 0;
		while (true) {
			var type = Rng.weighted(perkOdds, (p) -> p.odds).name;
			var name = type == "pet" ? Rng.weighted(Data.PETS, (p) -> p.odds).name : type == "skill" ? Rng.weighted(Data.SKILLS,
				(s) -> s.odds).name : Rng.weighted(Data.WEAPONS, (w) -> w.odds).name;
			var found = !(excludeOwned && b.owns(type, name)) && !preventPerk(b, type, name);
			if (found)
				return {type: type, name: name};
			tries++;
			if (!rerollUntilFound || tries >= maxTries)
				break;
		}
		// KadoKadeo: LaBrute makes the boosters rarer and rarer (999 draws out of 1000 drawn again from the 3rd one): when
		// only they are left, the draws above fail; a new perk is then drawn among the ones still possible
		if (!excludeOwned)
			return null;
		var left = candidates(b, types);
		if (left.length == 0)
			return null;
		var perk = Rng.weighted(left, (p) -> p.odds);
		return {type: perk.type, name: perk.name};
	}

	// the new perks of these types a draw can still give: not owned, the dogs in their order, the bear or the panther
	// (LaBrute: the other one 1 time in 1000), at most MAX_LIMITED_WEAPONS limited weapons. The boosters are in it.
	public static function candidates(b:Brute, types:Array<String>):Array<{type:String, name:String, odds:Float}> {
		var list:Array<{type:String, name:String, odds:Float}> = [];
		if (types.indexOf("weapon") >= 0) {
			var limited = 0;
			for (w in b.weapons)
				if (Data.LIMITED_WEAPONS.indexOf(w.name) >= 0)
					limited++;
			for (w in Data.WEAPONS)
				if (b.weaponTier(w.name) == 0 && (limited < Data.MAX_LIMITED_WEAPONS || Data.LIMITED_WEAPONS.indexOf(w.name) < 0))
					list.push({type: "weapon", name: w.name, odds: w.odds});
		}
		if (types.indexOf("skill") >= 0)
			for (s in Data.SKILLS)
				if (b.skillTier(s.name) == 0 && s.odds > 0)
					list.push({type: "skill", name: s.name, odds: s.odds});
		if (types.indexOf("pet") >= 0)
			for (p in Data.PETS) {
				if (b.petTier(p.name) > 0)
					continue;
				if (p.name == "dog2" && b.petTier("dog1") == 0)
					continue;
				if (p.name == "dog3" && (b.petTier("dog1") == 0 || b.petTier("dog2") == 0))
					continue;
				if ((p.name == "panther" && b.petTier("bear") > 0) || (p.name == "bear" && b.petTier("panther") > 0))
					continue;
				list.push({type: "pet", name: p.name, odds: p.odds * Balance.PET_ODDS_FACTOR});
			}
		return list;
	}

	// whether randomBonus can still give a new perk of these types
	public static function canGetNew(b:Brute, types:Array<String>):Bool {
		return candidates(b, types).length > 0;
	}
}

package labrute;

// LaBrute's data (labrute-react, core/src/brute/weapons.ts, skills.ts, pets.ts, constants.ts): every value is the
// original one, its 3 numbers are the 3 tiers of the perk (green / orange / red in the game). The French names are
// the ones of LaBrute (client/src/i18n/locales/fr).

// the stats of LaBrute (core/src/brute/skills.ts, FightStat): the index of a value in Fighter.stat and in the tables
class S {
	public static inline var REVERSAL = 0;
	public static inline var COUNTER = 1;
	public static inline var EVASION = 2;
	public static inline var DEXTERITY = 3;
	public static inline var BLOCK = 4;
	public static inline var ACCURACY = 5;
	public static inline var DISARM = 6;
	public static inline var SABOTAGE = 7;
	public static inline var COMBO = 8;
	public static inline var DEFLECT = 9;
	public static inline var ARMOR = 10;
	public static inline var DAMAGE = 11;
	public static inline var CRIT_CHANCE = 12;
	public static inline var CRIT_DAMAGE = 13;
	public static inline var HIT_SPEED = 14;
	public static inline var INITIATIVE = 15;
	public static inline var STRENGTH = 16;
	public static inline var AGILITY = 17;
	public static inline var SPEED = 18;
	public static inline var HP = 19;
	public static inline var REGENERATION = 20;
	public static inline var WEAPON_GRIP = 21;
	public static inline var SIZE = 22;
	public static inline var COUNT = 23;

	// (the names of LaBrute in its tooltips: the sabotage, the regeneration as it names their stat)
	public static var FR:Array<String> = [
		"Riposte", "Contre", "Esquive", "Dextérité", "Parade", "Précision", "Désarmement",
		"De chances de détruire une arme en réserve à chaque coup qui blesse", "Combo", "Renvoi", "Armure", "Dégâts", "Chance critique",
		"Dégâts critiques", "Vitesse de frappe", "Initiative", "Force", "Agilité", "Rapidité", "PV", "Régénération", "Poigne", "Taille"
	];
	// the name of a stat in the language of the game
	public static function name(stat:Int):String {
		return Lang.data("stat", Std.string(stat), FR[stat]);
	}

	// the colors of the stats in the tooltips of LaBrute (StatColor), by stat
	public static var COLORS:Array<Int> = [
		0x8FBC8F, 0x8A4520, 0x8686FF, 0xFFB6C1, 0x808080, 0x8686FF, 0xFF70FF, 0xFF4500, 0x8686FF, 0xFF4500, 0x008080, 0xFF0000, 0xFF0000,
		0xFF0000, 0x800080, 0xF08080, 0xFF0000, 0x8686FF, 0xEB9800, 0x17A717, 0x17A717, 0xFF70FF, 0x17A717
	];
}

class WeaponData {
	public var id:Int;
	public var name:String;
	public var fr:String;
	public var odds:Float;
	public var types:Array<String>;
	public var tempo:Array<Float>;
	// by stat (S): the 3 tiers, null for 0
	public var stats:Array<Array<Float>>;
	public var damage:Array<Float>;
	public var toss:Array<Float>;
	public var reach:Int;
	public var animation:String;

	public function new(id:Int, name:String, fr:String, odds:Float, types:Array<String>, tempo:Array<Float>, reversal:Array<Float>,
			evasion:Array<Float>, dexterity:Array<Float>, block:Array<Float>, accuracy:Array<Float>, disarm:Array<Float>,
			combo:Array<Float>, deflect:Array<Float>, critChance:Array<Float>, critDamage:Array<Float>, damage:Array<Float>,
			toss:Array<Float>, reach:Int, animation:String) {
		this.id = id;
		this.name = name;
		this.fr = fr;
		this.odds = odds;
		this.types = types;
		this.tempo = tempo;
		stats = [for (i in 0...S.COUNT) null];
		stats[S.REVERSAL] = reversal;
		stats[S.EVASION] = evasion;
		stats[S.DEXTERITY] = dexterity;
		stats[S.BLOCK] = block;
		stats[S.ACCURACY] = accuracy;
		stats[S.DISARM] = disarm;
		stats[S.COMBO] = combo;
		stats[S.DEFLECT] = deflect;
		stats[S.CRIT_CHANCE] = critChance;
		stats[S.CRIT_DAMAGE] = critDamage;
		this.damage = damage;
		this.toss = toss;
		this.reach = reach;
		this.animation = animation;
	}

	// its name in the language of the game
	public var label(get, never):String;

	function get_label():String {
		return Lang.data("weapon", name, fr);
	}

	public inline function stat(s:Int, tier:Int):Float {
		var a = stats[s];
		return a == null ? 0 : a[tier - 1];
	}

	public inline function has(type:String):Bool {
		return types.indexOf(type) >= 0;
	}
}

// a stat change of a skill (SkillModifiers): weaponType 0 = always, 1 = bare hands (or the mug), 2 = with a weapon of `wt`
class SkillMod {
	public var stat:Int;
	public var flat:Array<Float>;
	public var percent:Array<Float>;
	public var weaponType:Int;
	public var wt:String;
	public var details:String;
	public var opponent:Bool;

	public function new(stat:Int, flat:Array<Float>, percent:Array<Float>, ?weaponType:Int = 0, ?wt:String = null, ?details:String = null,
			?opponent:Bool = false) {
		this.stat = stat;
		this.flat = flat;
		this.percent = percent;
		this.weaponType = weaponType;
		this.wt = wt;
		this.details = details;
		this.opponent = opponent;
	}

	public inline function conditional():Bool {
		return details != null || weaponType != 0;
	}
}

class SkillData {
	public var id:Int;
	public var name:String;
	public var fr:String;
	public var desc:String;
	public var odds:Float;
	// passive, booster, super, talent
	public var type:String;
	public var toss:Array<Float>;
	public var uses:Array<Int>;
	public var canReload:Bool;
	public var mods:Array<SkillMod>;
	// ExtraTieredSkillData
	public var extra:Array<Float>;

	public function new(id:Int, name:String, fr:String, odds:Float, type:String, toss:Array<Float>, uses:Array<Int>, canReload:Bool,
			mods:Array<SkillMod>, extra:Array<Float>, desc:String) {
		this.id = id;
		this.name = name;
		this.fr = fr;
		this.odds = odds;
		this.type = type;
		this.toss = toss;
		this.uses = uses;
		this.canReload = canReload;
		this.mods = mods;
		this.extra = extra;
		this.desc = desc;
	}

	// its name and its description in the language of the game
	public var label(get, never):String;
	public var text(get, never):String;

	function get_label():String {
		return Lang.data("skill", name, fr);
	}

	function get_text():String {
		return Lang.data("desc", name, desc);
	}

	public function mod(stat:Int):SkillMod {
		for (m in mods)
			if (m.stat == stat)
				return m;
		return null;
	}
}

class PetData {
	public var name:String;
	public var fr:String;
	public var odds:Float;
	public var hpMalus:Array<Float>;
	public var initiative:Array<Float>;
	public var strength:Array<Float>;
	public var agility:Array<Float>;
	public var speed:Array<Float>;
	public var hp:Array<Float>;
	public var counter:Array<Float>;
	public var combo:Array<Float>;
	public var block:Array<Float>;
	public var evasion:Array<Float>;
	public var accuracy:Array<Float>;
	public var disarm:Array<Float>;
	public var damage:Array<Float>;
	// scaledStat.ts scalingByPet: strength, agility, speed, hp
	public var scaling:Array<Float>;
	// the model of labrute-pixi-fighter and its size (constants.ts FIGHTER_WIDTH / HEIGHT)
	public var model:String;
	public var width:Int;
	public var height:Int;

	public function new(name:String, fr:String, odds:Float, hpMalus:Array<Float>, initiative:Array<Float>, strength:Array<Float>,
			agility:Array<Float>, speed:Array<Float>, hp:Array<Float>, counter:Array<Float>, combo:Array<Float>, block:Array<Float>,
			evasion:Array<Float>, accuracy:Array<Float>, disarm:Array<Float>, damage:Array<Float>, scaling:Array<Float>, model:String,
			width:Int, height:Int) {
		this.name = name;
		this.fr = fr;
		this.odds = odds;
		this.hpMalus = hpMalus;
		this.initiative = initiative;
		this.strength = strength;
		this.agility = agility;
		this.speed = speed;
		this.hp = hp;
		this.counter = counter;
		this.combo = combo;
		this.block = block;
		this.evasion = evasion;
		this.accuracy = accuracy;
		this.disarm = disarm;
		this.damage = damage;
		this.scaling = scaling;
		this.model = model;
		this.width = width;
		this.height = height;
	}

	// its name in the language of the game
	public var label(get, never):String;

	function get_label():String {
		return Lang.data("pet", name, fr);
	}
}

class Data {
	// constants.ts
	public static inline var NO_WEAPON_TOSS = 10;
	public static inline var NO_SKILL_TOSS = 10;
	public static inline var BARE_HANDS_DAMAGE = 5;
	public static inline var BRUTE_STARTING_POINTS = 11;
	public static inline var BASE_TEMPO = 1.2;
	public static var BASE_FIGHTER_STATS:Array<Float> = {
		var a = [for (i in 0...S.COUNT) 0.0];
		a[S.EVASION] = 0.1;
		a[S.DEXTERITY] = 0.2;
		a[S.BLOCK] = -0.25;
		a[S.DISARM] = 0.05;
		a[S.CRIT_CHANCE] = 0.05;
		a[S.CRIT_DAMAGE] = 1.5;
		a;
	};

	public static inline var BRUTE_WIDTH = 50;
	public static inline var BRUTE_HEIGHT = 80;

	static inline function c(v:Float):Array<Float> {
		return [v, v, v];
	}

	// ---------------------------------------------------------------- weapons (weapons.ts, in the order of its record)
	public static var WEAPONS:Array<WeaponData> = [
		new WeaponData(7, "axe", "Marteau", 3, ["heavy", "blunt"], c(2.3), c(-0.2), c(-0.4), c(-0.8), c(-0.5), [0.5, 0.6, 0.7],
			[0.1, 0.15, 0.2], c(-0.4), null, null, null, [55, 75, 95], [5, 7, 9], 1, "slash"),
		new WeaponData(15, "baton", "Bâton", 70, ["long"], c(1), [0.3, 0.35, 0.4], [0.05, 0.1, 0.15], null, [0.25, 0.3, 0.35], null,
			[0.25, 0.3, 0.35], [0.1, 0.15, 0.2], null, [0.2, 0.25, 0.3], null, [6, 8, 10], [3, 5, 7], 3, "estoc"),
		new WeaponData(23, "broadsword", "Glaive", 100, ["sharp"], c(1.2), [0.1, 0.15, 0.2], null, null, [0.15, 0.25, 0.35], null,
			[0.15, 0.2, 0.25], null, null, [0.3, 0.35, 0.4], null, [10, 13, 16], [5, 7, 9], 1, "slash"),
		new WeaponData(8, "bumps", "Massue", 50, ["heavy", "blunt"], c(2), c(-0.3), c(-0.3), [-0.65, -0.6, -0.55], c(-0.3), [0.3, 0.4, 0.5],
			[0.1, 0.15, 0.2], [-0.6, -0.55, -0.5], null, [0.2, 0.3, 0.4], null, [30, 40, 50], [5, 7, 9], 1, "slash"),
		new WeaponData(0, "fan", "Éventail", 2, ["fast"], c(0.28), [0.5, 0.55, 0.6], [0.6, 0.65, 0.7], [0.5, 0.55, 0.6], c(-0.5), null,
			c(-0.5), [0.45, 0.5, 0.55], [0.25, 0.3, 0.35], null, null, [4, 6, 8], [5, 7, 9], 0, "slash"),
		new WeaponData(9, "flail", "Fléau", 4, ["heavy", "blunt"], c(2.2), null, c(-0.3), c(-1.6), c(-0.5), [1.5, 2, 2.5], c(-0.2),
			[0.3, 0.35, 0.4], null, c(-0.2), null, [36, 42, 48], [5, 7, 9], 1, "slash"),
		new WeaponData(10, "fryingPan", "Poêle", 0.4, ["heavy", "blunt"], c(1.2), null, null, null, [0.4, 0.45, 0.5], null, null,
			c(-0.4), [0.4, 0.5, 0.6], null, null, [17, 22, 27], [2, 4, 6], 1, "slash"),
		new WeaponData(16, "halbard", "Hallebarde", 2, ["long", "heavy", "sharp"], c(1.8), null, null, c(-0.4), null, null,
			[0.1, 0.15, 0.2], [0.1, 0.15, 0.2], null, null, null, [24, 30, 36], [2, 4, 6], 4, "slash"),
		new WeaponData(11, "hatchet", "Hache", 40, ["heavy", "sharp"], c(1.5), null, null, null, c(-0.1), null, null, null, null,
			[0.15, 0.25, 0.35], null, [17, 22, 27], [3, 5, 7], 1, "slash"),
		new WeaponData(1, "keyboard", "Clavier", 0.4, ["fast", "blunt"], c(1), null, [0.1, 0.15, 0.2], [0.2, 0.3, 0.4], null, null, null,
			[0.5, 0.55, 0.6], [0.3, 0.35, 0.4], null, null, [7, 10, 13], [2, 4, 6], 1, "slash"),
		new WeaponData(2, "knife", "Couteau", 80, ["fast", "sharp"], c(0.6), null, [0.1, 0.15, 0.2], [0.5, 0.55, 0.6], null, null, null,
			[0.3, 0.4, 0.5], null, c(0.25), null, [7, 10, 13], [5, 7, 9], 0, "estoc"),
		new WeaponData(17, "lance", "Lance", 40, ["long"], c(1.2), c(-0.1), null, null, null, null, [0.1, 0.15, 0.2], null, null,
			[0.15, 0.25, 0.35], null, [12, 16, 20], [2, 4, 6], 3, "estoc"),
		new WeaponData(3, "leek", "Poireau", 0.4, ["fast", "blunt"], c(1.1), c(1), null, c(-1), c(-0.5), [2, 3, 4], null, [2, 3, 4], null,
			null, null, [5, 8, 11], [2, 4, 6], 1, "slash"),
		new WeaponData(12, "mammothBone", "Os de mammouth", 20, ["heavy", "blunt"], c(1.6), null, null, c(-0.5), null,
			[0.5, 0.55, 0.6], [0.1, 0.15, 0.2], c(-0.1), null, [0.15, 0.25, 0.35], null, [14, 18, 22], [5, 7, 9], 1, "slash"),
		new WeaponData(13, "morningStar", "Étoile du matin", 6, ["heavy", "blunt"], c(1.5), null, c(-0.1), c(-0.35), null,
			[0.3, 0.4, 0.5], [0.1, 0.15, 0.2], null, null, [0.05, 0.1, 0.15], null, [20, 30, 40], [5, 7, 9], 1, "slash"),
		new WeaponData(4, "mug", "Mug", 0.4, ["fast"], c(0.9), null, [0.15, 0.2, 0.25], [0.3, 0.4, 0.5], c(-0.1), null, null,
			[0.4, 0.5, 0.6], null, null, null, [8, 12, 16], [2, 4, 6], 0, "estoc"),
		new WeaponData(20, "noodleBowl", "Bol de nouilles", 0.4, ["thrown"], c(0.45), null, [0.1, 0.15, 0.2], null, c(-0.1), null, null,
			[0.3, 0.4, 0.5], null, null, null, [10, 15, 20], [2, 4, 6], 0, "fist"),
		new WeaponData(21, "piopio", "Piou Piou", 0.4, ["thrown"], c(0.32), null, [0.5, 0.55, 0.6], null, c(-0.1), null,
			[0.5, 0.55, 0.6], null, null, null, null, [5, 8, 11], [2, 4, 6], 0, "fist"),
		new WeaponData(6, "racquet", "Raquette", 0.4, ["fast", "blunt"], c(0.8), [1, 1.5, 2], [0.1, 0.15, 0.2], null, [0.2, 0.25, 0.3],
			null, null, null, [0.5, 0.55, 0.6], null, null, [6, 9, 12], [2, 4, 6], 1, "slash"),
		new WeaponData(5, "sai", "Sai", 6, ["fast"], c(0.6), null, [0.1, 0.15, 0.2], [0.25, 0.35, 0.45], [0.3, 0.35, 0.4], null,
			[0.75, 0.8, 0.85], [0.3, 0.35, 0.4], [0.25, 0.35, 0.45], null, null, [8, 12, 16], [5, 7, 9], 0, "estoc"),
		new WeaponData(24, "scimitar", "Cimeterre", 6, ["sharp"], c(0.8), null, null, [0.2, 0.3, 0.4], [0.1, 0.15, 0.2], null, null,
			[0.15, 0.25, 0.35], null, [0.05, 0.1, 0.15], null, [10, 15, 20], [3, 5, 7], 1, "slash"),
		new WeaponData(22, "shuriken", "Shuriken", 8, ["thrown"], c(0.12), null, [0.15, 0.2, 0.25], null, c(-0.1), null, c(-0.5),
			[0.3, 0.4, 0.5], null, null, null, [3, 5, 7], [5, 7, 9], 0, "fist"),
		new WeaponData(25, "sword", "Épée", 4, ["sharp"], c(1.8), null, c(-0.2), [0.1, 0.15, 0.2], null, c(-0.2), [0.1, 0.15, 0.2], null,
			null, [0.05, 0.1, 0.15], null, [28, 36, 44], [5, 7, 9], 2, "slash"),
		new WeaponData(18, "trident", "Trident", 10, ["long"], c(1.4), [0.05, 0.1, 0.15], null, null, null, null, [0.2, 0.3, 0.4], null,
			null, [0.05, 0.1, 0.15], null, [14, 18, 22], [3, 5, 7], 3, "estoc"),
		new WeaponData(14, "trombone", "Trombone", 0.4, ["heavy", "blunt"], c(2.5), null, null, c(-0.3), [0.2, 0.25, 0.3],
			[0.2, 0.25, 0.3], [0.5, 0.55, 0.6], [0.3, 0.35, 0.4], null, c(-0.1), null, [20, 25, 30], [2, 4, 6], 2, "slash"),
		new WeaponData(19, "whip", "Fouet", 3, ["long"], c(1.5), c(-0.1), [0.3, 0.35, 0.4], [0.5, 0.55, 0.6], c(-0.2), c(-0.2),
			[0.3, 0.35, 0.4], [0.35, 0.4, 0.45], null, null, null, [10, 15, 20], [5, 7, 9], 5, "whip"),
	];

	// weapons.ts limitedWeapons, MAX_LIMITED_WEAPONS
	public static var LIMITED_WEAPONS:Array<String> = [
		"knife", "broadsword", "lance", "baton", "trident", "hatchet", "scimitar", "axe", "sword", "fan", "shuriken", "bumps",
		"morningStar", "mammothBone", "flail", "whip"
	];
	public static var MAX_LIMITED_WEAPONS = 13;

	// ---------------------------------------------------------------- skills (skills.ts, in the order of its record)
	public static var SKILLS:Array<SkillData> = [
		new SkillData(0, "herculeanStrength", "Force herculéenne", 60, "booster", null, null, false,
			[new SkillMod(S.STRENGTH, [3, 5, 7], [0.5, 0.6, 0.7])], null, "Avec ta force, tu es capable de déplacer des montagnes ! Mais pour l'instant, t'as un adversaire à cogner."),
		new SkillData(1, "felineAgility", "Agilité du félin", 60, "booster", null, null, false,
			[new SkillMod(S.AGILITY, [3, 5, 7], [0.5, 0.6, 0.7])], null, "Tu n'as pas de pelote de laine pour t'amuser, mais tu peux toujours embêter la brute en face."),
		new SkillData(2, "lightningBolt", "Frappe éclair", 60, "booster", null, null, false,
			[new SkillMod(S.SPEED, [3, 5, 7], [0.5, 0.6, 0.7])], null, "Tu distribues des coups plus vite que ton ombre et souvent dans les dents de ton adversaire"),
		new SkillData(3, "vitality", "Vitalité", 60, "booster", null, null, false,
			[new SkillMod(S.HP, [18, 30, 42], [0.5, 0.6, 0.7])], null, "Ton espérance de vie a augmenté ! Désormais tu tiendras debout plus longtemps dans l'arène."),
		new SkillData(4, "immortality", "Immortel", 0.14, "booster", null, null, false, [
			new SkillMod(S.HP, null, [2.5, 3, 3.5]),
			new SkillMod(S.STRENGTH, null, c(-0.25)),
			new SkillMod(S.AGILITY, null, c(-0.25)),
			new SkillMod(S.SPEED, null, c(-0.25))
		], null, "Ta santé a atteint un niveau inimaginable ! Il est devenu très difficile de te terrasser lors d'un combat !"),
		new SkillData(5, "reconnaissance", "Méditation", 1, "booster", null, null, false, [
			new SkillMod(S.INITIATIVE, c(-200), null),
			new SkillMod(S.SPEED, [5, 10, 15], [1.5, 2, 2.5]),
			new SkillMod(S.CRIT_DAMAGE, null, [0.5, 0.6, 0.7])
		], null, "Pour analyser les failles de ton adversaire, tu es prêt à prendre ton temps, mais lorsque tu démarres, rien ne t'arrête."),
		new SkillData(52, "deity", "Divinité", 2, "booster", null, null, false, [
			new SkillMod(S.SIZE, null, c(0.5)),
			new SkillMod(S.HP, null, [1, 1.25, 1.5]),
			new SkillMod(S.STRENGTH, null, [1, 1.25, 1.5]),
			new SkillMod(S.REVERSAL, null, [0.4, 0.5, 0.6]),
			new SkillMod(S.AGILITY, null, c(-1)),
			new SkillMod(S.SPEED, null, c(-1)),
			new SkillMod(S.DEXTERITY, null, c(-1)),
			new SkillMod(S.EVASION, null, c(-1)),
			new SkillMod(S.INITIATIVE, c(-200), null)
		], null, "Une puissance infinie. Des capacités de jogging limitées."),
		new SkillData(6, "weaponsMaster", "Maître d'armes", 10, "passive", null, null, false,
			[new SkillMod(S.DAMAGE, null, [0.5, 0.75, 1], 2, "sharp")], null, "Grâce à ta maîtrise, tu causes plus de dégâts à ton adversaire avec les armes tranchantes."),
		new SkillData(7, "martialArts", "Arts martiaux", 10, "passive", null, null, false,
			[new SkillMod(S.DAMAGE, null, [1, 1.5, 2], 1)], null, "Les cours de Chuck Norris ont porté leurs fruits ! Maintenant tu mets les pieds où tu veux… et c'est souvent dans la tronche !"),
		new SkillData(8, "sixthSense", "Sixième sens", 20, "passive", null, null, false,
			[new SkillMod(S.COUNTER, null, [0.1, 0.15, 0.2])], null, "Ta vigilance aiguisée te permet d'anticiper les fourberies de ton adversaire et de frapper avant lui."),
		new SkillData(9, "hostility", "Pugnace", 4, "passive", null, null, false,
			[new SkillMod(S.REVERSAL, null, [0.3, 0.35, 0.4])], null, "Dans l'arène tu n'es vraiment pas ingrat… Quand on te donne un coup, tu le rends aussitôt, et gratuitement !"),
		new SkillData(10, "fistsOfFury", "Tornade de coups", 10, "passive", null, null, false,
			[new SkillMod(S.COMBO, null, [0.2, 0.3, 0.4])], null, "… et tu tapes, tapes, tapes, c'est ta façon d'aimer, ce rythme qui t'entraîne jusqu'au bout de la nuit, éveille en toi le tourbillon d'un vent de foliiiiiie !"),
		new SkillData(11, "shield", "Bouclier", 10, "passive", null, null, false, [
			new SkillMod(S.BLOCK, null, [0.45, 0.5, 0.55]),
			new SkillMod(S.DAMAGE, null, c(-0.25))
		], null, "Un bouclier. Pour parer les coups… des fois."),
		new SkillData(12, "armor", "Armure", 4, "passive", null, null, false, [
			new SkillMod(S.ARMOR, null, [0.25, 0.3, 0.35]),
			new SkillMod(S.SPEED, null, c(-0.15))
		], null, "Ça, c'est une armure. Un truc qu'on met par-dessus son t-shirt pour pas le salir. En même temps, ça permet de mieux résister aux attaques"),
		new SkillData(13, "toughenedSkin", "Peau renforcée", 30, "passive", null, null, false,
			[new SkillMod(S.ARMOR, null, [0.1, 0.15, 0.2])], null, "A force de se faire taper, on finit par évoluer. Ta brute possède maintenant une peau plus résistante."),
		new SkillData(14, "untouchable", "Intouchable", 1, "passive", null, null, false,
			[new SkillMod(S.EVASION, null, [0.3, 0.4, 0.5])], null, "Tu évites les coups plus facilement. C'est très énervant, surtout pour ton adversaire !"),
		new SkillData(15, "sabotage", "Vandalisme", 3, "passive", null, null, false,
			[new SkillMod(S.SABOTAGE, null, [0.5, 0.75, 0.9])], null, "Certaines brutes font du vandalisme dans la rue, mais toi tu préfères vandaliser ton adversaire. Chaque coup peut détruire une de ses armes."),
		new SkillData(16, "shock", "Choc", 4, "passive", null, null, false,
			[new SkillMod(S.DISARM, null, [0.5, 0.6, 0.7])], null, "Tes coups sont tellement surprenants que ton adversaire en laisse tomber son arme… Profites-en pour leur en montrer d'autres !"),
		new SkillData(17, "bodybuilder", "Gros-bras", 5, "passive", null, null, false, [
			new SkillMod(S.HIT_SPEED, null, [0.4, 0.5, 0.6], 2, "heavy"),
			new SkillMod(S.DEXTERITY, null, [0.1, 0.15, 0.2], 2, "heavy")
		], null, "Grâce à tes gros bras, tu manipules les armes lourdes aussi facilement qu'un micro. Tu es le Philippe Risoli de la massue !"),
		new SkillData(18, "relentless", "Implacable", 4, "passive", null, null, false,
			[new SkillMod(S.ACCURACY, null, [0.3, 0.4, 0.5])], null, "Lorsque tu colles des baffes, elles arrivent toujours à destination. Personne ne peut les arrêter. En tout cas pas ton adversaire !"),
		new SkillData(19, "survival", "Survie", 4, "passive", null, null, false, [
			new SkillMod(S.BLOCK, null, [0.2, 0.3, 0.4], 0, null, "atOneHp"),
			new SkillMod(S.EVASION, null, [0.2, 0.3, 0.4], 0, null, "atOneHp")
		], null, "Les années de lutte t'ont rendu increvable. Les coups mortels te laissent 1 point de vie au lieu de t'abattre."),
		new SkillData(20, "leadSkeleton", "Squelette Plomb", 4, "passive", null, null, false, [
			new SkillMod(S.ARMOR, null, [0.15, 0.25, 0.35]),
			new SkillMod(S.DAMAGE, null, [-0.15, -0.2, -0.25], 2, "blunt", null, true),
			new SkillMod(S.EVASION, null, c(-0.15))
		], null, "Pas toujours pratique pour se déplacer, le plombage intégral de la cage thoracique permet néanmoins de réduire considérablement les dégâts des armes, surtout des armes contondantes."),
		new SkillData(21, "balletShoes", "Ballerines", 4, "passive", null, null, false,
			[new SkillMod(S.EVASION, null, [0.1, 0.15, 0.2])], null, "La danse des cygnes n'a aucun secret pour toi, impossible que ton adversaire t'atteigne, enfin, tant qu'ils ne pigent pas le truc !"),
		new SkillData(22, "determination", "Persévérant", 4, "passive", null, null, false, [], [0.6, 0.7, 0.8],
			"Rien ne te décourage, chaque échec te rend plus fort. Lorsqu'un coup ne porte pas, tu en lances un autre !"),
		new SkillData(23, "firstStrike", "Sang-Chaud", 8, "passive", null, null, false,
			[new SkillMod(S.INITIATIVE, [200, 300, 400], null)], null, "Tes adversaires entrent dans l'arène, mais toi tu préfères rentrer dans tes adversaires, tu es toujours le premier à frapper !"),
		new SkillData(24, "resistant", "Increvable", 3, "passive", null, null, false, [], [0.25, 0.2, 0.17],
			"Pour te mettre au tapis, il faut s'y prendre à plusieurs fois… C'est cinq beignes minimum, sinon rien"),
		new SkillData(25, "counterAttack", "Contre", 10, "passive", null, null, false, [
			new SkillMod(S.BLOCK, null, [0.1, 0.15, 0.2]),
			new SkillMod(S.REVERSAL, null, [0.9, 0.95, 0.99], 0, null, "afterBlock")
		], null, "La meilleure attaque ? C'est la défense bien entendu ! Pour chaque coup paré, tu ripostes automatiquement."),
		new SkillData(26, "ironHead", "Tête de fer", 4, "passive", null, null, false, [], [0.4, 0.5, 0.6],
			"Lorsque tu prends un coup, c'est ton adversaire qui doit résister à l'impact !"),
		new SkillData(27, "thief", "Voleur", 2.5, "super", [8, 10, 12], [2, 3, 4], true, [], null,
			"Cette compétence te permet d'emprunter discrètement l'arme de ton adversaire et de l'essayer sur eux."),
		new SkillData(28, "fierceBrute", "Brute féroce", 20, "super", [5, 8, 11], [1, 2, 3], true,
			[new SkillMod(S.CRIT_CHANCE, null, [0.1, 0.2, 0.3])], null,
			"Maintenant, t'es une vraie brute. Encore plus qu'avant. Tu peux effectuer une charge puissante pendant un combat."),
		new SkillData(29, "tragicPotion", "Potion tragique", 8, "super", [10, 12, 14], [1, 2, 3], false, [], null,
			"Boooooire un p'tit coup, c'est agréaaableuuu ! Oui, mais pas pour tout le monde…. Ce jus de pêche restaure une partie de ton énergie au cours du combat."),
		new SkillData(30, "net", "Filet", 16, "super", [5, 7, 9], [1, 2, 3], true, [], null,
			"Un filet classique. Pas aussi cool que la toile de Spiderman, mais faudra faire avec… Ton adversaire sera immobilisé jusqu'à ce que tu leur portes un coup."),
		new SkillData(31, "bomb", "Bombe", 6, "super", [2, 4, 6], [2, 3, 4], true, [], null,
			"Un peu comme une bombe à eau, mais en plus méchant !"),
		new SkillData(32, "hammer", "Marteau-pilon", 1, "super", [2, 4, 6], [1, 2, 3], true, [], null,
			"Une technique de catch qui consiste à sauter avec l'adversaire et retomber dessus."),
		new SkillData(33, "cryOfTheDamned", "Cri-qui-poutre", 4, "super", [8, 10, 12], [2, 3, 4], true, [], null,
			"Des bêtes féroces, ça ? Pfffff… Il suffit de crier un peu pour les faire fuir !"),
		new SkillData(34, "hypnosis", "Hypnose", 0.5, "super", [6, 8, 10], [1, 2, 3], true, [], null,
			"Lorsqu'il s'agit de faire du charme aux animaux domestiques ou à leur maitre, personne ne t'égale. Ils te suivent au doigt et à l'œil."),
		new SkillData(35, "flashFlood", "Déluge", 0.5, "super", [2, 4, 6], [3, 4, 5], true, [], null,
			"Puisque se balader avec 100 kilos d'armes t'est devenu insupportable, tu as trouvé un astucieux stratagème pour voyager léger."),
		new SkillData(36, "tamer", "Trappeur", 4, "super", [20, 22, 24], [4, 5, 6], false, [], null,
			"Rien ne se perd, tout se transforme. Tu consommes toutes les viandes mortes de l'arène."),
		new SkillData(37, "regeneration", "Pansement", 3, "talent", null, null, false,
			[new SkillMod(S.ARMOR, null, [0, 0.02, 0.05])], null,
			"Qui a dit que les pansements ne servaient qu'à soigner les bobos ? Grâce à votre maîtrise de la médecine de guerre, vous n'aurez jamais à cesser le combat !"),
		new SkillData(38, "chef", "Cuisinier", 1, "talent", null, null, false, [], [1.5, 2, 2.5],
			"Toutes les brutes le savent, le gros du combat se joue avant l'arène. Le plus souvent du côté de la cantine !"),
		new SkillData(39, "spy", "Espion", 3, "talent", null, null, false, [], [0.2, 0.25, 0.3],
			"Vous êtes devenu un maître dans l'art du détournement d'attention. Vos adversaires ne sauront jamais avec \"quoi\" vous les avez frappés."),
		new SkillData(40, "saboteur", "Saboteur", 3, "talent", null, null, false, [], [100, 150, 200],
			"Du marteau en mousse à l'épée en plastique, tu es le roi de l'imitation, tes adversaires n'y voient que du feu."),
		new SkillData(41, "backup", "Renforts", 5, "talent", null, null, false, [], [2.8, 3.3, 3.8],
			"Parce que l'amitié, c'est le partage, tu as appris à partager tes baffes pour que les adversaires de tes collègues profitent aussi un peu !"),
		new SkillData(42, "hideaway", "Planqué", 5, "talent", null, null, false,
			[new SkillMod(S.BLOCK, null, [0.25, 0.3, 0.35], 0, null, "againstThrows")], null,
			"Tu n'as vraiment pas envie de t'approcher de ton adversaire, tu préfères rester à distance et leur envoyer tout ton arsenal à la figure."),
		new SkillData(43, "monk", "Moine combattant", 5, "talent", null, null, false, [
			new SkillMod(S.COUNTER, null, [0.4, 0.45, 0.5]),
			new SkillMod(S.INITIATIVE, c(-200), null),
			new SkillMod(S.HIT_SPEED, null, c(-1))
		], null, "Tu peux voir les coups venir avant que ton adversaire ait le temps d'y penser si tu restes parfaitement calme."),
		new SkillData(44, "vampirism", "Vampirisme", 10, "super", [5, 8, 11], [1, 2, 3], false, [], null,
			"Dracula peut se reposer paisiblement, parce qu’en son absence, c’est toi qui prends le relais !"),
		new SkillData(45, "chaining", "Enchaînement", 5, "passive", null, null, false,
			[new SkillMod(S.COMBO, null, [0, 0.1, 0.2])], null, "Ton dada c’est de faire sonner les cloches ? Ce combo est fait pour toi !"),
		new SkillData(46, "haste", "Célérité", 5, "super", [3, 5, 7], [1, 2, 3], true,
			[new SkillMod(S.CRIT_CHANCE, null, [0.05, 0.1, 0.15])], null,
			"Tu as toujours rêvé de te déplacer aussi vite qu’un ninja ? Ça tombe bien, c’est le moment !"),
		new SkillData(47, "treat", "Friandise", 20, "super", [5, 8, 11], [4, 5, 6], false, [], null,
			"Se battre, ça creuse. C’est pourquoi j’emporte toujours une friandise pour remettre mes familiers d’aplomb !"),
		new SkillData(48, "repulse", "Repoussoir", 10, "passive", null, null, false, [
			new SkillMod(S.DEFLECT, null, [0.3, 0.35, 0.4]),
			new SkillMod(S.CRIT_CHANCE, null, [0.05, 0.1, 0.15])
		], null, "Des étoiles ninja se dirigent vers vous ? Aucun problème ! Canalisez le héros de film d'arts martiaux qui sommeille en vous et renvoyez les armes lancées comme des mouches."),
		new SkillData(49, "fastMetabolism", "Métabolisme Rapide", 5, "passive", null, null, false, [
			new SkillMod(S.REGENERATION, null, [0.01, 0.02, 0.03]),
			new SkillMod(S.HIT_SPEED, null, [-0.5, -0.65, -0.8]),
			new SkillMod(S.CRIT_CHANCE, null, [-0.05, -0.1, -0.15])
		], null, "Vos cellules fonctionnent à la vitesse de la lumière. Vous pouvez vous régénérer plus vite que votre adversaire ne peut vous infliger des dégâts... Enfin peut-être."),
		new SkillData(50, "mimic", "Mimique", 5, "super", null, [1, 2, 3], true, [], null,
			"C’est une belle compétence que tu as là. Ce serait dommage que quelqu’un l’apprenne instantanément."),
		new SkillData(51, "stickyHands", "Mains collantes", 5, "passive", null, null, false,
			[new SkillMod(S.WEAPON_GRIP, null, [0.5, 0.6, 0.7])], null, "Votre arme semble étrangement investie dans la relation. Elle a du mal à quitter votre main… mais aussi le visage de votre adversaire !"),
		new SkillData(53, "rewind", "Rembobinage", 5, "super", null, [1, 1, 1], false, [], [3, 4, 5],
			"Lorsqu'un coup pourrait mettre votre Brute hors de combat, elle remonte le temps pour éviter la défaite."),
		new SkillData(54, "reload", "Reload", 5, "super", null, [1, 2, 3], false, [], null,
			"À court ? Plus pour longtemps. Votre Brute puise au plus profond d'elle-même et récupère la majeure partie de son équipement."),
	];

	// ---------------------------------------------------------------- pets (pets.ts, in the order of its record)
	public static var PETS:Array<PetData> = [
		new PetData("bear", "Ours", 1, c(0.4), c(3.6), [40, 45, 50], [2, 4, 6], [1, 3, 5], [110, 120, 130], c(0), c(-0.2), c(-0.25),
			[0.1, 0.15, 0.2], [0.2, 0.3, 0.4], [0.05, 0.1, 0.15], [5, 10, 15], [0.4, 0.1, 0.1, 0.4], "bear", 100, 100),
		new PetData("panther", "Loup", 1, c(0.25), c(0.6), [23, 28, 33], [16, 20, 24], [24, 28, 32], [26, 30, 34], c(0),
			[0.7, 0.75, 0.8], c(0), [0.2, 0.25, 0.3], c(0), c(0), [3, 6, 9], [0.25, 0.3, 0.3, 0.15], "dog", 87, 60),
		new PetData("dog3", "Sunny", 2, c(0.1), c(0.1), [8, 10, 12], [7, 9, 11], [5, 7, 9], [16, 18, 20], c(0), [0.3, 0.4, 0.5], c(0),
			c(0), c(0), c(0), [5, 8, 11], [0.1, 0.2, 0.4, 0.1], "dog", 58, 40),
		new PetData("dog2", "Rouxie", 8, c(0.1), c(0.1), [7, 9, 11], [6, 8, 10], [4, 6, 8], [15, 17, 19], c(0), [0.25, 0.35, 0.45], c(0),
			c(0), c(0), c(0), [4, 7, 10], [0.1, 0.2, 0.4, 0.1], "dog", 58, 40),
		new PetData("dog1", "Truffe", 20, c(0.1), c(0.1), [6, 8, 10], [5, 7, 9], [3, 5, 7], [14, 16, 18], c(0), [0.2, 0.3, 0.4], c(0),
			c(0), c(0), c(0), [3, 6, 9], [0.1, 0.2, 0.4, 0.1], "dog", 58, 40),
	];

	// the leagues (LaBrute's ranks, from the first to the last)
	public static var LEAGUES:Array<String> = [
		"Padawan", "Pichenette du Désert", "Arracheur de pansements", "Baffe de Richter", "Poing d'acier", "Flamme du Vengeur",
		"Âme de Berserk", "Hemogrobil", "Avaleur de Sabres", "Biceps de Satan", "Dentiste du Chaos", "Légende Brutale"
	];

	public static var WEAPONS_TOTAL_ODDS:Float = sum([for (w in WEAPONS) w.odds]);
	public static var SKILLS_TOTAL_ODDS:Float = sum([for (s in SKILLS) s.odds]);
	public static var PETS_TOTAL_ODDS:Float = sum([for (p in PETS) p.odds]);

	// by id (WeaponId / SkillId)
	static var weaponById:Array<WeaponData>;
	static var skillById:Array<SkillData>;

	static function sum(a:Array<Float>):Float {
		var t = 0.0;
		for (v in a)
			t += v;
		return t;
	}

	public static function weapon(name:String):WeaponData {
		for (w in WEAPONS)
			if (w.name == name)
				return w;
		throw "Unknown weapon " + name;
	}

	public static function weaponId(id:Int):WeaponData {
		if (weaponById == null) {
			weaponById = [];
			for (w in WEAPONS)
				weaponById[w.id] = w;
		}
		return weaponById[id];
	}

	public static function skill(name:String):SkillData {
		for (s in SKILLS)
			if (s.name == name)
				return s;
		throw "Unknown skill " + name;
	}

	public static function skillId(id:Int):SkillData {
		if (skillById == null) {
			skillById = [];
			for (s in SKILLS)
				skillById[s.id] = s;
		}
		return skillById[id];
	}

	public static function pet(name:String):PetData {
		for (p in PETS)
			if (p.name == name)
				return p;
		throw "Unknown pet " + name;
	}

	// the skills that change a stat with a damage modifier (SkillDamageModifiers), in the order of SkillModifiers
	public static var DAMAGE_MODS:Array<{skill:SkillData, mod:SkillMod}> = {
		var a = [];
		for (s in SKILLS)
			for (m in s.mods)
				if (m.stat == S.DAMAGE)
					a.push({skill: s, mod: m});
		// SkillModifiers lists weaponsMaster, martialArts, shield, leadSkeleton in this order (SKILLS has the same)
		a;
	};

	// (the leagues stop at the last one)
	public static function leagueName(league:Int):String {
		var i = league < LEAGUES.length ? league : LEAGUES.length - 1;
		return Lang.data("league", Std.string(i), LEAGUES[i]);
	}
}

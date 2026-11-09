package labrute.fight;

import haxe.ds.IntMap;
import haxe.ds.ObjectMap;
import labrute.Data;

// a skill of a fighter (Tiered<Skill>): its uses can change during the fight
class FSkill {
	public var data:SkillData;
	public var tier:Int;
	public var uses:Array<Int>;

	public function new(data:SkillData, tier:Int, uses:Array<Int>) {
		this.data = data;
		this.tier = tier;
		this.uses = uses;
	}

	public static function of(data:SkillData, tier:Int):FSkill {
		return new FSkill(data, tier, data.uses == null ? null : data.uses.copy());
	}

	public inline function name():String {
		return data.name;
	}

	// skill.uses?.[skill.tier - 1]
	public inline function usesLeft():Int {
		return uses == null ? 0 : uses[tier - 1];
	}

	public inline function toss():Float {
		return data.toss == null ? 0 : data.toss[tier - 1];
	}

	public inline function percent(stat:Int):Float {
		var m = data.mod(stat);
		return m == null || m.percent == null ? 0 : m.percent[tier - 1];
	}

	public function copy():FSkill {
		return new FSkill(data, tier, uses == null ? null : uses.copy());
	}
}

// a weapon of a fighter (FightWeapon)
class FWeapon {
	public var data:WeaponData;
	public var tier:Int;
	// the initiative malus of a sabotaged weapon, the damage malus of a weapon given by a spy
	public var sabotaged:Float = 0;
	public var damaged:Float = 0;

	public function new(data:WeaponData, tier:Int) {
		this.data = data;
		this.tier = tier;
	}

	public inline function name():String {
		return data.name;
	}

	public inline function has(type:String):Bool {
		return data.has(type);
	}

	public function copy():FWeapon {
		var w = new FWeapon(data, tier);
		w.sabotaged = sabotaged;
		w.damaged = damaged;
		return w;
	}
}

// LaBrute's DetailedFighter (server/src/utils/fight/generateFight.ts). The records of skills and weapons are arrays
// kept in the order of the keys of the JavaScript objects (a removed key added again goes at the end).
class Fighter {
	public static inline var BRUTE = 0;
	public static inline var PET = 1;

	public var id:String;
	public var index:Int;
	// 0: left (the player), 1: right
	public var team:Int;
	public var name:String;
	public var type:Int;
	// the brute of a brute fighter (its look), the pet name of a pet
	public var brute:labrute.Brute;
	public var pet:String;
	public var master:String;
	public var arrivesAtInitiative:Float = 0;
	public var leavesAtInitiative:Float = 0;
	public var eaten:Bool = false;
	public var maxHp:Int = 0;
	public var hp:Int = 0;
	public var strength:Int = 0;
	public var agility:Int = 0;
	public var speed:Int = 0;
	// by S: reversal, counter, evasion, block, accuracy, disarm, sabotage, combo, deflect, armor, critical chance and damage,
	// hit speed, regeneration, weapon grip, size
	public var stat:Array<Float>;
	public var initiative:Float = 0;
	public var tempo:Float = 0;
	public var baseDamage:Int = 0;
	public var reach:Int = 0;
	public var determination:Float = 0;
	public var resistant:Float = 0;
	public var ironHead:Float = 0;
	public var retryAttack:Bool = false;
	public var bodybuilder:Bool = false;
	public var survival:Bool = false;
	public var balletShoes:Bool = false;
	// -1: null
	public var fastMetabolism:Int = -1;
	public var skills:Array<FSkill> = [];
	public var weapons:Array<FWeapon> = [];
	public var reloadableSkills:Array<FSkill> = [];
	public var reloadableWeapons:Array<FWeapon> = [];
	public var shield:Bool = false;
	public var activeSkills:Array<FSkill> = [];
	public var activeWeapon:FWeapon = null;
	public var keepWeaponChance:Float = 0;
	public var dead:Bool = false;
	// the index of the poisoner, 0: none
	public var poisonedBy:Int = 0;
	public var trapped:Bool = false;
	public var hitBy:IntMap<Int>;
	public var stunned:Bool = false;
	public var hypnotized:Bool = false;
	public var immune:Bool = false;

	public function new() {
		stat = [for (i in 0...S.COUNT) 0.0];
		hitBy = new IntMap();
	}

	public inline function isBrute():Bool {
		return type == BRUTE;
	}

	public inline function isPet():Bool {
		return type == PET;
	}

	public inline function size():Float {
		return stat[S.SIZE];
	}

	public function skill(name:String):FSkill {
		for (s in skills)
			if (s.data.name == name)
				return s;
		return null;
	}

	public inline function hasSkill(name:String):Bool {
		return skill(name) != null;
	}

	public function weapon(name:String):FWeapon {
		for (w in weapons)
			if (w.data.name == name)
				return w;
		return null;
	}

	public function hasActiveSkill(name:String):Bool {
		for (s in activeSkills)
			if (s.data.name == name)
				return true;
		return false;
	}

	public function hitCount(index:Int):Int {
		var v = hitBy.get(index);
		return v == null ? 0 : v;
	}

	// ---------------------------------------------------------------- the records (delete / set of a JavaScript object)

	public static function removeSkill(list:Array<FSkill>, name:String):Void {
		for (i in 0...list.length)
			if (list[i].data.name == name) {
				list.splice(i, 1);
				return;
			}
	}

	public static function setSkill(list:Array<FSkill>, s:FSkill):Void {
		for (i in 0...list.length)
			if (list[i].data.name == s.data.name) {
				list[i] = s;
				return;
			}
		list.push(s);
	}

	public static function removeWeapon(list:Array<FWeapon>, name:String):Void {
		for (i in 0...list.length)
			if (list[i].data.name == name) {
				list.splice(i, 1);
				return;
			}
	}

	public static function setWeapon(list:Array<FWeapon>, w:FWeapon):Void {
		for (i in 0...list.length)
			if (list[i].data.name == w.data.name) {
				list[i] = w;
				return;
			}
		list.push(w);
	}

	// fightRewind.ts cloneFighters: the uses and the flags are copied, the same skill / weapon in several records stays one
	// object (like structuredClone)
	public static function cloneAll(fighters:Array<Fighter>):Array<Fighter> {
		var skills = new ObjectMap<FSkill, FSkill>();
		var weapons = new ObjectMap<FWeapon, FWeapon>();
		function cs(s:FSkill):FSkill {
			var c = skills.get(s);
			if (c == null) {
				c = s.copy();
				skills.set(s, c);
			}
			return c;
		}
		function cw(w:FWeapon):FWeapon {
			var c = weapons.get(w);
			if (c == null) {
				c = w.copy();
				weapons.set(w, c);
			}
			return c;
		}
		return [for (f in fighters) f.clone(cs, cw)];
	}

	function clone(cs:FSkill->FSkill, cw:FWeapon->FWeapon):Fighter {
		var f = new Fighter();
		f.id = id;
		f.index = index;
		f.team = team;
		f.name = name;
		f.type = type;
		f.brute = brute;
		f.pet = pet;
		f.master = master;
		f.arrivesAtInitiative = arrivesAtInitiative;
		f.leavesAtInitiative = leavesAtInitiative;
		f.eaten = eaten;
		f.maxHp = maxHp;
		f.hp = hp;
		f.strength = strength;
		f.agility = agility;
		f.speed = speed;
		f.stat = stat.copy();
		f.initiative = initiative;
		f.tempo = tempo;
		f.baseDamage = baseDamage;
		f.reach = reach;
		f.determination = determination;
		f.resistant = resistant;
		f.ironHead = ironHead;
		f.retryAttack = retryAttack;
		f.bodybuilder = bodybuilder;
		f.survival = survival;
		f.balletShoes = balletShoes;
		f.fastMetabolism = fastMetabolism;
		f.skills = [for (s in skills) cs(s)];
		f.weapons = [for (w in weapons) cw(w)];
		f.reloadableSkills = [for (s in reloadableSkills) cs(s)];
		f.reloadableWeapons = [for (w in reloadableWeapons) cw(w)];
		f.shield = shield;
		f.activeSkills = [for (s in activeSkills) cs(s)];
		f.activeWeapon = activeWeapon == null ? null : cw(activeWeapon);
		f.keepWeaponChance = keepWeaponChance;
		f.dead = dead;
		f.poisonedBy = poisonedBy;
		f.trapped = trapped;
		for (k in hitBy.keys())
			f.hitBy.set(k, hitBy.get(k));
		f.stunned = stunned;
		f.hypnotized = hypnotized;
		f.immune = immune;
		return f;
	}
}

package labrute.fight;

// LaBrute's StepType (core/src/types.ts), the same numbers, and the sudden death of KadoKadeo
class StepType {
	public static inline var SABOTEUR = 0;
	public static inline var LEAVE = 1;
	public static inline var ARRIVE = 2;
	public static inline var TRASH = 3;
	public static inline var STEAL = 4;
	public static inline var TRAP = 5;
	public static inline var HEAL = 6;
	public static inline var RESIST = 7;
	public static inline var SURVIVE = 8;
	public static inline var HIT = 9;
	public static inline var FLASH_FLOOD = 10;
	public static inline var HAMMER = 11;
	public static inline var POISON = 12;
	public static inline var BOMB = 13;
	public static inline var HYPNOTISE = 14;
	public static inline var MOVE = 15;
	public static inline var EAT = 16;
	public static inline var MOVE_BACK = 17;
	public static inline var EQUIP = 18;
	public static inline var ATTEMPT_HIT = 19;
	public static inline var BLOCK = 20;
	public static inline var EVADE = 21;
	public static inline var SABOTAGE = 22;
	public static inline var DISARM = 23;
	public static inline var DEATH = 24;
	public static inline var THROW = 25;
	public static inline var END = 26;
	public static inline var COUNTER = 27;
	public static inline var SKILL_ACTIVATE = 28;
	public static inline var SKILL_EXPIRE = 29;
	public static inline var SPY = 30;
	public static inline var VAMPIRISM = 31;
	public static inline var HASTE = 32;
	public static inline var TREAT = 33;
	public static inline var DROP_SHIELD = 34;
	public static inline var REGENERATION = 35;
	public static inline var MIMIC = 36;
	public static inline var RELOAD = 37;
	public static inline var REWIND = 38;
	// KadoKadeo: the HP lost by every fighter during the sudden death since the previous one
	public static inline var DRAIN = 39;
}

// One step of a fight (LaBrute's FightStep, one class for all of them): the fields used by each type are the ones of its
// LaBrute step (b and f are both `f` here, the winner and the loser of End are `f` and `t`).
class Step {
	public var a:Int;
	public var f:Int = 0;
	public var t:Int = 0;
	// WeaponId, -1: none
	public var w:Int = -1;
	public var d:Int = 0;
	public var h:Int = 0;
	// SkillId, -1: none
	public var s:Int = -1;
	// Mimic: the tier of the skill copied
	public var tier:Int = 0;
	// Hit: stunned; Haste / Hit: critical hit
	public var stun:Bool = false;
	public var crit:Bool = false;
	// Move: got countered, same visual space, melee repositioning
	public var countered:Bool = false;
	public var same:Bool = false;
	public var reposition:Bool = false;
	// Throw: the weapon is kept, the weapon comes back (deflected)
	public var keep:Bool = false;
	public var ret:Bool = false;
	// Heal / Treat: poison cured; Regeneration: fast metabolism
	public var cured:Bool = false;
	public var delay:Bool = false;
	// KadoKadeo: a step played while the next ones go on (a pet that runs away, not waited for by LaBrute's client)
	public var concurrent:Bool = false;
	// Bomb / Hypnotise / Mimic / Drain: the fighters, Bomb / Drain: their damage (same order)
	public var targets:Array<Int>;
	public var dmgs:Array<Int>;
	// SkillActivate (cry): the pets that did not flee; Hypnotise: the pets hypnotised
	public var pets:Array<Int>;
	// Spy: the weapons sent and received
	public var sent:Array<Int>;
	public var recv:Array<Int>;
	// Reload: weapons and skills given back (id, tier, id, tier...)
	public var reloadW:Array<Int>;
	public var reloadS:Array<Int>;
	// Rewind: the steps undone, the turns
	public var n:Int = 0;
	public var turns:Int = 0;
	// KadoKadeo: when it is played (frames since the start of the fight) and for how long
	public var start:Int = 0;
	public var dur:Int = 0;

	public function new(a:Int) {
		this.a = a;
	}
}

package labrute.fight;

import labrute.fight.Step.StepType;

// How long each step of a fight is played, in frames of the game (32 a second). LaBrute's client plays a step for the
// time of its animations at speed 1 (client/src/utils/fight/Fight.ts): their durations, played FIGHT_SPEED times faster
// (THROWN_SPEED for the throws of a weapon kept in hand). The fight generator counts them for the countdown and the
// sudden death, the playback plays them: both see the same clock.
class Timing {
	// seconds at LaBrute's speed 1, by StepType
	static var SECONDS:Array<Float> = [
		0.8, // SABOTEUR
		0.6, // LEAVE
		0.8, // ARRIVE
		0.45, // TRASH
		1.2, // STEAL
		1.0, // TRAP
		1.5, // HEAL
		0, // RESIST: shown by the blow it comes with (LaBrute: no time)
		0.6, // SURVIVE
		0.4, // HIT
		0.5, // FLASH_FLOOD
		1.4, // HAMMER
		0.4, // POISON
		1.4, // BOMB
		1.4, // HYPNOTISE
		0.4, // MOVE
		1.2, // EAT
		0.4, // MOVE_BACK
		0.5, // EQUIP
		0.3, // ATTEMPT_HIT
		0.35, // BLOCK
		0.5, // EVADE: LaBrute's jumpBack
		0.6, // SABOTAGE
		0.4, // DISARM
		0.8, // DEATH
		0.5, // THROW
		0, // END: the end of the fight plays after
		0.05, // COUNTER
		0.7, // SKILL_ACTIVATE
		0, // SKILL_EXPIRE
		1.2, // SPY
		1.56, // VAMPIRISM: its bite 1.5 times longer than LaBrute's
		1.0, // HASTE
		1.0, // TREAT
		0.3, // DROP_SHIELD
		0.4, // REGENERATION
		0.8, // MIMIC
		0.8, // RELOAD
		1.2, // REWIND
		0, // DRAIN
	];

	// the skills that play the animation « strengthen » when they start (Fight.ts skillActivate), to its end
	static var STRENGTHEN:Array<String> = ["fierceBrute", "cryOfTheDamned", "hammer"];
	static inline var STRENGTHEN_SECONDS = 1.1;
	// the ends of skills that play something (Fight.ts skillExpire): the landing of « Déluge », the jump back of the hammer
	static var EXPIRE_SECONDS:Map<String, Float> = ["flashFlood" => 0.7, "hammer" => 0.33];

	public static function frames(step:Step):Int {
		if (step.concurrent)
			return 0;
		var seconds = step.a < SECONDS.length ? SECONDS[step.a] : 0;
		if (step.a == StepType.SKILL_ACTIVATE && STRENGTHEN.indexOf(labrute.Data.skillId(step.s).name) >= 0)
			seconds = STRENGTHEN_SECONDS;
		if (step.a == StepType.SKILL_EXPIRE && step.s >= 0 && EXPIRE_SECONDS.exists(labrute.Data.skillId(step.s).name))
			seconds = EXPIRE_SECONDS.get(labrute.Data.skillId(step.s).name);
		if (seconds <= 0)
			return 0;
		var speed = Balance.FIGHT_SPEED;
		if (step.a == StepType.THROW && step.w >= 0 && labrute.Data.weaponId(step.w).has("thrown"))
			speed = Balance.THROWN_SPEED;
		var f = Math.round(seconds * Balance.FPS / speed);
		return f < 1 ? 1 : f;
	}
}

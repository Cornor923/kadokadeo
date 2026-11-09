package labrute.fight;

import labrute.Brute;
import labrute.Data;
import labrute.Rng;
import labrute.fight.Fighter;
import labrute.fight.Step;

// thrown from a hit or a death to undo the turn (fightRewind.ts RewindRequested)
private class RewindRequested {
	public var fighter:Fighter;

	public function new(fighter:Fighter) {
		this.fighter = fighter;
	}
}

private class TurnSnapshot {
	public var stepIndex:Int;
	public var fighters:Array<Fighter>;
	public var initiative:Float;
	public var loser:String;
	public var consumed:Array<Int>;

	public function new(stepIndex, fighters, initiative, loser, consumed) {
		this.stepIndex = stepIndex;
		this.fighters = fighters;
		this.initiative = initiative;
		this.loser = loser;
		this.consumed = consumed;
	}
}

// fightRewind.ts FightRewind
private class FightRewind {
	var history:Array<TurnSnapshot> = [];
	var consumed:Array<Int> = [];

	public function new() {}

	public function beginTurn(fight:FightGen):Bool {
		var any = false;
		for (f in fight.fighters)
			if (canRewind(f))
				any = true;
		if (!any) {
			history = [];
			return false;
		}
		history.push(new TurnSnapshot(fight.steps.length, Fighter.cloneAll(fight.fighters), fight.initiative, fight.loser, consumed.copy()));
		if (history.length > 5)
			history.shift();
		return true;
	}

	function canRewind(f:Fighter):Bool {
		var skill = f.skill("rewind");
		return consumed.indexOf(f.index) < 0 && skill != null && skill.usesLeft() > 0;
	}

	public function request(fight:FightGen):Void {
		if (history.length == 0)
			return;
		for (f in fight.fighters)
			if (f.hp <= 0 && canRewind(f))
				throw new RewindRequested(f);
	}

	public function restore(fight:FightGen, caster:Fighter):Void {
		var skill = caster.skill("rewind");
		var turns = skill == null ? 0 : Std.int(skill.data.extra[skill.tier - 1]);
		if (turns <= 0)
			throw "Invalid Rewind skill tier";
		var count = Std.int(Math.min(turns, history.length));
		var target = history.length - count;
		var snapshot = history[target];
		var steps = fight.steps.length - snapshot.stepIndex;
		consumed.push(caster.index);
		fight.fighters = Fighter.cloneAll(snapshot.fighters);
		fight.initiative = snapshot.initiative;
		fight.loser = snapshot.loser;
		for (f in fight.fighters) {
			if (consumed.indexOf(f.index) < 0)
				continue;
			Fighter.removeSkill(f.skills, "rewind");
			Fighter.removeSkill(f.reloadableSkills, "rewind");
		}
		var restored:Fighter = null;
		for (f in fight.fighters)
			if (f.index == caster.index)
				restored = f;
		if (restored == null || restored.hp <= 0)
			throw "Rewind did not restore its caster alive";
		fight.advanceRewindInitiative(restored);
		history.splice(target, history.length - target);
		var step = new Step(StepType.REWIND);
		step.f = caster.index;
		step.n = steps;
		step.turns = count;
		fight.steps.push(step);
	}
}

typedef AttackResult = {
	blocked:Bool,
	reversed:Bool,
	lostReach:Int,
}

// LaBrute's fight generator (server/src/utils/fight: generateFight.ts, getFighters.ts, fightMethods.ts, getDamage.ts,
// getFighterStat.ts, applySpy.ts, fightRewind.ts), without the fight modifiers of the day, the bosses, the clans, the
// achievements and the chaos. Math.random is Rng.random (the gameplay random of KadoKadeo) and the sorts of LaBrute
// that called Math.random in their comparator are made deterministic.
//
// KadoKadeo: the fight has a clock (the steps played at their speed, see Timing): after the countdown, every fighter
// loses HP at each frame (Balance.drainTotal), applied at the end of each turn (a Drain step), and in the turn that
// decides the fight up to the blow that decided it (its Drain step put just after that blow: the HP stop there).
class FightGen {
	static inline var ONLY_FIGHTER = 1;
	static inline var ONLY_WEAPON = 2;
	static inline var TEMPO = -1;

	public var fighters:Array<Fighter> = [];
	public var initialFighters:Array<Fighter>;
	public var steps:Array<Step> = [];
	public var initiative:Float = 0;
	public var loser:String = null;
	public var winner:Fighter;
	public var loserFighter:Fighter;
	public var overtime:Bool = false;
	// KadoKadeo: the uses of the supers (the step where each one starts), for the icons of the fight
	public var superUses:Array<{step:Int, f:Int, s:Int}> = [];

	var rewind:FightRewind;
	// the sudden death
	var drainLevel:Int;
	var timedSteps:Int = 0;
	var clock:Int = 0;
	var drainedTo:Int = 0;
	// the steps when a main brute fell to 0 HP in this turn (the fight is decided there), -1: not in this turn
	var decidedAt:Int = -1;

	function new() {}

	// team1: the player's brute (left), team2: the opponent. backups: the brutes called by the skill Renforts
	public static function generate(brute1:Brute, backups1:Array<Brute>, brute2:Brute, backups2:Array<Brute>, drainLevel:Int):FightGen {
		var fight = new FightGen();
		fight.drainLevel = drainLevel;
		fight.run(brute1, backups1, brute2, backups2);
		return fight;
	}

	// ---------------------------------------------------------------- generateFight.ts

	function run(brute1:Brute, backups1:Array<Brute>, brute2:Brute, backups2:Array<Brute>):Void {
		fighters = getFighters([brute1], backups1, [brute2], backups2);
		initialFighters = Fighter.cloneAll(fighters);
		var hasRewind = false;
		for (f in fighters)
			if (f.hasSkill("rewind"))
				hasRewind = true;
		rewind = hasRewind ? new FightRewind() : null;

		// arrive steps (not the backups)
		for (f in fighters.copy()) {
			if (f.isBrute() && f.master != null)
				continue;
			fighterArrives(f);
		}

		// spy steps (1v1)
		orderFighters();
		var main = [for (f in fighters) if (f.isBrute() && f.master == null) f];
		for (b in main) {
			var opponent:Fighter = null;
			for (f in main)
				if (f.id != b.id)
					opponent = f;
			if (opponent != null)
				applySpy(b, opponent);
		}

		saboteur();

		var turn = 0;
		while (loser == null && turn < 2000) {
			orderFighters();
			var first = fighters[0];
			if (first == null)
				break;
			initiative = first.initiative;
			if (turn > 1000)
				overtime = true;
			playFighterTurn();
			checkDeaths();
			turn++;
		}

		// (should not happen with the sudden death) the main brute with the fewest HP loses
		if (loser == null) {
			var worst:Fighter = null;
			for (f in fighters)
				if (f.isBrute() && f.master == null && (worst == null || f.hp / f.maxHp < worst.hp / worst.maxHp))
					worst = f;
			loser = worst.id;
		}

		for (f in fighters)
			if (f.id == loser)
				loserFighter = f;
		var winnerId = loserFighter.team == 0 ? "b" + brute2.uid : "b" + brute1.uid;
		for (f in fighters)
			if (f.id == winnerId)
				winner = f;

		var end = new Step(StepType.END);
		end.f = winner.index;
		end.t = loserFighter.index;
		steps.push(end);

		// when each step is played
		var t = 0;
		for (s in steps) {
			s.start = t;
			s.dur = Timing.frames(s);
			t += s.dur;
		}
	}

	// the frames of the steps pushed so far
	function updateClock():Void {
		while (timedSteps < steps.length) {
			clock += Timing.frames(steps[timedSteps]);
			timedSteps++;
		}
	}

	// the frames of the steps before this one
	function clockAt(index:Int):Int {
		var t = 0;
		for (i in 0...index)
			t += Timing.frames(steps[i]);
		return t;
	}

	// KadoKadeo: a main brute fell to 0 HP (the steps so far decide the fight)
	function markDecided():Void {
		if (decidedAt >= 0)
			return;
		for (f in fighters)
			if (f.isBrute() && f.master == null && f.hp <= 0) {
				decidedAt = steps.length;
				return;
			}
	}

	// KadoKadeo: the HP lost by every fighter during the sudden death, at the end of a turn. In the turn that decides
	// the fight, up to the blow that decided it only (and nobody else falls: at least 1 HP left)
	function drain():Void {
		if (loser != null)
			return;
		updateClock();
		var timer = Balance.TIMER_FRAMES;
		var from = drainedTo < timer ? timer : drainedTo;
		var last = decidedAt >= 0;
		var to = last ? clockAt(decidedAt) : clock;
		if (to <= from)
			return;
		var amount = Balance.drainTotal(to - timer, drainLevel) - Balance.drainTotal(from - timer, drainLevel);
		drainedTo = to;
		if (amount <= 0)
			return;
		var step = new Step(StepType.DRAIN);
		step.targets = [];
		step.dmgs = [];
		var hit = [];
		for (f in fighters) {
			if (f.hp <= 0 || f.arrivesAtInitiative != 0)
				continue;
			var d = last && f.hp - amount < 1 ? f.hp - 1 : amount;
			if (d <= 0)
				continue;
			f.hp -= d;
			step.targets.push(f.index);
			step.dmgs.push(d);
			hit.push(f);
		}
		if (hit.length == 0)
			return;
		if (last) {
			// a step of 0 frame: the ones after it are played at the same time
			steps.insert(decidedAt, step);
			timedSteps++;
			for (u in superUses)
				if (u.step >= decidedAt)
					u.step++;
			return;
		}
		steps.push(step);
		for (f in hit)
			if (f.survival && f.hp <= 1) {
				f.survival = false;
				f.hp = 1;
				var s = new Step(StepType.SURVIVE);
				s.f = f.index;
				steps.push(s);
			}
	}

	// ---------------------------------------------------------------- getFighters.ts

	static function getTempo(speed:Float):Float {
		return 0.10 + (20 / Math.max(1, 10 + (speed * 1.5))) * 0.90;
	}

	function handleSkills(fighter:Fighter):Void {
		for (skill in fighter.skills) {
			for (m in skill.data.mods) {
				if (m.conditional())
					continue;
				var stat = m.stat;
				if (stat == S.DEXTERITY || stat == S.DAMAGE || stat == S.HP || stat == S.STRENGTH || stat == S.AGILITY || stat == S.SPEED)
					continue;
				if (m.flat != null) {
					var flat = m.flat[skill.tier - 1];
					if (stat == S.INITIATIVE)
						fighter.initiative -= flat / 100;
					else
						fighter.stat[stat] += flat;
				}
				if (m.percent != null)
					fighter.stat[stat] += m.percent[skill.tier - 1];
			}
			switch (skill.data.name) {
				case "determination":
					fighter.determination = skill.data.extra[skill.tier - 1];
				case "resistant":
					fighter.resistant = skill.data.extra[skill.tier - 1];
				case "ironHead":
					fighter.ironHead = skill.data.extra[skill.tier - 1];
				case "shield":
					fighter.shield = true;
				case "bodybuilder":
					fighter.bodybuilder = true;
				case "survival":
					fighter.survival = true;
				case "balletShoes":
					fighter.balletShoes = true;
				case "fastMetabolism":
					fighter.fastMetabolism = 0;
				case "fierceBrute":
					// one fierceBrute use more every 30 strength
					skill.uses = [for (u in skill.uses) u + Math.floor(fighter.strength / 30)];
				default:
			}
		}
	}

	static function tieredSkills(b:Brute):Array<FSkill> {
		return [for (p in b.skills) FSkill.of(Data.skill(p.name), p.tier)];
	}

	static function tieredWeapons(b:Brute):Array<FWeapon> {
		return [for (p in b.weapons) new FWeapon(Data.weapon(p.name), p.tier)];
	}

	static function reloadable(skills:Array<FSkill>):Array<FSkill> {
		return [for (s in skills) if (s.data.canReload) s.copy()];
	}

	function getFighters(team1:Array<Brute>, backups1:Array<Brute>, team2:Array<Brute>, backups2:Array<Brute>):Array<Fighter> {
		var spawnedPets = 0;
		var list:Array<Fighter> = [];
		var positiveIndex = 0;
		var teams = [{brutes: team1, backups: backups1}, {brutes: team2, backups: backups2}];
		for (teamIndex in 0...2) {
			var team = teams[teamIndex];
			for (brute in team.brutes) {
				positiveIndex++;
				var f = new Fighter();
				f.id = "b" + brute.uid;
				f.index = positiveIndex;
				f.team = teamIndex;
				f.name = brute.name;
				f.type = Fighter.BRUTE;
				f.brute = brute;
				f.maxHp = brute.hpValue;
				f.hp = brute.hpValue;
				f.strength = brute.strengthValue;
				f.agility = brute.agilityValue;
				f.speed = brute.speedValue;
				f.stat[S.CRIT_CHANCE] = Data.BASE_FIGHTER_STATS[S.CRIT_CHANCE];
				f.stat[S.CRIT_DAMAGE] = Data.BASE_FIGHTER_STATS[S.CRIT_DAMAGE];
				f.stat[S.SIZE] = 1;
				f.initiative = (Rng.between(0, 10) - brute.speedValue) / 100;
				f.tempo = getTempo(brute.speedValue);
				f.baseDamage = Data.BARE_HANDS_DAMAGE;
				f.skills = tieredSkills(brute);
				f.weapons = tieredWeapons(brute);
				f.reloadableSkills = reloadable(f.skills);
				f.reloadableWeapons = [for (w in f.weapons) w.copy()];
				handleSkills(f);
				list.push(f);

				// pets
				for (p in brute.pets) {
					var pet = Data.pet(p.name);
					var t = p.tier - 1;
					spawnedPets++;
					var pf = new Fighter();
					pf.id = "" + (-spawnedPets);
					pf.index = -spawnedPets;
					pf.team = teamIndex;
					pf.name = pet.fr;
					pf.type = Fighter.PET;
					pf.pet = pet.name;
					pf.master = f.id;
					pf.maxHp = Std.int(pet.hp[t]) + Math.ceil(pet.scaling[3] * brute.hpValue);
					pf.hp = pf.maxHp;
					pf.strength = Std.int(pet.strength[t]) + Math.ceil(pet.scaling[0] * brute.strengthValue);
					pf.agility = Std.int(pet.agility[t]) + Math.ceil(pet.scaling[1] * brute.agilityValue);
					pf.speed = Std.int(pet.speed[t]) + Math.ceil(pet.scaling[2] * brute.speedValue);
					pf.stat[S.CRIT_CHANCE] = Data.BASE_FIGHTER_STATS[S.CRIT_CHANCE];
					pf.stat[S.CRIT_DAMAGE] = Data.BASE_FIGHTER_STATS[S.CRIT_DAMAGE];
					pf.stat[S.SIZE] = 1;
					pf.initiative = pet.initiative[t] + Rng.between(0, 10) / 100;
					pf.tempo = getTempo(pf.speed);
					pf.baseDamage = Std.int(pet.damage[t]);
					pf.stat[S.COUNTER] = pet.counter[t];
					pf.stat[S.COMBO] = pet.combo[t];
					pf.stat[S.REVERSAL] = pet.counter[t];
					pf.stat[S.BLOCK] = pet.block[t];
					pf.stat[S.ACCURACY] = pet.accuracy[t];
					pf.stat[S.DISARM] = pet.disarm[t];
					pf.stat[S.EVASION] = pet.evasion[t];
					list.push(pf);
				}
			}

			// backups
			for (backup in team.backups) {
				var master = team.brutes[0];
				var arrivesAt = Rng.between(1, 500) / 100;
				spawnedPets++;
				var f = new Fighter();
				f.id = "" + (-spawnedPets);
				f.index = -spawnedPets;
				f.team = teamIndex;
				f.name = backup.name;
				f.type = Fighter.BRUTE;
				f.brute = backup;
				f.master = "b" + master.uid;
				f.arrivesAtInitiative = arrivesAt;
				var backupTier = master.skillTier("backup");
				f.leavesAtInitiative = arrivesAt + (backupTier > 0 ? Data.skill("backup").extra[backupTier - 1] : 0);
				f.maxHp = backup.hpValue;
				f.hp = backup.hpValue;
				f.strength = backup.strengthValue;
				f.agility = backup.agilityValue;
				f.speed = backup.speedValue;
				f.stat[S.CRIT_CHANCE] = Data.BASE_FIGHTER_STATS[S.CRIT_CHANCE];
				f.stat[S.CRIT_DAMAGE] = Data.BASE_FIGHTER_STATS[S.CRIT_DAMAGE];
				f.stat[S.SIZE] = 1;
				f.initiative = arrivesAt;
				f.tempo = getTempo(backup.speedValue);
				f.baseDamage = Data.BARE_HANDS_DAMAGE;
				f.skills = tieredSkills(backup);
				f.weapons = tieredWeapons(backup);
				f.reloadableSkills = reloadable(f.skills);
				f.reloadableWeapons = [for (w in f.weapons) w.copy()];
				handleSkills(f);
				f.initiative = arrivesAt;
				list.push(f);
			}
		}
		return list;
	}

	// ---------------------------------------------------------------- getFighterStat.ts

	function getFighterStat(fighter:Fighter, stat:Int, only:Int = 0):Float {
		if (stat == S.DEXTERITY) {
			if (only == ONLY_FIGHTER)
				return 0;
			if (fighter.activeWeapon != null) {
				var ws = fighter.activeWeapon.data.stat(S.DEXTERITY, fighter.activeWeapon.tier);
				if (fighter.bodybuilder && fighter.activeWeapon.has("heavy"))
					return ws + skillPercent(fighter, "bodybuilder", S.DEXTERITY);
				return ws;
			}
			return fighter.isBrute() ? Data.BASE_FIGHTER_STATS[S.DEXTERITY] : 0;
		}
		if (stat == TEMPO) {
			if (fighter.activeWeapon != null)
				return fighter.activeWeapon.data.tempo[fighter.activeWeapon.tier - 1];
			return Data.BASE_TEMPO;
		}
		var total = only == ONLY_WEAPON ? 0 : fighter.stat[stat];
		if (only != ONLY_FIGHTER) {
			if (fighter.activeWeapon != null)
				total += fighter.activeWeapon.data.stat(stat, fighter.activeWeapon.tier);
			else if (stat != S.CRIT_DAMAGE && stat != S.CRIT_CHANCE)
				total += fighter.isBrute() ? Data.BASE_FIGHTER_STATS[stat] : 0;
		}
		return total;
	}

	static function skillPercent(fighter:Fighter, name:String, stat:Int):Float {
		var s = fighter.skill(name);
		return s == null ? 0 : s.percent(stat);
	}

	// ---------------------------------------------------------------- getDamage.ts

	function getDamage(fighter:Fighter, opponent:Fighter, ?thrown:FWeapon):{damage:Int, criticalHit:Bool} {
		var base:Float = thrown != null ? thrown.data.damage[thrown.tier - 1] : fighter.activeWeapon != null ? fighter.activeWeapon.data.damage[fighter.activeWeapon.tier
			- 1] : fighter.baseDamage;
		var mult = 1.0;
		var piledriver = fighter.hasActiveSkill("hammer");

		for (dm in Data.DAMAGE_MODS) {
			var m = dm.mod;
			var name = dm.skill.name;
			if (!m.opponent) {
				var skill = fighter.skill(name);
				if (skill == null)
					continue;
				if (thrown != null && (name == "weaponsMaster" || name == "martialArts"))
					continue;
				if (piledriver && name == "martialArts")
					continue;
				mult += damageModValue(fighter, m, skill.tier);
			}
		}
		for (dm in Data.DAMAGE_MODS) {
			var m = dm.mod;
			var name = dm.skill.name;
			if (m.opponent) {
				var skill = opponent.skill(name);
				if (skill == null)
					continue;
				if (thrown != null && name == "leadSkeleton")
					continue;
				mult += damageModValue(fighter, m, skill.tier);
			}
		}

		if (fighter.hasActiveSkill("fierceBrute"))
			mult *= 2;
		if (piledriver)
			mult *= 4;

		var damage = 0;
		if (thrown != null)
			damage = Math.floor((base + fighter.strength * 0.1 + fighter.agility * 0.15) * (1 + Rng.random() * 0.5) * mult);
		else if (piledriver)
			damage = Math.floor((10 + opponent.strength * 0.6) * (0.8 + Rng.random() * 0.4) * mult);
		else
			damage = Math.floor((base + fighter.strength * (0.2 + base * 0.05)) * (0.8 + Rng.random() * 0.4) * mult);

		if (fighter.activeWeapon != null && fighter.activeWeapon.damaged > 0)
			damage = Math.floor(damage * (1 - fighter.activeWeapon.damaged));

		var criticalChance = getFighterStat(fighter, S.CRIT_CHANCE);
		var criticalHit = criticalChance != 0 && Rng.random() < criticalChance;
		if (criticalHit)
			damage = Math.floor(damage * getFighterStat(fighter, S.CRIT_DAMAGE));

		if (thrown == null)
			damage = Math.ceil(damage * (1 - Math.min(opponent.stat[S.ARMOR], 0.9)));

		if (damage < 1)
			damage = 1;
		return {damage: damage, criticalHit: criticalHit};
	}

	// the damage modifier of a skill, with its weapon type condition (undefined, null: bare hands or the mug, a type)
	static function damageModValue(fighter:Fighter, m:SkillMod, tier:Int):Float {
		var v = m.percent == null ? 0 : m.percent[tier - 1];
		switch (m.weaponType) {
			case 1:
				return fighter.activeWeapon == null || fighter.activeWeapon.name() == "mug" ? v : 0;
			case 2:
				return fighter.activeWeapon != null && fighter.activeWeapon.has(m.wt) ? v : 0;
			default:
				return v;
		}
	}

	// ---------------------------------------------------------------- applySpy.ts

	function applySpy(brute:Fighter, opponent:Fighter):Void {
		var spy = brute.skill("spy");
		if (spy == null)
			return;
		var opponentNames = [for (w in opponent.weapons) w.name()];
		var bruteNames = [for (w in brute.weapons) w.name()];
		var protectedSharp = opponent.hasSkill("weaponsMaster");
		var pairs:Array<{bw:FWeapon, ow:FWeapon}> = [];
		var processed:Array<String> = [];
		for (name in bruteNames) {
			var ow = opponent.weapon(name);
			if (ow != null) {
				if (protectedSharp && ow.has("sharp"))
					continue;
				pairs.push({bw: brute.weapon(name), ow: ow});
				processed.push(name);
			}
		}
		var uniqueBrute = [for (n in bruteNames) if (processed.indexOf(n) < 0) n];
		var uniqueOpponent = [
			for (n in opponentNames)
				if (processed.indexOf(n) < 0 && !(protectedSharp && opponent.weapon(n).has("sharp"))) n
		];
		var count = Std.int(Math.min(uniqueBrute.length, uniqueOpponent.length));
		for (i in 0...count)
			pairs.push({bw: brute.weapon(uniqueBrute[i]), ow: opponent.weapon(uniqueOpponent[i])});
		if (pairs.length == 0)
			return;
		var shuffled = Rng.shuffle(pairs);
		var maxSwaps = Std.int(Math.min(bruteNames.length, opponentNames.length));
		var swaps = shuffled.slice(0, maxSwaps);

		var step = new Step(StepType.SPY);
		step.f = brute.index;
		step.t = opponent.index;
		step.sent = [for (p in swaps) p.bw.data.id];
		step.recv = [for (p in swaps) p.ow.data.id];
		steps.push(step);

		for (p in swaps) {
			p.bw.damaged = spy.data.extra[spy.tier - 1];
			Fighter.removeWeapon(brute.weapons, p.bw.name());
			Fighter.removeWeapon(brute.reloadableWeapons, p.bw.name());
			Fighter.removeWeapon(opponent.weapons, p.ow.name());
			Fighter.removeWeapon(opponent.reloadableWeapons, p.ow.name());
			Fighter.setWeapon(opponent.weapons, p.bw);
			Fighter.setWeapon(opponent.reloadableWeapons, p.bw.copy());
			Fighter.setWeapon(brute.weapons, p.ow);
			Fighter.setWeapon(brute.reloadableWeapons, p.ow.copy());
		}
	}

	// ---------------------------------------------------------------- fightMethods.ts

	function skillTargetTamer(f:Fighter):Bool {
		return f.isPet() && f.hp <= 0 && !f.eaten;
	}

	function getOpponents(fighter:Fighter, bruteOnly:Bool = false, petOnly:Bool = false):Array<Fighter> {
		return [
			for (f in fighters)
				if (f.arrivesAtInitiative == 0 && f.hp > 0 && f.team != fighter.team && (!bruteOnly || f.isBrute())
					&& (!petOnly || f.isPet())) f
		];
	}

	function getRandomOpponent(fighter:Fighter, bruteOnly:Bool = false, petOnly:Bool = false, nonTrappedOrStunnedOnly:Bool = false):Fighter {
		var focus = fighter.hasSkill("hypnosis");
		var opponents = [
			for (f in getOpponents(fighter, bruteOnly || focus, petOnly))
				if ((!f.isPet() || !f.trapped) && (!nonTrappedOrStunnedOnly || (!f.trapped && !f.stunned)) && (!focus || f.master == null))
					f
		];
		if (opponents.length == 0)
			return null;
		return Rng.item(opponents);
	}

	function saboteur():Void {
		for (fighter in fighters.copy()) {
			if (!fighter.isBrute() || fighter.master != null)
				continue;
			var skill = fighter.skill("saboteur");
			if (skill == null)
				continue;
			var opponent = getRandomOpponent(fighter, true);
			if (opponent == null || opponent.weapons.length == 0)
				continue;
			var weapon = Rng.item(opponent.weapons);
			weapon.sabotaged = skill.data.extra[skill.tier - 1];
			Fighter.removeWeapon(opponent.reloadableWeapons, weapon.name());
		}
	}

	// sorted by initiative (dead then stunned last, a random order between equal initiatives): an insertion sort, the
	// same calls of the random in every browser
	function orderFighters():Void {
		var a = fighters;
		for (i in 1...a.length) {
			var x = a[i];
			var j = i - 1;
			while (j >= 0 && compareFighters(a[j], x) > 0) {
				a[j + 1] = a[j];
				j--;
			}
			a[j + 1] = x;
		}
	}

	function compareFighters(a:Fighter, b:Fighter):Float {
		if (a.hp <= 0)
			return 1;
		if (b.hp <= 0)
			return -1;
		if (a.stunned)
			return 1;
		if (b.stunned)
			return -1;
		if (a.initiative == b.initiative)
			return Rng.random() > 0.5 ? 1 : -1;
		return a.initiative - b.initiative;
	}

	function randomlyGetSuper(fighter:Fighter):FSkill {
		var supers = [for (s in fighter.skills) if (s.usesLeft() > 0 && s.name() != "mimic") s];
		if (supers.length == 0)
			return null;
		var opponents = getOpponents(fighter);
		var hasUntrappedPet = false;
		for (f in opponents)
			if (f.isPet() && !f.trapped)
				hasUntrappedPet = true;

		inline function without(name:String) {
			supers = [for (s in supers) if (s.name() != name) s];
		}
		inline function has(name:String):Bool {
			var r = false;
			for (s in supers)
				if (s.name() == name)
					r = true;
			return r;
		}

		if (fighter.hasActiveSkill("fierceBrute"))
			supers = [
				for (s in supers)
					if (s.name() != "fierceBrute" && s.name() != "tamer" && s.name() != "tragicPotion" && s.name() != "treat") s
			];

		var tamerTarget = false;
		for (f in fighters)
			if (skillTargetTamer(f))
				tamerTarget = true;
		if (!tamerTarget || fighter.hp > fighter.maxHp * 0.8)
			without("tamer");

		var armedOpponent = false;
		for (f in opponents)
			if (f.isBrute() && !f.trapped && f.activeWeapon != null)
				armedOpponent = true;
		if (!armedOpponent)
			without("thief");

		if (fighter.hp > fighter.maxHp * (fighter.poisonedBy != 0 ? 0.3 : 0.5))
			without("tragicPotion");

		if (!hasUntrappedPet) {
			without("cryOfTheDamned");
			without("hypnosis");
		}

		if (has("hypnosis"))
			without("bomb");

		if (has("hypnosis") && !fighter.stunned)
			without("cryOfTheDamned");

		if (fighter.weapons.length + (fighter.activeWeapon != null ? 1 : 0) < 3)
			without("flashFlood");

		var freeOpponent = false;
		for (f in opponents)
			if (!f.trapped && !f.stunned)
				freeOpponent = true;
		if (!freeOpponent || (hasUntrappedPet && (has("hypnosis") || has("cryOfTheDamned") || has("bomb"))))
			without("net");

		var bruteOpponent = false;
		for (f in opponents)
			if (f.isBrute())
				bruteOpponent = true;
		if (fighter.hp > fighter.maxHp / 2 || !bruteOpponent)
			without("vampirism");

		var hurtPet = false;
		for (f in fighters)
			if (f.isPet() && f.team == fighter.team && (f.hp < f.maxHp || f.trapped))
				hurtPet = true;
		if (!hurtPet)
			without("treat");

		if (supers.length == 0)
			return null;

		var total = -1.0;
		for (s in supers)
			total += s.toss();
		var randomSuper = Rng.between(0, Std.int(total + Data.NO_SKILL_TOSS));
		var toss = 0.0;
		for (s in supers) {
			toss += s.toss();
			if (randomSuper < toss)
				return s;
		}
		return null;
	}

	function randomlyDrawWeapon(weapons:Array<FWeapon>, forceDraw:Bool):FWeapon {
		if (weapons.length == 0)
			return null;
		var total = -1.0;
		for (w in weapons)
			total += w.data.toss[w.tier - 1];
		if (!forceDraw)
			total += Data.NO_WEAPON_TOSS;
		var r = Rng.between(0, Std.int(total));
		var toss = 0.0;
		for (w in weapons) {
			toss += w.data.toss[w.tier - 1];
			if (r < toss)
				return w;
		}
		return null;
	}

	inline function healFighter(fighter:Fighter, amount:Int):Void {
		fighter.hp += amount;
	}

	function increaseInitiative(fighter:Fighter, multiplicator:Float = 1):Void {
		var random = Rng.between(0, 10);
		var tempo = getFighterStat(fighter, TEMPO) * fighter.tempo + random / 100;
		if (fighter.activeWeapon != null && fighter.bodybuilder && fighter.activeWeapon.has("heavy"))
			tempo *= 1 - skillPercent(fighter, "bodybuilder", S.HIT_SPEED);
		tempo *= 1 - fighter.stat[S.HIT_SPEED];
		fighter.initiative += tempo * multiplicator;
	}

	public function advanceRewindInitiative(fighter:Fighter):Void {
		increaseInitiative(fighter, -3);
	}

	function fighterArrives(fighter:Fighter):Void {
		var step = new Step(StepType.ARRIVE);
		step.f = fighter.index;
		// poison the opponents (not the backups)
		if (fighter.master == null && fighter.hasSkill("chef"))
			for (o in getOpponents(fighter))
				o.poisonedBy = fighter.index;
		steps.push(step);
	}

	function wakeUp(fighter:Fighter, initiativeMalus:Bool = false):Void {
		fighter.stunned = false;
		if (fighter.initiative < initiative)
			fighter.initiative = initiative;
		if (initiativeMalus)
			fighter.initiative -= 0.3;
	}

	function pushSkillExpire(fighter:Fighter, name:String):Void {
		var s = new Step(StepType.SKILL_EXPIRE);
		s.f = fighter.index;
		s.s = Data.skill(name).id;
		steps.push(s);
	}

	function consumeActiveSkill(fighter:Fighter, name:String):Void {
		if (!fighter.hasActiveSkill(name))
			return;
		pushSkillExpire(fighter, name);
		fighter.activeSkills = [for (s in fighter.activeSkills) if (s.name() != name) s];
	}

	static function bombRange(pet:String):Array<Int> {
		return switch (pet) {
			case "panther": [40, 80];
			case "bear": [15, 30];
			default: [90, 150];
		}
	}

	function registerHit(fighter:Fighter, opponents:Array<Fighter>, damage:Int, criticalHit:Bool = false, thrown:Bool = false,
			source:String = null, flashFloodWeapon:FWeapon = null):Void {
		var actual:Array<Int> = [];
		for (o in opponents) {
			if (source == "bomb" && o.isPet()) {
				var r = bombRange(o.pet);
				actual.push(Math.round((Rng.between(r[0], r[1]) / 100) * o.maxHp));
			} else
				actual.push(damage);
		}

		for (i in 0...opponents.length) {
			var o = opponents[i];
			if (source != "poison")
				fighter.hitBy.set(o.index, 0);
			if (o.stunned)
				wakeUp(o, source != null);
			if (o.trapped) {
				o.trapped = false;
				o.initiative = initiative + 0.5;
				if (o.isBrute())
					o.stunned = true;
			}
			if (o.resistant > 0) {
				actual[i] = Std.int(Math.min(damage, Math.floor(o.maxHp * o.resistant)));
				if (actual[i] < damage) {
					var s = new Step(StepType.RESIST);
					s.f = o.index;
					steps.push(s);
				}
			}
			if (o.immune) {
				actual[i] = 0;
				o.immune = false;
				var s = new Step(StepType.RESIST);
				s.f = o.index;
				steps.push(s);
			}
			if (o.leavesAtInitiative != 0)
				o.leavesAtInitiative -= actual[i] * 0.05;
			else
				o.hp -= actual[i];
		}

		if (source == "bomb") {
			var s = new Step(StepType.BOMB);
			s.f = fighter.index;
			s.targets = [for (o in opponents) o.index];
			s.dmgs = actual.copy();
			steps.push(s);
		} else if (source == "vampirism") {
			var o = opponents[0];
			var heal = Math.floor(Math.min(actual[0] * (1 + Rng.random()), fighter.maxHp - fighter.hp));
			healFighter(fighter, heal);
			var s = new Step(StepType.VAMPIRISM);
			s.f = fighter.index;
			s.t = o.index;
			s.d = actual[0];
			s.h = heal;
			steps.push(s);
		} else if (source == "haste") {
			var o = opponents[0];
			var s = new Step(StepType.HASTE);
			s.f = fighter.index;
			s.t = o.index;
			s.d = actual[0];
			s.crit = criticalHit;
			steps.push(s);
		} else {
			for (i in 0...opponents.length) {
				var o = opponents[i];
				var type = source == "hammer" ? StepType.HAMMER : source == "flashFlood" ? StepType.FLASH_FLOOD : source == "poison" ? StepType.POISON : StepType.HIT;
				var s = new Step(type);
				s.f = fighter.index;
				s.t = o.index;
				s.w = source != null ? (flashFloodWeapon != null ? flashFloodWeapon.data.id : -1) : (fighter.activeWeapon != null ? fighter.activeWeapon.data.id : -1);
				s.d = actual[i];
				s.crit = criticalHit;
				if (!thrown && source == null && flashFloodWeapon == null && o.isBrute()) {
					o.hitBy.set(fighter.index, o.hitCount(fighter.index) + 1);
					if (fighter.hasSkill("chaining") && o.hitCount(fighter.index) == 3) {
						s.stun = true;
						o.stunned = true;
						o.hitBy.set(fighter.index, 0);
					}
				}
				steps.push(s);
			}
		}

		for (o in opponents) {
			if (o.survival && o.hp <= 1) {
				o.survival = false;
				o.hp = 1;
				var s = new Step(StepType.SURVIVE);
				s.f = o.index;
				steps.push(s);
			}
			if (o.fastMetabolism > 0)
				o.fastMetabolism = -1;
			if (o.fastMetabolism == 0 && o.hp < o.maxHp * 0.5) {
				o.fastMetabolism = 10;
				o.initiative = fighter.initiative;
			}
		}

		markDecided();
		requestRewind();
	}

	inline function requestRewind():Void {
		if (rewind != null)
			rewind.request(this);
	}

	function dropShield(fighter:Fighter, addStep:Bool = true):Void {
		fighter.shield = false;
		fighter.stat[S.BLOCK] -= skillPercent(fighter, "shield", S.BLOCK);
		Fighter.removeSkill(fighter.skills, "shield");
		if (addStep) {
			var s = new Step(StepType.DROP_SHIELD);
			s.f = fighter.index;
			steps.push(s);
		}
	}

	// concurrent: at the moment of the blow that disarms (its step takes no time)
	function disarm(fighter:Fighter, opponent:Fighter, concurrent:Bool = false):Void {
		if (opponent.activeWeapon == null)
			return;
		var s = new Step(StepType.DISARM);
		s.f = fighter.index;
		s.t = opponent.index;
		s.w = opponent.activeWeapon.data.id;
		s.concurrent = concurrent;
		steps.push(s);
		Fighter.removeWeapon(opponent.reloadableWeapons, opponent.activeWeapon.name());
		opponent.activeWeapon = null;
	}

	// true if the weapon was sabotaged
	function drawWeapon(fighter:Fighter, forceDraw:Bool = false):Bool {
		if (fighter.activeWeapon != null && Rng.between(0, fighter.weapons.length * 2) == 0)
			return false;
		if (fighter.activeWeapon != null && fighter.stat[S.WEAPON_GRIP] != 0) {
			if (fighter.stat[S.WEAPON_GRIP] * 100 >= Rng.between(1, 100))
				return false;
		}
		var possible = randomlyDrawWeapon(fighter.weapons, forceDraw);
		if (fighter.activeWeapon != null && Rng.random() < fighter.keepWeaponChance) {
			fighter.keepWeaponChance *= 0.5;
			return false;
		}
		if (possible == null)
			return false;
		if (fighter.activeWeapon != null) {
			var s = new Step(StepType.TRASH);
			s.f = fighter.index;
			steps.push(s);
			fighter.activeWeapon = null;
		}
		fighter.activeWeapon = possible;
		fighter.keepWeaponChance = 0.5;
		Fighter.removeWeapon(fighter.weapons, possible.name());
		var s = new Step(StepType.EQUIP);
		s.f = fighter.index;
		s.w = possible.data.id;
		steps.push(s);
		if (possible.sabotaged > 0) {
			var s = new Step(StepType.SABOTEUR);
			s.f = fighter.index;
			s.w = possible.data.id;
			steps.push(s);
			fighter.activeWeapon = null;
			fighter.initiative += possible.sabotaged / 100;
			return true;
		}
		return false;
	}

	function mimicSkill(fighter:Fighter, toMimic:FSkill):Void {
		var opponents = [for (o in getOpponents(fighter)) if (o.hasSkill("mimic")) o];
		if (opponents.length == 0)
			return;
		var mimicking:Array<Fighter> = [];
		for (o in opponents) {
			if (o.trapped || o.stunned)
				continue;
			switch (toMimic.name()) {
				case "flashFlood":
					if (o.weapons.length + (o.activeWeapon != null ? 1 : 0) < 3)
						continue;
				case "tamer":
					var any = false;
					for (f in fighters)
						if (f.isPet() && f.team == o.team)
							any = true;
					if (!any)
						continue;
				case "treat":
					var any = false;
					for (f in fighters)
						if (f.isPet() && f.team == o.team && f.hp > 0)
							any = true;
					if (!any)
						continue;
				default:
			}
			mimicking.push(o);
		}
		if (mimicking.length == 0)
			return;
		var s = new Step(StepType.MIMIC);
		s.targets = [for (o in mimicking) o.index];
		s.s = toMimic.data.id;
		s.tier = toMimic.tier;
		steps.push(s);
		for (o in mimicking) {
			var existing = o.skill(toMimic.name());
			if (existing != null)
				existing.uses = existing.uses == null ? [0, 0, 0] : [for (u in existing.uses) u + 1];
			else
				o.skills.push(new FSkill(toMimic.data, toMimic.tier, [1, 1, 1]));
			var mimic = o.skill("mimic");
			if (mimic != null && mimic.uses != null) {
				mimic.uses[mimic.tier - 1] = mimic.usesLeft() - 1;
				if (mimic.usesLeft() <= 0)
					Fighter.removeSkill(o.skills, "mimic");
			}
		}
	}

	function activateSuper(fighter:Fighter, skill:FSkill):Bool {
		if (skill.usesLeft() <= 0)
			return false;
		if (fighter.hypnotized)
			return false;
		var firstStep = steps.length;

		switch (skill.name()) {
			case "thief":
				var opponents = [for (o in getOpponents(fighter, true)) if (!o.trapped && o.activeWeapon != null) o];
				if (opponents.length == 0)
					return false;
				var opponent = Rng.item(opponents);
				if ((fighter.activeWeapon != null && fighter.activeWeapon.name() == opponent.activeWeapon.name())
					|| fighter.weapon(opponent.activeWeapon.name()) != null)
					return false;
				if (fighter.activeWeapon != null && Rng.between(1, 5) != 1)
					return false;
				if (fighter.activeWeapon != null) {
					var s = new Step(StepType.TRASH);
					s.f = fighter.index;
					steps.push(s);
					fighter.activeWeapon = null;
				}
				var s = new Step(StepType.STEAL);
				s.f = fighter.index;
				s.w = opponent.activeWeapon.data.id;
				s.t = opponent.index;
				steps.push(s);
				Fighter.removeWeapon(opponent.reloadableWeapons, opponent.activeWeapon.name());
				fighter.activeWeapon = opponent.activeWeapon;
				fighter.keepWeaponChance = 1;
				opponent.activeWeapon = null;
				if (opponent.stunned)
					wakeUp(opponent, true);
				fighter.initiative -= 0.01;

			case "fierceBrute":
				fighter.activeSkills.push(skill);
				var s = new Step(StepType.SKILL_ACTIVATE);
				s.f = fighter.index;
				s.s = skill.data.id;
				steps.push(s);
				fighter.initiative -= 0.01;

			case "tragicPotion":
				var healed = Math.floor(fighter.maxHp * (0.25 + Rng.random() * 0.25));
				healed = Std.int(Math.min(healed, fighter.maxHp - fighter.hp));
				healFighter(fighter, healed);
				var cured = false;
				if (fighter.poisonedBy != 0) {
					fighter.poisonedBy = 0;
					cured = true;
				}
				fighter.initiative += 0.30;
				var s = new Step(StepType.HEAL);
				s.f = fighter.index;
				s.h = healed;
				s.cured = cured;
				steps.push(s);

			case "net":
				var opponent = getRandomOpponent(fighter, false, true, true);
				if (opponent == null) {
					opponent = getRandomOpponent(fighter, true, false, true);
					if (opponent == null)
						return false;
				}
				opponent.trapped = true;
				opponent.initiative += 1000;
				fighter.initiative += 0.2 * fighter.tempo;
				var s = new Step(StepType.TRAP);
				s.f = fighter.index;
				s.t = opponent.index;
				steps.push(s);

			case "bomb":
				var opponents = getOpponents(fighter);
				var damage = 15 + Rng.between(0, 10);
				registerHit(fighter, opponents, damage, false, true, "bomb");
				fighter.initiative += 0.5 * fighter.tempo;

			case "hammer":
				if (fighter.activeWeapon != null) {
					if (Rng.between(1, 5) == 1) {
						var s = new Step(StepType.TRASH);
						s.f = fighter.index;
						steps.push(s);
						fighter.activeWeapon = null;
					} else
						return false;
				}
				if (fighter.shield)
					dropShield(fighter);
				var opponent = getRandomOpponent(fighter, true);
				if (opponent == null)
					return false;
				fighter.activeSkills.push(skill);
				var dmg = getDamage(fighter, opponent);
				var s = new Step(StepType.SKILL_ACTIVATE);
				s.f = fighter.index;
				s.s = skill.data.id;
				steps.push(s);
				var move = new Step(StepType.MOVE);
				move.f = fighter.index;
				move.t = opponent.index;
				move.same = true;
				steps.push(move);
				registerHit(fighter, [opponent], dmg.damage, dmg.criticalHit, false, "hammer");
				consumeActiveSkill(fighter, "fierceBrute");
				if (opponent.shield)
					dropShield(opponent);
				disarm(fighter, opponent);
				pushSkillExpire(fighter, "hammer");
				var back = new Step(StepType.MOVE_BACK);
				back.f = fighter.index;
				steps.push(back);
				fighter.initiative += 1 * fighter.tempo;
				fighter.activeSkills = [for (a in fighter.activeSkills) if (a.name() != "hammer") a];

			case "cryOfTheDamned":
				var pets = [for (o in getOpponents(fighter, false, true)) if (!o.trapped) o];
				var fear:Array<Step> = [];
				var unafraid:Array<Int> = [];
				for (pet in pets) {
					if (Rng.between(0, 1) == 0) {
						var s = new Step(StepType.LEAVE);
						s.f = pet.index;
						s.concurrent = true;
						fear.push(s);
						fighters = [for (f in fighters) if (f.index != pet.index) f];
					} else {
						pet.initiative = fighter.initiative - 0.01;
						unafraid.push(pet.index);
					}
				}
				for (o in getOpponents(fighter, true))
					o.initiative += 0.15;
				for (s in fear)
					steps.push(s);
				var s = new Step(StepType.SKILL_ACTIVATE);
				s.f = fighter.index;
				s.s = skill.data.id;
				if (unafraid.length > 0)
					s.pets = unafraid;
				steps.push(s);

			case "hypnosis":
				var pets = [for (o in getOpponents(fighter, false, true)) if (!o.trapped) o];
				var hypnotised:Array<Int> = [];
				for (pet in pets) {
					if (Rng.random() > 0.90)
						continue;
					hypnotised.push(pet.index);
					pet.master = fighter.id;
					pet.team = fighter.team;
					pet.initiative = fighter.initiative - 0.01;
				}
				var opponents = getOpponents(fighter, true);
				for (o in opponents)
					o.hypnotized = true;
				var s = new Step(StepType.HYPNOTISE);
				s.f = fighter.index;
				s.targets = [for (o in opponents) o.index];
				s.pets = hypnotised;
				steps.push(s);

			case "flashFlood":
				var opponent = getRandomOpponent(fighter, true);
				if (opponent == null)
					return false;
				var throwShield = false;
				if (fighter.shield && (skill.usesLeft() == 1 || fighter.weapons.length < 6)) {
					throwShield = true;
					dropShield(fighter, false);
				}
				var shuffled = Rng.shuffle(fighter.weapons);
				var toThrow = shuffled.slice(0, fighter.activeWeapon != null ? 2 : 3);
				for (w in toThrow)
					Fighter.removeWeapon(fighter.weapons, w.name());
				if (fighter.activeWeapon != null) {
					toThrow.unshift(fighter.activeWeapon);
					fighter.activeWeapon = null;
				}
				var s = new Step(StepType.SKILL_ACTIVATE);
				s.f = fighter.index;
				s.s = skill.data.id;
				steps.push(s);
				for (w in toThrow) {
					var damage = Math.floor(getDamage(fighter, opponent, w).damage * 1.5);
					registerHit(fighter, [opponent], damage, false, true, "flashFlood", w);
				}
				if (throwShield) {
					if (opponent.isBrute())
						opponent.stunned = true;
					var s = new Step(StepType.FLASH_FLOOD);
					s.f = fighter.index;
					s.t = opponent.index;
					s.d = 0;
					s.stun = true;
					steps.push(s);
				}
				consumeActiveSkill(fighter, "fierceBrute");
				pushSkillExpire(fighter, "flashFlood");
				fighter.initiative += 2 * fighter.tempo;

			case "tamer":
				var dead = [for (f in fighters) if (skillTargetTamer(f)) f];
				if (dead.length == 0)
					return false;
				var pet = Rng.item(dead);
				var healPercentage = switch (pet.pet) {
					case "panther": 0.3;
					case "bear": 0.5;
					default: 0.2;
				}
				var heal = Std.int(Math.min(fighter.maxHp - fighter.hp, Math.floor(fighter.maxHp * healPercentage)));
				healFighter(fighter, heal);
				fighter.initiative += 0.15;
				pet.eaten = true;
				var move = new Step(StepType.MOVE);
				move.f = fighter.index;
				move.t = pet.index;
				move.same = true;
				steps.push(move);
				var s = new Step(StepType.EAT);
				s.f = fighter.index;
				s.t = pet.index;
				s.h = heal;
				steps.push(s);
				var back = new Step(StepType.MOVE_BACK);
				back.f = fighter.index;
				steps.push(back);

			case "vampirism":
				var opponent = getRandomOpponent(fighter, true);
				if (opponent == null)
					return false;
				var damage = Math.floor((fighter.maxHp - fighter.hp) * 0.25);
				if (fighter.hasActiveSkill("fierceBrute"))
					damage *= 2;
				registerHit(fighter, [opponent], damage, false, false, "vampirism");
				consumeActiveSkill(fighter, "fierceBrute");
				fighter.initiative += 0.3 + fighter.tempo;

			case "haste":
				var opponent = getRandomOpponent(fighter);
				if (opponent == null)
					return false;
				if (fighter.activeWeapon == null)
					drawWeapon(fighter, true);
				var dmg = getDamage(fighter, opponent);
				var damage = dmg.damage + fighter.speed;
				registerHit(fighter, [opponent], damage, dmg.criticalHit, false, "haste");
				consumeActiveSkill(fighter, "fierceBrute");
				fighter.initiative += 0.3 + fighter.tempo;

			case "treat":
				var pet:Fighter = null;
				for (f in fighters)
					if (pet == null && f.isPet() && f.team == fighter.team && f.hp > 0 && (f.hp < f.maxHp || f.trapped))
						pet = f;
				if (pet == null)
					return false;
				var heal = Std.int(Math.min(Math.floor(pet.maxHp * 0.5), pet.maxHp - pet.hp));
				pet.hp += heal;
				var cured = false;
				if (pet.poisonedBy != 0) {
					pet.poisonedBy = 0;
					cured = true;
				}
				if (pet.trapped)
					pet.trapped = false;
				pet.initiative = fighter.initiative - 0.01;
				pet.immune = true;
				var move = new Step(StepType.MOVE);
				move.f = fighter.index;
				move.t = pet.index;
				move.same = true;
				steps.push(move);
				var s = new Step(StepType.TREAT);
				s.f = fighter.index;
				s.t = pet.index;
				s.h = heal;
				s.cured = cured;
				steps.push(s);

			default:
				return false;
		}

		// one use spent
		skill.uses[skill.tier - 1] = skill.usesLeft() - 1;
		superUses.push({step: firstStep, f: fighter.index, s: skill.data.id});
		mimicSkill(fighter, skill);
		if (skill.usesLeft() <= 0)
			Fighter.removeSkill(fighter.skills, skill.name());
		return true;
	}

	function counterAttack(fighter:Fighter, opponent:Fighter):Bool {
		if (opponent.hp <= 0 || opponent.trapped || opponent.stunned || opponent.hypnotized)
			return false;
		var random = Rng.random();
		var oReach = opponent.reach + (opponent.activeWeapon != null ? opponent.activeWeapon.data.reach : 0);
		var fReach = fighter.reach + (fighter.activeWeapon != null ? fighter.activeWeapon.data.reach : 0);
		var valueToBeat = (opponent.stat[S.COUNTER] * 10 + (oReach - fReach)) * 0.1;
		if (valueToBeat > 0.9)
			valueToBeat = 0.9;
		return random < valueToBeat;
	}

	function block(fighter:Fighter, opponent:Fighter, thrown:Bool = false, ease:Float = 1):Bool {
		if (opponent.hp <= 0 || opponent.trapped || opponent.stunned)
			return false;
		if (opponent.isPet())
			return false;
		var opponentBlock = getFighterStat(opponent, S.BLOCK);
		if (thrown && opponent.hasSkill("hideaway"))
			opponentBlock += ease * skillPercent(opponent, "hideaway", S.BLOCK);
		if (opponent.hp == 1 && opponent.hasSkill("survival"))
			opponentBlock += skillPercent(opponent, "survival", S.BLOCK);
		return Rng.random() * ease < Math.min(opponentBlock - getFighterStat(fighter, S.ACCURACY), 0.9 * ease);
	}

	function evade(fighter:Fighter, opponent:Fighter, difficulty:Float = 1):Bool {
		if (opponent.hp <= 0 || opponent.trapped || opponent.stunned)
			return false;
		if (fighter.hypnotized)
			return true;
		if (opponent.balletShoes) {
			opponent.balletShoes = false;
			return true;
		}
		var opponentEvasion = getFighterStat(opponent, S.EVASION);
		if (opponent.hp == 1 && opponent.hasSkill("survival"))
			opponentEvasion += skillPercent(opponent, "survival", S.EVASION);
		var agilityDifference = Math.min(Math.max(-40, (opponent.agility - fighter.agility) * 2), 40);
		var random = Rng.random();
		return random * difficulty < Math.min(opponentEvasion + agilityDifference * 0.01 - getFighterStat(fighter, S.ACCURACY)
			- getFighterStat(fighter, S.DEXTERITY), 0.9 * difficulty);
	}

	function breakShield(fighter:Fighter, opponent:Fighter):Bool {
		if (!opponent.shield)
			return false;
		return getFighterStat(fighter, S.DISARM) * 100 >= Rng.between(1, 300);
	}

	function shouldDisarm(fighter:Fighter, opponent:Fighter, thrown:Bool = false):Bool {
		if (opponent.activeWeapon == null)
			return false;
		var trigger = getFighterStat(fighter, S.DISARM, thrown ? ONLY_WEAPON : 0) * 100 >= Rng.between(1, 100);
		if (trigger && opponent.stat[S.WEAPON_GRIP] != 0) {
			if (opponent.stat[S.WEAPON_GRIP] * 100 >= Rng.between(1, 100))
				return false;
		}
		return trigger;
	}

	function shouldDisarmAttacker(fighter:Fighter, opponent:Fighter):Bool {
		if (fighter.activeWeapon == null)
			return false;
		if (opponent.ironHead == 0)
			return false;
		var trigger = Rng.random() < opponent.ironHead;
		if (trigger && fighter.stat[S.WEAPON_GRIP] != 0) {
			if (fighter.stat[S.WEAPON_GRIP] * 100 >= Rng.between(1, 100))
				return false;
		}
		return trigger;
	}

	function reversal(opponent:Fighter, blocked:Bool):Bool {
		if (opponent.stunned)
			return false;
		var random = Rng.random();
		var stat = getFighterStat(opponent, S.REVERSAL);
		if (blocked && opponent.hasSkill("counterAttack"))
			stat += skillPercent(opponent, "counterAttack", S.REVERSAL);
		else
			stat = Math.min(stat, 0.9);
		return random < stat;
	}

	function deflectProjectile(fighter:Fighter, timesDeflected:Int):Bool {
		if (fighter.hp <= 0 || fighter.trapped || fighter.stunned)
			return false;
		var withWeapon = timesDeflected % 2 == 0 || fighter.hasSkill("hideaway")
			|| (fighter.activeWeapon != null && fighter.activeWeapon.has("thrown"));
		var random = Rng.random();
		var stat = Math.min(getFighterStat(fighter, S.DEFLECT, withWeapon ? 0 : ONLY_FIGHTER), 0.9);
		return random < stat;
	}

	function attack(fighter:Fighter, opponent:Fighter, isCounter:Bool = false):AttackResult {
		if (fighter.hp <= 0)
			return {blocked: false, reversed: false, lostReach: 0};

		if (opponent.hypnotized) {
			opponent.hypnotized = false;
			pushSkillExpire(opponent, "hypnosis");
		}

		var damageResult = getDamage(fighter, opponent);
		var damage = damageResult.damage;
		var criticalHit = damageResult.criticalHit;

		var blocked = block(fighter, opponent);
		var evaded = evade(fighter, opponent);
		var brokeShield = breakShield(fighter, opponent);

		var s = new Step(StepType.ATTEMPT_HIT);
		s.f = fighter.index;
		s.t = opponent.index;
		s.w = fighter.activeWeapon != null ? fighter.activeWeapon.data.id : -1;
		steps.push(s);

		if (evaded) {
			damage = 0;
			var e = new Step(StepType.EVADE);
			e.f = opponent.index;
			steps.push(e);
		} else {
			if (brokeShield)
				dropShield(opponent);
			if (blocked) {
				damage = 0;
				var b = new Step(StepType.BLOCK);
				b.f = opponent.index;
				steps.push(b);
			}
		}

		// sabotage of a weapon of the opponent
		if (damage != 0 && fighter.stat[S.SABOTAGE] != 0) {
			if (opponent.weapons.length > 0 && Rng.random() < fighter.stat[S.SABOTAGE]) {
				var weapon = Rng.item(opponent.weapons);
				Fighter.removeWeapon(opponent.weapons, weapon.name());
				Fighter.removeWeapon(opponent.reloadableWeapons, weapon.name());
				var sb = new Step(StepType.SABOTAGE);
				sb.f = fighter.index;
				sb.t = opponent.index;
				sb.w = weapon.data.id;
				// (at the moment of the blow, not before it)
				sb.concurrent = true;
				steps.push(sb);
			}
		}

		if (damage != 0 && shouldDisarm(fighter, opponent))
			disarm(fighter, opponent, true);

		var lostReach = 0;
		if (damage != 0) {
			if (fighter.activeWeapon != null && shouldDisarmAttacker(fighter, opponent)) {
				lostReach = fighter.activeWeapon.data.reach;
				disarm(opponent, fighter, true);
			}
			registerHit(fighter, [opponent], damage, criticalHit);
		}

		if (!isCounter && damage == 0 && fighter.determination != 0 && !fighter.hypnotized && Rng.random() < fighter.determination)
			fighter.retryAttack = true;

		var reversed = reversal(opponent, blocked);
		return {blocked: !evaded && blocked, reversed: !evaded && reversed, lostReach: lostReach};
	}

	function checkDeaths():Void {
		requestRewind();
		for (fighter in fighters.copy()) {
			if (fighter.hp <= 0 && !fighter.dead) {
				fighter.dead = true;
				var s = new Step(StepType.DEATH);
				s.f = fighter.index;
				steps.push(s);
				if (!fighter.isPet() && loser == null) {
					var alive = false;
					for (f in fighters)
						if (f.team == fighter.team && f.master == null && f.hp > 0)
							alive = true;
					if (!alive)
						loser = fighter.id;
				}
			}
		}
	}

	function startAttack(fighter:Fighter, opponent:Fighter, isCounter:Bool = false):Void {
		var initialFighterHp = fighter.hp;
		var opponentWasTrapped = opponent.trapped;
		var result = {blocked: false, reversed: false, lostReach: 0};

		var first = attack(fighter, opponent, isCounter);
		if (first.blocked)
			result.blocked = true;
		if (first.reversed)
			result.reversed = true;
		result.lostReach = first.lostReach;

		var combo = getFighterStat(fighter, S.COMBO) + fighter.agility * 0.01;

		if (!isCounter) {
			var random = Rng.random();
			while (!result.reversed && (random < combo || fighter.retryAttack)) {
				fighter.retryAttack = false;
				if (fighter.hp < initialFighterHp)
					break;
				if (result.lostReach > 1) {
					var m = new Step(StepType.MOVE);
					m.f = fighter.index;
					m.t = opponent.index;
					m.reposition = true;
					steps.push(m);
				}
				combo *= 0.5;
				var next = attack(fighter, opponent);
				if (next.blocked)
					result.blocked = true;
				if (next.reversed)
					result.reversed = true;
				result.lostReach = next.lostReach;
				opponentWasTrapped = false;
				random = Rng.random();
			}

			if (!opponentWasTrapped && result.reversed && opponent.hp > 0) {
				var opponentReach = opponent.activeWeapon != null ? opponent.activeWeapon.data.reach : 0;
				var fighterReach = fighter.activeWeapon != null ? fighter.activeWeapon.data.reach : 0;
				if (opponentReach < fighterReach) {
					var m = new Step(StepType.MOVE);
					m.f = opponent.index;
					m.t = fighter.index;
					m.reposition = true;
					steps.push(m);
				}
				attack(opponent, fighter);
			}
		}

		fighter.retryAttack = false;
		checkDeaths();
	}

	function canReloadSkill(fighter:Fighter, skill:FSkill):Bool {
		if (!skill.data.canReload || skill.usesLeft() <= 0)
			return false;
		switch (skill.name()) {
			case "mimic":
				for (o in getOpponents(fighter))
					for (s in o.skills)
						if (s.name() != "mimic" && canReloadSkill(fighter, s))
							return true;
				return false;
			case "flashFlood":
				return fighter.weapons.length + (fighter.activeWeapon != null ? 1 : 0) >= 3;
			case "thief":
				for (o in getOpponents(fighter, true))
					if (o.activeWeapon != null || o.weapons.length > 0)
						return true;
				return false;
			case "cryOfTheDamned", "hypnosis":
				for (o in getOpponents(fighter, false, true))
					if (!o.trapped)
						return true;
				return false;
			default:
				return true;
		}
	}

	function reload(fighter:Fighter):Void {
		var reloadSkill = fighter.skill("reload");
		var remaining = reloadSkill == null ? 0 : reloadSkill.usesLeft();
		if (reloadSkill == null || reloadSkill.uses == null || remaining <= 0 || fighter.activeSkills.length > 0
			|| fighter.activeWeapon != null || fighter.weapons.length > 0)
			return;
		for (s in fighter.skills)
			if (canReloadSkill(fighter, s))
				return;
		var reloadableCount = 0;
		for (s in fighter.reloadableSkills)
			if (canReloadSkill(fighter, s))
				reloadableCount++;
		if (reloadableCount == 0 && fighter.reloadableWeapons.length == 0)
			return;

		var reloadable = [for (s in fighter.reloadableSkills) s.copy()];
		for (s in reloadable)
			Fighter.setSkill(fighter.skills, s);
		fighter.weapons = [for (w in fighter.reloadableWeapons) w.copy()];

		reloadSkill.uses[reloadSkill.tier - 1] = remaining - 1;
		if (remaining <= 1)
			Fighter.removeSkill(fighter.skills, "reload");

		var s = new Step(StepType.RELOAD);
		s.f = fighter.index;
		s.reloadW = [];
		for (w in fighter.weapons) {
			s.reloadW.push(w.data.id);
			s.reloadW.push(w.tier);
		}
		s.reloadS = [];
		for (rs in reloadable) {
			s.reloadS.push(rs.data.id);
			s.reloadS.push(rs.tier);
		}
		steps.push(s);
	}

	function executeFighterTurn():Void {
		var fighter = fighters[0];
		if (fighter == null)
			throw "No fighter found";

		if (fighter.trapped) {
			pushSkillExpire(fighter, "net");
			fighter.trapped = false;
		}
		if (fighter.stunned) {
			pushSkillExpire(fighter, "chaining");
			wakeUp(fighter);
		}

		// a backup leaves
		if (fighter.leavesAtInitiative != 0 && fighter.leavesAtInitiative <= initiative) {
			var s = new Step(StepType.LEAVE);
			s.f = fighter.index;
			steps.push(s);
			fighters.shift();
			return;
		}

		// a backup arrives
		if (fighter.arrivesAtInitiative != 0) {
			fighter.arrivesAtInitiative = 0;
			fighterArrives(fighter);
		}

		// fast metabolism
		if (fighter.fastMetabolism > 0) {
			if (fighter.hp >= fighter.maxHp) {
				fighter.fastMetabolism = -1;
				return;
			}
			fighter.fastMetabolism -= 1;
			var heal = Math.ceil(fighter.maxHp * 0.05);
			if (fighter.hp + heal > fighter.maxHp)
				heal = fighter.maxHp - fighter.hp;
			healFighter(fighter, heal);
			var s = new Step(StepType.REGENERATION);
			s.f = fighter.index;
			s.h = heal;
			s.delay = true;
			steps.push(s);
			if (fighter.fastMetabolism <= 0)
				fighter.fastMetabolism = -1;
			fighter.initiative += 0.15;
			return;
		}

		// regeneration
		if (fighter.hp < fighter.maxHp && fighter.stat[S.REGENERATION] > 0) {
			var heal = Math.ceil(fighter.maxHp * fighter.stat[S.REGENERATION]);
			if (fighter.hp + heal > fighter.maxHp)
				heal = fighter.maxHp - fighter.hp;
			healFighter(fighter, heal);
			var s = new Step(StepType.REGENERATION);
			s.f = fighter.index;
			s.h = heal;
			steps.push(s);
		}

		reload(fighter);

		var possibleSuper = randomlyGetSuper(fighter);
		if (possibleSuper != null && activateSuper(fighter, possibleSuper))
			return;

		var forceDraw = fighter.activeWeapon == null && fighter.hasActiveSkill("fierceBrute");
		if (drawWeapon(fighter, forceDraw))
			return;

		var attackType = "melee";
		if (fighter.activeWeapon != null) {
			if (fighter.activeWeapon.has("thrown"))
				attackType = "thrown";
			else if (fighter.hasSkill("hideaway"))
				attackType = Rng.between(0, 1) == 0 ? "thrown" : "melee";
			else
				attackType = Rng.between(0, Math.round(33 - fighter.activeWeapon.data.tempo[fighter.activeWeapon.tier - 1] * 5)) == 0 ? "thrown" : "melee";
		}

		var opponent = getRandomOpponent(fighter);
		if (opponent == null)
			return;

		// the opponent uses hypnosis if low on HP
		if (opponent.hp < opponent.maxHp * 0.20 && !opponent.stunned && !opponent.trapped && !fighter.hypnotized) {
			var hypnosis = opponent.skill("hypnosis");
			if (hypnosis != null && Rng.random() < 0.90) {
				if (activateSuper(opponent, hypnosis)) {
					if (fighter.isPet())
						return;
				}
			}
		}

		if (attackType == "melee") {
			var countered = counterAttack(fighter, opponent);
			var m = new Step(StepType.MOVE);
			m.f = fighter.index;
			m.t = opponent.index;
			m.countered = countered;
			steps.push(m);
			if (countered) {
				var c = new Step(StepType.COUNTER);
				c.f = opponent.index;
				c.t = fighter.index;
				steps.push(c);
				startAttack(opponent, fighter, true);
			} else {
				if (opponent.stunned && !opponent.trapped) {
					var cry = opponent.skill("cryOfTheDamned");
					if (cry != null && Rng.between(0, 1) == 0) {
						if (activateSuper(opponent, cry)) {
							wakeUp(opponent);
							if (fighters.indexOf(fighter) >= 0) {
								var b = new Step(StepType.MOVE_BACK);
								b.f = fighter.index;
								steps.push(b);
							}
							increaseInitiative(fighter, 0.5);
							return;
						}
					}
				}
				startAttack(fighter, opponent);
			}
		} else {
			var keepWeapon = fighter.activeWeapon.has("thrown") || fighter.hasSkill("hideaway");
			var firstThrow = true;
			var combo = getFighterStat(fighter, S.COMBO) + fighter.agility * 0.01;
			var random = Rng.random();
			while (firstThrow || (keepWeapon && random < combo)) {
				if (fighter.activeWeapon == null)
					break;
				if (fighter.hp <= 0 || opponent.hp <= 0)
					break;
				var thrownWeapon = fighter.activeWeapon;
				// (LaBrute: deflected starts null, then true while the weapon is sent back)
				var firstFlight = true;
				var deflected = false;
				var current = fighter;
				var currentOpponent = opponent;
				var timesDeflected = 0;
				while (firstFlight || deflected) {
					if (currentOpponent.hypnotized) {
						currentOpponent.hypnotized = false;
						pushSkillExpire(currentOpponent, "hypnosis");
					}
					var t = new Step(StepType.THROW);
					t.f = current.index;
					t.t = currentOpponent.index;
					t.w = thrownWeapon.data.id;
					t.keep = keepWeapon;
					t.ret = !firstFlight && deflected;
					steps.push(t);
					firstFlight = false;

					deflected = deflectProjectile(currentOpponent, timesDeflected);
					var damage = 0;
					var criticalHit = false;
					if (!deflected) {
						var dr = getDamage(current, currentOpponent, thrownWeapon);
						damage = dr.damage;
						criticalHit = dr.criticalHit;
						damage = Math.floor(damage * Math.pow(1.5, timesDeflected));
					}

					if (!deflected && block(current, currentOpponent, true, 2)) {
						damage = 0;
						var b = new Step(StepType.BLOCK);
						b.f = currentOpponent.index;
						steps.push(b);
					}
					if (damage != 0 && evade(current, currentOpponent, 2)) {
						damage = 0;
						var e = new Step(StepType.EVADE);
						e.f = currentOpponent.index;
						steps.push(e);
					}
					if (damage != 0) {
						if (shouldDisarm(current, currentOpponent, true))
							disarm(current, currentOpponent);
						registerHit(current, [currentOpponent], damage, criticalHit, true);
					}
					if (deflected) {
						var tmp = current;
						current = currentOpponent;
						currentOpponent = tmp;
						timesDeflected++;
					}
				}
				if (!keepWeapon)
					fighter.activeWeapon = null;
				firstThrow = false;
				combo *= 0.5;
				random = Rng.random();
			}
			checkDeaths();
		}

		for (s in fighter.activeSkills)
			pushSkillExpire(fighter, s.name());
		fighter.activeSkills = [];

		if (attackType == "melee" && fighter.hp > 0 && !fighter.stunned) {
			var b = new Step(StepType.MOVE_BACK);
			b.f = fighter.index;
			steps.push(b);
		}

		// poison
		if (loser == null && fighter.hp > 0 && fighter.poisonedBy != 0) {
			var poisoner:Fighter = null;
			for (f in fighters)
				if (f.index == fighter.poisonedBy)
					poisoner = f;
			if (poisoner != null) {
				var chef = poisoner.skill("chef");
				var percentage = chef == null ? 2 : chef.data.extra[chef.tier - 1];
				var poisonDamage = Math.ceil(fighter.maxHp * (percentage / 100));
				registerHit(poisoner, [fighter], poisonDamage, false, false, "poison");
			}
		}

		// overtime poison (after 1000 turns: never with the sudden death of KadoKadeo)
		if (loser == null && fighter.hp > 0 && overtime) {
			var poisonDamage = Math.ceil(fighter.maxHp / 4);
			var poisoner = getRandomOpponent(fighter, true);
			if (poisoner != null)
				registerHit(poisoner, [fighter], poisonDamage, false, false, "poison");
		}

		increaseInitiative(fighter);
	}

	// one turn, then the sudden death; undone by a Rewind
	function executeTurn():Void {
		decidedAt = -1;
		executeFighterTurn();
		drain();
	}

	function playFighterTurn():Void {
		if (rewind == null) {
			executeTurn();
			return;
		}
		if (!rewind.beginTurn(this)) {
			rewind = null;
			executeTurn();
			return;
		}
		try {
			executeTurn();
			rewind.request(this);
		} catch (e:RewindRequested) {
			rewind.restore(this, e.fighter);
		}
	}
}

package labrute;

import haxe.ds.IntMap;
import pixi.core.graphics.Graphics;
import labrute.Screen;
import labrute.fight.FightGen;
import labrute.fight.Step;
import labrute.view.Ui;

// Phase 3: a fight. Generated at once when the opponent is chosen (LaBrute's generator, with the sudden death of
// KadoKadeo), then played step by step at the speed of Timing: the points come with the steps (1 by damage dealt, the
// disarms, the pets killed), the reward and the bonuses at the end. A defeat ends the run, but the first one is
// forgiven with the skill « Pansement ».
class FightScreen extends Screen {
	public static inline var WIN = 0;
	public static inline var SAVED = 1;
	public static inline var LOST = 2;
	// the results: the room taken by the line of the new rank (above the button « Continuer »)
	static inline var RANK_ROOM = 30;
	// the room taken by the words of the bandage (a defeat forgiven)
	static inline var SAVED_ROOM = 30;
	// the line of the ears won, under the total
	static inline var EARS_ROOM = 22;
	// the line of the difficulty in the results: the colors of the choice (green, orange, red), darker to be read
	static var DIFFICULTY_COLORS = [0x2C6A22, 0xB06A10, 0x8E1616];

	public var opponent(default, null):Brute;
	public var difficulty(default, null):Int;
	public var gen(default, null):FightGen;
	public var steps(default, null):Array<Step>;
	public var endIndex(default, null):Int;
	// the level of its sudden death (Balance.drainLevel)
	public var drainLevel(default, null):Int;
	public var fightNumber(default, null):Int;
	// frames since the start of the fight, the last step started
	public var frame(default, null):Int = -1;
	public var cur(default, null):Int = -1;
	// the points of this fight (damage and bonuses)
	public var points(default, null):Int = 0;
	public var damagePoints(default, null):Int = 0;
	// the gold of the disarms, of the pets killed (in the results)
	public var disarmPoints(default, null):Int = 0;
	public var petPoints(default, null):Int = 0;
	// the gold of the backups of the opponent killed (in the results)
	public var backupPoints(default, null):Int = 0;
	// the ears won by this fight (a win, the backups of the opponent killed)
	public var earsWon(default, null):Int = 0;
	public var won(default, null):Bool;
	// the results: -1 while fighting
	public var resultFrame(default, null):Int = -1;
	public var outcome(default, null):Int = WIN;
	public var bonuses(default, null):Array<{label:String, value:Int}> = [];
	// the gold of the bonuses of the steps (a disarm, a pet killed), by step: shown where they happen
	public var stepGold(default, null):IntMap<Int> = new IntMap();
	// the fight won took the player to a new league
	public var newLeague(default, null):Bool = false;

	var team:IntMap<Int>;
	var pets:IntMap<String>;
	// the backups (Renforts) of the fight
	var backups:IntMap<Bool>;
	var backupsKilled = 0;
	// the fighters whose last HP lost were the sudden death's: their death gives nothing
	var drained:IntMap<Bool> = new IntMap();
	// the brute of the opponent, the hits it took (« One-shot ! »: one)
	var opponentIndex = -1;
	var opponentHits = 0;
	var mult:Float;
	var view:FightView;
	var resultBuilt = false;

	public function new(game:Game, opponent:Brute, difficulty:Int) {
		super(game);
		this.opponent = opponent;
		this.difficulty = difficulty;
		var run = game.run;
		fightNumber = run.fights + 1;
		drainLevel = Balance.drainLevel(fightNumber);
		var backupLevels = run.hiddenLevel() + Balance.BACKUP_LEVEL_OFFSET;
		if (backupLevels < 0)
			backupLevels = 0;
		var backups1 = run.brute.hasSkill("backup") ? [Opponents.make(backupLevels)] : [];
		var backups2 = opponent.hasSkill("backup") ? [Opponents.make(backupLevels)] : [];
		gen = FightGen.generate(run.brute, backups1, opponent, backups2, drainLevel);
		steps = gen.steps;
		endIndex = steps.length - 1;
		team = new IntMap();
		pets = new IntMap();
		backups = new IntMap();
		for (f in gen.initialFighters) {
			team.set(f.index, f.team);
			if (f.isPet())
				pets.set(f.index, f.pet);
			else if (f.master != null)
				backups.set(f.index, true);
			else if (f.team == 1)
				opponentIndex = f.index;
		}
		mult = run.multiplier();
		won = gen.winner.index == 1;
		view = new FightView(this, game);
	}

	inline function teamOf(index:Int):Int {
		var t = team.get(index);
		return t == null ? -1 : t;
	}

	inline function bonus(value:Float):Int {
		return Math.round(value * mult);
	}

	// ---------------------------------------------------------------- gameplay
	// (the fight goes on after its end, under its results: its last pictures, the confetti)
	override public function update():Void {
		frame++;
		if (resultFrame < 0) {
			while (cur < endIndex && steps[cur + 1].start <= frame) {
				cur++;
				score(cur, steps[cur]);
			}
			if (cur == endIndex && frame >= steps[endIndex].start + Balance.END_FRAMES)
				startResult();
		} else {
			resultFrame++;
			if (outcome != LOST && resultFrame >= Balance.RESULT_FRAMES)
				finish();
		}
	}

	override public function apply(action:Int):Void {
		if (action == A.CONTINUE && resultFrame >= 0 && outcome != LOST)
			finish();
	}

	function finish():Void {
		game.show(new ShopScreen(game));
	}

	function addPoints(n:Int):Void {
		if (n <= 0)
			return;
		points += n;
		game.addPoints(n);
	}

	function addStepGold(index:Int, n:Int):Void {
		addPoints(n);
		stepGold.set(index, n);
	}

	// the points of a step, when it is played
	function score(index:Int, s:Step):Void {
		switch (s.a) {
			case StepType.HIT, StepType.FLASH_FLOOD, StepType.HAMMER, StepType.POISON, StepType.VAMPIRISM, StepType.HASTE:
				dealt(s.f, s.t, s.d);
			case StepType.BOMB:
				for (i in 0...s.targets.length)
					dealt(s.f, s.targets[i], s.dmgs[i]);
			case StepType.DISARM:
				if (teamOf(s.f) == 0 && teamOf(s.t) == 1) {
					var n = bonus(Balance.DISARM_BONUS);
					disarmPoints += n;
					addStepGold(index, n);
				}
			case StepType.DRAIN:
				for (k in 0...s.targets.length)
					if (s.dmgs[k] > 0)
						drained.set(s.targets[k], true);
			case StepType.DEATH:
				if (drained.exists(s.f)) {
					// (killed by the sudden death: no bonus)
				} else if (pets.exists(s.f) && teamOf(s.f) == 1) {
					var n = bonus(switch (pets.get(s.f)) {
						case "bear": Balance.BEAR_KILL_BONUS;
						case "panther": Balance.PANTHER_KILL_BONUS;
						default: Balance.DOG_KILL_BONUS;
					});
					petPoints += n;
					addStepGold(index, n);
				} else if (backups.exists(s.f) && teamOf(s.f) == 1) {
					var n = bonus(Balance.BACKUP_KILL_BONUS);
					backupPoints += n;
					backupsKilled++;
					addStepGold(index, n);
				}
			case StepType.HYPNOTISE:
				for (p in s.pets)
					team.set(p, teamOf(s.f));
			default:
		}
	}

	function dealt(from:Int, to:Int, damage:Int):Void {
		if (damage <= 0)
			return;
		drained.remove(to);
		if (teamOf(from) == 0 && teamOf(to) == 1) {
			var n = damage * Balance.DAMAGE_POINTS;
			damagePoints += n;
			addPoints(n);
		}
		if (to == opponentIndex)
			opponentHits++;
	}

	function startResult():Void {
		resultFrame = 0;
		var run = game.run;
		if (won) {
			outcome = WIN;
			// (only a win takes the player further: the level of the opponents, the leagues)
			run.fights++;
			var league = run.league();
			run.wins++;
			newLeague = run.league() > league;
			bonuses.push({label: Lang.t(difficulty == 0 ? "Facile" : difficulty == 1 ? "Moyen" : "Difficile"), value: bonus(Balance.WIN_REWARD[difficulty])});
			for (f in gen.fighters)
				if (f.index == 1 && f.hp >= f.maxHp)
					bonuses.push({label: Lang.t("Victoire Parfaite !"), value: bonus(Balance.FULL_HP_BONUS)});
			if (opponentHits == 1)
				bonuses.push({label: Lang.t("One-shot !"), value: bonus(Balance.ONE_SHOT_BONUS)});
			if (steps[endIndex].start <= Balance.TIMER_FRAMES)
				bonuses.push({label: Lang.t("Rapide"), value: bonus(Balance.BEFORE_TIMER_BONUS)});
			for (f in gen.fighters)
				if (f.index == 1 && f.hp == 1)
					bonuses.push({label: Lang.t("Survie"), value: bonus(Balance.ONE_HP_BONUS)});
			for (b in bonuses)
				addPoints(b.value);
			earsWon += Balance.WIN_EARS;
		} else if (run.hasBandage()) {
			outcome = SAVED;
			run.bandageUsed = true;
		} else {
			outcome = LOST;
		}
		// (the backups killed: their ears, even in a defeat saved by the bandage)
		earsWon += backupsKilled * Balance.BACKUP_KILL_EARS;
		run.ears += earsWon;
		run.opponents = null;
		run.syncLevel();
		// a defeat ends the run at once (the fade of KadoKadeo)
		if (outcome == LOST)
			game.endRun();
	}

	// ---------------------------------------------------------------- pictures

	override public function render(t:Float, mx:Float, my:Float, live:Bool):Void {
		var alpha = t - game.frame;
		var now = frame + alpha;
		view.render(now < 0 ? 0 : now, mx, my, live);
		if (resultFrame >= 0 && !resultBuilt) {
			resultBuilt = true;
			buildResult();
		}
		super.render(t, mx, my, live);
	}

	// (a defeat has no results: the end of the run comes after it)
	function buildResult():Void {
		if (outcome == LOST)
			return;
		var run = game.run;
		var g = new Graphics();
		g.beginFill(0x000000, 0.45);
		g.drawRect(0, 0, 600, 460);
		g.endFill();
		// the difficulty and the damage (their gold in black), then the other bonuses: the gold of the steps (when there
		// is some), the bonuses of the end
		var rows:Array<{label:String, value:Int, plain:Bool}> = [];
		if (bonuses.length > 0)
			rows.push({label: bonuses[0].label, value: bonuses[0].value, plain: true});
		rows.push({label: Lang.t("Dégâts infligés"), value: damagePoints, plain: true});
		if (disarmPoints > 0)
			rows.push({label: Lang.t("Désarmement"), value: disarmPoints, plain: false});
		if (petPoints > 0)
			rows.push({label: Lang.t("Animaux neutralisés"), value: petPoints, plain: false});
		if (backupPoints > 0)
			rows.push({label: Lang.t("Renfort neutralisé"), value: backupPoints, plain: false});
		for (k in 1...bonuses.length)
			rows.push({label: bonuses[k].label, value: bonuses[k].value, plain: false});
		// (the new rank, the words of the bandage: room for them)
		var saved = outcome == SAVED;
		var ears = earsWon > 0 ? EARS_ROOM : 0;
		var h = 98 + rows.length * 22 + 62 + ears + (newLeague ? RANK_ROOM : 0) + (saved ? SAVED_ROOM : 0);
		var y = Std.int((460 - h) / 2);
		front.addChild(g);
		Ui.skinPanel(g, front, "recap", 120, y, 360, h, Col.PARCHMENT, saved ? Col.ORANGE : Col.GREEN);
		var ly = y + 62;
		if (saved) {
			// a defeat forgiven: the gold of the fight, no reward of a win (nor a step toward the next league)
			Ui.title(Ui.label(front, Lang.t("DÉFAITE…"), 300, y + 30, 30, Col.RED, 0.5, 0.5, 0x1A0C04));
			Ui.label(front, Lang.t("Mais le Pansement remet ta brute sur pied !"), 300, ly + 4, 15, Col.WOOD, 0.5, 0.5);
			ly += SAVED_ROOM;
		} else
			Ui.title(Ui.label(front, Lang.t("VICTOIRE !"), 300, y + 30, 30, Col.GREEN, 0.5, 0.5, 0x1A0C04));
		for (k in 0...rows.length) {
			var b = rows[k];
			// (the difficulty in its color, darker; the damage in black; the bonuses in gold)
			var c = k == 0 && bonuses.length > 0 ? DIFFICULTY_COLORS[difficulty] : Col.WOOD;
			Ui.label(front, b.label, 140, ly, 15, c);
			Ui.label(front, "+" + Ui.num(b.value), 460, ly, 15, k == 0 && bonuses.length > 0 ? c : b.plain ? 0x000000 : 0xB07A10, 1, 0);
			ly += 22;
		}
		var gl = new Graphics();
		gl.lineStyle(2, Col.WOOD, 0.6);
		gl.moveTo(140, ly + 4);
		gl.lineTo(460, ly + 4);
		front.addChild(gl);
		Ui.label(front, Lang.t("Total"), 140, ly + 10, 17, Col.WOOD);
		Ui.gold(front, 460, ly + 20, "+" + Ui.num(points), 17, 0xB07A10, -1, 1);
		// (the ears under the gold, without a label)
		if (earsWon > 0)
			Ui.ears(front, 460, ly + 20 + EARS_ROOM, "+" + earsWon, 17, 0xB07A10, -1, 1);
		if (newLeague)
			Ui.label(front, Lang.t("Nouveau rang : ") + Data.leagueName(run.league()), 300, ly + 50 + ears, 16, Col.RED, 0.5, 0.5, -1, true);
		buttons.push(new Button(front, 230, y + h - 52, 140, 36, Lang.t("Continuer"), A.CONTINUE, saved ? Col.ORANGE : Col.GREEN, 16, null, "button-recap"));
	}

	#if debug
	public function hudHp():Array<Int> {
		return view.hudHp();
	}
	#end

	override public function destroy():Void {
		view.destroy();
		super.destroy();
	}
}

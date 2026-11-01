package kanjigaiden;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import kanjigaiden.MC.Plans;

typedef Point = {x:Int, y:Int};

// Game.hx of the original (Haxe for Flash 8), line by line; the port's own parts are at the end
@:expose('GameKanjiGaiden')
class Game implements kado.GameInterface {
	// left / right turn the view, the button throws
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left",
				label: "◀",
				leftPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.LEFT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 90,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "shoot",
				label: "✦",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.SPACE,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	// ZQSD / WASD turn like the arrows, Enter throws like Space
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	// Flash played Kanji Gaiden at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	public static var DP_BONUS = 17;
	public static var DP_WARN = 16;
	public static var DP_SC = 15;

	public static var DP_HERO = 14;

	public static var DP_FG = 13;
	public static var DP_DEATH = 12;
	public static var DP_SHOOT = 11;
	public static var DP_PL1 = 10;
	public static var DP_BB1 = 9;
	public static var DP_PL2 = 8;
	public static var DP_BB2 = 7;
	public static var DP_PL3 = 6;
	public static var DP_BB3 = 5;
	public static var DP_PL4 = 4;
	public static var DP_BB4 = 3;
	public static var DP_BG = 1;

	public static var me:Game;

	public var dm:Plans;
	public var root:ASprite;
	public var bg:MC;
	public var warn_l:MC;
	public var warn_r:MC;
	public var hero:Kanji;

	var fg:Plan;

	public var plans:Array<Plan>;
	public var shoots:Array<Shot>;
	public var monkeys:Array<Monkey>;
	public var bonus:Array<Bonus>;

	public var pos:Float;

	var monkeyMin:Int;
	var diffCool:Float;

	public var diff:Int;

	var dead:Bool;
	var warnl:Bool;
	var warnr:Bool;

	public var mcScore:MC;

	// port
	var isReplay:Bool;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	// the score of KKApi (addScore), nothing after the game over
	var score:Int = 0;
	var over:Bool = false;
	#if debug
	// test harness: events of the game (coverage)
	public var stats = {
		shots: 0,
		kills: 0,
		hits: 0,
		jumps: 0,
		bonus: [0, 0, 0, 0],
		kinds: [0, 0, 0, 0, 0],
		stunned: 0,
		bamboo: 0
	};
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(3);
		keys[0] = KeyboardManager.LEFT;
		keys[1] = KeyboardManager.RIGHT;
		keys[2] = KeyboardManager.SPACE;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		MC.clearAll();
		Clip.reset();
		Monkey.me = null;
		Plan.me = null;
		// mt.Timer before its first update (Manager.init creates the game before the first Manager.main)
		Timer.tmod = 1;
		Clip.deferring = true;

		// the original's 300x300 pixels, drawn x2
		root = mc.createEmptyMovieClip("scene", 0);
		root._xscale = root._yscale = 100 * Clip.K;
		root.updateState();
		me = this;
		dm = new Plans(root);

		diffCool = Cs.DIFFBASE;
		monkeyMin = 4;
		diff = 0;
		pos = 0.5;

		hero = new Kanji();

		shoots = [];
		monkeys = [];
		bonus = [];

		initPlan();
		warnr = false;
		warnl = false;
		dead = false;

		warn_l = dm.attach("warning", DP_WARN);
		warn_r = dm.attach("warning", DP_WARN);
		// (_width / _height of the warning on its first frame, measured on the SWF)
		warn_l._x = Data.WARN_W * 0.5 + 5;
		warn_l._y = Data.WARN_H * 0.5 + 5;

		warn_r._xscale = -100;
		warn_r._x = Cs.mcw - Data.WARN_W * 0.5 - 5;
		warn_r._y = Data.WARN_H * 0.5 + 5;
		warn_l._visible = false;
		warn_r._visible = false;

		Clip.deferring = false;
		Clip.runLater();
		MC.displayAll(1);
		// Flash shows the first picture after the first frame (Manager.init, then Manager.main): nothing before
		root.visible = false;
		warmShaders();
	}

	public function getPos(dev:Float):Point {
		var ret:Point;
		var width = Math.ceil((300 + 600 * (1 - dev)));
		var px = Math.floor(pos * (width - 300));
		var py = Math.floor(Cs.pdf * dev);
		ret = {x: px, y: py};
		return ret;
	}

	public function getPosShot(dev:Float, hint:Float):Point {
		var ret:Point;
		var width = Math.ceil((300 + 600 * (1 - dev)));
		var px = Math.floor(hint * (width - 300) - pos * (width - 300) + Cs.mcw * 0.5);
		var py = Math.floor(Cs.pdf * dev);
		ret = {x: px, y: py};
		return ret;
	}

	function checkWarn() {
		warnr = false;
		warnl = false;
		for (m in monkeys) {
			if ((m.pl == 0)) {
				if (m.mcMonkey._x < (plans[0].width * pos) - 200)
					warnl = true;
				if (m.mcMonkey._x > (plans[0].width * pos) + 200)
					warnr = true;
			}
		}
	}

	function addMonkeyDebug() {
		plans[2].addMonkey();
	}

	public function addAMonkey(pl:Int) {
		if (pl >= 0) {
			plans[pl].addMonkey();
		} else {
			if (!dead) {
				dead = true;
				gameOver();
				var monkeyDeath = dm.attach("monkeyD", DP_DEATH);
				var smc = monkeyDeath.sub("smc");
				if (smc != null)
					smc.gotoAndPlay("_land");

				monkeyDeath._x = 150;
				monkeyDeath._y = 270;
			}
		}
	}

	public function addAMonkeySpecial(pl:Int, mtype:Int, life:Int, diff:Int, btype:Int) {
		if (pl >= 0) {
			plans[pl].addMonkeyTyped(mtype, life, diff, btype);
		} else {
			if (!dead) {
				dead = true;
				gameOver();
				// (the copy of the monkey at 100 %, see kanjigaiden_assets.py)
				var monkeyDeath = dm.attach("monkeyD", DP_DEATH);
				monkeyDeath.gotoAndStop(diff);

				var smc = monkeyDeath.sub("smc");
				var ban = smc != null ? smc.getClip("smc") : null;
				if (ban != null) {
					if (mtype != 4)
						ban.gotoAndStop(mtype + 1);
					else
						ban.gotoAndStop(5 + btype);
				}

				if (smc != null)
					smc.gotoAndPlay("_land");

				monkeyDeath._x = 150;
				monkeyDeath._y = 270;
			}
		}
	}

	function initPlan() {
		plans = [];

		var mcfg = dm.attach("fg", DP_FG);
		fg = new Plan(mcfg, 0, 0.75, 1);

		var mcBamboo1 = dm.empty(DP_BB1);
		var Bamboo1 = new Plan(mcBamboo1, 0, 0.5, 0);
		plans.push(Bamboo1);

		// (Col.setPercentColor(mcBamboo2, 25, 0xD4FBA2) and (mcBamboo3, 50, ...): baked in the pictures of the planes 1
		// and 2, the monkeys of those planes and their outline included, see kanjigaiden_assets.py)
		var mcBamboo2 = dm.empty(DP_BB2);
		var Bamboo2 = new Plan(mcBamboo2, 1, 0.25, 0);
		plans.push(Bamboo2);

		var mcBamboo3 = dm.empty(DP_BB3);
		var Bamboo3 = new Plan(mcBamboo3, 2, 0.125, 0);
		plans.push(Bamboo3);

		bg = dm.attach("mcBg", DP_BG);
		var bgPlan = new Plan(bg, 3, 0, 1);

		plans.push(bgPlan);

		addMonkeyDebug();
	}

	public function origUpdate() {
		hero.update();
		if (!dead) {
			if (KeyboardManager.isDown(KeyboardManager.RIGHT))
				move(0);
			else if (KeyboardManager.isDown(KeyboardManager.LEFT))
				move(1);

			if (KeyboardManager.isDown(KeyboardManager.SPACE))
				hero.shoot();
		}
		// (index loops reading the length at each turn, like Flash: an element removed by its update makes the next one
		// wait for the next frame, one added is updated in the same loop)
		var i = 0;
		while (i < plans.length)
			plans[i++].update();
		i = 0;
		while (i < shoots.length)
			shoots[i++].update();
		i = 0;
		while (i < monkeys.length)
			monkeys[i++].update();
		i = 0;
		while (i < bonus.length)
			bonus[i++].update();
		fg.update();
		if (monkeys.length < monkeyMin)
			addMonkeyDebug();

		incDifficulty();
		checkWarn();

		if (warnr)
			warn_r._visible = true;
		else
			warn_r._visible = false;
		if (warnl)
			warn_l._visible = true;
		else
			warn_l._visible = false;
	}

	public function move(dir:Int) {
		hero.move(dir);
	}

	public function scoreIt(sc:KKConst) {
		mcScore = dm.attach("score", DP_SC);
		// mcScore.mct._field.text = "" + KKApi.val(sc): the picture of that text
		mcScore.clip.setPicture("mct", Data.SCORES.indexOf(KKApi.val(sc)) + 1);
		mcScore._x = 300;
		mcScore._y = 300;
		addScore(KKApi.val(sc));
	}

	function incDifficulty() {
		if (diffCool < 0) {
			diff++;
			monkeyMin++;
			diffCool = Cs.DIFFBASE + Seed.random(Cs.DIFFBASE);
		} else {
			diffCool -= Timer.tmod;
		}
	}

	public function bonusMe(bt:Int) {
		#if debug
		stats.bonus[bt]++;
		#end
		if (bonus.length == 0) {
			var b = new Bonus(bt);
			bonus.push(b);
		} else {
			bonus[0].destroy();
			var b = new Bonus(bt);
			bonus.push(b);
		}
	}

	// ---------------------------------------------------------------- port
	// KKApi.addScore: nothing after the game over
	function addScore(n:Int) {
		if (over || n == 0)
			return;
		score += n;
		KadoKadeoManager.kkm.addScore(n);
	}

	// KKApi.gameOver({})
	function gameOver() {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	// the filters compile their shaders now, not at the first monkey or the first shot
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null)
			return;
		var holder = new pixi.core.display.Container();
		var s = new pixi.core.sprites.Sprite(pixi.core.textures.Texture.WHITE);
		s.filters = [new FlashBlur(4, 4, 1), new FlashGlow(2, 2, 1, 0x361C0D, 1, 3)];
		holder.addChild(s);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function stageRoot():ASprite {
		return root;
	}

	// ---------------------------------------------------------------- KadoKadeo step: 5 Flash frames every 4 steps
	public function update(delta:Float) {
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame();
		}
		MC.displayAll(frameAcc / 4);
	}

	// one Flash frame: the timelines advance, then Manager.main (tmod ~0.8: Timer settles on 32 / 40), then the frame
	// scripts the code triggered
	function flashFrame() {
		Timer.tmod = 32 / FLASH_FPS;
		MC.frameStart();
		Clip.deferring = true;
		origUpdate();
		Clip.deferring = false;
		Clip.runLater();
		frameCount++;
		root.visible = true;
		#if debug
		untyped js.Browser.window.__state = debugState();
		#end
	}

	#if debug
	// state compared between a game and its replay (test harness)
	function debugState():Dynamic {
		var mx = 0.0;
		for (m in monkeys)
			mx += m.x * 7 + m.y + m.pl * 1000;
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: score,
			pos: pos,
			diff: diff,
			monkeys: monkeys.length,
			msum: Math.round(mx * 1000) / 1000,
			shots: shoots.length,
			sType: hero.sType,
			bonus: bonus.length,
			stats: haxe.Json.stringify(stats),
			over: over,
		};
	}

	// test harness: clips drawn by the runtime on a page ([name, frame, x, y, scale, {nested instance: frame}]), to
	// compare with the SWF
	static var debugBox:ASprite = null;

	public function debugShow(list:Array<Array<Dynamic>>, bgColor:Int) {
		var stage:Dynamic = untyped KadoKadeoManager.kkm.stage;
		// (the previous page out: every page left on the stage would be drawn again under the next one)
		if (debugBox != null)
			debugBox.destroy({children: true});
		var box = debugBox = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		for (o in list) {
			var c = new Clip(o[0], 2);
			for (pass in 0...2) {
				if (pass == 1)
					c.gotoAndStop(o[1]);
				if (o.length > 5)
					for (k in Reflect.fields(o[5])) {
						var path = k.split(".");
						var sub = c;
						for (p in path)
							sub = sub != null ? sub.getClip(p) : null;
						if (sub != null)
							sub.gotoAndStop(Reflect.field(o[5], k));
					}
			}
			Clip.runLater();
			c._x = o[2];
			c._y = o[3];
			c._xscale = c._yscale = o[4] * 100;
			box.addChild(c);
		}
		box.updateState();
		box.updateGraphics(1);
		stage.addChild(box);
	}
	#end

	public function destroy():Void {
		if (plans != null)
			for (p in plans)
				p.dispose();
		me = null;
		MC.clearAll();
		Clip.reset();
	}
}

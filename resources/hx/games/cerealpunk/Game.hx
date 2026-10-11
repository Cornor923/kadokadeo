package cerealpunk;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import cerealpunk.MC.Plans;

// Game.mt of the original (MTypes, cuistot.swf), line by line; the port's own parts are at the end
@:expose('GameCerealPunk')
class Game implements kado.GameInterface {
	// left / right: one column, up: take, down: throw
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
				id: "down",
				label: "▼",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.DOWN,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "up",
				label: "▲",
				rightPx: 20,
				bottomPx: 90,
				size: 60,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	// ZQSD / WASD move like the arrows
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	// Flash played Cereal Punk at 40 frames/s (the rate of the SWF and of the KadoKado loader) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	public var animator:Animator;
	public var dmanager:Plans;
	public var level:Level;
	public var hero:Hero;

	var bg:MC;
	var time:Float;
	var maxtime:Float;
	var game_over:Bool = false;

	public var stats:{
		l:Int,
		g:Array<Int>,
		b1:Int,
		b2:Int,
		c:Array<Int>
	};

	var nlegs:KKConst;

	public var combo_phase:Int = 0;
	// out screen combo
	public var hscombo:Array<Legume>;

	var level_count:Int;

	// port
	var isReplay:Bool;
	var root:ASprite;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	// the score of KKApi, nothing after the game over
	var score:Int = 0;
	var over:Bool = false;
	#if debug
	// test harness: hash of the grid, the cook and the timer at every Flash frame (a replay must give the same)
	var ghash:Int = 0;

	// test harness: rare events of the game (coverage)
	public static var cov = {
		stones: 0,
		bonusDie: 0,
		bubbles: 0,
		hsKept: 0,
		hsLost: 0,
		combos: 0
	};
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(4);
		keys[0] = KeyboardManager.LEFT;
		keys[1] = KeyboardManager.RIGHT;
		keys[2] = KeyboardManager.UP;
		keys[3] = KeyboardManager.DOWN;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		MC.clearAll();
		Clip.reset();
		#if debug
		cov = {
			stones: 0,
			bonusDie: 0,
			bubbles: 0,
			hsKept: 0,
			hsLost: 0,
			combos: 0
		};
		#end
		// mt.Timer before its first update: Manager.init creates the game, whose constructor calls main() once, before
		// the first Manager.main (Timer.update)
		Timer.tmod = 1;
		Timer.deltaT = 1;
		Clip.deferring = true;
		// the original's 300x300 pixels, drawn x2
		root = mc.createEmptyMovieClip("scene", 0);
		root._xscale = root._yscale = 100 * Clip.K;
		root.updateState();

		dmanager = new Plans(root);
		bg = dmanager.attach("bg", Const.PLAN_BG);
		animator = new Animator(this);
		level = new Level(this);
		hero = new Hero(this);
		hscombo = [];
		maxtime = 15;
		level_count = 0;
		time = maxtime;
		nlegs = Const.NLEGS;
		stats = {
			b1: 0,
			b2: 0,
			c: [],
			g: [0, 0, 0, 0, 0],
			l: 0,
		};
		init();
		main();

		Clip.deferring = false;
		Clip.runLater();
		MC.displayAll(1);
	}

	// a cereal kind (0 .. nlegs - 1); 1 in 10: a bubble, a stone, or a gold cereal
	public function randId():Int {
		var n = KKApi.val(nlegs);
		var id = Seed.random(n);
		if (Seed.random(10) == 0) {
			id = Const.BULLE + randomProbas([25, 25, 2]);
			if (id == Const.BULLE + 2)
				id = Seed.random(n) + Const.GOLD;
		}
		return id;
	}

	// Tools.randomProbas: index drawn with the weights
	static function randomProbas(a:Array<Int>):Int {
		var n = 0;
		var i = a.length - 1;
		while (i >= 0) {
			n += a[i];
			i--;
		}
		n = Seed.random(n);
		i = 0;
		while (n >= a[i]) {
			n -= a[i];
			i++;
		}
		return i;
	}

	function init() {
		for (i in 0...3)
			level.genLine();
	}

	// the cereals stopped moving: bubbles under a cereal that moved burst, then the holes fill, then the groups explode
	public function explode() {
		if (game_over)
			return;

		var bulles = level.explodeBulles();
		if (bulles != null) {
			#if debug
			cov.bubbles += bulles.length;
			#end
			for (i in 0...bulles.length)
				animator.explodeLegume(bulles[i]);
			return;
		}

		var g = level.gravity();
		if (g != null) {
			for (i in 0...g.length)
				animator.gravity(g[i]);
			return;
		}

		var expl = level.explodes();
		// (no group: expl is null, combos undefined: the cereals thrown above the screen are lost)
		var combos = expl != null ? expl.combos : null;
		var s = 0;
		if (hscombo.length > 0) {
			#if debug
			if (combos != null)
				cov.hsKept++;
			else
				cov.hsLost++;
			#end
			hscombo.push(null);
			hscombo.push(null);
			if (combos != null)
				combos.push(hscombo);
		}
		hscombo = [];
		if (combos == null)
			return;
		for (i in 0...combos.length) {
			var c = combos[i];
			for (j in 0...c.length)
				animator.explodeLegume(c[j]);
			stats.c.push(c.length + combo_phase * 1000);
			var pts = Std.int(c.length * (combo_phase + 1)) * KKApi.val(Const.C100);
			s += pts;
			addScore(KKApi.val(KKApi.const(pts)));
		}

		if (s > 0) {
			var fs = dmanager.attach("fieldScore", Const.PLAN_INTERF);
			fs._x = 300;
			setFieldScore(fs, s);
		}

		if (combos.length > 0) {
			#if debug
			if (combo_phase > 0)
				cov.combos++;
			#end
			combo_phase++;
			time -= 0.3;
		}
	}

	function main() {
		animator.main();
		if (game_over) {
			var ntrys = 100;
			while (--ntrys > 0) {
				var x = Seed.random(Const.WIDTH);
				var y = Seed.random(Const.HEIGHT);
				var l = level.legumes[x][y];
				if (l == null)
					continue;
				level.legumes[x][y] = null;
				animator.destroyLegume(l);
				return;
			}
			for (x in 0...Const.WIDTH)
				for (y in 0...Const.HEIGHT) {
					animator.destroyLegume(level.legumes[x][y]);
					level.legumes[x][y] = null;
				}

			stats.l = level_count;
			gameOver();
			return;
		}

		hero.main();
		var h = level.maxHeight();
		time -= Timer.deltaT * (30 / (h * (1 + h)));

		if (h >= 8 && !animator.locked(true))
			game_over = true;

		if (time < 0 && !animator.locked(true)) {
			level.genLine();
			time = maxtime;
			level_count++;
			maxtime *= 0.97;
			if (KKApi.val(nlegs) < 5 && level_count % 15 == 0)
				nlegs = KKApi.cadd(nlegs, KKApi.const(1));
		}
	}

	// ---------------------------------------------------------------- port
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

	// one Flash frame: the timelines advance, then Manager.main (Timer settles on tmod 32 / 40, deltaT 1 / 40), then the
	// frame scripts the code triggered
	function flashFrame() {
		Timer.tmod = 32 / FLASH_FPS;
		Timer.deltaT = 1 / FLASH_FPS;
		MC.frameStart();
		Clip.deferring = true;
		main();
		Clip.deferring = false;
		Clip.runLater();
		frameCount++;
		#if debug
		var hsh = ghash;
		for (x in 0...Const.WIDTH)
			for (y in 0...Const.HEIGHT) {
				var l = level.legumes[x][y];
				hsh = (hsh * 31 + (l == null ? 7 : l.id * 3 + (l.gold ? 1 : 0) + l.life * 101)) | 0;
			}
		hsh = (hsh * 31 + hero.px * 17 + hero.legumes.length + Std.int(time * 1000)) | 0;
		ghash = hsh;
		untyped js.Browser.window.__state = debugState();
		#end
	}

	// fs.score = s: the text field of fieldScore.sc (_parent.score) shows it
	function setFieldScore(fs:MC, s:Int) {
		var sc = fs.clip.get("sc");
		if (sc != null) {
			var d = new Digits();
			d.setText(Std.string(s));
			sc.addChild(d);
		}
	}

	// KKApi.addScore: nothing after the game over
	public function addScore(n:Int) {
		if (over)
			return;
		score += n;
		KadoKadeoManager.kkm.addScore(n);
	}

	// KKApi.gameOver(stats): the original called it at every frame once the grid is cleared
	function gameOver() {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		var s:Dynamic = {};
		Reflect.setField(s, "$b1", stats.b1);
		Reflect.setField(s, "$b2", stats.b2);
		Reflect.setField(s, "$c", stats.c);
		Reflect.setField(s, "$g", stats.g);
		Reflect.setField(s, "$l", stats.l);
		KadoKadeoManager.kkm.gameOver(s);
	}

	#if debug
	// state compared between a game and its replay (test harness)
	function debugState():Dynamic {
		var grid = [];
		for (x in 0...Const.WIDTH)
			for (y in 0...Const.HEIGHT) {
				var l = level.legumes[x][y];
				grid.push(l == null ? "." : (l.gold ? "g" : "") + l.id);
			}
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: score,
			px: hero.px,
			held: hero.legumes.length,
			time: Math.round(time * 1e6) / 1e6,
			maxtime: Math.round(maxtime * 1e6) / 1e6,
			lines: level_count,
			nlegs: KKApi.val(nlegs),
			combo: combo_phase,
			height: level.maxHeight(),
			grid: grid.join(","),
			stats: haxe.Json.stringify(stats),
			cov: haxe.Json.stringify(cov),
			gameOver: game_over,
			ghash: ghash,
			over: over,
		};
	}

	// test harness: clips drawn by the runtime on a page ([name, frame, x, y, scale, {nested instance: frame}]), to
	// compare with the SWF
	public function debugShow(list:Array<Array<Dynamic>>, bgColor:Int) {
		var stage:Dynamic = untyped KadoKadeoManager.kkm.stage;
		var box = new ASprite();
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
						// (a path of nested instances: "m.m.it0")
						var sub = c;
						for (n in k.split("."))
							sub = sub != null ? sub.getClip(n) : null;
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
		MC.clearAll();
		Clip.reset();
	}
}

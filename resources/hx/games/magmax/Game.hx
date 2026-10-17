package magmax;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import magmax.MC.Plans;
import magmax.Monster.Bonus;
import magmax.Monster.Part;
import pixi.core.display.Container;
import pixi.core.textures.Texture;
import pixi.filters.colormatrix.ColorMatrixFilter;

// Game.mt of the original
@:expose('GameMagmax')
class Game implements kado.GameInterface {
	// a floating joystick (8 directions) gives the arrows; the button fires (Space: the hero keeps its direction while
	// it shoots)
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.JOYSTICK,
		joystick: {
			x: 0.2,
			y: 0.75,
			radius: 84,
			deadZone: 0.25,
			dynamicCenter: true,
			directions: 8,
		},
		buttons: [
			{
				id: "fire",
				label: "✹",
				rightPx: 20,
				bottomPx: 40,
				size: 96,
				keyCode: KeyboardManager.SPACE,
			}
		],
	};

	// ZQSD / WASD move like the arrows, Enter shoots like Space and Control
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	// Flash played Magmax at 40 frames/s (the rate of gaunt.swf and of the KadoKado loader) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	public var dmanager:Plans;
	public var tirs:Array<Tir>;
	public var monsters:Array<Monster>;
	public var bonus:Array<Bonus>;
	public var hero:Hero;
	public var level:Int;
	public var game_over:Bool;
	// seq, dual (not in the original, for the achievements): bomb, flower then turret killed in a row in one combo chain;
	// a special bonus picked up while the other one is active
	public var stats:{g:Array<Int>, k:Array<Int>, b:Array<Int>, c:Array<Int>, seq:Int, dual:Int};

	var parts:Array<Part>;
	var bg:MC;
	var last_dead:Float;
	var time:Float;
	var combo:Int;
	// types of the 2 previous kills of the current combo chain (-1: none)
	var prev1:Int = -1;
	var prev2:Int = -1;
	var combo_mc:MC;
	var death:MC;

	var root:ASprite;
	var isReplay:Bool;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	var over:Bool = false;

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(6);
		keys[0] = KeyboardManager.LEFT;
		keys[1] = KeyboardManager.RIGHT;
		keys[2] = KeyboardManager.UP;
		keys[3] = KeyboardManager.DOWN;
		keys[4] = KeyboardManager.SPACE;
		keys[5] = KeyboardManager.CONTROL;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		MC.clearAll();
		Clip.reset();
		setTiming();

		// the original's 300x300 pixels, drawn x2
		root = mc.createEmptyMovieClip("scene", 0);
		root._xscale = root._yscale = 100 * Clip.K;
		root.updateState();

		level = 1;
		time = 0;
		combo = 0;
		last_dead = -1000;
		game_over = false;
		dmanager = new Plans(root);
		bg = dmanager.attach(new MC("bg"), Const.PLAN_BG);
		hero = new Hero(this);
		tirs = new Array();
		parts = new Array();
		bonus = new Array();
		monsters = new Array();
		stats = {
			g: [0, 0, 0],
			k: [0, 0, 0],
			c: [0, 0, 0, 0],
			b: [0, 0, 0, 0, 0, 0],
			seq: 0,
			dual: 0
		};
		genMonster();

		MC.displayAll(1);
		warmShaders();
	}

	// one Flash frame of the original: tmod ~0.8 (Timer: 0.95 * tmod + 0.05 * deltaT * 32 settles on 32 / 40) and
	// deltaT 1 / 40 s
	static function setTiming() {
		Timer.tmod = 32 / FLASH_FPS;
		Timer.deltaT = 1 / FLASH_FPS;
	}

	// the colour transform of the code (monster hit, red hero) is a ColorMatrixFilter: its shader compiled now, not
	// at the first hit
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null)
			return;
		var holder = new Container();
		var s = new pixi.core.sprites.Sprite(Texture.WHITE);
		var cm = new ColorMatrixFilter();
		cm.matrix = [1, 0, 0, 0, 0.5, 0, 1, 0, 0, 0.5, 0, 0, 1, 0, 0.5, 0, 0, 0, 1, 0];
		s.filters = [cm];
		holder.addChild(s);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function addScore(n:Int) {
		// (nothing after KKApi.gameOver: the end screen is up)
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	function genMonster() {
		var t = 0;

		if (level >= 10)
			t = Const.randomProbas([3, 1]);
		if (level >= 20)
			t = Const.randomProbas([1, 4]);
		if (level >= 30)
			t = Const.randomProbas([3, 2, 1]);

		stats.g[t]++;
		var m = new Monster(this, t);
		monsters.push(m);
		level++;
	}

	public function gameOver() {
		if (!game_over) {
			game_over = true;
			death = dmanager.attach(new MC("death"), Const.PLAN_PART);
			death._x = hero.x;
			death._y = hero.y;
			hero.mc._visible = false;
		}
	}

	public function addPart(p:Part) {
		parts.push(p);
	}

	public function doCombo(type:Int) {
		var chained = time - last_dead < 2.5;
		if (!chained)
			prev1 = prev2 = -1;
		else if (prev2 == 0 && prev1 == 1 && type == 2)
			stats.seq++;
		prev2 = prev1;
		prev1 = type;
		if (chained) {
			if (combo < Const.COMBOS.length) {
				if (combo_mc != null)
					combo_mc.removeMovieClip();
				combo_mc = dmanager.attach(new MC("comment"), 2);
				combo_mc._y = 300;
				var c = combo_mc.clip.getClip("c");
				if (c != null)
					c.gotoAndStop(combo + 1);
				addScore(KKApi.val(Const.COMBOS[combo]));
				stats.c[combo]++;
				combo++;
			}
		} else
			combo = 0;
		last_dead = time;
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

	function flashFrame() {
		setTiming();
		MC.frameStart();
		main();
		frameCount++;
		#if debug
		untyped js.Browser.window.__state = state();
		#end
	}

	// main() of the original: one Flash frame
	function main() {
		time += Timer.deltaT;

		if (game_over && death != null && death.removed) {
			death = null;
			over = true;
			#if debug
			untyped js.Browser.window.__over = state();
			#end
			KadoKadeoManager.kkm.gameOver(stats);
		}

		if (monsters.length < 6 && Seed.random(Std.int(1500 * monsters.length / (Timer.tmod * level))) == 0)
			genMonster();
		if (!game_over && !hero.update())
			gameOver();
		var i = 0;
		while (i < monsters.length) {
			if (!monsters[i].update())
				monsters.splice(i--, 1);
			i++;
		}
		i = 0;
		while (i < tirs.length) {
			if (!tirs[i].update())
				tirs.splice(i--, 1);
			i++;
		}
		i = 0;
		while (i < parts.length) {
			var p = parts[i];
			p.x += p.vx * Timer.tmod;
			p.y += p.vy * Timer.tmod;
			if (p.y > 0) {
				p.y *= -1;
				p.vy *= -0.5;
			}
			p._rotation += p.vx * 5 * Timer.tmod;
			p._alpha -= 5;
			if (p._alpha <= 0) {
				p.removeMovieClip();
				parts.splice(i--, 1);
			}
			p.vy += Timer.tmod;
			p._x = p.x;
			p._y = p.by + p.y;
			i++;
		}
		dmanager.compact(Const.PLAN_HERO);
		dmanager.ysort(Const.PLAN_HERO);
	}

	#if debug
	// end state compared between a game and its replay (test harness)
	function state():Dynamic {
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			level: level,
			hx: hero.x,
			hy: hero.y,
			mons: monsters.length,
			tirs: tirs.length,
			bonus: bonus.length,
			over: game_over,
			stats: haxe.Json.stringify(stats),
		};
	}

	// test harness: clips drawn by the runtime on a page ([name, frame, x, y, scale, {nested instance: frame}]), to
	// compare with the SWF (examples/magmax/ncheck.mjs, ref.py)
	public function debugShow(list:Array<Array<Dynamic>>, bgColor:Int) {
		var stage:Dynamic = untyped KadoKadeoManager.kkm.stage;
		var box = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		// the option particles on their first frame, like the reference
		Clip.random = n -> 0;
		for (o in list) {
			var c = new Clip(o[0], 2);
			// nested clips driven by the code: before and after the frame change (clips created on the new frame)
			for (pass in 0...2) {
				if (pass == 1)
					c.gotoAndStop(o[1]);
				if (o.length > 5)
					for (k in Reflect.fields(o[5])) {
						var sub = c.getClip(k);
						if (sub != null)
							sub.gotoAndStop(Reflect.field(o[5], k));
					}
			}
			c._x = o[2];
			c._y = o[3];
			c._xscale = c._yscale = o[4] * 100;
			box.addChild(c);
		}
		Clip.random = Seed.random;
		box.updateState();
		box.updateGraphics(1);
		stage.addChild(box);
	}
	#end

	// the joystick presses the arrows (read by Hero.update like the keyboard, recorded in the replay)
	public function pollTouchControls():Void {
		var joystick = KadoKadeoManager.kkm.getTouchJoystickState();
		if (joystick == null)
			return;
		var ax = joystick.active ? joystick.dirX : 0;
		var ay = joystick.active ? joystick.dirY : 0;
		setKey(KeyboardManager.LEFT, ax < 0);
		setKey(KeyboardManager.RIGHT, ax > 0);
		setKey(KeyboardManager.UP, ay < 0);
		setKey(KeyboardManager.DOWN, ay > 0);
	}

	inline function setKey(keyCode:Int, down:Bool):Void {
		if (down)
			KeyboardManager.setKeyDown(keyCode);
		else
			KeyboardManager.setKeyUp(keyCode);
	}

	public function destroy():Void {
		MC.clearAll();
		Clip.reset();
	}
}

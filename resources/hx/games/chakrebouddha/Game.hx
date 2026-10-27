package chakrebouddha;

import chakrebouddha.Anim;
import chakrebouddha.Common;
import chakrebouddha.FlashFilters;
import chakrebouddha.Gfx;
import chakrebouddha.MC.FilterDef;
import chakrebouddha.MC.Plans;
import haxe.io.UInt16Array;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;

/**
 * Chakre Bouddha (KadoKado "Chakras", Haxe 2 for Flash 8): a click anywhere when a chakra lights up. The sooner, the
 * more points; a click with no chakra to touch, or a chakra let go, costs energy, and the game ends without energy.
 */
@:expose('GameChakreBouddha')
class Game implements kado.GameInterface {
	// texture pixels per Flash pixel: the original's 300 x 300 pixels drawn x2
	public static inline var K = 2;
	// Flash played Chakras at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32: tmod = 0.8
	public static inline var FRAME_RATE = 40;
	// replay event: a key released (Key.onKeyUp)
	static inline var EV_KEYUP = 1;

	public static var me:Game;

	public var dm:Plans;
	public var root:MC;
	public var mcBg:MC;
	public var mcEnergy:Energy;
	public var mcRelease:MC;
	public var plasma:Plasma;
	public var cycles:Int;
	// nombre de tours avant animation
	public var threshold:Int;
	// Si une animation est en cours
	public var animated:Bool;
	public var missLock:Bool;
	public var missKeyLock:Bool;
	public var animReseted:Int;

	var shakeSpeed:Float;
	var shakeCpt:Float;
	var anim:Array<Anim>;
	var chakras:Array<Chakra>;
	var step:Step;
	var activatedStep:Step;
	// nombre de tours avant le prochain test
	var pause:Int;
	var pauseCoeff:Int;
	var pauseBase:Int;
	var activation:Int;
	var missed:Int;
	var chakraLock:Bool;
	var points:Int;
	var started:Bool;
	var countCycles:Int;
	var mouse:Bool;
	var catchKey:Bool;
	var combo:Int;

	// ---------------------------------------------------------------- port
	var isReplay:Bool;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	var over:Bool = false;
	// a key released during the last step (live game): applied at this step, like the replay applies its event
	var keyUpTyped:Bool = false;
	var flushListener:Dynamic;
	#if debug
	// test harness: what the game went through (window.__over)
	public var stats:Dynamic;
	#end

	/*----------------------------------- INIT -------------------------------------*/
	/*------------------------------------------------------------------------------*/
	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		// (a replay keeps the params it was recorded with: the replays from before the space bar have no key)
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: UInt16Array.fromArray([KeyboardManager.SPACE]),
			recordInputs: true,
			recordEvents: true,
			recordMousePosition: true,
			recordedMouseButtons: UInt16Array.fromArray([MouseManager.BUTTON_LEFT]),
		});
		// statics of the original (the SWF was loaded again for every game)
		Const.reset();
		MC.clearAll();
		Sprite.spriteList = [];
		#if debug
		// test harness (modes/chakrebouddha.js): the constants of the game, changed the same way in a game and its replay
		untyped js.Browser.window.__cbConst = Const;
		stats = {touches: 0, highs: 0, combos: 0, bonus: 0, traps: 0, missedChakras: 0, missedKeys: 0, keyUps: 0, rests: 0, moves: 0};
		#end

		root = new MC(null, 1 / K);
		root.posK = K;
		// the shake of the screen (root._x / _y): shown frame by frame, not smoothed
		root.noLerp = true;
		mc.addChild(root.spr);
		me = this;

		combo = 0;
		catchKey = true;
		shakeSpeed = 0.1;
		shakeCpt = 0;
		mouse = false;
		started = false;
		points = 300;
		chakraLock = false;
		animReseted = 0;
		threshold = Const.ANIMATION_THRESHOLD;
		activation = 0;
		// (haxe.Firebug.redirectTraces())

		dm = new Plans(root);

		// attach("mcBg", DP_BG) frame 1: the same picture as mcEnergy (frame 2 of mcBg), attached just over it, opaque:
		// never seen, not drawn
		mcBg = dm.empty(Const.DP_BG);

		mcEnergy = dm.add(new Energy(), Const.DP_BG);

		step = Play;
		initChakras();
		cycles = Const.BASE_CYCLE;
		pause = Const.MAX_PAUSE;
		pauseBase = Const.MAX_PAUSE;
		anim = new Array();
		missed = 0;
		missLock = false;
		countCycles = KKApi.val(Const.CYCLES);
		// flash.Key.onKeyUp = function() { me.missKeyLock = false; }: see update

		// an invisible square over the stage (beginFill(1, 0)) whose onPress sets mouse: see update
		mcRelease = dm.empty(Const.DP_TOP);

		// BlurFilter 4 x 4 quality 3, ColorTransform(1, 1, 1, 1, 0, 0, 0, -25), blendMode "ligthen": see Plasma
		plasma = new Plasma(dm.empty(Const.DP_CHAKRAS), 300, 300, 0.4);

		// the plasma is drawn on the GPU just before the screen is: after the steps of the frame (NORMAL priority),
		// before the render of the page (LOW)
		flushListener = function(_) {
			if (plasma != null)
				plasma.flush();
		};
		var ticker:Dynamic = KadoKadeoManager.kkm.ticker;
		ticker.add(flushListener, null, -10);

		MC.displayAll(1);
		warmShaders();
	}

	function initChakras() {
		chakras = [];
		var i = 1;
		chakras.push(new Chakra(this, Const.X, 278, i++));
		chakras.push(new Chakra(this, Const.X, 250, i++));
		chakras.push(new Chakra(this, Const.X, 209, i++));
		chakras.push(new Chakra(this, Const.X, 168, i++));
		chakras.push(new Chakra(this, Const.X, 128, i++));
		chakras.push(new Chakra(this, Const.X, 60, i++));
		chakras.push(new Chakra(this, Const.X, 34, i++));
	}

	/*----------------------------------- CONTROL -------------------------------------*/
	/*---------------------------------------------------------------------------------*/
	function checkInput() {
		if (step == GameOver) {
			return;
		}

		if (!started) {
			mouse = false;
			return;
		}

		if (activatedStep != null && catchKey) {
			getKeyBoardKey();
			catchKey = true;
		} else {
			missKey();
		}
	}

	public function missedChakra(c:Chakra) {
		if (missLock)
			return;
		#if debug
		stats.missedChakras++;
		#end
		c.miss();
		shake();
		var me = this;
		var f = function() {
			me.missLock = false;
		};
		loose(f);
		missLock = true;
	}

	function missKey() {
		if (missLock)
			return;
		if (missKeyLock)
			return;

		if (mouse) {
			#if debug
			stats.missedKeys++;
			#end
			mouse = false;
			shake();
			var me = this;
			var f = function() {
				me.missKeyLock = false;
			};
			loose(f);

			missKeyLock = true;
		}
	}

	public function getKeyBoardKey() {
		if (step == GameOver)
			return;
		if (chakraLock)
			return;

		if (mouse) {
			mouse = false;
			missKeyLock = true;
			if (activatedStep != null && activatedStep != Play) {
				chakraLock = true;
				var chakra = chakras[Type.enumIndex(activatedStep)];
				if (chakra.trap) {
					#if debug
					stats.traps++;
					#end
					missedChakra(chakra);
				} else {
					var touch = chakra.touch();
					if (touch > 0) {
						#if debug
						stats.touches++;
						#end
						if (threshold-- <= 0 && !animated) {
							// (the moves only change the picture: their random is the visual one)
							var anim = Const.MOVES[Seed.randomVfx(Const.MOVES.length)];
							#if debug
							stats.moves++;
							#end
							animReseted = 0;
							animated = true;
							threshold = 0;
							for (c in chakras) {
								c.animate(anim, Seed.randomVfx(5));
							}
						}

						if (chakra.missed) {
							showPoints(chakra, 0);
						} else {
							var score = KKApi.const(0);
							if (chakra.bonus) {
								#if debug
								stats.bonus++;
								#end
								score = KKApi.cmult(Const.SCORE_MUL, KKApi.const(Std.int(touch * 20)));
							} else
								score = KKApi.cmult(Const.SCORE_MUL, KKApi.const(Std.int(touch * 10)));

							addScore(score);

							// le score est élevé on affiche le symbole
							if (touch > cycles - cycles / KKApi.val(Const.CYCLE_DIV) * KKApi.val(Const.CYCLE_DIV_2)) {
								#if debug
								stats.highs++;
								#end
								energyUp(addPoints(KKApi.val(Const.ENERGY_UP)));

								if (combo++ == KKApi.val(Const.COMBO_T)) {
									#if debug
									stats.combos++;
									#end
									showNeon(chakra, true);
									var p = new BonusAnim(this, KKApi.val(Const.COMBO_SCORE));
									anim.push(p);
									addScore(Const.COMBO_SCORE);
									combo = 0;
								} else {
									showPoints(chakra, KKApi.val(score));
									showNeon(chakra);
								}
								return;
							} else {
								showPoints(chakra, KKApi.val(score));
								energyUp(addPoints(KKApi.val(Const.ENERGY_SUP)));
								combo = 0;
							}
						}
					}
				}
			}
		}
	}

	/*----------------------------------- ANIM -------------------------------------*/
	/*---------------------------------------------------------------------------------*/
	function getStep(idx:Int):Step {
		switch (idx) {
			case 0:
				return Muladhara;
			case 1:
				return Swadhisthana;
			case 2:
				return Manipura;
			case 3:
				return Anahata;
			case 4:
				return Visshudha;
			case 5:
				return Ajna;
			case 6:
				return Sahasrara;
		}
		return null;
	}

	// ---------------------------------------------------------------- UPDATE
	public function update(delta:Float) {
		// Flash played Chakras at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32: tmod = 0.8, one
		// update() per Flash frame. KadoKadeo steps 32 times per second: 5 Flash frames every 4 steps. The events of
		// the step (a click, a key released) come before its Flash frames, between two Flash frames like Flash's
		mt.Timer.tmod = 32 / FRAME_RATE;

		// flash.Key.onKeyUp (any key): missKeyLock = false. Not a key the replay records: a replay event, applied at
		// the next step in both modes
		var keyUp = false;
		for (e in KadoKadeoManager.kkm.replay.consumeEvents())
			if (e != null && e.k == EV_KEYUP)
				keyUp = true;
		if (keyUpTyped) {
			keyUpTyped = false;
			keyUp = true;
		}
		if (keyUp) {
			#if debug
			stats.keyUps++;
			#end
			missKeyLock = false;
		}
		if (!isReplay)
			for (c in KeyboardManager.getFrameKeyChanges())
				if (!c.isDown && !keyUpTyped) {
					KadoKadeoManager.kkm.replay.recordEvent({k: EV_KEYUP});
					keyUpTyped = true;
				}

		// mcRelease.onPress: a press on the stage (300 x 300; not on the bar under it)
		for (c in MouseManager.getFrameButtonChanges())
			if (c.button == MouseManager.BUTTON_LEFT && c.isDown) {
				var mx = Math.max(0, MouseManager.getX()) / K;
				var my = Math.max(0, MouseManager.getY()) / K;
				if (mx < 300 && my < 300)
					mouse = true;
			}
		// the space bar too (not in the original): a press on the stage. Its release is a key released like the others
		for (c in KeyboardManager.getFrameKeyChanges())
			if (c.keyCode == KeyboardManager.SPACE && c.isDown)
				mouse = true;

		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			MC.frameStart();
			main();
			frameCount++;
		}
		MC.displayAll(frameAcc / 4);
	}

	// update() of the original: one Flash frame
	function main() {
		// (if( chakras.cheat ) KKApi.flagCheater(): mt.flash.PArray, dropped)

		if (Sprite.spriteList.length > 0) {
			var l = Sprite.spriteList.copy();
			for (s in l) {
				s.update();
			}
		}

		if (shakeCpt > 0) {
			// (the shake is for the eye: the visual random)
			root._x = (Seed.randomVfx(2) * 2 - 1) * shakeCpt;
			root._y = (Seed.randomVfx(2) * 2 - 1) * shakeCpt;
			shakeCpt -= shakeSpeed;
			if (shakeCpt <= 0) {
				shakeCpt = 0;
				root._x = 0;
				root._y = 0;
			}
		}

		for (c in chakras) {
			c.update();
		}

		// (for( a in anim ) of Haxe 2: an index loop, an anim removed makes the next one wait for the next frame)
		if (anim.length > 0) {
			var i = 0;
			while (i < anim.length) {
				var a = anim[i];
				i++;
				if (a.play()) {
					// (onEnd not set: calling undefined does nothing in Flash)
					if (a.onEnd != null)
						a.onEnd();
					a.clean();
					anim.remove(a);
				}
			}
		}

		plasma.update();

		if (step == GameOver) {
			gameOver();
			return;
		}

		step = Play;

		checkInput();
		checkEnergy();

		if (pause-- <= 0) {
			if (activatedStep == null) {
				started = true;

				// (9 constructors: Play and GameOver too. idx 7 or 8: no chakra, chakras[idx] is undefined and its
				// activate does nothing; getStep gives null: a rest)
				var ct = Type.getEnumConstructs(Step);
				var idx = Seed.random(ct.length);
				var c = chakras[idx];
				activatedStep = getStep(idx);
				if (c != null)
					c.activate(cycles);
				#if debug
				else
					stats.rests++;
				#end
				activation++;
			}

			modifyGameplay();

			if (pauseBase <= Const.MIN_PAUSE) {
				switch (Seed.random(3)) {
					case 0:
						pause = pauseBase + Seed.random(80);
					case 1:
						pause = 2;
					case 2:
						pause = pauseBase + Seed.random(80);
				}
			} else {
				pause = pauseBase;
			}
		}
	}

	function modifyGameplay() {
		// réglage du laps de temps entre les affichages du curseur
		if (activation % 2 == 0 && pauseBase > Const.MIN_PAUSE) {
			pauseBase -= KKApi.val(Const.PAUSE_DEC);
		}

		if (activation % 25 == 0) {
			if (KKApi.val(Const.CYCLES) > 4) {
				Const.CYCLES = KKApi.const(KKApi.val(Const.CYCLES) - KKApi.val(Const.CYCLE_DEC));
			}
		}
	}

	function energyUp(p:Int) {
		var a = new EnergyAnim(mcEnergy.mask, p, false);
		anim.push(a);
	}

	function showPoints(chakra:Chakra, points:Int) {
		if (chakra.bonus) {
			var b = new BonusPointsAnim(this, chakra, points);
			anim.push(b);
			return;
		}

		var p = new PointsAnim(this, chakra, points);
		anim.push(p);
	}

	function loose(f:Void->Void) {
		var r = removePoints(KKApi.val(Const.MISS_KEY_LOOSE));

		if (KKApi.val(Const.POINTS) <= 0) {
			var me = this;
			var a = new EnergyAnim(mcEnergy.mask, r);
			a.onEnd = function() {
				me.step = GameOver;
				f();
			};
			anim.push(a);
			return;
		} else {
			var a = new EnergyAnim(mcEnergy.mask, r);
			a.onEnd = function() {
				f();
			};
			anim.push(a);
		}
	}

	function shake() {
		shakeCpt = 2;
		// (the rocks are for the eye: the visual random)
		for (i in 0...10) {
			var mc = dm.attach("rock", Const.DP_TOP, 1);
			mc.gotoAndStop(Seed.randomVfx(2) + 1);
			mc._yscale = mc._xscale = Seed.randomVfx(80) + 20;
			mc._x = (i + 1) * (Seed.randomVfx(30) + 10);
			mc._y = -10;
			var s = new Phys(mc);
			s.vy = mc._yscale / 20;
			s.weight = mc._yscale / 80;
			s.vr = mc._yscale / 10;
			s.timer = 50;
		}
	}

	function checkEnergy() {
		if (KKApi.val(Const.POINTS) <= 0) {
			step = GameOver;
			return;
		}

		if (countCycles-- <= 0) {
			countCycles = KKApi.val(Const.CYCLES);
			// (never: the energy is at most 300)
			if (KKApi.val(Const.POINTS) > 300)
				return;
			var r = removePoints(KKApi.val(Const.ENERGY_DEC));
			if (step != GameOver)
				EnergyAnim.moveBy(mcEnergy.mask, KKApi.val(Const.ENERGY_DEC) * 20);
		}
	}

	function showNeon(c:Chakra, all = false) {
		if (all) {
			for (i in 1...8) {
				neon(i);
			}
			return;
		}

		neon(c.type);
	}

	function neon(type:Int) {
		var m = dm.attach("neon", Const.DP_BG, 1);
		switch (type) {
			case 1:
				m._x = 228;
				m._y = 8; // rouge
			case 2:
				m._x = 48;
				m._y = 7; // orange
			case 3:
				m._x = 232;
				m._y = 66; // jaune
			case 4:
				m._x = 187;
				m._y = 21; // vert : OK
			case 5:
				m._x = 0;
				m._y = 109; // cyan
			case 6:
				m._x = 246;
				m._y = 108; // bleu
			case 7:
				m._x = 15;
				m._y = 49; // violet
		}
		m.gotoAndStop(8 - type);
		var p = new Phys(m);
		p.fadeType = 4;
		p.fadeLimit = 25;
		p.timer = 50;
	}

	// Quand l'animation globale des chakras est présente
	public function resetAnim(anim:Chakra_Move) {
		if (animReseted++ == chakras.length - 1) {
			animated = false;
			threshold = Const.ANIMATION_THRESHOLD;
			animReseted = 0;
		}
	}

	public function resetChakra(c:Chakra, endAnim = false) {
		chakraLock = false;
		c.initGlow();
		activatedStep = null;
		missKeyLock = false;
		missLock = false;
		// catchKey = true;
	}

	function removePoints(p:Int):Int {
		var result = KKApi.val(Const.POINTS) - p;
		if (result <= 0) {
			var v = KKApi.val(Const.POINTS);
			Const.POINTS = KKApi.const(0);
			// (step == GameOver: a comparison, it does nothing)
			return v;
		}

		Const.POINTS = KKApi.const(result);
		return p;
	}

	function addPoints(p:Int):Int {
		if (KKApi.val(Const.POINTS) >= KKApi.val(Const.MAX_POINTS)) {
			Const.POINTS = Const.MAX_POINTS;
			return 0;
		}

		if (KKApi.val(Const.POINTS) + p >= KKApi.val(Const.MAX_POINTS)) {
			var v = KKApi.val(Const.POINTS);
			Const.POINTS = Const.MAX_POINTS;
			return KKApi.val(Const.MAX_POINTS) - v;
		}

		Const.POINTS = KKApi.const(KKApi.val(Const.POINTS) + p);
		return p;
	}

	// ---------------------------------------------------------------- port: score, game over
	function addScore(n:KKConst) {
		if (over)
			return;
		KadoKadeoManager.kkm.addScore(KKApi.val(n));
	}

	// KKApi.gameOver({}), called by the original at every frame once the game is over
	function gameOver() {
		if (over)
			return;
		over = true;
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		var cs = [for (c in chakras) c.mc._x + "," + c.mc._y];
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			activation: activation,
			pauseBase: pauseBase,
			cycles: KKApi.val(Const.CYCLES),
			combo: combo,
			mask: mcEnergy.mask._y,
			chakras: cs.join(" "),
			stats: haxe.Json.stringify(stats)
		};
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	// ---------------------------------------------------------------- port: display
	// The first use of a filter or a mask compiles its shader (tens of ms of freeze): every one is drawn once now, off
	// screen (the plasma compiles its own)
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		var g:FlashGlow = cast FlashFilters.take(FlashGlow);
		g.set(2, 1, 0xFFFFFF, 3);
		var b:FlashBlur = cast FlashFilters.take(FlashBlur);
		b.set(4, 4);
		var c:FlashCx = cast FlashFilters.take(FlashCx);
		c.set([0.3, 0.3, 0.3, 255, 255, 255]);
		s.filters = [g, b, c];
		holder.addChild(s);
		var m = new PixiSprite(Texture.WHITE);
		var ms = new PixiSprite(Texture.WHITE);
		holder.addChild(ms);
		m.mask = ms;
		holder.addChild(m);
		var rt:Dynamic = (cast RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		s.filters = null;
		FlashFilters.release(g);
		FlashFilters.release(b);
		FlashFilters.release(c);
		holder.destroy({children: true});
		rt.destroy(true);
	}

	#if debug
	// test harness (ncheck.mjs): the pictures of pages.json drawn by the runtime of the game, over the stopped game.
	// Item: [kind, frame, x, y, scale(, options)], x y in pixels of the canvas
	public function debugShow(list:Array<Array<Dynamic>>, bgColor:Int) {
		var stage:Dynamic = untyped KadoKadeoManager.kkm.stage;
		root.spr.visible = false;
		var box = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		var dbg = new MC(null, 1 / K);
		dbg.posK = K;
		box.addChild(dbg.spr);
		for (o in list) {
			var opt:Dynamic = o.length > 5 ? o[5] : {};
			var kind:String = o[0];
			var m:MC = switch (kind) {
				case "chakra":
					var c = new MC("chakra", K);
					var col = Const.COLORS[(o[1] : Int) - 1];
					if (opt.glow != null)
						c.filters = [Glow(2, 2, col, 3), Glow(8, opt.glow, col, 3)];
					c;
				case "active":
					var a = new Active();
					var col:Int = opt.cx;
					a.cx = [0.3, 0.3, 0.3, (col >> 16) & 0xFF, (col >> 8) & 0xFF, col & 0xFF];
					a;
				case "lotus":
					var l = new Lotus();
					var col:Int = opt.color;
					l.cx = [0.3, 0.3, 0.3, (col >> 16) & 0xFF, (col >> 8) & 0xFF, col & 0xFF];
					if (opt.glow != null)
						l.filters = [Glow(32, 1, col, 1)];
					if (opt.rot != null)
						l._rotation = opt.rot;
					l;
				case "points":
					var p = new Points(opt.big == 1);
					p.text.text = opt.text;
					p;
				case "bonus":
					new Bonus();
				case "energy":
					var e = new Energy();
					e.mask._y = opt.mask;
					e;
				default:
					new MC(kind, 1);
			}
			dbg.attach(m);
			m.gotoAndStop(o[1]);
			m._x = o[2] / K;
			m._y = o[3] / K;
			m._xscale = m._yscale = o[4] * 100;
		}
		MC.displayAll(1);
		box.updateState();
		box.updateGraphics(1);
		stage.addChild(box);
	}
	#end

	public function stageRoot():ASprite {
		return root != null ? root.spr : null;
	}

	public function destroy():Void {
		if (flushListener != null) {
			var ticker:Dynamic = KadoKadeoManager.kkm.ticker;
			ticker.remove(flushListener);
			flushListener = null;
		}
		if (plasma != null)
			plasma.destroy();
		plasma = null;
		MC.clearAll();
		FlashFilters.clear();
		Sprite.spriteList = [];
		Const.reset();
		if (me == this)
			me = null;
	}
}

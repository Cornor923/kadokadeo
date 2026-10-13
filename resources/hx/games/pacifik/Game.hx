package pacifik;

import pacifik.Anim;
import pacifik.Common;
import pacifik.FlashFilters;
import pacifik.Gfx;
import pacifik.MC.FilterDef;
import pacifik.MC.Plans;
import pacifik.Part.GlowLayer;
import haxe.io.UInt16Array;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;

/**
 * Pacifik (KadoKado, Haxe 2 for Flash 8): canons on both sides fire coloured balls at each other; the mouse moves a
 * laser across the screen and a click changes its colour (black, yellow, pink, cyan). A ball crossing the laser of its
 * colour is destroyed and scores; the black laser takes the bonus balls. A canon hit by a ball is lost (the first ones
 * have shields), and the game ends when a side has no canon left, or when the ship that comes down the middle is hit
 * twice (by the balls or by a coloured laser).
 */
@:expose('GamePacifik')
class Game implements kado.GameInterface {
	// texture pixels per Flash pixel: the original's 300 x 300 pixels drawn x2
	public static inline var K = 2;
	// Flash played Pacifik at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32: tmod = 0.8
	public static inline var FRAME_RATE = 40;

	// touch screens: a finger moves the laser (the mouse, without its button); the two buttons are the mouse button
	// (root.onPress / onRelease: a tap changes the colour, a long press puts the black laser back). Their key, SPACE,
	// does the same on a keyboard
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: kado.TouchControlsConfig.TouchControlsMode.KEYBOARD,
		passthroughMouseButtons: false,
		buttons: [
			{
				id: "colorL",
				label: "◐",
				leftPx: 10,
				bottomPx: 10,
				size: 64,
				keyCode: KeyboardManager.SPACE,
				shape: kado.TouchControlsConfig.TouchButtonShape.CIRCLE,
			},
			{
				id: "colorR",
				label: "◐",
				rightPx: 10,
				bottomPx: 10,
				size: 64,
				keyCode: KeyboardManager.SPACE,
				shape: kado.TouchControlsConfig.TouchButtonShape.CIRCLE,
			}
		]
	};

	public static var signalSent = false;
	public static var game:Game;

	public var dm:Plans;
	public var root:MC;
	public var gameOver:Bool = false;
	public var anim:Array<Anim>;
	public var canon1:Int;
	public var canon2:Int;
	public var laser:Laser;

	var shipEnergy:Int;
	var canons1:Array<Canon>;
	var canons2:Array<Canon>;
	var canons1Count:Int;
	var canons2Count:Int;
	var bg:MC;
	var ship:CarMC;
	var beware:Bool = false;

	var cycles:Int;
	var ball_speed_cycles:Float;
	var fire_cycles:Float;
	var replaceCycle:Float;
	var ship_cycle:Float;
	var shipIn:Bool = false;
	var g1:Array<OndeMC>;
	var g2:Array<OndeMC>;

	public var balls:Array<Ball>;

	// ---------------------------------------------------------------- port
	var isReplay:Bool;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	var over:Bool = false;
	// root._xmouse at the previous step and at this one (the Flash frames between take it in between, see update)
	var mousePrev:Float = Math.NaN;
	var mouseCur:Float = 150;
	// the press began on the stage (root.onRelease follows only such a press)
	var pressed:Bool = false;
	var flushListener:Dynamic;
	#if debug
	// test harness: what the game went through (window.__over)
	public var stats:Dynamic;
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: UInt16Array.fromArray([KeyboardManager.SPACE]),
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: UInt16Array.fromArray([MouseManager.BUTTON_LEFT]),
		});
		// statics of the original (the SWF was loaded again for every game)
		Const.reset();
		Ball.reset();
		signalSent = false;
		MC.clearAll();
		GlowLayer.clearAll();
		CanonMC.clearAll();
		Sprite.spriteList = [];
		mt.Timer.tmod = 32 / FRAME_RATE;
		#if debug
		// test harness (modes/pacifik.js): the constants of the game, changed the same way in a game and its replay
		untyped js.Browser.window.__pkConst = Const;
		stats = {balls: 0, kills: [0, 0, 0, 0], canonsLost: [0, 0], shields: 0, ships: 0, shipHits: 0, presses: 0, nanBalls: 0};
		#end

		root = new MC(null, 1 / K);
		root.posK = K;
		mc.addChild(root.spr);
		// (root.useHandCursor = false; haxe.Firebug.redirectTraces())
		dm = new Plans(root);

		shipEnergy = KKApi.val(Const.CAR_ENERGY);

		g1 = new Array();
		g2 = new Array();

		bg = dm.attach("bg", Const.DP_BG, 1);
		bg._x = Const.HEIGHT / 2;
		bg._y = Const.HEIGHT / 2;

		// (the waves are for the eye: the visual random)
		for (i in 0...6) {
			var o = dm.add(new OndeMC(), Const.DP_BG);
			o._x = Const.HEIGHT;
			o.gotoAndStop(Seed.randomVfx(o._totalframes) + 1);
			if (Seed.randomVfx(2) == 0) {
				o.y = -o.height();
				o._y = o.y;
				o.top = true;
			} else {
				o.y = Const.HEIGHT + o.height();
				o._y = o.y;
				o.top = false;
			}

			o._rotation = -180;
			o.speed = Seed.randomVfx(3) + 1;
			o.sleep = Seed.randomVfx(20);
			o.a = Seed.randomVfx(180);
			g2.push(o);
		}

		for (i in 0...6) {
			var o = dm.add(new OndeMC(), Const.DP_BG);
			o.gotoAndStop(Seed.randomVfx(o._totalframes) + 1);
			if (Seed.randomVfx(2) == 0) {
				o.y = -o.height();
				o._y = o.y;
				o.top = true;
			} else {
				o.y = Const.HEIGHT + o.height();
				o._y = o.y;
				o.top = false;
			}

			o.speed = Seed.randomVfx(3) + 1;
			o.sleep = Seed.randomVfx(20);
			o.a = Seed.randomVfx(180);
			g1.push(o);
		}

		for (i in 0...3) {
			var d = dm.attach("dock", Const.DP_BG, 1);
			d._y = Data.DOCK_HEIGHT + i * Data.DOCK_HEIGHT;
			d._x = Const.HEIGHT;
			d._rotation = -180;
		}

		for (i in 0...3) {
			var d = dm.attach("dock", Const.DP_BG, 1);
			d._y = i * Data.DOCK_HEIGHT;
		}

		anim = new Array();
		canons1 = new Array();
		canons2 = new Array();
		canon1 = canon2 = -1;
		balls = new Array();
		cycles = 0;
		replaceCycle = KKApi.val(Const.CANON_REPLACE_CYCLE);
		ball_speed_cycles = 0;
		fire_cycles = 0;
		ship_cycle = KKApi.val(Const.CAR_CYCLE) * 1.8;
		game = this;

		// (a Plasma bitmap on DP_BG (blur 2, colour transform, "lighten"), into which the particles listed in plasmaPart
		// are drawn: nothing is ever put in plasmaPart (the push is commented out), the plasma stays empty: not drawn)

		init();

		MC.displayAll(1);
		GlowLayer.placeAll();

		// the caches of the canons are drawn just before the screen is: after the steps and the interpolation of the
		// frame (NORMAL priority), before the render of the page (LOW)
		// (while KadoKadeo seeks, the stage is not interpolated: neither are the caches)
		flushListener = function(_) {
			var kk:Dynamic = KadoKadeoManager.kkm;
			if (kk.seekTarget == null && kk.catchUpTarget == null)
				CanonMC.flushAll(kk.ff.alpha);
		};
		var ticker:Dynamic = KadoKadeoManager.kkm.ticker;
		ticker.add(flushListener, null, -10);
		warmShaders();
	}

	public function init() {
		laser = new Laser(this);

		for (i in 0...KKApi.val(Const.MAX_CANONS)) {
			canons1.push(null);
			canons2.push(null);
		}

		canons1Count = canons2Count = Const.CANONS;

		for (i in 0...Const.CANONS) {
			var idx = getFreeIndex(canons1);
			var c = new Canon(this, idx * Const.CANON_SPACE + Const.CANON_STARTPOS, idx, KKApi.val(Const.SHIELD));
			canons1[idx] = c;
		}
		for (i in 0...Const.CANONS) {
			var idx = getFreeIndex(canons2);
			var c = new Canon(this, idx * Const.CANON_SPACE + Const.CANON_STARTPOS, true, idx, KKApi.val(Const.SHIELD));
			canons2[idx] = c;
		}

		// initKeyListener(): root.onPress / onRelease, see update
		playStartAnim(canons1);
		playStartAnim(canons2);
	}

	function playStartAnim(l:Array<Canon>) {
		for (c in l) {
			if (c == null)
				continue;
			if (c.init)
				continue;
			if (c.startAnim)
				continue;
			c.startAnim = true;
			c.display();
			var a = new CanonIn(c);
			a.onEnd = c.prepare;
			anim.push(a);
		}
	}

	function getFreeIndex(a:Array<Canon>):Null<Int> {
		if (a.length <= 0)
			return Seed.random(KKApi.val(Const.MAX_CANONS));

		var s = new Array();
		for (i in 0...KKApi.val(Const.MAX_CANONS)) {
			var c = a[i];
			if (c != null)
				continue;
			s.push(i);
		}

		if (s.length <= 0)
			return null;

		return s[Seed.random(s.length)];
	}

	// ---------------------------------------------------------------- UPDATE
	public function update(delta:Float) {
		// Flash played Pacifik at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32: tmod = 0.8, one update()
		// per Flash frame. KadoKadeo steps 32 times per second: 5 Flash frames every 4 steps.
		mt.Timer.tmod = 32 / FRAME_RATE;
		CanonMC.stepAll();

		// root._xmouse: the mouse in the stage (recorded each step)
		var mx = Math.max(0, MouseManager.getX()) / K;
		var my = Math.max(0, MouseManager.getY()) / K;
		mousePrev = Math.isNaN(mousePrev) ? mx : mouseCur;
		mouseCur = mx;

		// root.onPress / root.onRelease (laser.switchType / laser.testPress): a press on the stage (its 300 x 300
		// background), a release of such a press over the stage. Events of the step: before its Flash frames
		var inStage = mx < Const.HEIGHT && my < Const.HEIGHT;
		for (c in MouseManager.getFrameButtonChanges()) {
			if (c.button != MouseManager.BUTTON_LEFT)
				continue;
			if (c.isDown) {
				if (inStage)
					press();
			} else if (pressed) {
				if (inStage)
					release();
				else
					pressed = false;
			}
		}
		// (port) the touch buttons / SPACE: the mouse button
		for (c in KeyboardManager.getFrameKeyChanges()) {
			if (c.keyCode != KeyboardManager.SPACE)
				continue;
			if (c.isDown)
				press();
			else if (pressed)
				release();
		}

		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			MC.frameStart();
			// the mouse at the time of this Flash frame: frameAcc / 5 of a step before the end of the step (Flash
			// read it 40 times per second: the laser's jump test, LASER_OFF pixels per Flash frame, keeps its speed)
			var t = 1 - frameAcc / 5;
			main(mousePrev + (mouseCur - mousePrev) * t);
			frameCount++;
		}
		MC.displayAll(frameAcc / 4);
		GlowLayer.placeAll();
	}

	function press() {
		pressed = true;
		#if debug
		stats.presses++;
		#end
		laser.switchType();
	}

	function release() {
		pressed = false;
		laser.testPress();
	}

	// update() of the original: one Flash frame
	function main(xmouse:Float) {
		// (if( canons1.cheat ) KKApi.flagCheater(): the anti-cheat of mt.flash.PArray, dropped)
		var tmod = mt.Timer.tmod;

		// (plasmaPart: always empty, see new)

		if (Sprite.spriteList.length > 0) {
			var l = Sprite.spriteList.copy();
			for (s in l) {
				s.update();
			}
		}

		// (for( a in anim ) of Haxe 2: the length is read at each turn, an anim removed makes the next one wait for the
		// next frame, an anim pushed during the loop plays in this frame)
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

		laser.updatePos(xmouse);
		// (plasma.update(): see new)
		updateCanons(canons1);
		updateCanons(canons2);
		fire(canons1, getTarget(canons2));
		fire(canons2, getTarget(canons1));
		moveBalls(tmod);
		addCanons(tmod);
		addShip(tmod);
		updateShip(tmod);
		updateVV(g1, tmod);
		updateVV(g2, tmod);
		testEnd();

		if (gameOver && !signalSent) {
			endGame();
			signalSent = true;
		}

		updateGameplay(tmod);
	}

	function updateGameplay(tmod:Float) {
		Ball.update(tmod);

		ball_speed_cycles -= tmod;
		if (ball_speed_cycles <= 0) {
			Const.BALL_SPEED = KKApi.const(KKApi.val(Const.BALL_SPEED) + KKApi.val(Const.BALL_SPEED_ADD));
			ball_speed_cycles = KKApi.val(Const.BALL_SPEED_CYCLE);
		}

		fire_cycles -= tmod;
		if (fire_cycles <= 0) {
			Const.FIRE_CYCLE = KKApi.const(KKApi.val(Const.FIRE_CYCLE) - KKApi.val(Const.FIRE_CYCLE_MINUS));
			fire_cycles = KKApi.val(Const.FIRE_CYCLE);
		}
	}

	function updateVV(l:Array<OndeMC>, tmod:Float) {
		for (o in l) {
			o.a += tmod * 2;
			o._alpha = 40 * Math.sin(o.a * Math.PI / 180);
			if (o.a > 180)
				o.a = 0;

			o.sleep -= tmod;
			if (o.sleep > 0)
				continue;

			o.y += (if (o.top) tmod else -tmod) * 0.4 * o.speed;
			o._y = o.y;

			// (a wave going down turns back at the bottom; going up it never turns back: top = false again)
			if (o.top && o.y > Const.HEIGHT) {
				o.top = false;
			} else if (!o.top && o.y < 0) {
				o.top = false;
			}
		}
	}

	function addShip(tmod:Float) {
		if (gameOver)
			return;
		if (shipIn)
			return;

		ship_cycle -= tmod;
		if (ship_cycle <= 0) {
			beware = false;
			shipIn = true;
			ship = game.dm.add(new CarMC(), Const.DP_CANON);
			ship.gotoAndStop(Seed.random(ship._totalframes) + 1);
			ship._x = Const.HEIGHT / 2;
			ship.y = -ship.height();
			ship._y = ship.y;
			var c = KKApi.val(Const.CAR_CYCLE);
			ship_cycle = c / 2 + Seed.random(c * 3);
			var color = 0xFB04D6;
			// GradientGlowFilter(0, 45, [color, color], [0, 1], [0, 255], 4, 4, 1, 3, "outer")
			ship.filters = [Glow(4, 1, color, 3)];
			#if debug
			stats.ships++;
			#end
			return;
		}

		if (ship_cycle < 150 && !beware) {
			beware = true;
			var a = new Beware(this);
			anim.push(a);
		}
	}

	function updateShip(tmod:Float) {
		if (gameOver)
			return;
		if (!shipIn)
			return;

		ship.y += tmod - ship._currentframe * 0.1;
		ship._y = ship.y;

		var r1 = ship.r1();
		if (r1 != null) {
			reactorFx(ship._x + r1[0], ship.y + r1[1]);
		}

		var r2 = ship.r2();
		if (r2 != null) {
			reactorFx(ship._x + r2[0], ship.y + r2[1]);
		}

		if (laser.hitCar(ship)) {
			destroyShip();
			return;
		}

		if (ship._y > Const.HEIGHT) {
			ship.removeMovieClip();
			ship = null;
			shipIn = false;
		}
	}

	function addCanons(tmod:Float) {
		if (gameOver)
			return;

		var needC1 = canons1Count < KKApi.val(Const.MAX_CANONS);
		var needC2 = canons2Count < KKApi.val(Const.MAX_CANONS);
		var needAll = needC1 && needC2;
		if (!needC1 && !needC2)
			return;

		replaceCycle -= tmod;
		if (replaceCycle <= 0) {
			replaceCycle = KKApi.val(Const.CANON_REPLACE_CYCLE);

			if (needAll) {
				if (Seed.random(2) == 0) {
					addCanon(canons1);
					playStartAnim(canons1);
					addCanon(canons2, true);
					playStartAnim(canons2);
				} else {
					addCanon(canons2, true);
					playStartAnim(canons2);
					addCanon(canons1);
					playStartAnim(canons1);
				}
				return;
			}

			if (needC2) {
				addCanon(canons2, true);
				playStartAnim(canons2);
				return;
			}

			addCanon(canons1);
			playStartAnim(canons1);
		}
	}

	function addCanon(l:Array<Canon>, invert = false) {
		var idx:Null<Int> = 0;
		if (invert) {
			if (canon2 >= 0) {
				var old = l[canon2];
				// (port fix) the original freed l[canon2] after canon2 = -1 (a property "-1" of the array): the old
				// canon, cleaned, kept its slot. Once the side had 11 canons and such a slot, getFreeIndex found no slot,
				// the next canon went to l[null] (out of the array: never shown, never touched) and was counted: the
				// side lost its canons but not the game
				l[canon2] = null;
				canon2 = -1;
				idx = getFreeIndex(l);
				var c = new Canon(this, idx * Const.CANON_SPACE + Const.CANON_STARTPOS, invert, idx, old.shield);
				old.clean();
				l[idx] = c;
				return;
			}

			idx = getFreeIndex(l);
			// (port fix) no free slot: no new canon (see above)
			if (idx == null)
				return;
			canons2Count++;
		} else {
			if (canon1 >= 0) {
				var old = l[canon1];
				l[canon1] = null;
				canon1 = -1;
				idx = getFreeIndex(l);
				var c = new Canon(this, idx * Const.CANON_SPACE + Const.CANON_STARTPOS, invert, idx, old.shield);
				old.clean();
				l[idx] = c;
				return;
			}

			idx = getFreeIndex(l);
			// (port fix) no free slot: no new canon (see above)
			if (idx == null)
				return;
			canons1Count++;
		}

		var c = new Canon(this, idx * Const.CANON_SPACE + Const.CANON_STARTPOS, invert, idx);
		l[idx] = c;
	}

	function updateCanons(l:Array<Canon>) {
		if (gameOver)
			return;

		for (c in l) {
			// (null: calling a method of undefined does nothing in Flash)
			if (c != null)
				c.update();
		}
	}

	function fire(l:Array<Canon>, target:Canon) {
		if (target == null)
			return;

		for (c in l) {
			if (c == null)
				continue;
			if (!c.init)
				continue;
			if (c.destroyed)
				continue;
			c.initFire(target);
		}
	}

	function getTarget(l:Array<Canon>) {
		var a:Array<Canon> = new Array();
		for (c in l) {
			// (!c.init first in the original: undefined for a null canon, skipped too)
			if (c == null || !c.init)
				continue;
			if (c.destroyed)
				continue;
			a.push(c);
		}

		if (a.length <= 0)
			return null;

		var r = a[Seed.random(a.length)];
		return r;
	}

	function moveBalls(tmod:Float) {
		if (gameOver)
			return;

		// (for( b in balls ) while removing from it: the ball after a removed one is skipped until the next frame)
		var i = 0;
		while (i < balls.length) {
			var b = balls[i];
			i++;
			b.move(tmod);

			if (shipIn) {
				if (Const.hit(b.mc != null ? b.mc.bounds() : null, ship.smcBounds())) {
					#if debug
					stats.shipHits++;
					#end
					destroyShip();
					b.destroy(0);
					balls.remove(b);
				}
			}

			if (laser.hit(b)) {
				laser.hitAnim(b);

				var s = 0;

				if (b.bonus) {
					addScore(Const.BONUS_BALL);
					s = KKApi.val(Const.BONUS_BALL);
				} else {
					var ss = switch (b.type) {
						case 0: Const.BALL1;
						case 1: Const.BALL2;
						default: Const.BALL3;
					};
					addScore(ss);
					s = KKApi.val(ss);
				}
				#if debug
				stats.kills[b.bonus ? 3 : b.type]++;
				#end

				b.destroy(s);
				balls.remove(b);
				continue;
			}

			var bx = b.mc != null ? b.mc.x : Math.NaN;
			if (b.moveLeft && bx < Const.CANON_HIT_POS) {
				for (c in canons1) {
					if (c == null || !c.canBeTouched())
						continue;
					if (Const.hit(b.mc.bounds(), c.mc.bounds())) {
						touched(c, 0);
					}
				}
				continue;
			}

			if (!b.moveLeft && bx > Const.HEIGHT - Const.CANON_HIT_POS) {
				for (c in canons2) {
					if (c == null || !c.canBeTouched())
						continue;
					if (Const.hit(b.mc.bounds(), c.mc.bounds())) {
						touched(c, 1);
					}
				}
			}
		}
	}

	// a canon touched by a ball
	function touched(c:Canon, side:Int) {
		#if debug
		if (c.shield > 0)
			stats.shields++;
		else
			stats.canonsLost[side]++;
		#end
		c.destroy();
		c.removeMe();
		var a = new CanonOut(c);
		anim.push(a);
	}

	public function removeCanon(idx:Int, invert:Bool) {
		if (invert) {
			var c = canons2[idx];
			c.clean();
			c = null;
			canons2[idx] = c;
			canons2Count--;
			return;
		}

		var c = canons1[idx];
		c.clean();
		c = null;
		canons1[idx] = c;
		canons1Count--;
	}

	function testEnd() {
		if (canons1Count <= 0)
			gameOver = true;
		if (canons2Count <= 0)
			gameOver = true;
	}

	function destroyShip() {
		shipEnergy--;

		if (shipEnergy > 0) {
			// ColorTransform: rgb = 0xFFFFFF (offsets 255), multipliers 0.3: white
			ship.cx = [0.3, 0.3, 0.3, 255, 255, 255];
			return;
		}

		shipEnergy = 0;
		var p = new Phys(ship);
		p.timer = 10;

		// (the pieces are for the eye: the visual random. sleep reads the i of the inner loop)
		for (i in 0...10) {
			for (i in 0...30) {
				var m = game.dm.add(new Part("mcCarPart"), Const.DP_BALL);
				m._x = ship._x;
				m._y = ship._y + ship.height() / 2;
				m._rotation = Seed.randomVfx(360);
				var p = new Phys(m);
				p.vr = 1 + Seed.randomVfx(10);
				p.timer = 30;
				var rad = m._rotation * Math.PI / 180;
				p.vx = Math.cos(rad) * (if (Seed.randomVfx(2) == 0) 1 else -1);
				p.vy = Math.sin(rad) * (if (Seed.randomVfx(2) == 0) 1 else -1);
				p.sleep = if (i > 0) i * 2.0 else null;
				p.frict = 1.06;
				p.vsc = 1.05;
			}
		}

		gameOver = true;
	}

	// (the smoke is for the eye: the visual random)
	public function reactorFx(x:Float, y:Float) {
		var m = game.dm.add(new Part("mcSmoke"), Const.DP_BG);
		// (an attached clip plays: mcSmoke's 2 frames alternate)
		m.play();
		m._x = x;
		m._y = y;
		m._rotation = Seed.randomVfx(25) * if (Seed.randomVfx(2) == 0) -1 else 1;
		var rot = m._rotation;
		var p = new Phys(m);
		p.timer = 2 + Seed.randomVfx(25);
		var rad = rot * Math.PI / 180;
		p.vx = Math.sin(rad) * if (Seed.randomVfx(2) == 0) -Seed.randomVfx(100) / 100 else Seed.randomVfx(100) / 100;
		p.vy = Math.sin(rad) * -1;
		p.frict = 1.03;
		m.glow(Const.COLORS[0], 8);
	}

	// ---------------------------------------------------------------- port: score, game over
	function addScore(n:KKConst) {
		if (over)
			return;
		KadoKadeoManager.kkm.addScore(KKApi.val(n));
	}

	// KKApi.gameOver({})
	function endGame() {
		if (over)
			return;
		over = true;
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		var cs = [for (l in [canons1, canons2]) [for (c in l) c == null ? "." : c.destroyed ? "x" : c.shield < 0 ? "o" : Std.string(c.shield)].join("")];
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			balls: balls.length,
			speed: KKApi.val(Const.BALL_SPEED),
			fire: KKApi.val(Const.FIRE_CYCLE),
			learn: KKApi.val(Const.LEARN_STEP),
			canons: cs.join(" "),
			counts: canons1Count + "," + canons2Count,
			energy: shipEnergy,
			stats: haxe.Json.stringify(stats)
		};
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	// ---------------------------------------------------------------- port: display
	// The first use of a filter compiles its shader (tens of ms of freeze): every one is drawn once now, off screen
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		var g:FlashGlow = cast FlashFilters.take(FlashGlow);
		g.set(4, 1, 0xFFFFFF, 3);
		var b:FlashBoxBlur = cast FlashFilters.take(FlashBoxBlur);
		b.set(8, 1);
		var c:FlashCx = cast FlashFilters.take(FlashCx);
		c.set([0.3, 0.3, 0.3, 255, 255, 255]);
		s.filters = [g, b, c];
		holder.addChild(s);
		var rt:Dynamic = (cast RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		s.filters = null;
		FlashFilters.release(g);
		FlashFilters.release(b);
		FlashFilters.release(c);
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function stageRoot():ASprite {
		return root != null ? root.spr : null;
	}

	public function destroy():Void {
		if (flushListener != null) {
			var ticker:Dynamic = KadoKadeoManager.kkm.ticker;
			ticker.remove(flushListener);
			flushListener = null;
		}
		MC.clearAll();
		GlowLayer.clearAll();
		CanonMC.clearAll();
		FlashFilters.clear();
		Sprite.spriteList = [];
		Const.reset();
		Ball.reset();
		signalSent = false;
		if (game == this)
			game = null;
	}
}

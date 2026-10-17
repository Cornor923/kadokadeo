package mel;

import mel.Lib;
import mel.Gfx;
import mel.Entity;
import mel.Nmy;

enum CharState {
	SPAWN;

	WANDER_STAND;
	WANDER_RUN;

	JUMP;
	FALL;
	DOUBLE_JUMP;

	WALL_STICK;
	WALL_JUMP;

	KICK_JUMP;

	TEST;

	CROUCH;
	CROUCH_STUCK;
	FORCE_CROUCH;
	PAUSE;

	TOLERANT_FALL;
}

typedef FrameLabelExt = {
	frame:Int,
	name:String,
	prev:{name:String, frame:Int},
	next:{name:String, frame:Int},
	dur:Int,
	lastFrame:Int
};

// the target over an enemy Mel can kick (Quantizeur)
class TargetedShape extends MovementFX {
	public var nmy:Nmy;
	public var char:Char;

	public function new() {
		super();
		gotoAndStop("target");
	}

	public var game(get, null):Game;

	function get_game()
		return Game.me;

	public function init(c:Char, e:Nmy) {
		char = c;
		nmy = e;
		var lvl = game.level;
		lvl.dm.add(this, Level.CHAR_DEPTH);
		scaleX = scaleY = 3.5;
		game.tweenie.create(this, "scaleX", 1, TElasticEnd, 425);
		game.tweenie.create(this, "scaleY", 1, TElasticEnd, 425);
		e.nmyFlags.set(ACQUIRED);
		update();
		snap();
	}

	public function update() {
		var xy = nmy.getLogCenter();
		if (xy == null) {
			x = nmy.mc.x;
			y = nmy.mc.y;
		} else {
			x = Std.int(xy.x);
			y = Std.int(xy.y);
		}
	}

	public function destroy() {
		if (nmy != null)
			nmy.nmyFlags.unset(ACQUIRED);
		detach();
		game.char.targets.destroy(this);
		nmy = null;
		char = null;
	}
}

enum CharFlags {
	FOCUSED;
	STICK_2_JUMP;
}

// Char.hx of the original: Mel
class Char extends Entity {
	public var nmyKilled = 0;

	public var godMode = false;
	public var state:CharState;
	public var me:Hero;
	public var stateLife:Int;
	public var jumpEscaped = false;
	public var tasks:List<Void->Bool>; // true means remove me

	public var cl:CT;

	public var targets:Pool<TargetedShape>;
	public var kickData:{locked:Nmy, angle:Float, dist:Float};
	public var flagsExt:haxe.EnumFlags<CharFlags>;

	public var blinkTimer:Int = 0;
	public var crouchGauge:Float = 0.0;
	public var input = true;

	public var powers:haxe.EnumFlags<CharPowers>;
	public var shadowPow:Int = 0;

	// Mag Grips switched off by the player (key G): not in the original (Arkadeo players avoided picking them up)
	public var gripOff = false;

	var hits:Map<String, Rect>;

	static inline var MAX_JUMP_SPEED = -0.7;

	public function new() {
		super();
		mc = me = new Hero();
		powers = haxe.EnumFlags.ofInt(0);

		tasks = new List();
		targets = new Pool(() -> new TargetedShape());

		changeState(SPAWN);
		move(Lib.nbcw() >> 1, Lib.nbch() - 1);

		cl = new CT();
		me.colorTransform = cl;

		flagsExt = haxe.EnumFlags.ofInt(0);

		pv = 2;
		// league: Mel starts with the double jump
		powers.set(CP_DOUBLE_JUMP);

		// the _hit box of each label of gfx.Hero (written in the code of the original)
		hits = new Map();
		hits.set('stand', new Rect(-10, -60, 20, 59.8));
		hits.set('walk', new Rect(-2, -60, 20, 59.8));
		hits.set('jump', new Rect(-9, -52.9, 20, 48.9));
		hits.set('doubleJump', new Rect(-11.1, -26.4, 22.6, 23.7));
		hits.set('grip', new Rect(-21.05, -36.85, 22.1, 45));
		hits.set('crouch', new Rect(-9, -49.85, 20, 49.9));
	}

	static var mrect = new Rect();

	override public function getRect():Rect {
		var r = hits.get(me.currentLabel);
		mrect.x = r.x + me.x;
		mrect.y = r.y + me.y;
		mrect.width = r.width;
		mrect.height = r.height;
		return mrect;
	}

	var gr:FxGreyscale = null;

	override public function onDestroy() {
		game.pause = true;
		Mov.stopAllIn(game);
		changeState(PAUSE);
		gr = new FxGreyscale();
		gr.setStrengthBloom(0);
		FTimer.tick(function(r) {
			gr.setStrengthBloom(r);
			Game.me.filters = [gr.get()];
			if (r >= 0.99 && !game.level.gameOverCalled) {
				game.level.gameOverCalled = true;
				game.gameOver();
			}
		}, 40);
	}

	// Mel has the Mag Grips and they are on (the original only tested the power)
	public inline function hasGrip():Bool {
		return powers.has(CP_WALL_STICK) && !gripOff;
	}

	// key G: Mag Grips off / on, when Mel has them; off, Mel lets go of a wall and does as without them (the sides of
	// the platforms do not stop her, she does not hang on them); back on, she grips again from her next landing
	public function toggleGrip() {
		if (!powers.has(CP_WALL_STICK) || isDead() || game.level.gameOverCalled)
			return;
		gripOff = !gripOff;
		if (gripOff) {
			flags.unset(CAN_GRIP);
			if (state == WALL_STICK) {
				changeState(FALL);
			}
		} else if (state == WANDER_STAND || state == WANDER_RUN) {
			flags.set(CAN_GRIP);
		}
	}

	// char.mc.height (the bounds of the current picture of Mel: the height of the label, measured on its first frame)
	public function heightOfMc():Float {
		var h:Null<Float> = Reflect.field(Art.meta().heroHeight, me.currentLabel);
		return h == null ? 60 : h;
	}

	public function getMeter()
		return (-(cy + ry) + Lib.nbch()) / 3.0;

	public function getAbsCy()
		return (-(cy + ry) + Lib.nbch());

	function mkCl()
		me.colorTransform = cl;

	var pcxy = -1;

	public function update() {
		var l = lev();

		stateLife++;
		updateState();

		if (tasks.length > 0)
			for (t in tasks)
				if (t())
					tasks.remove(t);

		syncPos();

		if (cy * 255 + cx != pcxy)
			pcxy = cy * 255 + cx;

		if (blinkTimer > 0) {
			blinkTimer--;
			blinkFrame(blinkTimer);
			if (blinkTimer == 0) {
				cl.ofs();
				cl.mul();
				mkCl();
				blinkTimer = -1;
			}
		}

		if (shadowPow > 0)
			if (Game.getFrame() % 2 == 0) {
				var r = (state == DOUBLE_JUMP && stateLife > CANCEl_SL && powers.has(CP_CANCEL)) ? 0xFF1108 : 0xFFAA2A;
				if (!Game.isLowQuality())
					new FxShade2(me, 6, r);
			}
	}

	public var tolerance = 3;

	function blinkFrame(bt:Int) {
		var t = 7;
		switch (bt % t) {
			case 0, 1, 2:
				cl.ofs(222, 122, 0);
				cl.mul(0, 0, 0);
			case 3, 4:
				cl.ofs(255, 255, 255);
				cl.mul();
			case 5, 6:
				cl.ofs();
				cl.mul();
		}
		mkCl();
	}

	function blinkFrame2(bt:Int) {
		var t = 8;
		switch (bt % t) {
			case 0, 1, 2, 4, 5:
				cl.ofs();
				cl.mul();
			case 6:
				cl.ofs(255, 255, 255);
				cl.mul();
			case 7:
				cl.ofs(222, 122, 0);
				cl.mul(0, 0, 0);
		}
		mkCl();
	}

	var wasSpace = false;
	var isSpace = false;
	var onSpace = false;

	function setDir() {
		if (dx < -0.001)
			mc.scaleX = -1;
		else if (dx > 0.001)
			mc.scaleX = 1;
	}

	inline function goLeft() {
		return if (dx < -0.01) -1; else 1;
	}

	// mt.gx.MathEx.sameSign
	static inline function sameSign(f0:Float, f1:Float):Bool {
		return ((f0 < 0) && (f1 < 0)) || ((f0 > 0) && (f1 > 0));
	}

	function getPlayerDir():Float {
		var l = dx * dx + dy * dy;
		if (l == 0)
			return 0;
		else {
			l = Math.sqrt(l);
			return Math.atan2(dx / l, -dy / l);
		}
	}

	function updateKey() {
		if (isDead() || game.level.gameOverCalled)
			return;

		var lev = game.level;
		wasSpace = isSpace;
		isSpace = Game.isKeyDown(KeyboardManager.SPACE) || Game.isKeyDown(KeyboardManager.CONTROL) || Game.isKeyDown(KeyboardManager.UP);
		onSpace = isSpace && !wasSpace;

		switch (state) {
			case WALL_STICK:
				if (Game.isKeyDown(KeyboardManager.DOWN) && !flagsExt.has(STICK_2_JUMP) && stateLife >= 4) {
					flags.unset(CAN_GRIP);
					changeState(FALL);
					return;
				}

				if (onSpace && !flagsExt.has(STICK_2_JUMP)) {
					changeState(WALL_JUMP);
					return;
				}

				if (stateLife >= 10 && !flagsExt.has(STICK_2_JUMP)) {
					if (!lev.testColl(cx - 1, cy - 1) && lev.testColl(cx - 1, cy) && Game.isKeyDown(KeyboardManager.LEFT)) {
						cx = cx - 1;
						cy = cy - 1;
						rx = 0.75;
						ry = 1;
						var f = game.level.data.playFX("slash2");
						f.x = mc.x;
						f.y = mc.y;
						changeState(CROUCH_STUCK);
						f.scaleX = 1;
						me.scaleX = 1;
					}

					if (!lev.testColl(cx + 1, cy - 1) && lev.testColl(cx + 1, cy) && Game.isKeyDown(KeyboardManager.RIGHT)) {
						cx = cx + 1;
						cy = cy - 1;
						rx = 0;
						ry = 1;
						var f = game.level.data.playFX("slash2");
						f.x = mc.x;
						f.y = mc.y;
						changeState(CROUCH_STUCK);
						f.scaleX = -1;
						me.scaleX = -1;
					}
					return;
				}

			case TOLERANT_FALL:
				if (onSpace)
					changeState(JUMP);

			case WANDER_RUN, WANDER_STAND:
				fx = 0.65;
				var incr = 0.225;
				var s = 0.750;

				if (stateLife <= 2)
					incr *= 0.5;

				var odx = dx;

				if (Game.isKeyDown(KeyboardManager.LEFT))
					dx -= s * incr;
				else if (Game.isKeyDown(KeyboardManager.RIGHT))
					dx += s * incr;

				if (Math.abs(dx) > 0.01 && !sameSign(odx, dx)) {
					var m = game.level.data.playFX("runChange");
					m.x = me.x;
					m.y = me.y;
					m.scaleX = goLeft();
				}

				if (isSpace) {
					changeState(JUMP);
				} else {
					if (dx > s)
						dx = s;
					if (dx < -s)
						dx = -s;

					if (Math.abs(dx) > 0.01) {
						if (state != WANDER_RUN)
							changeState(WANDER_RUN);
					} else {
						if (Game.isKeyDown(KeyboardManager.DOWN) && powers.has(CP_SUPER_JUMP)) {
							dx *= 0.1;
							changeState(CROUCH);
						}
					}

					setDir();
				}

			case DOUBLE_JUMP:
				var jinc = 0.2;
				var dj = 0.5;
				if (Game.isKeyDown(KeyboardManager.LEFT)) {
					dx -= dj * jinc;
					if (dx < -dj)
						dx = -dj;
				} else if (Game.isKeyDown(KeyboardManager.RIGHT)) {
					dx += dj * jinc;
					if (dx > dj)
						dx = dj;
				}

			case FALL, JUMP:
				fx = 0.68;
				var jinc = 0.125;
				var sj = 0.525;

				if (Game.isKeyDown(KeyboardManager.LEFT)) {
					dx -= sj * jinc;
					if (dx < -sj)
						dx = -sj;
				} else if (Game.isKeyDown(KeyboardManager.RIGHT)) {
					dx += sj * jinc;
					if (dx > sj)
						dx = sj;
				}

				if (state == JUMP) {
					if (!isSpace && !jumpEscaped) {
						if (dy < 0)
							dy = Math.max(MAX_JUMP_SPEED * 0.5, dy);
						jumpEscaped = true;
					}

					if (onSpace && jumpEscaped && powers.has(CP_DOUBLE_JUMP)) {
						changeState(DOUBLE_JUMP);
						return;
					}
				} else if (onSpace && powers.has(CP_DOUBLE_JUMP)) {
					changeState(DOUBLE_JUMP);
					return;
				}

				if (Game.isKeyToggled(KeyboardManager.DOWN) && powers.has(CP_KICK)) {
					makeAcquisition();

					var acqs = targets.getUsed();

					var min:TargetedShape = null;
					for (a in acqs) {
						if (min == null)
							min = a;
						else {
							var dax = a.x - mc.x, day = a.y - mc.y;
							var dmx = min.x - mc.x, dmy = min.y - mc.y;
							if (dax * dax + day * day < dmx * dmx + dmy * dmy)
								min = a;
						}
					}

					var acq = min;
					if (acq != null) {
						var mrx = cx + rx;
						var mry = cy + ry;

						var lck = acq.nmy;

						acq.destroy();

						var lrx = lck.mc.x;
						var lry = lck.mc.y;

						// (sic: cells and pixels mixed)
						var a = Game.q(Math.atan2(mry - lrx, mrx - lry));
						var d = Math.sqrt((mrx - lrx) * (mrx - lrx) + (mry - lry) * (mry - lry));

						kickData = {locked: lck, angle: a, dist: d};
						changeState(KICK_JUMP);
					}
				}

			case CROUCH:
				// SUPER_JUMP
				if (onSpace) {
					var f = getCrouchFocus();
					changeState(JUMP);
					jumpEscaped = true; // cancel jump kill
					dy *= f;
					shadowPow++;
					FTimer.delay(function() shadowPow--, 10);
				} else if (!Game.isKeyDown(KeyboardManager.DOWN))
					changeState(WANDER_RUN);

			default:
		}
	}

	function focusMax() {
		if (!flagsExt.has(FOCUSED))
			me.filters = [Glow(Data.ORANGE, 0.9666, 3, 3, 10)];
		flagsExt.set(FOCUSED);
	}

	function defocus() {
		crouchGauge = 0;
		cl.rst();
		mkCl();
		me.filters = me.filters.filter(function(f) {
			return switch (f) {
				case Glow(_, a, _, _, _): Math.abs(a - 0.9666) >= 0.01;
				case _: true;
			}
		});
		flagsExt.unset(FOCUSED);
	}

	static inline var crMin = 0.6;
	static inline var crMax = 1.40;
	static inline var crD = 80;

	function getCrouchFocus():Float
		return crMin + (getCrouchRatio() * (crMax - crMin));

	public function onColl(e:Nmy):Bool {
		if (!e.aggro)
			return false;

		if (godMode)
			return false;

		switch (state) {
			// hurt self
			case KICK_JUMP:
				return false;

			case DOUBLE_JUMP:
				if (e.canBeKilled) {
					var r = e.hurt(1);
					changeState(JUMP);
					return r;
				} else if (e.instaKill) {
					if (e.type != NT_SWARM)
						hurt(1);
					else
						hurt(10);
					return false;
				} else
					return false;

			default:
				if (e.type != NT_SWARM)
					hurt(1);
				else
					hurt(10);
				return false;
		}
	}

	static inline var crouch_max = 40 * 1.5;

	public function getCrouchRatio():Float {
		var r = stateLife / crouch_max;
		return r < 0 ? 0 : (r > 1 ? 1 : r);
	}

	static inline var lock_dist = 10 * 10;

	var jumpSceneLabels:Map<String, FrameLabelExt>;

	function updateState() {
		switch (state) {
			case SPAWN:
				changeState(WANDER_STAND);
			case KICK_JUMP:
				if (kickData == null)
					return;

				var kd = kickData;
				var lck = kickData.locked;
				lck.stop = true;

				function ha() {
					var a = kd.angle;
					var pivot = -Math.PI / 2;
					var racc = 0.25;
					if (a > pivot)
						a = pivot + (a - pivot) * racc;
					else
						a = (pivot - a) * racc + a;
					return a;
				}
				switch (stateLife) {
					case 1: // disappear
						if (!Game.isLowQuality()) {
							var m = game.level.data.playFX("targetExplode");
							var c = lck.getLogCenter();
							m.x = c.x;
							m.y = c.y;
						}

						lck.pause = true;
						me.visible = false;
						me.gotoAndStop("jump");
						me.smc.gotoAndStop('init');

						dx = 0;
						dy = 0;

					case 6:
						dx = 0;
						dy = 0;
						me.visible = true;
						cx = lck.cx;
						cy = lck.cy;
						ry = lck.ry;
						rx = lck.rx;
						me.snap();

						if (!Game.isLowQuality()) {
							var m = game.level.data.playFX("teleport");
							var c = lck.getLogCenter();
							m.x = c.x;
							m.y = c.y;
							m.scaleX = -1;
							m.rotationZ = 57.29577951308232 * (kd.angle + Math.PI);
						}

						var a = ha();
						var tx = Game.q(Math.cos(a));
						var ty = Game.q(Math.sin(a));
						moveF(cx + rx + tx, cy + ry + ty);
						flags.unset(GRAVITY);
						flags.set(FLY);

						me.smc.gotoAndStop("sideKick");

					case 22:
						var a = ha();
						var fx = Game.q(Math.cos(a));

						var intensX = Math.min(Math.max(kd.dist * 0.55, 1.25), 2.5);
						var intensY = Math.min(Math.max(kd.dist * 0.33, 0.9), 1.1);

						dx = fx * 0.4 * intensX;

						lck.hurt(1);
						lck.pause = true;

						invincible = false;
						flags.unset(FLY);
						flags.set(GRAVITY);
						me.smc.gotoAndStop("init");
						changeState(JUMP);
						dy = MAX_JUMP_SPEED * 1.1 * intensY;
						jumpEscaped = true;
						kickData = null;
				}

			case TOLERANT_FALL:
				if (stateLife > tolerance)
					changeState(FALL);
			case CROUCH_STUCK:
				var smc = me.smc;
				if (smc.playing())
					smc.stop();
				smc.prevFrame();
				smc.prevFrame();

			default:
		}

		if (input)
			updateKey();
		updatePhy();

		switch (state) {
			case WANDER_RUN:
				if (Math.abs(dx) <= 0.015)
					changeState(WANDER_STAND);

			case FORCE_CROUCH, CROUCH:
				if (getCrouchRatio() >= 0.99) {
					crouchGauge = 0;
					cl.rst();
					mkCl();
					focusMax();
				} else {
					crouchGauge += getCrouchRatio() * 0.0125;
					var fr = Std.int(crouchGauge * crD);
					blinkFrame2(fr);
				}

			case JUMP:
				if (powers.has(CP_KICK))
					makeAcquisition();

				if (jumpSceneLabels == null) {
					jumpSceneLabels = new Map<String, FrameLabelExt>();
					var cl = me.smc.labels();
					for (i in 0...cl.length) {
						var l = cl[i];
						var prev = (i == 0) ? null : cl[i - 1];
						var next = (i == cl.length - 1) ? null : cl[i + 1];
						var dur = (next == null) ? (me.smc.totalFrames - 1) - l.frame : next.frame - l.frame;
						jumpSceneLabels.set(l.name, {
							frame: l.frame,
							name: l.name,
							prev: prev,
							next: next,
							dur: dur,
							lastFrame: l.frame + dur,
						});
					}
				}

				var smc = me.smc;
				var l = 0.1;
				switch (smc.currentLabel) {
					case "init":
						var elem = jumpSceneLabels.get("init");
						var n = elem.next;
						if (smc.currentFrame == n.frame - 1) {
							if (dx < -l)
								smc.gotoAndPlay("initLeft");
							else if (dx > l)
								smc.gotoAndPlay("initRight");
						}

					case "initLeft", "loopLeft":
						smc.stop();
						if (dx > -l)
							smc.prevFrame();
						else
							smc.nextFrame();

					case "loop":
						if (dx > -l && dx < l)
							smc.play();
						else {
							if (dx <= -l)
								smc.gotoAndPlay('initLeft');
							else if (dx >= l)
								smc.gotoAndPlay('initRight');
						}

					case "initRight", "loopRight":
						smc.stop();
						if (dx < l)
							smc.prevFrame();
						else
							smc.nextFrame();

						if (smc.currentFrame == jumpSceneLabels.get("initRight").frame - 1) {
							var lbl = jumpSceneLabels.get("loop");
							var tgt = lbl.frame + lbl.dur;
							while (smc.currentFrame != tgt)
								smc.prevFrame();
						}

					default:
				}
			default:
		}

		if (state != JUMP)
			cleanAcquisition();

		if (state == DOUBLE_JUMP)
			if (stateLife > CANCEl_SL)
				if (Game.isKeyDown(KeyboardManager.DOWN) && powers.has(CP_CANCEL)) {
					scheduleRestoreGrip();
					changeState(FALL);
				}
	}

	public static inline var CANCEl_SL = 24;

	function cleanAcquisition() {
		if (targets.nbUsed() > 0)
			for (t in Lambda.array(targets.getUsed()))
				t.destroy();
	}

	function makeAcquisition() {
		function getD(e:Nmy)
			return (cx - e.cx) * (cx - e.cx) + (cy - e.cy) * (cy - e.cy);

		function hasPath(e:Nmy) {
			return true;
		}

		function isValid(e:Nmy) {
			if (e.mc == null)
				return false;
			var sameSide = (dx < 0 && e.cx < cx) || (dx > 0 && e.cx > cx);
			return sameSide && e.canBeTarget && ((e.mc.y) >= (mc.y)) && getD(e) <= lock_dist && hasPath(e);
		}

		for (t in targets.getUsed())
			if (!isValid(t.nmy))
				t.destroy();
			else
				t.update();

		for (tl in game.level.nmyLists())
			for (e in tl)
				if (!e.nmyFlags.has(ACQUIRED) && isValid(e)) {
					var c = targets.create();
					c.init(this, e);
				}
	}

	override function onFall() {
		if (state == KICK_JUMP)
			return;
		if (state != WALL_STICK)
			changeState(TOLERANT_FALL);
	}

	override function onLand(dy:Float) {
		if (state == KICK_JUMP)
			return;

		switch (state) {
			case CROUCH_STUCK, WANDER_STAND, FORCE_CROUCH:

			default:
				if (dy > 0.74) {
					changeState(CROUCH_STUCK);
				} else {
					this.dx *= 0.25;
					setDir();
					changeState(WANDER_STAND);
				}
		}
	}

	function leaveState(s:CharState) {
		if (s == null)
			return;

		switch (s) {
			case FORCE_CROUCH, CROUCH:
				defocus();
			case KICK_JUMP:
				flags.unset(NO_COLLIDE);
				kickData = null;

			case WALL_STICK:
				oppy = 0;
				me.scaleX = 1;
				flags.unset(GRIPPED);
				flagsExt.unset(STICK_2_JUMP);
			case JUMP:

			case DOUBLE_JUMP:
				shadowPow--;
			default:
		}
	}

	function scheduleRestoreGrip() {
		if (hasGrip()) {
			var t = 5;
			tasks.add(function() {
				t--;
				if (t == 0) {
					if ((state == JUMP || state == FALL) && hasGrip())
						flags.set(CAN_GRIP);
					return true;
				}
				return false;
			});
		}
	}

	inline function lev()
		return game.level;

	public function changeState(ns:CharState) {
		leaveState(state);

		switch (ns) {
			case PAUSE:
				me.stop();
				me.smc.stop();
			case TEST:
				me.gotoAndStop("walk");

			case SPAWN:
				me.gotoAndStop("stand");

			case DOUBLE_JUMP:
				var acTrigBonus = 0.5;

				me.gotoAndStop("doubleJump");
				flags.set(GRAVITY);
				flags.unset(CAN_GRIP);

				dy = -0.45;

				if (Game.isKeyDown(KeyboardManager.LEFT))
					dx -= acTrigBonus;
				else if (Game.isKeyDown(KeyboardManager.RIGHT))
					dx += acTrigBonus;

				ry = 0.99;

				var m = game.level.data.playFX("doubleJump");
				m.x = me.x;
				m.y = me.y;
				m.rotation = getPlayerDir() * 57.29577951308232;
				shadowPow++;

			case WALL_JUMP:
				flags.unset(CAN_GRIP);
				scheduleRestoreGrip();

				if (game.level.testColl(cx - 1, cy))
					dx += 1.25;
				else
					dx -= 1.25;

				shadowPow++;
				FTimer.delay(function() {
					shadowPow--;
				}, 10);

				changeState(JUMP);

				dy *= 0.75;
				return;

			case KICK_JUMP:
				invincible = true;
				flags.set(NO_COLLIDE);
				flags.unset(GRAVITY);

				dx = 0;
				dy = 0;
				var m = game.level.data.playFX("teleportStart");
				m.x = me.x;
				m.y = me.y;

			case JUMP:
				me.gotoAndStop("jump");
				flags.set(GRAVITY);

				fx = 0.7;
				dy = -0.7;
				ry = 0.99;
				setDir();
				jumpEscaped = false;

			case TOLERANT_FALL, FALL:
				me.gotoAndStop("jump");
				flags.set(GRAVITY);

			case WANDER_RUN:
				me.gotoAndStop("walk");

				if (!lev().testColl(cx - 1, cy) && !lev().testColl(cx + 1, cy)) {
					if (Math.abs(dx) > 0.1) {
						var m = game.level.data.playFX("run");
						m.x = me.x;
						m.y = me.y;
						m.scaleX = goLeft();
					}
					setDir();
				}

			case WANDER_STAND:
				if (me.currentFrameLabel != "stand")
					me.gotoAndStop("stand");

				dy = 0;
				ry = 1;
				flags.unset(GRAVITY);
				if (hasGrip())
					flags.set(CAN_GRIP);

			case FORCE_CROUCH, CROUCH:
				me.gotoAndStop("crouch");

			case CROUCH_STUCK:
				me.gotoAndStop("crouch");
				me.smc.gotoAndStop(me.smc.totalFrames);
				me.smc.stop();
				dx = 0;
				dy = 0;

				FTimer.delay(function() {
					changeState(WANDER_STAND);
				}, Std.int(me.smc.totalFrames / 2));

			case WALL_STICK:
				me.gotoAndStop("grip");
				flags.unset(GRAVITY);
				flags.set(GRIPPED);
				dx = 0;
				dy = 0;
				oppy = Entity.grav;

				var t = 100;
				tasks.add(function() {
					if (state != WALL_STICK)
						return true;
					t--;
					if (t <= 0) {
						flags.unset(CAN_GRIP);
						changeState(FALL);
						return true;
					}
					return false;
				});
		}
		stateLife = 0;
		state = ns;
	}

	override function onWallGrip(x:Int, y:Int) {
		if (hasGrip())
			if (state == FALL || state == JUMP) {
				if (cx > x) {
					me.scaleX = -1;
					rx = 0;
				} else {
					rx = 1;
					me.scaleX = 1;
				}
				ry = 0.99;
				changeState(WALL_STICK);
			}
	}

	override public function hurt(v:Float):Bool {
		if (godMode)
			return false;

		if (Level.NO_KILL)
			return false;

		var b = super.hurt(v);
		if (b == false) {
			godMode = true;

			game.addChild(game.level.data.bmpHit);
			FTimer.tick(function(r) {
				var rr = 1.0 - (r * r);
				game.level.data.bmpHit.alpha = rr;
				cl.alphaMultiplier = Game.q(Math.sin(Game.getFrame() * 0.75));
				if (r >= 1.0) {
					cl.alphaMultiplier = 1.0;
					godMode = false;
					game.filters = [];
					game.level.data.bmpHit.detach();
				}
				me.colorTransform = cl;
			}, 80);
			game.ui.bar._blink.play();
		}
		return b;
	}
}

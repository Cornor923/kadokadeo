package judocommando;

class Human extends Ent {
	public var flCrouch:Bool;
	public var flJumpUp:Bool;

	var anim:String;

	public var state:Null<State>;

	var climbDir:Int;
	var climbSpeed:Float;
	var coef:Float;

	// (set to null by Mon.freedom: NaN here, like Flash reads null in a calculation or a comparison)
	public var knockOutTimer:Float;
	public var life:Float;

	// SCRIPT
	var flAutoTurn:Bool;
	var script:Array<Command>;
	var scriptWalk:Null<Float>;
	var scriptTimer:Float;

	public function new(mc:MC) {
		super(mc);
		climbSpeed = 0.1;
		knockOutTimer = 0;
	}

	override function update() {
		root.setPercentColor(0, 0xFF0000);
		switch (state) {
			case Script:
				updateScript();
			case Ladder:
				updateLadder();
			case KnockOut:
				updateKnockOut();
			case Fall:
				updateFall();
			case Fly:
				updateFly();
			case null:
			default:
		}

		super.update();
	}

	// WALKING ENGINE
	// (a callback left null is a call that does nothing in Flash)
	function walk(ws:Float, ?walkInEmptyGround:Void->Void, ?walkToEmptyGround:Void->Void, ?walkInWall:Void->Void) {
		if (walkInEmptyGround == null)
			walkInEmptyGround = fall;

		var sens = Std.int(ws / Math.abs(ws));

		var next = Game.me.getSq(px + sens, py);
		var curGround = Game.me.getSq(px, py + 1);
		var nextGround = Game.me.getSq(px + sens, py + 1);

		ox += ws;

		var odx = Math.abs(ox + 0.5 * sens - 0.5);
		if (odx > 0.5) {
			if (next.type == BLOCK || (state == Hang && next.type == EMPTY)) {
				ox = 0.5;
				if (walkInWall != null)
					walkInWall();
			} else if (nextGround.type == EMPTY) {
				if (walkToEmptyGround != null)
					walkToEmptyGround();
			}
		}
		if (odx > 0.25) {
			if (curGround.type == EMPTY) {
				walkInEmptyGround();
			}
		}

		if (ox >= 1)
			swapSquare(0);
		if (ox < 0)
			swapSquare(2);

		if (ox >= 1 || ox < 0)
			ox = 0.5;
	}

	function fall() {
		interrupt();
		jump();
		vy = 0;
	}

	// PHYS
	override function onCollision(sx:Int, sy:Int) {
		super.onCollision(sx, sy);
		switch (state) {
			case KnockOut:
				if (sx != 0 || sy == -1)
					Game.me.fxBrickDust(sq, sx, sy);
			case null:
			default:
		}
	}

	function updateFall() {
		var y = Cs.getY(py + oy);
		var lim = Game.me.gry;
		var x = Cs.getX(px + ox);
		var bd = 42;

		vx *= 0.95;

		if (x < -bd || x > Cs.mcw + bd)
			lim += 4;
		if (y > lim) {
			state = null;
			stopPhys();
			root._y = lim - Cs.CS * 0.5;
			// display: the fall of the last frame ended below the ground, the crash is drawn from its place at once (the
			// camera does not move, held at gry - 50)
			root.teleport();
			updatePos = function() {};
			playAnim("crash");
			life = 0;
			Game.me.updateLifeBar();
			Game.me.initGameOver();
			for (i in 0...3) {
				var mc = fxBleed();
				mc._y = root._y + Cs.CS * 0.6;
			}
		}
	}

	// ANIM
	public function playAnim(str:String) {
		anim = str;
		root.gotoAndStop(str);
	}

	function nextFrame() {
		var smc = root.sub("smc");
		if (smc == null)
			return;
		if (smc.frame == smc.def.n)
			smc.gotoAndStop(1);
		else
			smc.stepFrame();
	}

	// LADDER
	function grabLadder(dir = 0) {
		state = Ladder;
		playAnim("ladder");
		var s = root.sub2("smc", "smc");
		if (s != null)
			s.stop();
		climbDir = dir;
	}

	function updateLadder() {
		var dx = 0.5 - ox;
		ox += dx * 0.5;

		if (climbDir != 0)
			nextFrame();

		oy += climbDir * climbSpeed;
		var next = Game.me.getSq(px, py + climbDir);

		var ody = Math.abs(oy + 0.5 * climbDir - 0.5);
		if (ody > 0.5) {
			if (!next.ladder) {
				if (climbDir == 1) {
					if (Game.me.isGround(next.type)) {
						oy = 0.5;
						backToNormal();
					} else {
						fall();
					}
				}
			}
		}
		if (ody > 0.25) {
			if (!sq.ladder) {
				oy = 0.5;
				playAnim("crouch");
				var smc = root.sub("smc");
				if (smc != null)
					smc.gotoAndStop(4);
				scr(backToNormal, 6);
			}
		}

		if (oy >= 1)
			swapSquare(1);
		if (oy < 0)
			swapSquare(3);
	}

	// KNOCKOUT
	public function knockOut(vx:Float, vy:Float, ?dam:Null<Int>, ?fr:Null<Int>) {
		interrupt();

		var sx = Std.int(vx / Math.abs(vx));
		if (vx == 0)
			sx = 1;
		setSens(sx);

		state = KnockOut;
		playAnim("knockOut");
		initPhys();
		this.vx = vx;
		this.vy = vy;
		weight = 0.25;
		if (dam != null)
			damage(dam);
	}

	function updateKnockOut() {}

	// DAMAGE
	public function damage(n:Float) {
		life -= n;
		root.setPercentColor(100, 0xFF0000);
		if (state == KnockOut || state == Crash) {
			knockOutTimer = 30;
		}
	}

	// JUMP
	public function jump() {
		flJumpUp = true;
		state = Fly;
		initPhys();
		weight = 0.6;
		playAnim("jump");
	}

	function updateFly() {
		if (flJumpUp && vy > -0.5) {
			flJumpUp = false;
			if (anim == "jump")
				playAnim("jumpDown");
		}
	}

	// FX
	public function fxBleed():MC {
		var mc = Game.me.fxAttach("mcBlood", root._x + (Seed.randVfx() * 2 - 1) * 3, root._y + (Seed.randVfx() * 2 - 1) * 5);
		mc._rotation = Seed.randomVfx(4) * 90;
		return mc;
	}

	// SCRIPT
	public function scr(f:Void->Void, n:Float) {
		state = Script;
		if (script == null) {
			script = [];
			scriptTimer = 0;
		}

		var t = n;
		if (script.length > 0)
			t += script[script.length - 1].t;
		script.push({f: f, t: t});
	}

	public function updateScript() {
		scriptTimer += mt.Timer.tmod;
		// (a script whose last action left the state on Script, the gorilla's game over: script is null, Flash reads
		// null[0] as undefined and does nothing)
		var action = script != null ? script[0] : null;
		var to = 0;
		while (action != null && scriptTimer > action.t) {
			action.f();
			// (an action can end the script: interrupt() sets script to null, Flash reads null.shift() as nothing)
			if (script == null)
				break;
			script.shift();
			if (script.length == 0) {
				script = null;
				scriptWalk = null;
				break;
			} else {
				action = script[0];
			}
			if (to++ > 100)
				break;
		}
		if (scriptWalk != null)
			walk(scriptWalk);

		if (flAutoTurn && Game.me.hero != null && sens != getSens(Game.me.hero))
			setSens(-sens);
	}

	public function interrupt() {
		state = null;
		script = null;
		flCrouch = false;
	}

	public function gotoState(st:State) {
		state = st;
	}

	public function backToNormal() {}

	// IS
	public function isTouchingGround():Bool {
		switch (state) {
			case Crash, Wheel, KneeGrabbed, Ground, Stand, Grapple, Crouch:
				return true;
			case Script:
				return false;
			case Held:
				return false;
			case null:
				return false;
			default:
				return false;
		}
	}
}

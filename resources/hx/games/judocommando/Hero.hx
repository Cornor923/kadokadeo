package judocommando;

class Hero extends Human {
	public var flEndLevelOk:Bool;
	public var flSkipNextGGrab:Bool;

	var left:Bool;
	var right:Bool;
	var up:Bool;
	var down:Bool;
	var fire:Bool;
	var lockUp:Bool;
	var lockRight:Bool;
	var lockDown:Bool;
	var lockLeft:Bool;
	var lockFire:Bool;
	var walkSpeed:Float;
	var runSpeed:Float;

	var crouchTimer:Int;
	var jumpBoostTimer:Int;

	var holdSens:Int;

	public var hold:Mon;
	public var holdStyle:Null<HoldMode>;

	public function new() {
		var mc = Game.me.dm.attach("mcHero", Game.DP_ENT);
		mc.stop();
		super(mc);
		type = HERO;

		flSkipNextGGrab = false;

		runSpeed = 0.2;
		walkSpeed = 0.04;

		life = 10;

		Game.me.focus = this;

		state = Stand;
	}

	override function update() {
		control();
		switch (state) {
			case Ground:
				updateGround();
			case Stand:
				updateStand();
			case Crouch:
				updateCrouch();
			case Grapple:
				updateGrapple();
			case KneeGrab:
				updateKneeGrab();
			case AirDrop:
				updateAirDrop();
			case Hang:
				updateHang();
			case null:
			default:
		}

		super.update();
		if (hold != null && holdStyle != GRAPPLE && holdStyle != KNEE) {
			hold.copyPos(this);
			hold.setSens(sens * holdSens);

			// root.smc.hold: the marker of the animation, where the held body goes
			var smc = root.sub("smc");
			var hd = smc != null ? smc.marker("hold") : null;
			if (hd != null) {
				hold.root._x += hd[0] * sens;
				hold.root._y += hd[1];
				hold.root._rotation = hd[2] * sens;
			}
			// (the hero put somewhere else at once: the body he holds goes with him)
			if (root.cut)
				hold.root.teleport();
		}

		// BONUS
		var a = getNears(8, BONUS);
		for (e in a) {
			var p:PowerUp = cast e;
			p.activate();
		}

		// END SPARK
		if (flEndLevelOk)
			fxSpark();

		// SECURITY
		if (hold != null) {
			var flBreak = !hold.root._visible;
			if (hold.state != Held && hold.state != KneeGrabbed && hold.state != Script && hold.state != null)
				flBreak = true;
			if (flBreak) {
				switch (holdStyle) {
					case KNEE:
						jump();
						vy = 0;
					case null:
					default:
				}

				interrupt();
				backToNormal();
			}
		}
	}

	function control() {
		left = KeyboardManager.isDown(KeyboardManager.LEFT);
		right = KeyboardManager.isDown(KeyboardManager.RIGHT);
		up = KeyboardManager.isDown(KeyboardManager.UP);
		down = KeyboardManager.isDown(KeyboardManager.DOWN);
		fire = KeyboardManager.isDown(KeyboardManager.SPACE);

		if (lockUp) {
			if (!up)
				lockUp = false;
			up = false;
		}
		if (lockDown) {
			if (!down)
				lockDown = false;
			down = false;
		}
		if (lockLeft) {
			if (!left)
				lockLeft = false;
			left = false;
		}
		if (lockRight) {
			if (!right)
				lockRight = false;
			right = false;
		}
		if (lockFire) {
			if (!fire)
				lockFire = false;
			fire = false;
		}
	}

	function lockAll() {
		lockUp = true;
		lockDown = true;
		lockLeft = true;
		lockRight = true;
	}

	// STAND
	public function initStand() {
		state = Stand;
		flCrouch = false;
	}

	function updateStand() {
		// RUN
		var runAmmount = 0;
		if (left)
			runAmmount = -1;
		else if (right)
			runAmmount = 1;
		if (runAmmount != 0) {
			run(runAmmount);
		} else if (anim == "run" || anim == "walk" || anim == "hold" || anim == "walk_lift") {
			backToStand();
		}

		// SECURITY BREAK
		if (state != Stand)
			return;

		// JUMP / CROUCH / LADDER
		if (hold == null) {
			if (fire) {
				if (flEndLevelOk) {
					endJump();
				} else {
					lockFire = true;
					jump();
				}
			} else if (up) {
				if (sq.ladder) {
					grabLadder();
				}
			} else if (down) {
				crouch();
			} else {
				var a = getNears(7, MONSTER);
				for (mon in a) {
					if (mon.isGrappable())
						grapple(mon);
					return;
				}
			}
		} else {
			if (holdStyle == LIFT) {
				if (down && !lockDown)
					throwBackward();
				else if (fire || lockFire)
					hitBody();
				else if (up && !lockUp)
					chandelle();
			} else {
				if (up)
					liftBody();
				else if (down)
					dropBody();
				else if (fire)
					throwBody();
			}
		}
	}

	function run(n:Int) {
		setSens(n);
		var inc = runSpeed;
		if (hold != null) {
			playAnim(holdStyle == LIFT ? "walk_lift" : "hold");
			inc = walkSpeed;
		} else {
			playAnim("run");
		}
		walk(inc * sens);
	}

	override function jump() {
		super.jump();
		vy = -3;
		jumpBoostTimer = 4;
		lockUp = true;
	}

	function jumpDown() {
		jump();
		vy = -0.5;
		missLine = py + 1;
	}

	// FLY
	override function updateFly() {
		super.updateFly();

		// BOOST
		if (jumpBoostTimer-- > 0 && lockFire) {
			vy -= 1.1;
		}

		// DECALAGE
		var flySpeed = 3;
		if (left)
			vx = -flySpeed;
		else if (right)
			vx = flySpeed;
		else
			vx *= 0.5;

		if (vx != 0)
			setSens();

		// LADDER
		if (up && sq.ladder) {
			lockFire = true;
			stopPhys();
			grabLadder();
			return;
		}

		// AIR/KNEE GRAB
		var a = getNears(12, MONSTER);
		for (mon in a) {
			if (mon.life > 0) {
				switch (mon.state) {
					case KnockOut:
						if (jumpBoostTimer < 3)
							airGrab(mon);
						return;

					case Normal, Script:
						if (mon.py > py && vy > 0 && mon.isGrappable()) {
							kneeGrab(mon);
							return;
						}

					case null:
					default:
				}
			}
		}

		// CLIMB
		var csx = 0;
		if (left)
			csx = -1;
		if (right)
			csx = 1;
		if (ox == 0.5 && oy < 0.5 && csx != 0 && vy > 0) {
			var nsq = Game.me.getSq(px + csx, py);
			var above = Game.me.getSq(px + csx, py - 1);
			if (nsq.type == BLOCK && above.type == EMPTY) {
				climb(csx);
			}
		}

		// HANG
		if (!down && oy < 0.5 && vy > 0 && Game.me.isHangable(px, py)) {
			hangOn();
		}

		// FATAL FALL
		if (py > Cs.YMAX) {
			state = Fall;
			Game.me.initFall();
		}
	}

	override function land() {
		playAnim("land");
		stopPhys();
		initStand();

		if (life <= 0) {
			state = Crash;
			playAnim("crash");
			Game.me.initGameOver();
			return;
		}

		if (hold != null) {
			hold.mtag(PILEDRIVER);
			hold.flSafe = true;
			hold.oy = 0.8;
			releaseBody(sens, -2.5, Cs.DAMAGE_PILEDRIVER);
			scr(backToNormal, 14);
			playAnim("heavyLand");

			blast(Cs.CS, Cs.DAMAGE_PILEDRIVER_SIDE);

			var gr = Game.me.getSq(px, py + 1);
			if (gr.type == BLOCK)
				Game.me.fxBrickDust(gr, 0, -1);
			Game.me.fxShake(gr.type == BLOCK ? 40 : 20);
		}
	}

	override function updateKnockOut() {
		super.updateKnockOut();
		// FATAL FALL
		if (py > Cs.YMAX) {
			state = Fall;
			Game.me.initFall();
		}
	}

	override function confirmCol(sx:Int, sy:Int):Bool {
		var sq = Game.me.getSq(px + sx, py + sy);
		if (sq.type == PLAT && state == AirDrop && Seed.random(3) == 0) {
			Game.me.explodeSquare(px + sx, py + sy);
			vy *= 0.33;
			hold.damage(1);
			return false;
		}

		return true;
	}

	// HANG ON
	function hangOn() {
		lockUp = true;
		stopPhys();
		state = Hang;
		playAnim("hangOn");
		var smc = root.sub("smc");
		if (smc != null)
			smc.stop();
		oy = 0.5;
	}

	function updateHang() {
		if (down) {
			jump();
			vy = 0;
		} else if (up && !lockUp) {
			oy -= 1;
			swapSquare(3);
			updatePos();
			teleport();
			playAnim("hangClimb");
			scr(backToNormal, 14);
		} else {
			var inc = 0;
			if (left)
				inc = -1;
			else if (right)
				inc = 1;

			if (inc != 0) {
				nextFrame();
				walk(inc * 0.025, function() {}, null);
			}
		}
	}

	// AIRDROP
	function airGrab(mon:Mon) {
		vx = 0;
		if (hold != null) {
			// (the original traces "double hold" in its test build and paints the first body green)
			hold.root.setColor(0x00FF00);
		}
		hold = mon;
		holdBody();
		playAnim("airGrab");
		state = AirDrop;
		vy -= 1;
	}

	function updateAirDrop() {}

	// CROUCH
	function crouch() {
		flCrouch = true;
		state = Crouch;
		playAnim("crouch");
		crouchTimer = 0;
	}

	function updateCrouch() {
		if (!down) {
			flCrouch = false;

			// HOLD
			if (flSkipNextGGrab)
				flSkipNextGGrab = false;
			else {
				var mon = getNearGroundBody();
				if (mon != null) {
					hold = mon;
					holdBody(-mon.sens);
					playAnim("holdBody");
					scr(backToNormal, 4);
					return;
				}
			}

			// STAND
			playAnim("stand");
			initStand();
			return;
		}
		if (fire) {
			// ARM LOCK
			var mon = getNearGroundBody();
			if (mon != null) {
				var ax = (mon.root._x - mon.sens * 6) - sens * 2;
				setPos(ax, root._y);
				teleport();
				mon.knockOutTimer = 80;
				mon.mtag(ARMLOCK);
				playAnim("armLock");
				mon.playAnim("crashCustom");
				scr(mon.groundDamage.bind(2), 11);
				scr(Game.me.fxShake.bind(15), 0);
				scr(Game.me.fxFlash.bind(1), 0);
				scr(mon.playAnim.bind("groundHitCustom"), 0);
				scr(backToNormal, 16);
				// (cast root)._afr: the monster shown in the arm lock (frame scripts of the animation)
				root.clip.setVar("afr", Type.enumIndex(mon.mtype) + 1);
				return;
			}

			// JUMP DONW PLAT
			var ground = Game.me.getSq(px, py + 1);
			switch (ground.type) {
				case PLAT:
					jumpDown();
					return;
				default:
			}
		}

		crouchTimer++;
		if (crouchTimer > 4 && down && Game.me.getSq(px, py + 1).ladder) {
			lockFire = true;
			swapSquare(1);
			oy = 0;
			grabLadder();
		}
	}

	function getNearGroundBody():Mon {
		var a = getNears(Cs.CS * 0.5, MONSTER);
		for (e in a) {
			var mon:Mon = cast e;
			if (mon.state == Crash && mon.life > 0)
				return mon;
		}
		return null;
	}

	// CLIMB
	function climb(sx:Int) {
		stopPhys();
		setSens(sx);
		swapSquare(sx, -1);
		playAnim("climb");
		scr(backToNormal, 20);
		ox = 0.5 - sens * 0.4;
		oy = 0.5;
		updatePos();
		teleport();
	}

	// GROUND
	function initGround() {
		state = Ground;
		playAnim("ground");
	}

	function updateGround() {}

	// HIT
	public function hit(sens:Int, damage:Int) {
		fxBleed();
		knockOut(2 * sens, -1, damage);
	}

	public function incLife(n:Int) {
		life += n;
		if (life > 10)
			life = 10;
		Game.me.updateLifeBar();
	}

	// LADDER
	override function updateLadder() {
		climbDir = 0;
		if (up || lockUp)
			climbDir = -1;
		if (down)
			climbDir = 1;

		if (Game.me.isFree(px, py) && fire) {
			jump();
			vy = -1;
		}

		// CHECK MONSTERS
		var a = getNears(Cs.CS * 0.5, MONSTER);
		for (e in a) {
			var mon:Mon = cast e;
			if (mon.state == Ladder) {
				var sens = Seed.random(2) * 2 - 1;
				mon.knockOut(sens * 1.5, -1);
			}
		}

		super.updateLadder();
	}

	// GRAPPLING
	function grapple(mon:Mon) {
		if (hold != null)
			hold.root.setColor(0x00FF00);

		if (mon.state == KnockOut) {
			if (mon.vy > 0) {
				hold = mon;
				holdBody();
				playAnim("holdBody");
				scr(backToNormal, 4);
			}
			return;
		}
		hold = mon;

		state = Grapple;

		playAnim("grapple");

		var dx = (mon.px + mon.ox) - (px + ox);
		var sx = Std.int(dx / Math.abs(dx));
		if (dx == 0)
			sx = 1;

		setSens(sx);

		var rdx = Math.abs(dx) - 0.4;
		ox += rdx * 0.5 * sens;
		mon.ox -= rdx * 0.5 * sens;

		mon.grappled();

		holdStyle = GRAPPLE;

		lockAll();
	}

	function updateGrapple() {
		if (up && !lockUp) {
			scoreTec();
			playAnim("tomoeNage");
			scr(releaseBody.bind(-sens, -6, Cs.DAMAGE_TOMOENAGE, null), 4);
			scr(rollBack, 10);
			hold.fkoTimer = 8;
			hold.mtag(TOMOENAGE);

			return;
		} else if (down && !lockDown) {
			lockDown = true;
			holdBody(-1);
			playAnim("kataGuruma");
			scr(backToNormal, 8);
			scriptWalk = 0.02 * sens;
			return;
		}

		var tec = 0;
		if (left && !lockLeft)
			tec = sens;
		if (right && !lockRight)
			tec = -sens;

		if (tec == 1) {
			scoreTec();
			playAnim("ipponSeoi");
			hold.fkoTimer = 8;
			scr(releaseBody.bind(-sens * 4, -2, Cs.DAMAGE_IPPONSEOI, null), 4);
			scr(backToNormal, 15);
			hold.mtag(IPPONSEOI);
		} else if (tec == -1) {
			scoreTec();
			playAnim("osotogari");
			scriptWalk = 0.016 * sens;
			scr(releaseBody.bind(sens * 2, 0, Cs.DAMAGE_OSOTOGARI, 7), 6);
			scr(backToNormal, 9);
			hold.mtag(OSOTOGARI);
		}
	}

	// HOLD
	function holdBody(sens = 1) {
		holdStyle = SHOULDER;
		holdSens = sens;
		hold.held();
	}

	public function releaseBody(?vvx:Null<Float>, ?vvy:Null<Float>, ?dam:Null<Int>, ?fr:Null<Int>) {
		hold.root._rotation = 0;
		if (vvx != null) {
			hold.knockOut(vvx, vvy, dam, fr);
			hold.knockOutTimer = 20;
		} else {
			hold.interrupt();
			hold.backToNormal();
		}
		hold = null;
		holdStyle = null;
	}

	function throwBody() {
		lockFire = true;
		scoreTec();
		hold.fkoTimer = 4;
		scr(releaseBody.bind(sens * 5, -2, Cs.DAMAGE_KATAGURUMA, null), 4);
		scr(backToNormal, 4);
		playAnim("throwBody");
		hold.mtag(KATAGURUMA);
	}

	function liftBody() {
		holdSens = 1;
		playAnim("lift");
		scr(hold.playAnim.bind("lifted"), 7);
		scr(backToNormal, 5);
		holdStyle = LIFT;
	}

	function dropBody() {
		flSkipNextGGrab = true;
		hold.setSens(-sens);
		releaseBody(0, 0);
		backToNormal();
	}

	// LIFT
	function hitBody() {
		lockFire = true;
		if (hold.life <= Cs.DAMAGE_LIFT_KICK) {
			hold.damage(Cs.DAMAGE_LIFT_KICK);
			throwBackward();
			return;
		}
		playAnim("hitBody");
		hold.playAnim("walk");
		hold.playAnim("lifted");
		hold.damage(Cs.DAMAGE_LIFT_KICK);
		Game.me.fxScore(root._x + sens * 7, root._y - 17, Cs.SCORE_HIT);
		hold.mtag(STROKE);

		scr(backToNormal, 6);
	}

	function throwBackward() {
		playAnim("throwBackward");
		releaseBody(-sens * 3, -0.5);
		scr(backToNormal, 8);
	}

	function chandelle() {
		hold.playAnim("knockOut");
		playAnim("throwUpward");
		scr(releaseBody.bind(sens * 2.3, -5, Cs.DAMAGE_CHANDELLE, null), 4);
		scr(backToNormal, 8);
	}

	public function bodyShieldImpact(dam:Int) {
		hold.playAnim("walk");
		hold.playAnim("lifted");
		hold.damage(dam);
		if (hold.life <= 0)
			bodyShieldDrop();
	}

	public function bodyShieldDrop() {
		hold.fxBleed();
		hold.flSafe = true;
		releaseBody(-sens * 2, -1.5, Cs.DAMAGE_PUNCH);
		backToNormal();
	}

	// KNEE
	function kneeGrab(mon:Mon) {
		if (hold != null)
			hold.root.setColor(0x00FF00);

		oy = 1 / Cs.CS;
		teleport();
		hold = mon;
		holdStyle = KNEE;
		stopPhys();
		playAnim("kneeGrab");
		state = KneeGrab;

		mon.kneeGrabbed();
	}

	function updateKneeGrab() {
		// FIST
		if (fire) {
			if (hold.life <= Cs.DAMAGE_FIST_HEAD) {
				releaseBody(0, 0, Cs.DAMAGE_FIST_HEAD);
				jump();
				vy = -1;
				return;
			}
			playAnim("kneeGrab");
			playAnim("hitHead");

			scr(hold.damage.bind(Cs.DAMAGE_FIST_HEAD), 4);
			scr(Game.me.fxScore.bind(root._x, root._y - 14, Cs.SCORE_HIT), 0);
			scr(gotoState.bind(KneeGrab), 3);
			hold.mtag(STROKE);

			return;
		}

		// BUMP JUMP
		if (up && !lockUp) {
			releaseBody();
			jump();
			vy += 1;
			return;
		}

		// HEAD CRUSHER
		if (down && !lockDown) {
			var nsq = Game.me.getSq(hold.px + sens, hold.py);
			var nsqg = Game.me.getSq(hold.px + sens, hold.py + 1);
			if (nsq.type == BLOCK || nsqg.type == EMPTY)
				return;

			oy = 0.5;
			teleport();

			hold.state = null;
			hold.setSens(sens);
			playAnim("headCrush");

			scr(hold.playAnim.bind("grappling"), 3);
			scr(releaseBody.bind(sens * 4, -2, Cs.DAMAGE_HEAD_CRUSHER, null), 7);
			scr(crushMove.bind(px + sens, py), 12);
			scr(setOffset.bind(ox, oy), 0);
			scr(backToNormal, 0);
			hold.mtag(HEADCRUSHER);
			return;
		}
	}

	// end of the head crusher: on the square of the monster, where the animation ends
	function crushMove(x:Int, y:Int) {
		moveTo(x, y);
		teleport();
	}

	// DAMAGE
	override function damage(n:Float) {
		super.damage(n);
		Game.me.updateLifeBar();
	}

	// FATALITY
	public function fatalityGrabbed(e:Ent) {
		Game.me.focus = e;
		Game.me.cutCamera();
		interrupt();
		stopPhys();
		kill();
	}

	// SCRIPT
	override function interrupt() {
		super.interrupt();
		var h = hold;
		if (hold != null) {
			hold.fkoTimer = Math.NaN;
			switch (holdStyle) {
				case GRAPPLE, KNEE:
					releaseBody();
				case SHOULDER, LIFT:
					releaseBody(0, 0);
					h.flSafe = true;
				case null:
					// ("HoldStyle unknown !")
			}
		}
	}

	function rollBack() {
		playAnim("groundRoll");
		scriptWalk = -sens * 0.02;
		scr(backToNormal, 6);
	}

	override function backToNormal() {
		super.backToNormal();
		initStand();
		backToStand();
	}

	// ANIM
	function backToStand() {
		var fr = "stand";
		if (holdStyle == LIFT)
			fr = "stand_lift";
		if (holdStyle == SHOULDER)
			fr = "standQuiet";
		playAnim(fr);
	}

	// FX
	public function endJump() {
		setSens(1);
		flEndLevelOk = false;
		Game.me.endLevel();

		var max = 16;
		var cr = 4;
		for (i in 0...max) {
			var a = i / max * 6.28;
			var speed = 2 + i % 2;
			var ca = Math.cos(a) * speed;
			var sa = Math.sin(a) * speed;
			var p = new Phys(Game.me.dm.attach("fxSpark2", Game.DP_FX));
			p.x = root._x + ca * cr;
			p.y = root._y + sa * cr;
			p.vx = ca;
			p.vy = sa;
			p.timer = 50;
			p.frict = 0.95;
		}
	}

	public function fxSpark() {
		var mc = Game.me.dm.attach("fxSpark", Game.DP_FX);
		mc.whiteTint = true;
		var p = new Phys(mc);
		var ec = 8;
		p.x = root._x + (Seed.randVfx() * 2 - 1) * ec;
		p.y = root._y + (Seed.randVfx() * 2 - 1) * ec;
		p.weight = -(0.05 + Seed.randVfx() * 0.1);

		var col = Col.objToCol(Col.getRainbow(Seed.randVfx()));
		p.root.setPercentColor(20, col);
	}

	// IS
	public function isTargetable():Bool {
		return state != KnockOut && state != Crash;
	}

	// score
	public function scoreTec() {
		Game.me.fxScore(root._x, root._y - 12, Cs.SCORE_TEC);
	}

	override function kill() {
		Game.me.hero = null;
		super.kill();
	}
}

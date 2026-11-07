package kslash;

import common_haxe_avm1.KeyboardManager;

class Hero extends Ent {
	public static var SPEED:Float = 5;
	public static inline var JUMP_EXTEND = 3;
	public static inline var JUMP_START = 8;

	public static inline var STAR_SPEED = 14;
	public static inline var QUEUE_SPACE = 5;

	var flQueue:Bool;

	var flShootReady:Bool;
	var flMoving:Bool;
	var flCheckGroundSafe:Bool;
	var flDoubleJump:Bool;
	var flDoubleJumpReady:Bool;
	var flUp:Bool;
	var flGameOver:Bool;

	public var flInvicible:Bool;

	var flControl:Bool;

	var boost:Null<Float>;
	var cooldown:Float;
	var jvx:Float;
	var woodTimer:Null<Float>;
	var qTimer:Float;

	public var sTimer:Null<Float>;

	var blink:Float;

	public var star:Int;

	// the hero was put somewhere else without moving (first placement, teleport): the camera too
	public var snapped:Bool;

	public function new(mc:Clip) {
		super(mc);
		x = Std.int(Game.XMAX * 0.5);
		y = 1;
		weight = 0.7;
		flMoving = false;
		cooldown = 0;
		star = 0;
		incStar(40);
		jvx = 0;
		sens = 1;

		flInvicible = false;
		flControl = true;
		flGameOver = false;
		qTimer = 0;
		fall();
	}

	function initStep(n:Int) {
		step = n;
		switch (step) {
			case Cs.ST_NORMAL:
				flMoving = false;
			case Cs.ST_FLY:
				jvx = vx;
				flUp = true;
				flGround = false;
			case Cs.ST_DEATH:
				nextAnim = "death";
				vy = -8;
				vx *= 0.5;
				flCol = false;
				flInvicible = true;
				flGround = false;
		}
	}

	override public function update() {
		var jvx = vx;

		if (flQueue)
			queue();

		var wasSnap = snap;
		super.update();
		if (wasSnap)
			snapped = true;
		if (!flGround)
			vx = jvx; // PATCH pour no friction en l'air

		switch (step) {
			case Cs.ST_NORMAL:
				control();
			case Cs.ST_FLY:
				control();
				if (flUp && vy > 0 && flDoubleJump) {
					flUp = false;
					if (nextAnim == null)
						nextAnim = "fly_down";
				}
			case Cs.ST_DEATH:
				var yLim = (Cs.mch * 2) - 18;
				if (root._y > yLim) {
					vy *= -1.25;
					if (!flGameOver) {
						Cs.game.stats.dif = Std.int(Cs.game.dif);
						Cs.game.gameOver();
						flGameOver = true;
					}
					root._y = yLim;
				}
		}

		if (woodTimer != null) {
			woodTimer -= Timer.tmod;
			if (woodTimer < 0) {
				woodTimer = null;
				flControl = true;
				flInvicible = false;
				teleport();
				Cs.game.stats.respawn++;
			}
		} else {
			if (root._rotation != 0)
				root._rotation = 0;
		}

		if (boost != null) {
			boost *= Math.pow(0.8, (Timer.tmod * 0.5) + 0.5);
			if (boost < 0.1)
				boost = null;
		}

		if (sTimer != null)
			updateSupa();

		if (flCol) {
			if (!flInvicible) {
				checkDeath();
				checkBonus();
			}
		}
	}

	function checkDeath() {
		for (tx in 0...3) {
			for (ty in 0...3) {
				var list = Cs.game.gridList(x + tx - 1, y + ty - 1);
				if (list == null)
					continue;
				var i = 0;
				while (i < list.length) {
					var m = list[i];
					var dist = getDist(m.root);

					if (dist < 24) {
						if (sTimer == null) {
							if (step == Cs.ST_FLY && !m.flSpike) {
								var da = Math.abs(1.57 - getAng(m.root));
								if (da < 1.3) {
									if (vy > 0) {
										vy = -8;
										m.harm(21);
										if (m.hp < 0) {
											Cs.game.stats.sk[m.id]++;
										}
									}
									return;
								}
							}
							if (dist < 18) {
								initStep(Cs.ST_DEATH);
							}
						} else {
							burst(m);
							Cs.game.stats.supak++;
						}
					}
					i++;
				}
			}
		}
	}

	function checkBonus() {
		var i = 0;
		while (i < Cs.game.bList.length) {
			var b = Cs.game.bList[i];
			if (getDist(b.root) < 24) {
				b.take();
			}
			i++;
		}
	}

	function control() {
		if (!flControl)
			return;
		// RUN
		var flMove = false;
		if (KeyboardManager.isDown(KeyboardManager.LEFT)) {
			setSens(-1);
			flMove = true;
		}
		if (KeyboardManager.isDown(KeyboardManager.RIGHT)) {
			setSens(1);
			flMove = true;
		}

		if (flMove) {
			if (flGround) {
				vx = SPEED * sens;
			} else if (flDoubleJump) {
				var dvx = SPEED * sens - vx;
				var lim = 0.25;
				vx += Math.min(Math.max(-lim, dvx * 0.1), lim);
			}
			if (!flMoving) {
				flMoving = true;
				if (flGround) {
					nextAnim = "walk";
					for (i in 0...3) {
						var list = Cs.game.gridList(x - i * sens, y);
						if (list != null && list.length > 0) {
							nextAnim = "run";
							break;
						}
					}
				}
			}
		} else {
			if (flMoving) {
				flMoving = false;
				if (flGround)
					nextAnim = "wait";
			}
		}

		if (flGround) {
			vx *= Math.pow(0.8, Timer.tmod);
		}

		// JUMP
		if (KeyboardManager.isDown(KeyboardManager.UP)) {
			if (flGround) {
				flDoubleJump = true;
				flDoubleJumpReady = false;
				jump();
			} else if (flDoubleJump && flDoubleJumpReady) {
				flDoubleJump = false;
				jump();
				nextAnim = "ball";
				if (flMove)
					vx = SPEED * sens;
			} else {
				if (boost != null) {
					vy -= JUMP_EXTEND * boost * Timer.tmod;
				}
			}
		} else {
			flDoubleJumpReady = true;
		}

		// DOWN
		if (flGround && KeyboardManager.isDown(KeyboardManager.DOWN) && y + 2 < Game.YMAX) {
			jump();
			boost = 0;
			vy *= 0.65;
			flCheckGroundSafe = true;
		}

		// SHOOT
		cooldown -= Timer.tmod;
		if (KeyboardManager.isDown(KeyboardManager.SPACE) || KeyboardManager.isDown(KeyboardManager.CONTROL)) {
			if (cooldown < 0 && flShootReady)
				shoot();
		} else {
			flShootReady = true;
		}
	}

	function jump() {
		initStep(Cs.ST_FLY);
		boost = 1;
		vy = -JUMP_START;
		nextAnim = "fly_up";
	}

	override public function land() {
		if (woodTimer != null) {
			if (vy > 4) {
				vr = (Seed.randVfx() * 2 - 1) * Math.abs(vy) * 3;
			}
			vx *= 0.8;
			vy *= -1;
			return;
		}
		super.land();

		initStep(Cs.ST_NORMAL);
		if (nextAnim == null)
			nextAnim = "land";
		flDoubleJump = true;

		for (i in 0...3) {
			var p = Cs.game.newPart("partDust");
			p.root._x = root._x + (Seed.randVfx() * 2 - 1) * 14;
			p.root._y = root._y + 12 + Seed.randVfx() * 24;
			p.weight = 0.1 + Seed.randVfx() * 0.3;
			p.scale = 50 + Seed.randVfx() * 70;
			p.root._xscale = p.scale;
			p.root._yscale = p.scale;
			p.t = 20 + Seed.randVfx() * 10;
			p.ft = 0;
			if (Cs.game.flNight) {
				p.root.gotoAndStop(2);
			} else {
				p.root.stop();
			}
		}
	}

	override public function checkGround():Bool {
		if (flCheckGroundSafe) {
			flCheckGroundSafe = false;
			return false;
		}
		return super.checkGround();
	}

	override public function fall() {
		initStep(Cs.ST_FLY);
		super.fall();
		nextAnim = "fall";
		flUp = false;
	}

	function shoot() {
		var list = Cs.game.getClosestMonsters();

		flShootReady = false;

		// CHECK BLADE (no monster: undefined target and NaN distance in Flash)
		var trg = list.length > 0 ? list[0].m : null;
		var dist = Math.NaN;
		if (trg != null) {
			var dx = trg.root._x - root._x;
			var dy = (trg.root._y - root._y) * 1.5;
			dist = Math.sqrt(dx * dx + dy * dy);
		}
		// dist<optList[OPT_KATANA]?72:48 in the source: the reach of the blade, longer with the katana
		var flNear = dist < (Cs.game.optList[Cs.OPT_KATANA] ? 72 : 48);
		if (flNear || star == 0) {
			slash(trg, flNear);
			return;
		}

		var max = 1;
		if (step == Cs.ST_FLY && !flDoubleJump) {
			max = Std.int(Math.min(star, list.length));
		}

		for (i in 0...max) {
			var o = list[i];
			if (o != null && o.d > 8)
				break;
			throwStar(o != null ? o.m : null);
		}
	}

	function slash(trg:Monster, flNear:Bool) {
		cooldown = 10;
		var bfx = root.getClip("bfx");
		bfx.gotoAndPlay(2);
		var blade = bfx.getClip("blade");
		if (blade != null)
			blade.gotoAndStop(Cs.game.optList[Cs.OPT_KATANA] ? 2 : 1);
		if (flNear) {
			if ((trg.x - x) * sens < 0)
				setSens(-sens);
			trg.cut(21);
			if (trg.hp > 0) {
				vx = -5 * sens;
			}
		}
	}

	function throwStar(trg:Monster) {
		if (Cs.game.stats.fssc == -1) {
			Cs.game.stats.fssc = KadoKadeoManager.kkm.score;
		}
		incStar(-1);
		cooldown = 2;
		var a = getAng(trg != null ? trg.root : null);
		var s = new Star(Clip.attach(Cs.game.mdm, "mcNinjaShot", Game.DP_SHOOT));
		s.x = x;
		s.y = y;
		s.dx = dx + (cx - 1) * Cs.SIZE * 0.5;
		s.dy = dy + (cy - 1) * Cs.SIZE * 0.5;
		s.vx = Cs.q(Math.cos(a) * STAR_SPEED);
		s.vy = Cs.q(Math.sin(a) * STAR_SPEED);
		if (Cs.game.optList[Cs.OPT_FLAMES]) {
			s.damage = 8;
			s.root.gotoAndStop(2);
		} else {
			s.root.gotoAndStop(1);
		}
	}

	public function incStar(n:Int) {
		star = Std.int(Math.min(Math.max(0, star + n), 200));
		Cs.game.setStarField(star);
		Cs.game.stats.maxs = Std.int(Math.max(Cs.game.stats.maxs, star));
	}

	public function hit(s:Shoot) {
		if (Cs.game.optList[Cs.OPT_SCROLL]) {
			Cs.game.optList[Cs.OPT_SCROLL] = false;
			Cs.game.updateIcons();
			setSens(1);
			root.gotoAndPlay("tronc");
			root.setOverride("kunai", s.root._rotation, null, null);
			smoke();
			flFreezeAnim = true;
			flInvicible = true;
			flControl = false;
			woodTimer = 30;
			//
			var vitx = s.vx * 0.5;
			var vity = s.vy * 0.5 - 3;
			if (flGround) {
				vity = Math.min(0, vity);
				if (vity < 0)
					initStep(Cs.ST_FLY);
			}
			vx += vitx;
			vy += vity;
		} else {
			initStep(Cs.ST_DEATH);
		}
	}

	function teleport() {
		vr = 0;
		x = Std.int(Game.XMAX * 0.5);
		y = 1;
		vx = 0;
		vy = 0;
		flFreezeAnim = false;
		fall();
		smoke();
		// (Flash: drawn there at once, no slide across the screen)
		snap = true;
	}

	function smoke() {
		var p = Cs.game.newPart("partSmoke");
		p.root._x = (x + 0.25 + (cx * 0.5)) * Cs.SIZE + dx;
		p.root._y = (y + 0.25 + (cy * 0.5)) * Cs.SIZE + dy;
	}

	//
	public function initSupa() {
		sTimer = 500;
		blink = 0;
		SPEED = 9;
	}

	function updateSupa() {
		sTimer -= Timer.tmod;
		qTimer -= Timer.tmod;
		if (qTimer < 0) {
			qTimer = QUEUE_SPACE;
			var mc = Clip.attach(Cs.game.mdm, "mcShade", Game.DP_SHADE);
			mc._x = root._x;
			mc._y = root._y;
			mc._xscale = root._xscale;
			mc.getClip("shade").gotoAndStop(root.frame);
			mc.updateState();
		}

		var blinkSpeed = 67;
		if (sTimer < 100)
			blinkSpeed = 127;
		blink = (blink + blinkSpeed * Timer.tmod) % 628;

		var prc = (Math.cos(blink / 100) + 1) * 40;
		if (sTimer < 0) {
			sTimer = null;
			prc = 0;
			SPEED = 5;
		}
		Cs.setPercentColor(root, prc, 0xFFDDFF);
	}

	function queue() {}

	function burst(m:Monster) {
		m.harm(100);
		var max = 8;
		for (v in 0...max) {
			for (n in 0...2) {
				var p = Cs.game.newPart("partLight");
				p.root._x = m.root._x;
				p.root._y = m.root._y;
				var a = ((v + 0.5 * n) / max) * 6.28;
				var speed = (3 + n * 2);
				p.vx += Math.cos(a) * speed;
				p.vy += Math.sin(a) * speed;
				p.t = 26 + Seed.randVfx() * 4 - n * 10;
				p.frict = 0.9;
			}
		}
	}
}

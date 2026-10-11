package ironchouquette;

import common_haxe_avm1.KeyboardManager;
import common_haxe_avm1.KKApi;
import mt.bumdum.Lib;
import mt.DepthManager;
import mt.Timer;
import pixi.core.Pixi.BlendModes;

class OndeSprite extends ASprite {
	public var list:Array<Bads>;
}

class LaserRayListSprite extends ASprite {
	public var vr:Float;
	public var t:Float;
}

class LaserRaySprite extends ASprite {
	public var t:Float;
	public var ray:ASprite;
	public var dm:DepthManager;
	public var list:Array<LaserRayListSprite>;
}

class BlackHoleSpritePart extends Part {
	public var black:Float;
	public var captured:Bool;
}

class BlackHoleSprite extends ASprite {
	public var vr:Float;
	public var step:Int;
	public var list:Array<BlackHoleSpritePart>;
}

class Hero extends Phys {
	public inline static var WP_PLASMA = 0;
	public inline static var WP_SIDER = 1;
	public inline static var WP_LASER = 2;
	public inline static var WP_SPEED = 3;
	public inline static var WP_VOID = 4;
	public inline static var WP_MISSILE = 5;

	public static var RAY = KadoKadeoManager.I(8);
	public static var INVINCIBLE_RAY = KadoKadeoManager.I(32);

	var reactorPosOnFrame:Array<Array<{x:Float, y:Float}>> = [
		[{x: 11.334, y: 10}, {x: 17, y: 10}],
		[{x: 11, y: 10}, {x: 17.333, y: 10}],
		[{x: 10.666, y: 10}, {x: 17.666, y: 10}],
		[{x: 10, y: 10}, {x: 18, y: 10}],
		[{x: 9.334, y: 10}, {x: 18.666, y: 10}],
		[{x: 8.666, y: 10}, {x: 19.333, y: 10}],
		[{x: 8, y: 10}, {x: 20, y: 10}],
		[{x: 7.333, y: 10}, {x: 20.666, y: 10}],
		[{x: 6.666, y: 10}, {x: 21.333, y: 10}],
		[{x: 5.666, y: 10}, {x: 22, y: 10}],
		[{x: 6.666, y: 10}, {x: 21.333, y: 10}],
		[{x: 7.333, y: 10}, {x: 20.666, y: 10}],
		[{x: 8, y: 10}, {x: 20, y: 10}],
		[{x: 8.666, y: 10}, {x: 19.333, y: 10}],
		[{x: 9.334, y: 10}, {x: 18.666, y: 10}],
		[{x: 10, y: 10}, {x: 18, y: 10}],
		[{x: 10.666, y: 10}, {x: 17.666, y: 10}],
		[{x: 11, y: 10}, {x: 17.333, y: 10}],
		[{x: 11.334, y: 10}, {x: 17, y: 10}],
		[{x: 11.666, y: 10}, {x: 16.666, y: 10}],
	];

	var flame1:ASprite;
	var flame2:ASprite;

	public var isDead:Bool = false;

	public var flControl:Bool;

	public var slotMax:Int;
	public var speed:Float;
	public var rollX:Float;
	public var rollY:Float;
	public var invincibleTimer:Float;

	public var dm:DepthManager;

	// LASER
	public var laserStartAngle:Float;
	public var laserTrg:Bads;
	public var laserFlip:Int;
	public var laserList:Array<Array<Float>>;
	public var laserRay:LaserRaySprite;

	// SONIC BOOM
	public var onde:OndeSprite;
	public var blackHole:BlackHoleSprite;

	public var boxes:Array<ASprite>;
	public var slots:Array<Int>;
	public var cslots:Array<Int>;
	public var weapons:Array<Array<Dynamic>>;
	public var cweapons:Array<Array<Int>>;

	public var lastLaser:ASprite;

	public function new(mc) {
		super(mc);
		flame1 = mc.attachMovie("mcFlame", "flame1", -1);
		flame2 = mc.attachMovie("mcFlame", "flame2", -1);
		flame1.loop = true;
		flame1.play();
		flame2.loop = true;
		flame2.play();
		updateFlamePos();

		ray = RAY;
		speed = KadoKadeoManager.S(3.6);
		frict = 0.6;

		laserStartAngle = 0;
		laserFlip = 0;

		rollX = 0;
		rollY = 0;

		slots = [];
		cslots = [];
		weapons = [];
		cweapons = [];
		boxes = new Array();
		for (i in 0...3)
			addBox();
		for (i in 0...6) {
			weapons[i] = [(i == 0) ? 1 : 0, 0];
			cweapons[i] = [(i == 0) ? 1 : 0, 0];
		}

		dm = new DepthManager(root);
		flControl = false;
		root.gotoAndStop(10);

		x = Cs.mcw * 0.5 - KadoKadeoManager.I(5);
		y = Cs.mch + ray;
	}

	public function updateFlamePos() {
		var frame = this.root._currentframe - 1;
		var poses = reactorPosOnFrame[frame];
		flame1._x = KadoKadeoManager.S(poses[0].x) - root._width * 0.5;
		flame1._y = KadoKadeoManager.S(poses[0].y);
		flame2._x = KadoKadeoManager.S(poses[1].x) - root._width * 0.5;
		flame2._y = KadoKadeoManager.S(poses[1].y);
	}

	public override function update() {
		if (isDead) {
			return;
		}
		super.update();
		updateFlamePos();

		if (flControl) {
			control();
			updateShoot();
		} else {
			y -= KadoKadeoManager.S(0.8) * Timer.tmod;
		}

		if (onde != null)
			updateOnde();
		if (laserRay != null)
			updateLaserRay();
		if (blackHole != null)
			updateBlackHole();
		if (invincibleTimer != null)
			updateInvincible();

		if (!flControl && Stykades.dif > 56) {
			Game.SCROLL_SPEED += KadoKadeoManager.S(2.4);
			flControl = true;
		}

		// CHECK CHEAT
		for (i in 0...6) {
			if (weapons[i][0] != cweapons[i][0])
				KKApi.flagCheater();
		}
		for (i in 0...slots.length) {
			if (slots[i] != cslots[i])
				KKApi.flagCheater();
		}

		// TODO: getCheat does not exist
		// if (boxes.getCheat())
		// 	KKApi.flagCheater();
	}

	public function updateInvincible() {
		invincibleTimer -= Timer.tmod;

		Col.setPercentColor(root, 70 + Math.cos(invincibleTimer * 0.5) * 20, 0xFFFFFF);

		var size = Math.min(invincibleTimer / 50, 1);
		// PARTS

		var p = new Part(Cs.game.dm.attach("partInvincibility", Game.DP_UNDERPARTS));
		var a = Seed.randVfx() * 6.28;
		var ca = Math.cos(a);
		var sa = Math.sin(a);
		var r = 0;
		var sp = 1.5 + Seed.randVfx() * 1.5;
		p.x = x;
		p.y = y - KadoKadeoManager.I(6);
		p.vx = ca * sp;
		p.vy = sa * sp + KadoKadeoManager.I(4);
		p.plasmaId = 1;
		p.timer = 10;
		p.fadeType = 0;
		p.root.blendMode = BlendModes.ADD;
		p.setScale((150 + Seed.randVfx() * 100) * size);

		if (invincibleTimer < 0) {
			invincibleTimer = null;
			ray = RAY;
			Col.setPercentColor(root, 0, 0xFFFFFF);
		}
		var pdm = new DepthManager(p.root);

		//
		if (Seed.randVfx() * 3 < 1) {
			var mc = pdm.attach("mcLaserLight", 0);
			mc._rotation = Seed.randVfx() * 360;
			mc._xscale = 100 + Seed.randVfx() * 100;
			mc._yscale = 50 + Seed.randVfx() * 100;
			mc.play();
		}
	}

	public function control() {
		var boost = weapons[3][0];
		var sp = Math.min(speed + boost * KadoKadeoManager.S(1.6), KadoKadeoManager.S(10)) * Timer.tmod;

		// MOVE
		var mx:Float = 0;
		var my:Float = 0;
		var bent = 0.25;
		var leftDown = KeyboardManager.isDown(KeyboardManager.LEFT)
			|| KeyboardManager.isDown(KeyboardManager.A)
			|| KeyboardManager.isDown(KeyboardManager.Q);
		var rightDown = KeyboardManager.isDown(KeyboardManager.RIGHT) || KeyboardManager.isDown(KeyboardManager.D);
		var upDown = KeyboardManager.isDown(KeyboardManager.UP)
			|| KeyboardManager.isDown(KeyboardManager.W)
			|| KeyboardManager.isDown(KeyboardManager.Z);
		var downDown = KeyboardManager.isDown(KeyboardManager.DOWN) || KeyboardManager.isDown(KeyboardManager.S);
		if (leftDown) {
			mx -= sp;
			laserStartAngle -= bent;
			rollX -= Timer.tmod * 5;
		}
		if (rightDown) {
			mx += sp;
			laserStartAngle += bent;
			rollX += Timer.tmod * 5;
		}
		if (upDown) {
			my -= sp;
			rollY -= Timer.tmod * 3.5;
		}
		if (downDown) {
			my += sp;
			rollY += Timer.tmod * 3.5;
		}
		rollX *= 0.6;
		rollY *= Math.pow(0.87, Timer.tmod);
		laserStartAngle *= Math.pow(0.94, Timer.tmod);

		// BOOST

		if (boost > 0) {
			var max = 2;
			var mc = Cs.game.dm.attach("mcSpeed", Game.DP_PARTS);
			mc.gotoAndStop(boost);
			mc._xscale = (120 + boost * 40) * 2;
			mc._yscale = mc._xscale;
			for (k in 0...max) {
				var coef = k / max;
				mc._x = x + mx * coef;
				mc._y = y + (my + Game.SCROLL_SPEED) * coef;
				// mc.blendMode = BlendModes.ADD
				Cs.game.plasmaDraw(mc, 0);

				for (i in 0...3) {
					var a = Seed.rand() * 6.28;
					var ray = KadoKadeoManager.S(20 + Seed.rand() * 50);
					mc._x = x + Math.cos(a) * ray;
					mc._y = y + Math.sin(a) * ray;
					mc._xscale = 100 + Seed.rand() * 180;
					mc._yscale = mc._xscale;
					Cs.game.plasmaDraw(mc, 0);
				}
			}
			mc.removeMovieClip();

			var r = ray * (((60 + boost * 40) * 1.7) / 100) * 1.3;
			for (i in 0...boost) {
				var p = new Part(Cs.game.dm.attach("partSparkSpeed", Game.DP_UNDERPARTS));
				p.x = x + (Seed.randVfx() * 2 - 1) * r;
				p.y = y + (Seed.randVfx() * 2 - 1) * r;
				p.setScale(10 + Seed.randVfx() * (15 + boost * 5));
				p.root.gotoAndPlay(Seed.randomVfx(p.root._totalframes) + 1);
				p.vy = Game.SCROLL_SPEED;
				p.timer = 20 + Seed.randVfx() * 10;
			}
		}

		x += mx;
		y += my;

		// GFX
		var frame = 1 + Std.int(Num.mm(0, 10 + rollX, 20));
		root.gotoAndStop(frame);

		// COL
		checkBounds();
	}

	// WEAPON
	public function addWeapon(id) {
		if (slots.length == boxes.length) {
			sacrifice(0);
		}
		weapons[id][0]++;
		cweapons[id][0]++;
		slots.push(id);
		cslots.push(id);
		updateBoxes();
	}

	public function addBox() {
		var mc = Cs.game.dm.attach("mcSlot", Game.DP_INTER);
		var m = KadoKadeoManager.I(8);
		mc._x = m;
		mc._y = Cs.mch - (m + boxes.length * (m + KadoKadeoManager.I(5)));
		mc.stop();
		boxes.push(mc);
	}

	public function updateBoxes() {
		for (i in 0...boxes.length) {
			var id = slots[i];
			if (id == null)
				id = -1;
			boxes[i].gotoAndStop(id + 2);
		}
	}

	public function sacrifice(n) {
		if (slots.length == 0)
			return;
		if (n == null)
			n = slots.length - 1;
		var id = slots[n];
		weapons[id][0]--;
		cweapons[id][0]--;
		slots.splice(n, 1);
		cslots.splice(n, 1);
		updateBoxes();

		Cs.game.stats.b.push([Std.int(Stykades.dif), 100 + id]);
		Cs.game.stats.sak[id].push([0, 0]);
		switch (id) {
			case Hero.WP_PLASMA:
				var shot = newShot(0, 14, 18);
				shot.ray = KadoKadeoManager.I(50);
				shot.damage = 50;
				shot.flPierce = true;
				shot.bList.push(11);
				var idx = Cs.game.stats.sak[Hero.WP_PLASMA].length - 1;
				shot.onKill = () -> {
					Cs.game.stats.sak[Hero.WP_PLASMA][idx][0] += 1;
				}
			// shot.vr = (Math.random()*2-1)*10
			case Hero.WP_SIDER:
				if (onde != null)
					onde.removeMovieClip();
				onde = cast Cs.game.dm.attach("mcSonicBoom", Game.DP_UNDERPARTS);
				onde.list = new Array();
				onde._x = x;
				onde._y = y;
				onde._xscale = 80;
				onde._yscale = onde._xscale;
			case Hero.WP_VOID:
				if (blackHole == null) {
					blackHole = cast Cs.game.dm.attach("mcBlackHole", Game.DP_UNDERPARTS);
					blackHole.list = new Array();
					blackHole._x = x;
					blackHole._y = y;
					blackHole.step = 0;
					blackHole._xscale = 10;
					blackHole._yscale = 10;
					blackHole.vr = 10;

					var list:Array<Phys> = new Array();
					for (b in Cs.game.badsList)
						list.push(b);
					for (s in Cs.game.shotList)
						list.push(s);
					Cs.game.stats.sak[id][Cs.game.stats.sak[id].length - 1][0] = Cs.game.badsList.length;
					Cs.game.stats.sak[id][Cs.game.stats.sak[id].length - 1][1] = Cs.game.shotList.length;

					while (list.length > 0) {
						var b = list.pop();
						if (b.flash != null) {
							b.flash = 0;
							b.updateFlash();
						}
						var p = new BlackHoleSpritePart(b.root);
						p.x = b.x;
						p.y = b.y;
						p.vx = b.vx;
						p.vy = b.vy;
						p.frict = 0.94;
						p.ray = b.ray;
						p.black = 0;
						p.captured = false;
						p.root.stop();
						b.root = null;
						b.kill();
						blackHole.list.push(p);
					}
				}

			/*
				while( blackHole.list.length<150 ){
					var p =  downcast(new Part(Cs.game.dm.attach("partBlackHole",Game.DP_PARTS)));
					p.x = Math.random()*Cs.mcw;
					p.y = Math.random()*Cs.mch;
					p.ray2 = 14;
					p.frict = 0.94;
					blackHole.list.push(p);
				}
			 */
			case Hero.WP_SPEED:
				if (laserRay == null) {
					laserRay = cast Cs.game.dm.attach("mcBigLaser", Game.DP_UNDERPARTS);
					laserRay.blendMode = BlendModes.ADD;
					laserRay._xscale = 0;
					laserRay.dm = new DepthManager(laserRay);
					laserRay.list = new Array();
					for (i in 0...12) {
						var mc:LaserRayListSprite = cast laserRay.dm.attach("mcLaserRay", 0);
						mc._rotation = Seed.rand() * 360;
						mc._xscale = 100 + Seed.rand() * 100;
						mc._yscale = 100 + Seed.rand() * 500;
						mc.t = 10 + Seed.rand() * 50;
						mc.blendMode = BlendModes.ADD;
						mc.vr = (Seed.rand() * 2 - 1) * 5;
						laserRay.list.push(mc);
					}
					laserRay.t = 80;
				}

			case Hero.WP_LASER:
				invincibleTimer = 300;
				ray = INVINCIBLE_RAY; // ADD;

			case Hero.WP_MISSILE:
				var max = 12;
				for (i in 0...max) {
					var shot = newMissile(6.28 * i / max);
					shot.sleep = 6;
					shot.timer = 60;
					var idx = Cs.game.stats.sak[Hero.WP_MISSILE].length - 1;
					shot.onKill = () -> {
						Cs.game.stats.sak[Hero.WP_MISSILE][idx][0] += 1;
					}
				}
			case null:
				Cs.game.bt = {trg: 0.3, timer: 100, val: 1};
			case _:
		}
		// CLEAN SHOOT
		var list = Cs.game.shotList.copy();
		if (id != Hero.WP_VOID) {
			var idx = Cs.game.stats.sak[id].length - 1;
			Cs.game.stats.sak[id][idx][1] = list.length;
		}
		for (i in 0...list.length) {
			var shot = list[i];
			if (shot.flGood != true)
				shot.kill();
		}
		//
		Cs.game.flashouille = 100;
		Cs.game.lagTimer = -70;
		Stykades.nextWave = 100;
	}

	public function updateShoot() {
		var flFire = KeyboardManager.isDown(KeyboardManager.SPACE) || KeyboardManager.isDown(KeyboardManager.ENTER);

		if (lastLaser != null && lastLaser._visible) {
			lastLaser.removeMovieClip();
			// its lines are freed (graphics card buffers), the plasma stamp of last frame (if any) is flushed
			lastLaser.destroy({children: true});
			lastLaser = null;
		}

		for (i in 0...6) {
			var a = weapons[i];
			if (a[0] > 0) {
				if (a[1] > 0)
					a[1] = Std.int(a[1] - Timer.tmod);
				while (flFire && a[1] <= 0 && blackHole == null && laserRay == null) {
					switch (i) {
						case WP_PLASMA:
							switch (a[0]) {
								case 1:
									var shot = newShot(0, 12, 14);
									shot.ray = KadoKadeoManager.I(6);
									shot.damage = 1;
									shot.onKill = () -> Cs.game.stats.spk[WP_PLASMA] += 1;
								case 2:
									for (n in 0...2) {
										var shot = newShot(0, 12, 14);
										shot.ray = KadoKadeoManager.I(6);
										shot.x = x + (n * 2 - 1) * KadoKadeoManager.I(5);
										shot.damage = 1;
										shot.onKill = () -> Cs.game.stats.spk[WP_PLASMA] += 1;
									}
								case 3:
									{
										var shot = newShot(0, 15, 14);
										shot.ray = KadoKadeoManager.I(8);
										shot.setScale(150);
										shot.damage = 2;
										shot.flPierce = true;
										shot.onKill = () -> Cs.game.stats.spk[WP_PLASMA] += 1;
									}
									for (n in 0...2) {
										var sens = n * 2 - 1;
										var shot = newShot(sens * 0.15, 12, 14);
										shot.ray = KadoKadeoManager.I(8);
										shot.x = x + sens * KadoKadeoManager.I(5);
										shot.damage = 1;
										shot.onKill = () -> Cs.game.stats.spk[WP_PLASMA] += 1;
									}
								case _:
									{
										var shot = newShot(0, 15, 14);
										shot.ray = KadoKadeoManager.I(4 + a[0]);
										shot.setScale(100 + a[0] * 25);
										shot.damage = 1 + (a[0] * 0.5);
										shot.flPierce = true;
										shot.onKill = () -> Cs.game.stats.spk[WP_PLASMA] += 1;
									}
									for (n in 0...2) {
										var sens = n * 2 - 1;
										for (k in 0...Std.int((a[0] + 1) * 0.5)) {
											var shot = newShot(sens * (0.15 + k * 0.15), 12 - (k * 1.5), 14);
											shot.ray = KadoKadeoManager.I(8);
											shot.x = x + sens * KadoKadeoManager.I(5 + k * 5);
											shot.damage = 1;
											shot.onKill = () -> Cs.game.stats.spk[WP_PLASMA] += 1;
										}
									}
							}
							a[1] += 8;

						case WP_MISSILE:
							for (n in 0...2) {
								var sens = n * 2 - 1;
								for (k in 0...a[0]) {
									var c = (k / (a[0] - 1)) - 0.5;
									if (a[0] == 1)
										c = 0;
									var ec = 0.5 + a[0] * 0.2;

									var shot = newMissile(sens * 1.9 + ec * c);
									shot.onKill = () -> Cs.game.stats.spk[WP_MISSILE] += 1;
								}
							}
							a[1] += 40; // 50;

						case WP_SIDER:
							for (n in 0...2) {
								var max = Std.int(Math.min(a[0], 6));
								for (k in 0...max) {
									var sens = n * 2 - 1;

									var c = (k / (max - 1)) - 0.5;
									if (max == 1)
										c = 0;
									var ec = 0.3 + a[0] * 0.1;

									var shot = newShot(sens * (1.57 - rollY * 0.05) + ec * c, 14, 16);
									shot.damage = 0.85;
									shot.onKill = () -> Cs.game.stats.spk[WP_SIDER] += 1;
									// shot.root._xscale = sens*100
									shot.x += sens * KadoKadeoManager.I(14);
									shot.y += KadoKadeoManager.I(16);
									shot.orient();
									shot.updatePos();

									if (k > 1 && k < max - 1) {
										shot.setScale(150);
										shot.damage = 1.5;
										shot.speed = KadoKadeoManager.I(18);
										shot.updateVit();
										shot.x += sens * KadoKadeoManager.I(6);
									}
								}
							}
							a[1] += 5;

						case WP_LASER:
							// SEEK
							if (laserTrg == null || laserTrg.flDeath) {
								var dist = 1 / 0;
								laserTrg = cast {
									get_x: function() {
										return x;
									},
									get_y: function() {
										return -KadoKadeoManager.I(20);
									},
									ray: KadoKadeoManager.I(10),
									damage: null,
									flDeath: true,
									shieldLim: null
								};
								for (n in 0...Cs.game.badsList.length) {
									var b = Cs.game.badsList[n];
									var d = getDist({x: b.x, y: b.y});
									if (d < dist) {
										laserTrg = b;
										dist = d;
									}
								}
							}

							// CREATE LIST
							var op = [x, y - 6];
							var list = [op];
							var angle = -1.57;
							if (!laserTrg.flDeath)
								angle += laserStartAngle;
							var va = 0.1;
							var ca = 0.1;
							var sp = KadoKadeoManager.I(7);
							var tr = 0;

							while (true) {
								var dx = laserTrg.x - op[0];
								var dy = laserTrg.y - op[1];
								var ta = Math.atan2(dy, dx);
								var da = Num.hMod(ta - angle, 3.14);
								angle += Num.mm(-va, da * ca, va);
								var nx = op[0] + Math.cos(angle) * sp;
								var ny = op[1] + Math.sin(angle) * sp;
								if (laserTrg.shieldLim != null) {
									var dist = Cs.getDist({x: Std.int(laserTrg.x), y: Std.int(laserTrg.y)}, {x: Std.int(nx), y: Std.int(ny)});
									if (dist < laserTrg.shieldLim) {
										angle = Cs.getAng({x: Std.int(nx), y: Std.int(ny)}, {x: Std.int(laserTrg.x), y: Std.int(laserTrg.y)})
											+ laserStartAngle * 0.2;
										ca = 0.5;
										va = 10;
									}
								}

								var np = [nx, ny];
								list.push(np);
								op = np;

								if (Math.abs(dx) + Math.abs(dy) < laserTrg.ray * 0.5) {
									break;
								}
								if (tr++ > 100)
									break;

								ca = Math.min(ca + 0.01, 1);
								va += 0.01;
							}

							// DRAW
							//*
							laserFlip = (laserFlip + 1) % 2;
							var s0 = 12 + (a[0] + laserFlip * 2) * KadoKadeoManager.I(3);
							var s1 = 1 + (a[0] + laserFlip) * KadoKadeoManager.S(2.5);
							var mc = Cs.game.dm.empty(Game.DP_PARTS);

							mc.lineStyle(s0, 0xFF0000, 30, "round", "round");
							mc.moveTo(list[0][0], list[0][1]);
							for (n in 1...list.length) {
								var p = list[n];
								mc.lineTo(p[0], p[1]);
							}

							mc.lineStyle(s1, 0xFFFFFF, 100, "round", "round");
							mc.moveTo(list[0][0], list[0][1]);
							for (n in 1...list.length) {
								var p = list[n];
								mc.lineTo(p[0], p[1]);
							}
							//*/

							//*
							var ba = 2;
							var br = 2;
							var ra = KadoKadeoManager.I(3) + s1;
							mc.lineStyle(1, 0xFFFFFF, 100, "round", "round");
							for (n in 0...3) {
								var k = 0;
								var st = Seed.randomVfx(list.length - 3);
								mc.moveTo(list[st][0], list[st][1]);
								while (Seed.randomVfx(k) == 0) {
									k++;
									st = Std.int(Math.min(st + ba + Seed.randomVfx(br), list.length - 1));
									var px = list[st][0] + (Seed.randVfx() * 2 - 1) * ra;
									var py = list[st][1] + (Seed.randVfx() * 2 - 1) * ra;
									mc.lineTo(px, py);
								}
								st = Std.int(Math.min(st + ba + Seed.randomVfx(br), list.length - 1));
								mc.lineTo(list[st][0], list[st][1]);
							}
							//*/

							//*
							if (Cs.game.gfxMode >= 1) {
								mc.blendMode = BlendModes.ADD;
								Cs.game.plasmaDraw(mc, 1);
							}
							// not in the original with the plasma (only drawn into it): also shown at full resolution
							// for one frame, the plasma upscale x4 made its thin lines blocky
							lastLaser = mc;
							//*/
							laserList = list;

							a[1] = 0.1;

						case WP_VOID:
							var shot = newShot((Seed.rand() * 2 - 1) * (0.3 + a[0] * 0.15), 10, 17);
							shot.damage = 1.2;
							shot.orient();
							// shot.plasmaId = 1
							shot.bList.push(4);
							shot.speed = KadoKadeoManager.I(12);
							shot.decal = Seed.rand() * 628;
							shot.onKill = () -> Cs.game.stats.spk[WP_VOID] += 1;

							a[1] += 18 / (a[0] * 4);

						case WP_SPEED:
							a[1] = 0.1;

						case _:
					}
				}
			}
		}

		if (!flFire) {
			laserTrg = null;
			laserList = null;
		}
	}

	// SPECIAL
	public function updateLaserRay() {
		laserRay._x = x;
		laserRay._y = y;
		if (laserRay.t >= 10) {
			laserRay._xscale += 32 * Timer.tmod;
		} else {
			if (laserRay.t < 0 && laserRay._currentframe == 1)
				laserRay.play();
		}
		laserRay._xscale *= Math.pow(0.9, Timer.tmod);
		laserRay.t -= Timer.tmod;

		var i = 0;
		while (i < laserRay.list.length) {
			var mc = laserRay.list[i];
			var dr = Num.hMod(-90 - mc._rotation, 180);

			mc._rotation += mc.vr + dr * 0.03 * Timer.tmod;
			mc._xscale += 10;
			mc.t -= Timer.tmod;

			if (laserRay.t < 10) {
				mc._yscale *= 0.6;
			}

			if (mc.t < 10) {
				mc._alpha = mc.t * 10;
				if (mc.t < 0) {
					mc.removeMovieClip();
					laserRay.list.splice(i, 1);
					continue;
				}
			}

			/*
				var lim = 100;
				mc._rotation +=Num.mm(-lim,dr*0.2*Timer.tmod,lim);
				mc._xscale *= 1.05;
				mc._yscale *= 0.95;
				if(Math.abs(dr)<2){
					mc.removeMovieClip();
					laserRay.list.splice(i--,1);
				}
				// */
			i++;
		}

		while (laserRay.list.length < Math.min(12, laserRay.t * 0.5)) {
			var mc:LaserRayListSprite = cast laserRay.dm.attach("mcLaserRay", 0);
			mc._rotation = Seed.randVfx() * 360;
			mc._xscale = 100 + Seed.randVfx() * 100;
			mc._yscale = 100 + Seed.randVfx() * 1000;
			mc.t = 10 + Seed.randVfx() * 60;
			mc.blendMode = BlendModes.ADD;
			mc.vr = (Seed.randVfx() * 2 - 1) * 5;
			laserRay.list.push(mc);
		}
		if (laserRay.t > 0) {
			for (b in Cs.game.badsList) {
				if (b == null)
					continue;
				if (Math.abs(b.x - x) < (KadoKadeoManager.I(8) * laserRay._xscale / 100) + b.ray && b.y < y) {
					var isDead = b.damage(2.5 * Timer.tmod);
					if (isDead) {
						Cs.game.stats.sak[Hero.WP_SPEED][Cs.game.stats.sak[Hero.WP_SPEED].length - 1][0] += 1;
					}
				}
			}
		} else {
			if (laserRay.t < -10) {
				laserRay.removeMovieClip();
				laserRay = null;
			}
		}
	}

	public function updateOnde() {
		onde._xscale *= 1.25;
		onde._yscale = onde._xscale;

		for (i in 0...Cs.game.badsList.length) {
			var b = Cs.game.badsList[i];
			var flStrike = true;
			for (n in 0...onde.list.length) {
				if (b == onde.list[n]) {
					flStrike = false;
					break;
				}
			}

			if (b != null && flStrike && b.getDist({x: onde._x, y: onde._y}) < onde._xscale * 0.5) {
				var isDead = b.damage(5);
				onde.list.push(b);
				if (isDead) {
					Cs.game.stats.sak[Hero.WP_SIDER][Cs.game.stats.sak[Hero.WP_SIDER].length - 1][0] += 1;
				}
			}
		}

		if (onde._xscale > Cs.mcw * 2) {
			onde.removeMovieClip();
			onde = null;
		}
	}

	public function updateBlackHole() {
		blackHole.vr *= Math.pow(1.05, Timer.tmod);
		blackHole._rotation += 12 * Timer.tmod;

		var acc = 1;
		var bh = {x: blackHole._x, y: blackHole._y};
		var captureRay = blackHole._xscale * KadoKadeoManager.S(0.5);
		var alphaRay = Math.max(captureRay, 0.0001);
		var centerEps = KadoKadeoManager.I(20);

		var i = blackHole.list.length - 1;
		while (i >= 0) {
			var p = blackHole.list[i];
			var dist = p.getDist(bh);

			if (dist <= captureRay) {
				p.root._alpha = (dist + centerEps) / alphaRay * 25;
			} else {
				p.root._alpha = 100;
			}

			if (!p.captured) {
				var a = p.getAng(bh);
				p.vx += Math.cos(a) * acc * Timer.tmod;
				p.vy += Math.sin(a) * acc * Timer.tmod;

				if (dist < p.ray) {
					p.captured = true;
					p.kill();
					blackHole.list.splice(i, 1);
					i--;
					continue;
				}
			}
			i--;
		}
		// Log.setColor(0xFF0000)
		// trace(blackHole.step);
		switch (blackHole.step) {
			case 0 | 2:
				var ts = (blackHole.step == 0) ? 150 : 0;
				var ds = ts - blackHole._xscale;
				var scaleLerp = 1 - Math.pow(0.7, Timer.tmod);
				blackHole._xscale += ds * scaleLerp;
				if (Math.abs(ds) <= 1) {
					blackHole.step++;
					blackHole._xscale = ts;
				}
				blackHole._yscale = blackHole._xscale;
			case 1:
				if (blackHole.list.length == 0)
					blackHole.step = 2;
			case 3:
				if (blackHole.list.length == 0) {
					blackHole.removeMovieClip();
					blackHole = null;
				}
			case _:
		}
	}

	//
	public function newShot(a:Float, speed:Float, skin:Int) {
		a -= 1.57;
		var shot = new Shot(null);
		shot.setSkin(skin, 1);
		shot.a = a;
		shot.flGood = true;
		shot.x = x;
		shot.y = y - KadoKadeoManager.I(20);
		shot.vx = Math.cos(a) * KadoKadeoManager.S(speed);
		shot.vy = Math.sin(a) * KadoKadeoManager.S(speed);

		return shot;
	}

	public function newMissile(a) {
		var shot = newShot(a, 4, 15);
		shot.root.stop();
		shot.y += KadoKadeoManager.I(10);
		shot.ray = KadoKadeoManager.I(8);
		shot.damage = 2;
		shot.speed = KadoKadeoManager.I(4);
		shot.accel = {
			inc: KadoKadeoManager.S(0.5),
			max: KadoKadeoManager.I(16)
		}
		shot.va = 0.2;
		shot.ca = 0.1;
		shot.orient();
		shot.queue = "mcQueueStandard";
		shot.bList.push(3);
		shot.timer = 120;
		return shot;
	}

	//
	public function hit(shot) {
		explode();
	}

	public function explode() {
		if (isDead)
			return;
		// PARTS
		for (i in 0...12) {
			var p = new Part(Cs.game.dm.attach("mcExploPart", Game.DP_PARTS));
			p.setScale(20 + Seed.randVfx() * 30);
			var a = Seed.randVfx() * 6.28;
			var ca = Math.cos(a);
			var sa = Math.sin(a);
			var ray = KadoKadeoManager.I(8);
			var sp = 6 + Seed.randVfx() * 6;
			p.x = x + ca * ray;
			p.y = y + sa * ray;
			p.vx = ca * sp;
			p.vy = sa * sp;
			p.plasmaId = 1;
			p.timer = 10 + Seed.randVfx() * 30;
			// original: fadeType left undefined falls into Part.mt's default branch = alpha fade (the Int
			// default 0 here would scale-fade instead)
			p.fadeType = 6;
			p.frict = 0.96;
			p.root.blendMode = BlendModes.ADD;
			p.root._rotation = Seed.randVfx() * 360;
			p.root.play();
		}
		// TRACE
		for (i in 0...6) {
			var mc = Cs.game.dm.attach("mcExploTrace", Game.DP_PARTS);
			mc._x = x + (Seed.randVfx() * 2 - 1) * ray;
			mc._y = y + (Seed.randVfx() * 2 - 1) * ray;
			mc._xscale = 150 + Seed.randVfx() * 150;
			mc._yscale = mc._xscale;
			mc._rotation = Seed.randVfx() * 360;
			mc.blendMode = BlendModes.ADD;
			mc.onFrame.set(3, function() {
				Cs.game.plasmaDraw(mc, 1);
				mc.removeMovieClip();
			});
			mc.gotoAndPlay(Seed.randomVfx(3) + 1);
		}
		// ONDE
		var mc = Cs.game.dm.attach("mcOnde", Game.DP_UNDERPARTS);
		mc._x = x;
		mc._y = y;
		mc._xscale = 150;
		mc._yscale = 150;
		mc.play();

		kill();
	}

	public override function kill() {
		if (!isDead) {
			isDead = true;
			// Cs.game.hero = cast {x: x, y: y};
			KadoKadeoManager.kkm.gameOver(Cs.game.stats);
			if (lastLaser != null) {
				lastLaser.removeMovieClip();
			}
			if (onde != null) {
				onde.removeMovieClip();
			}
			if (laserRay != null) {
				laserRay.removeMovieClip();
			}
		}
		super.kill();
	}

	public function checkBounds() {
		var c = -0.3;
		if (x < ray || x > Cs.mcw - ray) {
			vx *= c;
			x = Num.mm(ray, x, Cs.mcw - ray);
		}
		if (y < ray || y > Cs.mch - ray) {
			vy *= c;
			y = Num.mm(ray, y, Cs.mch - ray);
		}
	}
}

// LE RAYON d'INVICIBILITE A ETE CORRIGE
// FREQUENCE DE TIR ORANGE DIMINUE
// DEGAT DU TIR ORANGE AUGMENTE
// FEQUENCE DE TIR BLEU ( MISSILES ) AUGMENTE DE 20%
// AUGMENTATION DE LA ZONE DE L AURA ROSE

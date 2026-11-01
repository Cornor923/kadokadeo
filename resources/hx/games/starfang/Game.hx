package starfang;

import haxe.io.UInt16Array;
import common_haxe_avm1.KeyboardManager;
import mt.bumdum.Part;
import mt.bumdum.Sprite;
import mt.bumdum.Lib.Num;
import mt.DepthManager;
import mt.Timer;
import kado.KadoKadeoManager;
import kado.TouchControlsConfig.TouchControlsMode;
import kado.TouchControlsConfig.TouchButtonShape;

class DashlightSprite extends ASprite {
	public var multi:Float;
}

@:expose('GameStarfang')
class Game implements kado.GameInterface {
	// mobile: turn left / right, the up arrow thrusts, the fire button shoots (Space), the one at its left fires the second
	// weapon (down)
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
				id: "fire",
				label: "✦",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.SPACE,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "thrust",
				label: "▲",
				rightPx: 20,
				bottomPx: 90,
				size: 60,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "fire2",
				label: "✹",
				rightPx: 90,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.DOWN,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	public static var DP_INTERFACE = 12;
	public static var DP_SHOT = 10;
	public static var DP_PARTS = 9;
	public static var DP_BADS = 8;
	public static var DP_HERO = 7;
	public static var DP_DRAW = 5;
	public static var DP_UNDERPARTS = 3;
	public static var DP_BG = 3;

	public var stats:{
		b:Array<Int>,
		kb:Array<Int>, // kill with bonuses
		l:Array<Array<Int>>, // levels: 1 per level [asteroid1, asteroid2, asteroid3, asteroid4, asteroid5, shotCount, framesOnLevel]
	};

	var step:Int;
	var monsterlvl:Float;
	var phaseTimer:Float;
	var scrollDash:Float;
	var scrollSpeed:Float;
	var dashLightList:Array<DashlightSprite>;
	var bg:ASprite;
	var draw:ASprite;

	public var lvl:Int;
	public var flOption:Bool;
	public var shotList:Array<Shot>;
	public var badsList:Array<Bads>;
	public var bonusList:Array<Bonus>;
	public var dm:DepthManager;
	public var hero:Hero;
	public var root:ASprite;
	public var inter:Inter;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayKeys = new UInt16Array(13);
		replayKeys[0] = KeyboardManager.RIGHT;
		replayKeys[1] = KeyboardManager.DOWN;
		replayKeys[2] = KeyboardManager.LEFT;
		replayKeys[3] = KeyboardManager.UP;
		replayKeys[4] = KeyboardManager.SPACE;
		replayKeys[5] = KeyboardManager.CONTROL;
		replayKeys[6] = KeyboardManager.D;
		replayKeys[7] = KeyboardManager.S;
		replayKeys[8] = KeyboardManager.Q;
		replayKeys[9] = KeyboardManager.Z;
		replayKeys[10] = KeyboardManager.A;
		replayKeys[11] = KeyboardManager.W;
		replayKeys[12] = KeyboardManager.ENTER;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
		});

		Cs.game = this;
		dm = new DepthManager(root);
		this.root = root;

		shotList = new Array();
		badsList = new Array();
		bonusList = new Array();

		bg = dm.attach("mcBg", DP_BG);

		hero = new Hero(dm.empty(DP_HERO));
		hero.x = Cs.mcw * 0.5;
		hero.y = Cs.mch * 0.5;

		inter = new Inter(dm.empty(DP_INTERFACE));
		inter.h = hero;

		draw = dm.empty(DP_DRAW);
		stats = {
			b: [],
			kb: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			l: [],
		};

		lvl = 1;
		stats.l.push([0, 0, 0, 0, 0, 0, 0]);

		initStep(1);
	}

	function initStep(n) {
		step = n;
		switch (n) {
			case 1:
				var mc = new Part(dm.empty(DP_INTERFACE));
				var txt = mc.root.initTextField("txt", {
					font: "Orbitron",
					size: 60,
					color: 0xFFFFFF,
					align: "left",
				});
				mc.root._x = 0;
				mc.root._y = 0;
				txt.text = "SECTEUR " + lvl;
				mc.timer = 64;
				mc.fadeLimit = 20;
				mc.fadeType = 3;

				flOption = true;
				genMonsters();
			case 2:
				stats.l.push([0, 0, 0, 0, 0, 0, 0]);
				lvl++;
				if (hero != null) {
					hero.wings[0].trg = 0;
					hero.wings[1].trg = 0;
				}
			case 3:
				scrollDash = 0;
				scrollSpeed = 0;
				dashLightList = new Array();
			case _:
		}
	}

	public function update(delta:Float) {
		draw.clear();

		// SPRITE
		Sprite.updateAll();

		switch (step) {
			case 1: // PLAY;
				if (hero != null) {
					hero.control();
					stats.l[lvl - 1][6]++;
				}
				if (badsList.length == 0 && bonusList.length == 0)
					initStep(2);
			case 2:
				if (shotList.length == 0)
					initStep(3);
			// Log.print(speed)
			// Log.setColor(0x000000)
			case 3:
				var lim = 0.1;
				if (hero != null) {
					hero.angle -= Num.mm(-lim, hero.angle * 0.2, lim);
					hero.root._rotation = hero.angle / 0.0174;
					var ca = Math.max(0, Math.cos(hero.angle));
					hero.mainFlameTrg = Math.max(0, ca * 100);
					var center = {x: Cs.mcw * 0.5, y: Cs.mch * 0.5};
					hero.toward(center, 0.1, KadoKadeoManager.I(3));
					var f = Math.pow(0.9, Timer.tmod);
					hero.vx *= f;
					hero.vy *= f;
					scrollDash += Timer.tmod;
					scrollSpeed = ca * Math.max(KadoKadeoManager.I(20) - hero.getDist(center), 0) + scrollDash;
					Cs.game.hero.launchSparks(0, Std.int(Math.min(scrollSpeed * 0.1, 5)), scrollSpeed * 0.1);
				}
				if (scrollDash >= 100)
					initStep(4);
				scrollBg();
				updateDashLight();
			case 4:
				if (hero != null) {
					var center = {x: Cs.mcw * 0.5, y: Cs.mch * 0.5};
					hero.toward(center, 0.1, KadoKadeoManager.I(3));
					Cs.game.hero.launchSparks(0, Std.int(Math.min(scrollSpeed * 0.1, 5)), scrollSpeed * 0.1);
				}
				scrollSpeed *= Math.pow(0.95, Timer.tmod);
				scrollBg();
				updateDashLight();
				if (dashLightList.length == 0) {
					initStep(1);
				}
			case _:
		}

		#if debug
		for (n in 65...83) {
			if (KeyboardManager.isDown(n)) {
				var bonus = new Bonus(dm.attach("mcBonus", Game.DP_SHOT));
				bonus.id = n - 65;
				bonus.root.gotoAndStop(bonus.id + 1);
				bonus.x = 20;
				bonus.y = 20;
			}
		}
		#end
	}

	public function destroy() {}

	function genMonsters() {
		var dif:Float = lvl * 14 - 8;
		var asteroids = new Array<Asteroid>();
		while (dif > 0) {
			if (Seed.random(2) == 0) {
				var type = Std.int(Math.min(Seed.random(Std.int(lvl * 0.5)), 4));
				var m = new Asteroid(dm.attach("mcAsteroid" + (type + 1), DP_BADS));
				var max = Math.min(Math.pow(lvl - type, 0.5), 3);
				var size = 2 + Seed.random(Std.int(max));
				m.setInfo(type, size);
				m.initStartPosition();
				asteroids.push(m);
				dif -= m.dif;
			}
		}
		for (m in asteroids) {
			m.reserveBonus();
		}
	}

	//

	function scrollBg() {
		bg._x -= scrollSpeed;
		if (bg._x < -KadoKadeoManager.I(900)) {
			bg._x += KadoKadeoManager.I(900);
			bg._prevState.x = bg._x + scrollSpeed;
		}
	}

	function spawnDashLight() {
		if (Seed.randomVfx(2) == 0)
			return;
		var mc:DashlightSprite = cast dm.attach("mcDashLight", DP_PARTS);
		mc._x = Cs.mcw + Seed.randVfx() * KadoKadeoManager.I(100);
		mc._y = Seed.randVfx() * Cs.mch;
		mc._yscale = 50 + Seed.randVfx() * 50;
		mc._xscale = mc._yscale;

		mc.multi = 1 + Seed.randVfx() * 3;
		dashLightList.push(mc);
	}

	function updateDashLight() {
		for (i in 0...Std.int(scrollSpeed * 0.1)) {
			spawnDashLight();
		}
		var i = 0;
		while (i < dashLightList.length) {
			var mc = dashLightList[i];
			mc._x -= scrollSpeed * (mc._yscale / 100);
			mc._xscale = mc._yscale + Math.max(scrollSpeed - KadoKadeoManager.I(30), 0) * 10 * mc.multi;
			mc._alpha -= 4 * (mc._yscale / 100) * Timer.tmod;
			if (mc._x < -mc._width || mc._alpha < 3) {
				mc.removeMovieClip();
				dashLightList.splice(i, 1);
				continue;
			}
			i++;
		}
	}
}

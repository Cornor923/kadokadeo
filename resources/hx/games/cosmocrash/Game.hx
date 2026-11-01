package cosmocrash;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import cosmocrash.Cs.Num;
import cosmocrash.MC.Plans;
import pixi.core.Pixi.BlendModes;

// a star of the sky / a piece of the decor of the horizon: its parallax factor and its position (the clip is placed
// on it)
typedef Star = {mc:MC, c:Float, x:Float, y:Float, w:Float};

// Game.hx of the original (Haxe for Flash 8), line by line; the port's own parts are at the end
@:expose('GameCosmoCrash')
class Game implements kado.GameInterface {
	// left / right turn the ship, up thrusts (and takes off)
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
				id: "up",
				label: "▲",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	// ZQSD / WASD move like the arrows
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	// Flash played Cosmo Crash at 40 frames/s (the rate of the SWF and of the KadoKado loader) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	public static var DP_FX = 14;

	public static var DP_FOLK = 13;
	public static var DP_GROUND = 12;
	public static var DP_SHUTTLE = 10;

	public static var DP_VEHICULE = 8;
	public static var DP_HERO = 6;
	public static var DP_PLAT = 4;

	public static var DP_UNDER_FX = 2;

	public static var DP_BG = 0;

	public var focus:Element;

	public var dif:Float;

	var scrx:Null<Float>;
	var scry:Null<Float>;

	public var flRescue:Bool;

	public var fuel:Float;
	public var glow:Null<Float>;
	public var endTimer:Null<Int>;
	public var learnTimer:Int;
	public var step:Int;
	public var opt:Int;
	public var lag:Int;
	public var seed:mt.Rand;

	public var hero:Hero;
	public var top:Array<Int>;
	public var elements:Array<Element>;
	public var plats:Array<Plat>;
	public var starField:Array<Star>;
	public var groundField:Array<Star>;
	public var sgrid:Array<Array<Array<Shot>>>;

	public var vehicules:Array<Vehicule>;
	public var folks:Array<Folk>;

	public static var me:Game;

	// mdm: the planes of the game's clip; dm: the planes of the map (the original drew the map into the screen bitmap,
	// see MC)
	public var mdm:Plans;
	public var dm:Plans;
	public var root:ASprite;
	public var gyro:MC;
	public var mcHor:MC;

	// port
	var isReplay:Bool;
	var screen:ASprite;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	// the camera of the last two Flash frames (display)
	var camX:Float = 0;
	var camY:Float = 0;
	var pcamX:Float = 0;
	var pcamY:Float = 0;
	// Filt.glow(gyro, 8, st, 0xFFFFFF) and gyro.blendMode = "add"
	var gyroGlow:FlashGlow;
	// the score of KKApi (setScore / addScore), nothing after the game over
	var score:Int = 0;
	var over:Bool = false;
	#if debug
	// test harness: events of the game (coverage)
	public var stats = {crashes: 0, launches: 0, loops: 0, shots: 0, lowFuel: 0};
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(3);
		keys[0] = KeyboardManager.LEFT;
		keys[1] = KeyboardManager.RIGHT;
		keys[2] = KeyboardManager.UP;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		MC.clearAll();
		Clip.reset();
		// mt.Timer before its first update (Manager.init creates the game before the first Manager.main)
		Timer.tmod = 1;
		Clip.deferring = true;

		Cs.init();
		// the original's 300x300 pixels, drawn x2
		root = mc.createEmptyMovieClip("scene", 0);
		root._xscale = root._yscale = 100 * Clip.K;
		root.updateState();
		me = this;
		mdm = new Plans(root);

		// mcBg drawn into a 10 x 10 bitmap, shown at 3000 % without smoothing (attachBitmap)
		initBg();

		flRescue = true;

		opt = 0;
		lag = 0;

		initScreen();
		initMap();

		elements = [];
		vehicules = [];
		folks = [];

		initStarField();
		initGrid();
		initInter();

		hero = new Hero();

		learnTimer = 600;
		step = 0;

		fuel = 100;
		dif = 0;

		for (i in 0...12)
			new Folk();

		initHor();

		Clip.deferring = false;
		Clip.runLater();
		// the first picture: the camera of the first frame
		camera();
		pcamX = camX;
		pcamY = camY;
		displayCamera(1);
		MC.displayAll(1);
		// Flash shows the first picture after the first frame (Manager.init, then Manager.main): nothing before (the
		// horizon and the stars are placed by display(), the flames hidden by the hero's update)
		root.visible = false;
		warmShaders();
	}

	function initMap() {
		dm = new Plans(screen, null, true);

		genLevel();
	}

	function initGrid() {
		sgrid = [];
		for (x in 0...Cs.XMAX) {
			sgrid[x] = [];
			for (y in 0...Cs.YMAX) {
				sgrid[x][y] = [];
			}
		}
	}

	public function origUpdate() {
		if (learnTimer > 0)
			learnTimer--;
		switch (step) {
			case 0:
				if (!flRescue)
					updateDif();
			case 1:
				updateSpawn();
		}

		if (endTimer != null && endTimer-- == 0) {
			gameOver();
		}

		optimize();
		updateSprites();
		updateInter();
		updateHor();
		display();
	}

	function updateSprites() {
		var a = elements.copy();
		for (sp in a)
			sp.update();
	}

	// DIF
	public function updateDif() {
		if (hero == null)
			return;
		dif++;
		var vmax = dif * 0.0018 - 2;
		if (vehicules.length < vmax) {
			new Vehicule();
		}
		if (Seed.random(200) == 0) {
			var sum = 0;
			for (f in folks)
				if (f.step == 1)
					sum++;
			for (i in sum...Std.int(12 + vmax * 2)) {
				var f = new Folk();
				f.x = getFarAwayX();
			}
		}
	}

	// LEVEL
	// (the topography and the platforms come from mt.Rand(0): the same level in every game. The bitmap of the ground
	// (rocks and dirt drawn into bmpLevel with the next draws of the same generator) is drawn by the asset pipeline from
	// the same calls: cosmocrash_level.py, anim "ground")
	function genLevel() {
		seed = new mt.Rand(0);

		for (i in 0...Data.GROUND_TILES) {
			var t = dm.attach(Clip.GROUND + i, DP_GROUND);
			t._x = i * Data.GROUND_TILE;
			t._y = Data.GROUND_Y;
			t.cx0 = Data.GROUND_TILE / 2;
			t.cullR = Data.GROUND_TILE / 2 + 10;
		}

		//
		genTop();

		// PLATS
		var ec = 8;
		plats = [];
		var to = 0;
		var m = 150;
		for (i in 0...3) {
			while (true) {
				var x = m + seed.random(Cs.lw - 2 * m);
				var flAdd = true;
				for (pl in plats)
					if (Math.abs(pl.x - x) < 300)
						flAdd = false;
				if (flAdd) {
					var px = Std.int(x / Cs.PW);
					var ly = Math.max(top[px], top[(px + 1) % Cs.PMAX]);
					var y = Cs.lh - Std.int(ly * ec + 50 + seed.rand() * 50);
					var p = new Plat(x, y, 25 + i * 25);
					var s = p.skin.sub("rampe");
					s = s != null ? s.getClip("shuttle") : null;
					if (s != null)
						s.gotoAndStop("bat");
					break;
				}
				if (to++ > 100) {
					break;
				}
			}
		}
		#if debug
		// the pictures of the ground were drawn for this level
		if (top.join(",") != Data.LEVEL_TOP.join(","))
			throw "level: top differs from the pictures";
		for (i in 0...3) {
			var d = Data.LEVEL_PLATS[i];
			var p = plats[i];
			if (p.x != d[0] || p.y != d[1] || p.ray != d[2] || p.rampeX != d[3])
				throw "level: platform " + i + " differs from the pictures";
		}
		#end
	}

	function genTop() {
		// TOPOGRAPHIE
		var st = 3;
		top = [];
		for (i in 0...Cs.PMAX)
			top.push(st);

		// PIC
		var ray = 2;
		for (i in 0...Cs.PMAX) {
			var index = seed.random(Cs.PMAX);
			for (dx in 0...ray * 2 + 1) {
				var ind = Std.int(Num.sMod(index + dx - ray, Cs.PMAX));
				top[ind] += 1 + ray - Std.int(Math.abs(dx - ray));
			}
		}

		// APPLANIE
		var hmax = 25;
		var lim = 5;
		var prev = top[Cs.PMAX - 1];
		for (i in 0...Cs.PMAX) {
			if (top[i] > hmax)
				top[i] = hmax;

			var dif = top[i] - prev;
			if (dif > lim)
				top[i] += lim - dif;
			if (dif < -lim)
				top[i] += -lim - dif;
			prev = top[i];
		}
	}

	// SCREEN
	function initScreen() {
		screen = mdm.get(1);
	}

	// the camera of the original's display() (the screen shows the map from (x, y)) and the parallax of the sky and the
	// horizon; the map itself is placed by MC.displayAll
	function display() {
		var mult = 1;

		var vision = 1;

		var fx = focus.x + focus.vx * vision;
		var fy = focus.y + focus.vy * vision + 30;
		var x = Num.sMod(fx - Cs.mcw * 0.5, Cs.lw);
		var y = Num.mm(0, fy - Cs.mch * 0.5, Cs.lh - Cs.mch);
		x = Std.int(x / mult) * mult;
		y = Std.int(y / mult) * mult;

		//
		// HORIZON

		var hh = Cs.lh - Cs.mch;
		var c = scry == null ? Math.NaN : scry / hh;
		var h = 120 - c * 54;
		mcHor._y = Cs.mch - 80;
		mcHor.setSub("smc", null, null, null, h);

		// STARFIELD
		if (scrx != null) {
			var vx = Num.hMod(x - scrx, Cs.lw * 0.5);
			var vy = Num.hMod(y - scry, Cs.lw * 0.5);
			for (mc in starField) {
				mc.x = Num.sMod(mc.x - vx * mc.c, Cs.mcw);
				mc.y = Num.sMod(mc.y - vy * mc.c, Cs.mch);
				mc.mc._x = mc.x;
				mc.mc._y = mc.y;
			}

			for (mc in groundField) {
				mc.x -= vx * mc.c;
				if (mc.x - mc.w * 0.5 > Cs.mcw)
					mc.x -= mc.w + Cs.mcw;
				if (mc.x + mc.w * 0.5 < 0)
					mc.x += mc.w + Cs.mcw;
				mc.y = mcHor._y + mc.c * h;
				mc.mc._x = mc.x;
				mc.mc._y = mc.y;
			}
		}
		scrx = x;
		scry = y;

		// (port: bmpScreen.draw(map, -x, -y), and again one map width further when the screen crosses the end of the map)
		pcamX = camX;
		pcamY = camY;
		camX = x;
		camY = y;
	}

	// INTER
	function initInter() {
		gyro = mdm.attach("mcGyro", 2);
		var m = 16;
		gyro._x = Cs.mcw - m;
		gyro._y = m;
		gyroGlow = new FlashGlow(8, 8, 1.2, 0xFFFFFF);
		gyroGlow.blendMode = BlendModes.ADD;
	}

	function updateInter() {
		// (no hero: hero.root._rotation, hero.vx... are undefined, NaN: the gyroscope keeps its needles)
		var h = hero;
		var hr = h != null ? h.root._rotation : Math.NaN;
		setStab(hr);
		var rot = Math.abs(hr);
		var speed = h != null ? Math.sqrt(h.vy * h.vy + h.vx * h.vx) : Math.NaN;
		var vec = gyro.sub("vector");
		if (vec != null)
			vec.stop();
		var c = speed / (Cs.LAND_SPEED_LIMIT * 2);
		// gyro.stab.smc._yscale = c * 100: the square masked by the disc of stab, drawn as the picture of that band
		// (anim 'gyroBand': half height of 0 to 11 Flash pixels by texture pixels; NaN without hero: unchanged)
		var stab = gyro.sub("stab");
		var band:Clip.Gfx = stab != null ? cast stab.get("smc") : null;
		if (band != null && Math.isFinite(c)) {
			var n = band.frames.length - 1;
			band.show(Std.int(Math.max(0, Math.min(1, c)) * n + 0.5) + 1);
		}

		// ([...][hero.danger]: undefined before the hero's first flight and without hero, Col.setColor(gyro, undefined)
		// gives black, glow included: nothing shows once added)
		var d = h != null ? h.danger : null;
		var col:Null<Int> = d == null ? null : [0x00FF00, 0xFFFF00, 0xFF0000][d];

		var st = 1.2;
		if (fuel < 20) {
			#if debug
			if (glow == null)
				stats.lowFuel++;
			#end
			if (glow == null)
				glow = 0;
			glow = (glow + 77) % 628;
			var c = (Math.sin(glow * 0.01) + 1) * 0.5;
			st = 1.2 + c * 2;
			col = 0xFF0000;
			gyro._visible = !gyro._visible;
			if (h != null)
				Cs.setPercentColor(h.root, c * 100, 0xFF0000);
		} else {
			if (glow != null) {
				glow = null;
				gyro._visible = true;
				if (h != null)
					Cs.setPercentColor(h.root, 0, 0xFF0000);
			}
		}

		// Col.setColor(gyro, col): multiply 100 %, offset col - 255: on these pictures (each channel 0 or 255) the same as
		// a tint by col. Flash applies the colour transform of the clip after its filters: the white glow is coloured too
		// (the original's gauge: red and blue stay those of the sky inside the green disc), the same as a glow of colour
		// col under the tinted pictures (a tint multiplies each channel)
		var tint = col == null ? 0 : col;
		gyro.clip.setColour(tint, 0);
		gyroGlow.set(8, 8, st);
		gyroGlow.setColor(tint);
		gyro.clip.filters = [gyroGlow];
	}

	// gyro.stab._rotation = hero.root._rotation (the hero turns by steps of 10 degrees: not interpolated)
	function setStab(r:Float) {
		var s = gyro.sub("stab");
		if (s == null || !Math.isFinite(r))
			return;
		gyro.setSub("stab", null, null, null, null, r);
		if (s._prevState != null)
			s._prevState.rotation = s._curState.rotation;
	}

	public function incFuel(n:Float) {
		fuel += n;

		if (fuel < 0)
			fuel = 0;
		if (fuel > 100)
			fuel = 100;

		var vec = gyro.sub("vector");
		if (vec != null)
			vec.gotoAndStop(Std.int(40 * fuel / 100) + 1);
	}

	public function stopRescue() {
		if (!flRescue)
			return;
		flRescue = false;
		var inf = gyro.sub("inf");
		if (inf != null)
			inf.play();
	}

	// TOOLS
	public function getGY(x:Null<Float>):Float {
		if (x == null)
			return 0;
		var x = Num.sMod(x, Cs.lw);

		var px = Std.int(x / Cs.PW);
		var c = x / Cs.PW - px;
		var sy = top[px];
		var ey = top[(px + 1) % Cs.PMAX];
		return Cs.lh - Std.int((sy * (1 - c) + ey * c) * Cs.EC);
	}

	public function getFarAwayX():Int {
		var hx:Null<Float> = hero != null ? hero.x : null;
		if (hx == null)
			hx = Seed.random(Cs.lw);
		return Std.int(Num.sMod(hx + Cs.lw * 0.5 + (Seed.rand() * 2 - 1) * 200, Cs.lw));
	}

	public function getHeroDX(ex:Float):Float {
		if (hero == null)
			return 100;
		return Num.hMod(hero.x - ex, Cs.lw * 0.5);
	}

	// HORIZON
	public function initHor() {
		mcHor = mdm.attach("mcHor", 0);
		updateHor();
		groundField = [];
		var max = 40;
		for (i in 0...max) {
			// (mcDecor on frame i + 1, its smc on frame i + 1: one picture each, decor<i>)
			var mc = mdm.attach("decor" + i, 0);
			var w = Data.DECOR_WIDTH[i];
			mc.wrapX = w + Cs.mcw;
			// (a position on the screen: only pictures, visual random)
			var s:Star = {
				mc: mc,
				c: 0.05 + (i / max) * 0.95,
				x: Seed.randVfx() * Cs.mcw + w - w * 0.5,
				y: 0,
				w: w
			};
			groundField.push(s);
		}
	}

	public function updateHor() {}

	// SPAWN
	public function spawn() {
		step = 1;
		learnTimer = 30;
		setScore(KKApi.const(0));
	}

	public function updateSpawn() {
		if (learnTimer == 0) {
			step = 0;
			hero = new Hero();
			fuel = 100;
		}
	}

	// FX
	public function initStarField() {
		starField = [];
		var max = 25;
		for (i in 0...max) {
			var c = 0.25 + (i / max) * 0.75;
			var mc = mdm.attach("mcStar", 0);
			mc.wrapX = Cs.mcw;
			mc.wrapY = Cs.mch;
			// (only pictures: visual random)
			starField.push({
				mc: mc,
				x: Seed.randVfx() * Cs.mcw,
				y: Seed.randVfx() * Cs.mch,
				c: c,
				w: 0
			});
		}
	}

	public function fxScore(x:Float, y:Float, n:Int) {
		var p = new Part(dm.attach("fxScore", DP_FX));
		p.x = x;
		p.y = y;
		// placed now: the display interpolates its first frame from the clip's position, not from (0, 0)
		p.updatePos();
		p.weight = -0.03;
		p.frict = 0.95;
		p.timer = 30;
		// Reflect.setField(p.root, "_sc", n): the text field of its smc shows it
		var smc = p.root.clip.get("smc");
		if (smc != null) {
			var d = new Digits();
			d.setText(Std.string(n));
			smc.addChild(d);
		}
		p.root.clip.filters = [new FlashGlow(2, 2, 4, 0x000044)];
	}

	public function getDust(?x:Float):Part {
		var p = new Part(dm.attach("partDust", DP_FX));
		if (x != null) {
			p.x = x;
			p.y = getGY(x);
			p.updatePos();
		}
		// (only pictures: visual random)
		p.frict = 0.92;
		p.weight = 0.01 + Seed.randVfx() * 0.04;
		p.timer = 10 + Seed.randVfx() * 30;
		p.root._xscale = p.root._yscale = 100 + Seed.randomVfx(100);
		return p;
	}

	// OPTIMISATION (mt.Timer.tmod settles on 32 / 40 at 40 frames/s: never more than 1.5)
	public function optimize() {
		if (Timer.tmod > 1.5)
			opt++;
		else if (opt > 0)
			opt--;
		if (opt > 10) {
			opt = 0;
			if (groundField.length > 6)
				groundField.pop().mc.removeMovieClip();
			if (starField.length > 6)
				starField.pop().mc.removeMovieClip();
			lag++;
		}
	}

	// ---------------------------------------------------------------- port
	// mcBg drawn into a 10 x 10 BitmapData (Data.BG) and attached at 3000 %: Flash shows a bitmap attached without
	// smoothing, so the 100 pixels are big squares
	function initBg() {
		var cv:js.html.CanvasElement = cast js.Browser.document.createElement("canvas");
		cv.width = 10;
		cv.height = 10;
		var ctx = cv.getContext2d();
		var img = ctx.createImageData(10, 10);
		for (i in 0...100) {
			var c = Data.BG[i];
			img.data[i * 4] = (c >> 16) & 0xFF;
			img.data[i * 4 + 1] = (c >> 8) & 0xFF;
			img.data[i * 4 + 2] = c & 0xFF;
			img.data[i * 4 + 3] = 255;
		}
		ctx.putImageData(img, 0, 0);
		var tex = pixi.core.textures.Texture.from(cv);
		tex.baseTexture.scaleMode = pixi.core.Pixi.ScaleModes.NEAREST;
		var bg = new ASprite();
		bg.texture = tex;
		bg._xscale = bg._yscale = 3000;
		bg.updateState();
		mdm.get(0).addChild(bg);
	}

	// KKApi.addScore / setScore: nothing after the game over
	public function addScore(n:Int) {
		setScore(score + n);
	}

	function setScore(n:Int) {
		if (over)
			return;
		var d = n - score;
		score = n;
		if (d != 0)
			KadoKadeoManager.kkm.addScore(d);
	}

	// KKApi.gameOver({})
	function gameOver() {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	// the glow filter compiles its shader now, not at the first vehicle
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null)
			return;
		var holder = new pixi.core.display.Container();
		var s = new pixi.core.sprites.Sprite(pixi.core.textures.Texture.WHITE);
		var g = new FlashGlow(3, 3, 1, 0xFFFFFF);
		g.blendMode = BlendModes.ADD;
		s.filters = [new FlashGlow(3, 3, 1, 0x000000), g];
		holder.addChild(s);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

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
		displayCamera(frameAcc / 4);
		MC.displayAll(frameAcc / 4);
	}

	// one Flash frame: the timelines advance, then Manager.main (tmod ~0.8: Timer settles on 32 / 40), then the frame
	// scripts the code triggered
	function flashFrame() {
		Timer.tmod = 32 / FLASH_FPS;
		MC.frameStart();
		Clip.deferring = true;
		origUpdate();
		Clip.deferring = false;
		Clip.runLater();
		frameCount++;
		root.visible = true;
		#if debug
		untyped js.Browser.window.__state = debugState();
		#end
	}

	// the camera shown: one Flash frame late, like the clips (MC)
	function displayCamera(f:Float) {
		MC.camX = pcamX + Num.hMod(camX - pcamX, Cs.lw * 0.5) * f;
		MC.camY = pcamY + (camY - pcamY) * f;
	}

	// the camera of display() without the parallax (the first picture, before the first frame)
	function camera() {
		var fx = focus.x + focus.vx;
		var fy = focus.y + focus.vy + 30;
		camX = Std.int(Num.sMod(fx - Cs.mcw * 0.5, Cs.lw));
		camY = Std.int(Num.mm(0, fy - Cs.mch * 0.5, Cs.lh - Cs.mch));
	}

	#if debug
	// state compared between a game and its replay (test harness)
	function debugState():Dynamic {
		var fx = 0.0;
		for (f in folks)
			fx += f.x * 7 + f.y;
		var vxs = 0.0;
		for (v in vehicules)
			vxs += v.x;
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: score,
			hx: hero != null ? hero.x : null,
			hy: hero != null ? hero.y : null,
			fuel: fuel,
			dif: dif,
			rescue: flRescue,
			folks: folks.length,
			fsum: Math.round(fx * 1000) / 1000,
			veh: vehicules.length,
			vsum: Math.round(vxs * 1000) / 1000,
			elements: elements.length,
			lvl: [for (p in plats) p.shuttleLevel].join(","),
			stats: haxe.Json.stringify(stats),
			cap: [for (p in plats) p.capacity].join(","),
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
						var sub = c.getClip(k);
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
		me = null;
		MC.clearAll();
		Clip.reset();
	}
}

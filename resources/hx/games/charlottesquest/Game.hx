package charlottesquest;

import haxe.io.UInt16Array;
import common_haxe_avm1.display.ASprite;
import kado.TouchControlsConfig;

// Charlotte's Quest (Arkadeo, Motion Twin, 600 x 460 at 30 frames/s), its League: Charlotte flies on her unicorn through
// rooms that scroll by themselves, shoots hearts at the monsters of her nightmares, picks up the notes they drop and the
// power-ups of the "?" chests; the rooms come without end, harder and harder. The code is the original (Haxe 2, AS3) on the
// AS3 display list of the lib (arkadeo); this class is the Game of the original and the game KadoKadeo creates, steps and
// records (the keys, the mouse and its button) instead of the Arkadeo loader (AKApi).
//
// What changes from the original, and why:
//  - the LvUP campaign (20 levels, the shop of Jessicat, the coins, the alarm clock of the end, Ellon at the level 20),
//    and the in-game prizes of Arkadeo (it.KPoint) are not ported: the code of the League only;
//  - the inputs: the keys (arrows / ZQSD / WASD, Ctrl / Space to shoot, U for the mouse controls of the original) and
//    the mouse (its position and the left button: AKApi.getCustomValue / isClicked) polled at each step of KadoKadeo
//    and recorded; a touch screen has a joystick (8 directions, the arrows) and a button (Space);
//  - the random: the seed of the game (AKApi.getSeed) is drawn from the seed of KadoKadeo, the generators of the
//    original (mt.Rand: the game's, each room's, each entity's, each wave's) are kept on it; what only changes the look
//    (the effects, the random frames of the animations) on the random of the effects (Seed.*Vfx);
//  - the trigonometry that moves the game rounded to 1/65536 (Game.cos / sin / atan2): the same game in every browser;
//  - no low quality (AKApi.getRealFramerate): the effects of a fast machine (perf 1: the plasma of the background, the
//    puffs of the enemies), they never depend on the machine;
//  - the plans of the rooms are read from Data.hx (levels.png in the original), the animations Entity.cacheAnims drew
//    into bitmaps are pictures of the sheet drawn the same way by the asset pipeline;
//  - haxe.Timer.delay (the texts that pop) counted in frames of the game.
@:expose('GameCharlottesQuest')
class Game extends Sprite implements kado.GameInterface {
	public static var ME:Game;
	public static inline var WID = 600;
	public static inline var HEI = 460;
	public static var TW:Tweenie;
	static var MAP_SIZE = 100;
	static inline var SCROLL_SPEED_LEAGUE = 16; // x10
	public static inline var RAINBOW_SCALE = 6;

	static var RAINBOW_LOSS:ColorTransform = null;

	// the depths of the original (uniq++: 0 to 12); uniq goes on for the ids of the entities
	public static inline var DP_BG = 0;
	public static inline var DP_LEVEL = 1;
	public static inline var DP_CHESTS = 2;
	public static inline var DP_FX = 3;
	public static inline var DP_ITEM = 4;
	public static inline var DP_ENEMY = 5;
	public static inline var DP_SHADOW = 6;
	public static inline var DP_PLAYER = 7;
	public static inline var DP_TEXTS = 8;
	public static inline var DP_BULLET = 9;
	public static inline var DP_SHOP_BG = 10;
	public static inline var DP_INTERF = 11;
	public static inline var DP_MASK = 12;
	static inline var DEPTHS = 13;

	public static var uniq = DEPTHS;

	// the keys of the original (ZQSD / WASD: the arrows, KeyboardManager.ALIASES_MOVE), U: the mouse controls
	static inline var KEY_U = 85;

	public static var KEY_ALIASES:Array<Dynamic> = KeyboardManager.ALIASES_MOVE;

	public static var TOUCH_CONTROLS:TouchControlsConfig = {
		mode: TouchControlsMode.JOYSTICK,
		joystick: {
			x: 0.16,
			y: 0.78,
			radius: 54,
			deadZone: 0.2,
			dynamicCenter: true,
			directions: 8,
		},
		buttons: [
			{
				id: "shoot",
				label: "❤",
				rightPx: 16,
				bottomPx: 16,
				size: 84,
				keyCode: KeyboardManager.SPACE,
			}
		],
	};

	// the game runs at 30 frames/s and KadoKadeo steps it 32 times a second: 15 frames every 16 steps
	public static inline var FPS = 30;
	static inline var STEPS_PER_SECOND = 32;

	public var seed:Int;
	public var rseed:Rand;
	public var time:Float;
	public var absoluteTime:Float;
	public var perf:Float;
	public var ended:Bool;
	public var shopping:Bool;
	public var lockControls:Bool;
	public var rendering:Bool;
	public var skipFrames:Int;

	public var fx:Fx;

	public var scroller:Sprite;
	public var dm:DepthManager;
	public var sdm:DepthManager;
	public var viewport:Rectangle;
	public var lastScroll:{x:Float, y:Float};

	public var map:Map<String, Room>;
	public var curRoom:Room;
	public var nextUber:Int;
	public var powerUpSpread:Array<Int>;

	public var player:Player;
	public var bullets:List<Bullet>;
	public var enemies:List<Enemy>;
	public var items:List<Entity>;
	public var killList:List<Entity>;

	public var nextWave:Int;
	public var glevel:Int;
	public var diff:Float;
	public var skill:Float;
	public var corridorLen:Int;
	public var scrollSpeedFact:Float;

	public var bgColor:Int;
	public var plasmaBg:Bitmap;
	public var plasma:BitmapData;
	// (the noise of the plasma, exact pixels: plasma is its blur, drawn on the GPU)
	public var plasmaSrc:BitmapData;
	public var plasmaAlpha:Float;
	public var plasmaSettings:{dx:Float, dy:Float, w:Int, h:Int};
	public var ptime:Int;

	public var rainbow:Bitmap;

	public var mouseControls:Bool;
	public var cursor:Sprite;
	public var xm:Int;
	public var ym:Int;

	// ---------------------------------------------------------------- KadoKadeo
	public var isReplay(default, null):Bool;
	public var frameCount(default, null):Int;
	public var over(default, null):Bool;

	var frameAcc:Int;
	var gameMask:pixi.core.graphics.Graphics;
	var onPointerDown:Dynamic->Void;
	// (AKApi.isToggled(U)) the key U at the previous frame
	var uWas:Bool;
	// (haxe.Timer.delay) the calls waiting for their frame
	var delayed:Array<{t:Int, cb:Void->Void}>;
	// (OVERLAY of the plasma over the background) the filter of plasmaBg
	var plasmaFilter:PlasmaOverlay;

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		super();
		this.isReplay = isReplay;

		var buttons = new UInt16Array(1);
		buttons[0] = MouseManager.BUTTON_LEFT;
		var keys = new UInt16Array(7);
		for (i => k in [KeyboardManager.LEFT, KeyboardManager.RIGHT, KeyboardManager.UP, KeyboardManager.DOWN, KeyboardManager.SPACE,
			KeyboardManager.CONTROL, KEY_U])
			keys[i] = k;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: buttons,
		});

		resetStatics();
		frameAcc = FPS;
		frameCount = 0;
		over = false;
		uWas = false;
		delayed = [];

		Tex.init("/charlottesquest");
		Clip.init(Data.clips);
		TextField.init(Data.fonts);

		mc.addChild(node);
		// the game area of Arkadeo (600 x 460): what goes out of it is not drawn (under the bar of KadoKadeo)
		gameMask = new pixi.core.graphics.Graphics();
		gameMask.beginFill(0xFFFFFF);
		gameMask.drawRect(0, 0, WID, HEI);
		gameMask.endFill();
		mc.addChild(gameMask);
		node.mask = gameMask;

		// the mouse stays with the game while the button is held (Flash kept it out of the stage)
		if (!isReplay) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null) {
				onPointerDown = function(e:Dynamic) {
					try {
						canvas.setPointerCapture(e.pointerId);
					} catch (_:Dynamic) {}
				};
				canvas.addEventListener("pointerdown", onPointerDown);
			}
		}

		ME = this;

		// (AKApi.getSeed: a seed of KadoKadeo)
		seed = Seed.random(0x3FFFFFFF);
		#if debug
		// (cqcmp.mjs: the seed of the AKApi of the Arkadeo HTML5 port, to play the same game, &cqseed=<n>)
		var cs = new js.html.URLSearchParams(js.Browser.window.location.search).get("cqseed");
		if (cs != null)
			seed = Std.parseInt(cs);
		#end
		rseed = new Rand(0);
		rseed.initSeed(seed);
		fx = new Fx();
		scrollSpeedFact = 0;
		skill = 0;
		nextUber = -1;
		powerUpSpread = [];

		xm = ym = 0;

		skipFrames = 40;

		shopping = false;
		lockControls = true;
		perf = 1;
		time = 0;
		absoluteTime = -1; // incrément en début de frame
		ptime = 0;
		map = new Map();
		nextWave = 40 * 5;
		glevel = 1;
		diff = glevel;
		TW = new Tweenie();
		bullets = new List();
		enemies = new List();
		items = new List();
		killList = new List();
		lastScroll = {x: 0, y: 0}
		ended = false;

		dm = new DepthManager(this);
		scroller = new Sprite();
		dm.add(scroller, DP_LEVEL);
		sdm = new DepthManager(scroller);

		// Curseur de souris
		var spr = new Sprite();
		spr.graphics.lineStyle(2, 0xFF97FF, 1);
		spr.graphics.drawCircle(0, 0, 7);
		spr.filters = [new GlowFilter(0xFF48FF, 0.6, 8, 8, 2),];
		cursor = new Sprite();
		cursor.addChild(Lib.flatten(spr, 4, true));
		dm.add(cursor, DP_INTERF);
		setMouseControls(false);

		player = new Player();

		viewport = new Rectangle(0, 0, WID, HEI);

		// Réglages plasma
		rseed.initSeed(seed);
		do {
			bgColor = Color.randomColor(rseed.rand(), rseed.range(0.5, 0.7), rseed.range(0.2, 0.3));
		} while (Color.getRgbRatio(bgColor).g > 0.7);
		var bgColor2 = Color.randomColor(rseed.rand(), 0.3, rseed.range(0.3, 0.5));
		var pow2 = [8, 16, 32, 64];
		plasmaSettings = {
			dx: rseed.range(0, 0.8, true),
			dy: rseed.range(0, 0.8, true),
			w: pow2.splice(rseed.random(pow2.length), 1)[0],
			h: -1,
		}
		if (plasmaSettings.w >= 64)
			pow2.remove(8);
		if (plasmaSettings.w <= 8)
			pow2.remove(64);
		plasmaSettings.h = pow2.splice(rseed.random(pow2.length), 1)[0];

		// Bg plasma
		var gradient:Array<Int> = [Color.interpolateInt(bgColor, 0x0, 0.8), bgColor, bgColor2,];
		if (rseed.random(100) < 20)
			gradient.reverse();
		var bg = new Sprite();
		var m = new Matrix();
		m.createGradientBox(WID, HEI, 90 * 3.14 / 180);
		bg.graphics.beginGradientFill(GradientType.LINEAR, gradient, [1, 1, 1], [0, 160, 255], m);
		bg.graphics.drawRect(0, 0, WID, HEI);
		plasmaBg = new Bitmap(new BitmapData(WID, HEI, false, 0x0));
		dm.add(plasmaBg, DP_BG);
		plasmaBg.bitmapData.draw(bg);

		// Etoiles
		rseed.initSeed(seed);
		var s = 3;
		var perlin = new BitmapData(Math.ceil(WID / s), Math.ceil(HEI / s), false, 0x0);
		perlin.perlinNoise(Std.int(200 / s), Std.int(128 / s), 1, seed, false, false, 1, true);
		var star = new Sprite();
		star.graphics.beginFill(0xffffff, 1);
		star.graphics.drawRect(0, 0, 2, 2);
		star.filters = [new GlowFilter(bgColor2, 0.8, 8, 8, 4, 2)];
		var star = Lib.flatten(star, 8);
		var ct = new ColorTransform();
		for (i in 0...300) {
			var x = rseed.random(WID);
			var y = rseed.random(HEI);
			var m = new Matrix();
			m.translate(x, y);
			ct.alphaMultiplier = 0.7 * perlin.getPixel(Std.int(x / s), Std.int(y / s)) / 0xffffff;
			plasmaBg.bitmapData.draw(star.bitmapData, m, ct, BlendMode.ADD);
		}
		star.bitmapData.dispose();
		perlin.dispose();

		// Décors de fond
		rseed.initSeed(seed);
		var cont = new Sprite();
		var base = rseed.range(0, 6.28);
		var frames = new RandList();
		var n = 5;
		if (glevel < 10) {
			frames.add(1, 20); // arbres
			frames.add(2, 1); // bigben
			frames.add(3, 2); // visages
			frames.add(4, 2); // mains
			n = rseed.irange(0, 20);
		} else if (glevel < 15) {
			frames.add(2, 1); // bigben
			frames.add(3, 5); // visages
			frames.add(4, 15); // mains
			n = rseed.irange(0, 6);
		} else {
			frames.add(2, 1); // bigben
			frames.add(3, 15); // visages
			frames.add(4, 5); // mains
			n = rseed.irange(5, 12);
		}
		for (i in 0...n) {
			var a = base - rseed.range(0, 2);
			var mc = new MovieClip("DecorBG");
			mc.gotoAndStop(frames.draw(rseed.random));
			cont.addChild(mc);
			mc.x = WID * 0.5 + Math.cos(a) * WID * 0.7;
			mc.y = HEI * 0.5 + Math.sin(a) * HEI * 0.6;
			mc.scaleX = mc.scaleY = rseed.range(0.4, 1, true);
			mc.scaleX *= rseed.sign();
			mc.rotation = 90 + Lib.deg(a);
			mc.filters = [new GlowFilter(0x0, 0.8, 16, 16, 1)];
		}
		if (glevel == 1) {
			// Big ben
			var mc = new MovieClip("DecorBG");
			mc.gotoAndStop(2);
			cont.addChild(mc);
			mc.x = 400;
			mc.y = HEI;
			mc.rotation = 190;
		}
		cont.filters = [Color.getColorizeMatrixFilter(bgColor, 0.8, 0.2), new BlurFilter(4, 4),];
		plasmaBg.bitmapData.draw(cont);
		releaseClips(cont);

		// Nuages de fond
		var clouds = new Bitmap("clouds2");
		clouds.width = WID;
		clouds.height = HEI;
		var ct = new ColorTransform();
		ct.color = Color.randomColor(rseed.rand(), 0.7, 0.7);
		ct.color = bgColor2;
		ct.alphaMultiplier = 0.3;
		plasmaBg.bitmapData.draw(clouds, clouds.transform.matrix, ct, BlendMode.DIFFERENCE);

		// Plasma (alpha défini dans update): drawn x6 in OVERLAY over the background (the filter of plasmaBg, PIXI cannot
		// read what is under a sprite)
		var s = 6;
		plasma = new BitmapData(Math.ceil(WID / s), Math.ceil(HEI / s), false, 0x0);
		plasmaSrc = new BitmapData(plasma.width, plasma.height, false, 0x0);
		plasmaAlpha = 0;
		plasmaFilter = new PlasmaOverlay(plasma, s);
		plasmaBg.node.filters = [plasmaFilter];

		// (the plasma of the shop: LvUP)

		// Arc en ciel
		RAINBOW_LOSS = Color.getColorizeCT(0x0, 0.01);
		var s = RAINBOW_SCALE;
		rainbow = new Bitmap(new BitmapData(Math.ceil(WID / s), Math.ceil(HEI / s), true, 0x0));
		sdm.add(rainbow, DP_FX);
		rainbow.scaleX = rainbow.scaleY = s;
		rainbow.blendMode = BlendMode.ADD;
		rainbow.alpha = 0.8;

		// Ombre
		var s = new Bitmap("shadow2");
		s.blendMode = BlendMode.MULTIPLY;
		s.width = WID;
		s.height = HEI;
		dm.add(s, DP_SHADOW);

		// Niveau
		initPowerUps();
		generateMap();

		curRoom = getRoom(0, 0);
		curRoom.attach();
		curRoom.getNext().attach();
		curRoom.getNext().getNext().attach();

		var mask = new Sprite();
		mask.graphics.beginFill(0x0, 1);
		mask.graphics.drawRect(0, 0, WID, HEI);
		mask.alpha = 1;
		var bmp = Lib.flatten(mask);
		dm.add(bmp, DP_MASK);
		player.setPosScreen(190, 170);
		TW.create(bmp, "alpha", 0, TEaseIn, 1500).onEnd = function() {
			bmp.parent.removeChild(bmp);
			bmp.bitmapData.dispose();
			lockControls = false;
		}

		warmShaders();
		Flash.display(this, 1);
	}

	// the MovieClips drawn into a bitmap: their timelines stop (they are not used any more)
	static function releaseClips(c:DisplayObjectContainer) {
		for (o in c.children) {
			var m = Std.downcast(o, MovieClip);
			if (m != null)
				m.dispose();
		}
	}

	// (haxe.Timer.delay) a call after `ms` milliseconds of the game (30 frames/s)
	public function delay(cb:Void->Void, ms:Int) {
		delayed.push({t: Math.round(ms * FPS / 1000), cb: cb});
	}

	public function pop(x:Float, y:Float, str:Dynamic, ?color = 0xffffff, ?duration = 500) {
		var tf = createField(str, true);
		tf.textColor = color;
		tf.x = Std.int(x - tf.textWidth * 0.5 - 2);
		tf.y = Std.int(y - tf.textHeight * 0.5 - 1);
		tf.filters = [new GlowFilter(0xffffff, 0.2, 10, 10, 10)];

		var bmp = Lib.flatten(tf, true);
		bmp.blendMode = BlendMode.ADD;
		sdm.add(bmp, DP_TEXTS);

		delay(function() {
			TW.create(bmp, "alpha", 0, TEase, 500).onEnd = function() {
				bmp.parent.removeChild(bmp);
				bmp.bitmapData.dispose();
			}
		}, duration);
	}

	public function addScore(?from:Entity, v:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(v);
		if (from != null) {
			var pt = from.getPoint();
			pop(pt.x, pt.y, v, from.color);
		}
	}

	public function addSkill(v:Float) {
		skill += v;
		if (skill > 1)
			skill = 1;
		if (skill < 0)
			skill = 0;
	}

	public function onNextWave() {
		if (curRoom.last())
			return;

		rseed.initSeed(seed + Enemy.WAVE_ID * 99);
		nextWave = 40 * 3;

		var waves = new RandList<Void->Void>();

		// Pacmans
		waves.add(function() {
			if (diff >= charlottesquest.en.Pacman.MIN_DIFFS[2]) {
				// Tireurs
				Enemy.initWave();
				for (i in 0...rseed.irange(5, 8))
					new charlottesquest.en.Pacman(2);
				nextWave = Std.int(40 * 5);
			} else if (diff >= charlottesquest.en.Pacman.MIN_DIFFS[1]) {
				// Solides
				for (j in 0...2) {
					Enemy.initWave();
					for (i in 0...rseed.irange(3, 6))
						new charlottesquest.en.Pacman(1);
				}
				nextWave = 40 * 6;
			} else if (diff >= charlottesquest.en.Pacman.MIN_DIFFS[0]) {
				// Petits
				var packs = if (diff < 8) rseed.irange(1, 2) else rseed.irange(1, 3);
				for (j in 0...packs) {
					Enemy.initWave();
					for (i in 0...(packs == 1 ? 4 : rseed.irange(6, 8)))
						new charlottesquest.en.Pacman(0);
				}
				nextWave = 40 * (diff <= 3 ? 9 : 6);
			}
		}, 100);

		// Yeux
		if (diff >= charlottesquest.en.Eye.MIN_DIFFS[0]) {
			if (diff >= charlottesquest.en.Eye.MIN_DIFFS[1])
				// Gros
				waves.add(function() {
					Enemy.initWave();
					for (i in 0...rseed.irange(3, 5))
						new charlottesquest.en.Eye(1);
					nextWave = 40 * 9;
				}, 70);
			else
				// Petits
				waves.add(function() {
					Enemy.initWave();
					for (i in 0...rseed.irange(4, 7))
						new charlottesquest.en.Eye(0);
					nextWave = 40 * 9;
				}, 50);
		}

		// Moustiques
		if (diff >= charlottesquest.en.Mosquito.MIN_DIFF)
			waves.add(function() {
				Enemy.initWave();
				for (i in 0...rseed.irange(1, 2))
					new charlottesquest.en.Mosquito();
				nextWave = 40 * 4;
			}, 60);

		// Vers
		if (diff >= charlottesquest.en.Worm.MIN_DIFFS[0])
			waves.add(function() {
				var t = diff >= charlottesquest.en.Worm.MIN_DIFFS[1] ? 1 : 0;
				Enemy.initWave();
				var len = t == 0 ? rseed.irange(6, 10) : rseed.irange(9, 12);
				for (i in 0...len)
					new charlottesquest.en.Worm(t);
				nextWave = 40 * 6;
			}, 30);

		// Vers Fourmis
		if (diff >= charlottesquest.en.Worm.MIN_DIFFS[2])
			waves.add(function() {
				for (i in 0...rseed.irange(10, 20)) {
					Enemy.initWave();
					for (i in 0...2)
						new charlottesquest.en.Worm(2);
				}
				nextWave = 40 * 8;
			}, 60);

		// Guêpes
		if (diff >= charlottesquest.en.Bee.MIN_DIFF)
			waves.add(function() {
				var n = 1;
				if (diff >= charlottesquest.en.Bee.MIN_DIFF + 5)
					n++;
				if (diff >= charlottesquest.en.Bee.MIN_DIFF + 10)
					n++;
				if (diff >= charlottesquest.en.Bee.MIN_DIFF + 20)
					n++;
				Enemy.initWave();
				for (i in 0...n)
					new charlottesquest.en.Bee();
				nextWave = 40 * n * 6;
			}, 100);

		// Tirage
		waves.draw(rseed.random)();
	}

	public function populateRoom(r:Room) {
		if (r.distance == 0)
			return;

		rseed.initSeed(seed + r.distance);

		// (the chests of the in-game prizes of Arkadeo: not ported)

		// Coffres à power-ups
		if (r.hasPowerUp) {
			Enemy.initWave();
			var k = charlottesquest.it.PowerUp.randomKind(rseed);
			if (k == null)
				new charlottesquest.en.Chest(r); // Non, finalement, des thunes ça ira aussi
			else
				new charlottesquest.en.Chest(r, function(c) new charlottesquest.it.PowerUp(c, k));
		}

		// Coffres Uber !
		if (r.hasUber) {
			Enemy.initWave();
			new charlottesquest.en.Chest(r, function(c) new charlottesquest.it.PowerUp(c, Uber));
		}

		// Coffres à thunes
		if (r.distance > 0) {
			Enemy.initWave();
			var rlist = new RandList();
			rlist.add(0, 100);
			rlist.add(1, 50);
			rlist.add(2, 30);
			rlist.add(4, 3);
			rlist.add(8, 1);
			for (i in 0...rlist.draw(rseed.random))
				new charlottesquest.en.Chest(r);
		}

		// Mines
		var hasMines = false;
		if (diff >= charlottesquest.en.Mine.MIN_DIFF && rseed.random(100) < 15) {
			Enemy.initWave();
			var n = Math.round(rseed.irange(4, 6));
			for (i in 0...n)
				new charlottesquest.en.Mine(r, rseed.random(100) < 20 ? 1 : 0);
			hasMines = true;
		}

		// Tourelles
		if (diff >= charlottesquest.en.Turret.MIN_DIFF) {
			Enemy.initWave();
			var min = 0;
			var max = 0;
			if (diff < 6) {
				min = 1;
				max = 2;
			} else if (diff < 8) {
				min = 1;
				max = 3;
			} else if (diff < 14) {
				min = 2;
				max = 3;
			} else if (diff < 18) {
				min = 3;
				max = 4;
			} else if (diff < 21) {
				min = 3;
				max = 5;
			} else {
				min = 4;
				max = 6;
			}
			if (hasMines)
				max = Std.int(max * 0.5);
			if (min > max)
				min = max;
			var n = rseed.irange(min, max);
			for (i in 0...n)
				new charlottesquest.en.Turret(r, diff <= 3 ? 0 : 1);
		}
	}

	function setMouseControls(b:Bool) {
		mouseControls = b;
		if (skipFrames <= 0)
			pop(viewport.x + WID * 0.5, viewport.y + 20, mouseControls ? Lang.get("MouseOn") : Lang.get("MouseOff"), 0xFFE655);
		cursor.visible = mouseControls && !isReplay;
		// (flash.ui.Mouse.hide / show)
		var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
		if (canvas != null && canvas.style != null && !isReplay)
			canvas.style.cursor = mouseControls ? "none" : "";
	}

	// (League: Charlotte only loses; the victory of the LvUP and its wake-up animation are not ported)
	public function gameOver(win:Bool) {
		if (ended)
			return;
		ended = true;

		player.dx = player.dy = 0;

		if (mouseControls) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null && canvas.style != null)
				canvas.style.cursor = "";
			cursor.visible = false;
		}

		// Défaite
		var mask = new Sprite();
		dm.add(mask, DP_MASK);
		mask.graphics.beginFill(0x1F1F1F, 1);
		mask.graphics.drawRect(0, 0, WID, HEI);
		mask.alpha = 0;
		TW.create(mask, "alpha", 0.4, TEase, 2200).onEnd = function() {
			endGame();
		}
	}

	// AKApi.gameOver: the end of the game for KadoKadeo
	function endGame() {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	public function createField(str:Dynamic, ?adjustSize = false, ?letterSpacing = 1.0) {
		var str = Std.string(str);
		var f = new TextFormat();
		f.font = "def";
		f.size = 16;
		f.color = 0xffffff;
		f.letterSpacing = letterSpacing;

		// (embedded font: the glyphs of the SWF, Data.fonts)
		var tf = new TextField(f.font);
		tf.width = adjustSize ? 500 : 300;
		tf.height = 50;
		tf.mouseEnabled = tf.selectable = false;
		tf.defaultTextFormat = f;
		tf.embedFonts = true;
		tf.text = str;
		if (adjustSize) {
			tf.width = tf.textWidth + 5;
			tf.height = tf.textHeight + 5;
		}

		return tf;
	}

	function initPowerUps() {
		var rlist = new RandList();
		rlist.add(0, 10);
		rlist.add(1, 100);
		rlist.add(2, 90);
		rlist.add(3, 50);
		rlist.add(4, 20);
		rlist.add(5, 5);
		var closes = rlist.draw(rseed.random);
		var closeChance = 15.0;

		powerUpSpread = [];
		var totalDist = 0;
		for (n in 0...30) {
			var nextDist = if (n == 0) rseed.irange(1, 3); else if (closes > 0 && rseed.random(100) < closeChance) {
				closeChance = 15;
				closes--;
				1;
			} else {
				closeChance *= 1.4;
				if (n <= 3) rseed.irange(2, 3); else rseed.irange(2, 4);
			}

			totalDist += nextDist;
			powerUpSpread.push(totalDist);
		}
	}

	public function generateMap(?count:Int) {
		if (count == null)
			count = 3;
		var newMap = Room.ALL.length == 0;
		var last = Room.ALL[Room.ALL.length - 1];
		var x = newMap ? 0 : last.cx + last.getNextDir().dx;
		var y = newMap ? 0 : last.cy + last.getNextDir().dy;
		var n = 0;
		var k = Bedroom;
		if (!newMap)
			k = switch (last.kind) {
				case Bedroom: Horizontal;
				case Horizontal, VerticalDown, VerticalUp: last.kind;
				case FromUp, FromDown: Horizontal;
				case ToUp: VerticalUp;
				case ToDown: VerticalDown;
			}

		if (nextUber == -1) {
			rseed.initSeed(seed);
			nextUber = 99999;
			nextUber = rseed.irange(8, 20);
		}

		rseed.initSeed(seed + Room.ALL.length * 99);
		var corridorLen = Room.ALL.length == 0 ? 2 : 0;
		while (n < count) {
			var r = new Room(x, y, k);

			var next = r.getNextDir();
			x += next.dx;
			y += next.dy;
			corridorLen--;

			k = switch (k) {
				case Bedroom: Horizontal;
				case ToDown: VerticalDown;
				case ToUp: VerticalUp;
				case FromDown: Horizontal;
				case FromUp: Horizontal;
				default: k;
			}
			if (corridorLen <= 0) {
				corridorLen = rseed.irange(1, 4);
				k = switch (k) {
					case VerticalDown:
						rseed.random(6) == 0 ? k : FromUp;
					case VerticalUp:
						rseed.random(6) == 0 ? k : FromDown;
					case Horizontal, Bedroom:
						corridorLen++;
						rseed.random(2) == 0 ? ToUp : ToDown;
					default: k;
				}
			}

			if (powerUpSpread.length > 0 && powerUpSpread[0] == r.distance) {
				powerUpSpread.splice(0, 1);
				r.hasPowerUp = true;
			}
			if (nextUber-- <= 0) {
				r.hasUber = true;
				nextUber = rseed.irange(10, 20);
			}
			n++;
		}
	}

	public inline function setRoom(cx:Int, cy:Int, r:Room) {
		map.set(cx + "," + cy, r);
	}

	public inline function getRoom(cx:Int, cy:Int) {
		return map.get(cx + "," + cy);
	}

	public inline function getRoomAt(x:Float, y:Float) {
		return getRoom(Math.floor(x / (Room.CWID * Room.GRID)), Math.floor(y / (Room.CHEI * Room.GRID)));
	}

	function countRealEnemies() {
		var n = 0;
		for (e in enemies)
			if (e.hasToBeKilled)
				n++;
		return n;
	}

	inline function actionKey() {
		return !mouseControls
			&& (KeyboardManager.isDown(KeyboardManager.CONTROL) || KeyboardManager.isDown(KeyboardManager.SPACE)) || mouseControls
			&& MouseManager.isButtonDown(MouseManager.BUTTON_LEFT);
	}

	public inline function isLeague() {
		return true;
	}

	// the mouse in the game area (canvas pixels, the replay records it: >= 0)
	public static inline function mouseX():Float return Math.max(0, MouseManager.getX());

	public static inline function mouseY():Float return Math.max(0, MouseManager.getY());

	// the trigonometry that moves the game, rounded to 1/65536 (the last bits of Math.cos / Math.sin / Math.atan2 may differ
	// between browsers): the same game in every replay
	public static inline function q(v:Float):Float return Math.round(v * 65536) / 65536;

	public static inline function cos(a:Float):Float return q(Math.cos(a));

	public static inline function sin(a:Float):Float return q(Math.sin(a));

	public static inline function atan2(y:Float, x:Float):Float return q(Math.atan2(y, x));

	inline function updateMouse() {
		if (mouseControls) {
			var grid = 8;
			var minDeltaX = Math.ceil(WID / grid) + 20;
			var minDeltaY = Math.ceil(HEI / grid) + 20;

			var oldX = Std.int(xm / grid);
			var oldY = Std.int(ym / grid);

			var x = Math.round(mouseX() / grid);
			var y = Math.round(mouseY() / grid);
			var dx = Math.floor(x - oldX) + minDeltaX;
			var dy = Math.floor(y - oldY) + minDeltaY;
			if (dx < 0)
				dx = 0;
			if (dy < 0)
				dy = 0;

			// (AKApi.getCustomValue: the value itself, the mouse is recorded by KadoKadeo)
			xm = (oldX + dx - minDeltaX) * grid;
			ym = (oldY + dy - minDeltaY) * grid;

			cursor.x = mouseX();
			cursor.y = mouseY();
		}
	}

	// ---------------------------------------------------------------- KadoKadeo step: 15 frames of the game every 16 steps
	// Shown 30/32 of a frame behind the last frame of the game (see arkadeo.Flash), ASprite interpolating between two steps
	public function update(delta:Float) {
		frameAcc += FPS;
		while (frameAcc >= STEPS_PER_SECOND) {
			frameAcc -= STEPS_PER_SECOND;
			Flash.frameStart(this);
			MovieClip.tickAll();
			updateGame(true);
			Clip.runPending();
			frameCount++;
			Flash.frameEnd(this);
		}
		Flash.display(this, (frameAcc + STEPS_PER_SECOND - FPS) / STEPS_PER_SECOND);
	}

	// a touch screen: the joystick presses the arrows (8 directions)
	public function pollTouchControls():Void {
		var j = KadoKadeoManager.kkm.getTouchJoystickState();
		if (j == null)
			return;
		var ax = j.active ? j.dirX : 0;
		var ay = j.active ? j.dirY : 0;
		touchKey(KeyboardManager.LEFT, ax < 0);
		touchKey(KeyboardManager.RIGHT, ax > 0);
		touchKey(KeyboardManager.UP, ay < 0);
		touchKey(KeyboardManager.DOWN, ay > 0);
	}

	static inline function touchKey(k:Int, down:Bool) {
		if (down)
			KeyboardManager.setKeyDown(k);
		else
			KeyboardManager.setKeyUp(k);
	}

	// the update of the original Game (one frame at 30 frames/s)
	public function updateGame(r:Bool) {
		// (haxe.Timer.delay)
		var i = 0;
		while (i < delayed.length) {
			var d = delayed[i];
			if (--d.t <= 0) {
				delayed.splice(i, 1);
				d.cb();
			} else
				i++;
		}

		updateMouse();

		absoluteTime++;
		rendering = r;

		// (AKApi.getRealFramerate / getBaseFramerate: a fast machine)
		perf = 1;

		Room.updateAll();

		var uDown = KeyboardManager.isDown(KEY_U);
		var uToggled = uDown && !uWas;
		uWas = uDown;

		if (skipFrames-- > 0)
			return;

		if (!shopping) {
			// En jeu (the dev keys of the original, #if dev, are not ported: they read keys a replay does not record; the test
			// modes of the harness do their work)

			if (curRoom.last(2) && isLeague()) {
				glevel++;
				diff += 1.32 + 0.6 * skill;
				generateMap(2);
			}

			if (time % 5 == 0 && curRoom.distance > 0 && nextWave > 40 && !curRoom.last() && !player.dead() && !ended && countRealEnemies() == 0)
				nextWave = 40;
			if (nextWave-- <= 0)
				onNextWave();

			// Contrôles mouvement
			if (!lockControls && !player.dead() && !ended) {
				var reset = true;
				var ps = player.speed + 0.15 * player.speed * (1 - player.getCD("slow") / 15);

				if (mouseControls) {
					var pt = player.getScreenPoint();
					var d = Lib.distance(xm, ym, pt.x, pt.y);
					var ms = d <= 30 ? ps * (d / 30) : ps;
					var ang = atan2(ym - pt.y, xm - pt.x);
					player.dx += cos(ang) * ms;
					player.dy += sin(ang) * ms;
				} else {
					if (KeyboardManager.isDown(KeyboardManager.UP)) {
						reset = false;
						player.setPlayerAnim("up");
						player.dy -= ps;
					}
					if (KeyboardManager.isDown(KeyboardManager.DOWN)) {
						reset = false;
						player.setPlayerAnim("down");
						player.dy += ps;
					}

					if (KeyboardManager.isDown(KeyboardManager.LEFT)) {
						reset = false;
						player.setPlayerAnim("left");
						player.mc.rotation -= 1;
						player.dx -= ps;
					}
					if (KeyboardManager.isDown(KeyboardManager.RIGHT)) {
						reset = false;
						player.setPlayerAnim("right");
						player.mc.rotation += 1;
						player.dx += ps;
					}
				}
				if (uToggled) {
					setMouseControls(!mouseControls);
				}

				if (reset)
					player.setPlayerAnim();

				// Tir
				if (actionKey()) {
					player.shoot();
					player.setCD("slow", 15);
				}
			}

			// Scrolling auto
			if (scrollSpeedFact < 1 && time >= 40) {
				scrollSpeedFact += 0.008;
				if (scrollSpeedFact > 1)
					scrollSpeedFact = 1;
			}
			var d = curRoom.getNextDir();
			if (curRoom.getNext() == null)
				d.dx = d.dy = 0;
			var speed = scrollSpeedFact * SCROLL_SPEED_LEAGUE / 10;
			if (ended)
				speed = 0;
			#if debug
			if (testNoScroll)
				speed = 0;
			#end
			var curScroll = {dx: d.dx * speed, dy: d.dy * speed}
			viewport.x += curScroll.dx;
			viewport.y += curScroll.dy;
			scroller.x = -Std.int(viewport.x);
			scroller.y = -Std.int(viewport.y);

			// Salle suivante
			if (curRoom.goneThrough()) {
				curRoom.detach();
				curRoom = curRoom.getNext();
				var next = curRoom.getNext();
				if (next != null) {
					next.attach();
					if (next.getNext() != null)
						next.getNext().attach();
				}
				viewport.x = curRoom.cx * Room.CWID * Room.GRID;
				viewport.y = curRoom.cy * Room.CHEI * Room.GRID;
			}

			// Updates
			lastScroll = {x: curScroll.dx / Room.GRID, y: curScroll.dy / Room.GRID}
			for (e in bullets)
				e.update();
			for (e in enemies)
				e.update();
			for (e in items)
				e.update();
			player.update();
			for (e in killList)
				e.unregister();
			killList = new List();

			// Plasma
			if (perf < 0.9 && plasmaAlpha > 0)
				plasmaAlpha -= 0.05;
			if (!ended && time % 2 == 0 && perf >= 0.9) {
				if (plasmaAlpha < 0.4)
					plasmaAlpha += 0.05;
				if (rendering) {
					var s = 0.4;
					var vdx = viewport.x * 0.05;
					var vdy = viewport.y * 0.05;
					var off = [
						new Point(ptime * s * plasmaSettings.dx + vdx, ptime * s * plasmaSettings.dy * 0.3 + vdy),
						new Point(ptime * s * plasmaSettings.dx * 0.3 + vdx * 0.9, ptime * s * plasmaSettings.dy + vdy * 0.9),
					];
					plasmaSrc.perlinNoise(plasmaSettings.w, plasmaSettings.h, 2, 0, true, false, 1, true, off);
					plasmaSrc.threshold(plasmaSrc, plasmaSrc.rect, new Point(0, 0), ">", Color.addAlphaF(0x232323), 0x0, 0xffFFFFFF, true);
					plasma.applyFilter(plasmaSrc, plasmaSrc.rect, new Point(0, 0), new BlurFilter(4, 4));
				}
				ptime++;
			}
			plasmaFilter.update(plasma, plasmaAlpha);

			// Arc en ciel
			if (perf >= 0.7) {
				if (rendering) {
					if (!rainbow.visible)
						rainbow.visible = true;
					rainbow.x = viewport.x;
					rainbow.y = viewport.y;
					var bd = rainbow.bitmapData;
					if (absoluteTime % 2 == 0)
						bd.applyFilter(bd, bd.rect, new Point(0, 0), new BlurFilter(2, 2));
					bd.colorTransform(bd.rect, RAINBOW_LOSS);
				}
			} else if (rainbow.visible)
				rainbow.visible = false;

			time++;
		}

		fx.update();
		TW.update();
	}

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null) {
				canvas.removeEventListener("pointerdown", onPointerDown);
				if (canvas.style != null)
					canvas.style.cursor = "";
			}
			onPointerDown = null;
		}
		Particle.clearAll();
		resetStatics();
		node.mask = null;
		if (gameMask.parent != null)
			gameMask.parent.removeChild(gameMask);
		gameMask.destroy();
		if (node.parent != null)
			node.parent.removeChild(node);
		node.destroy({children: true});
		ME = null;
	}

	// statics of the game: one page plays several games and replays
	static function resetStatics() {
		// the display: the twips of Flash, the bitmaps of the game without smoothing (Flash's Bitmap: the plasma and the
		// rainbow are pixels of 6 x 6), the glows of Flash
		Flash.reset();
		BitmapData.gpuScaleMode = 0;
		// (the perlin noises: the bricks of the background, the stars, the plasma)
		BitmapData.perlinFractal = true;
		Particle.ALL = [];
		uniq = DEPTHS;
		Room.reset();
		Entity.ANIM_CACHE = new Map();
		Enemy.WAVE_ID = 0;
		Enemy.WAVES = [];
		charlottesquest.en.Pacman.reset();
		charlottesquest.bullet.Heart.clearCache();
		charlottesquest.bullet.Bad.clearCache();
		TW = null;
		ME = null;
	}

	// the first use of a filter compiles its shader (a frozen frame of 10 to 80 ms): each filter of the game is drawn once
	// here (the glows, the drop shadows, the blurs, the colour matrices); the sheets are uploaded to the GPU now too
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var flts:Array<BitmapFilter> = [];
		for (d in [2, 8, 16, 32])
			flts.push(new GlowFilter(0xFFFFFF, 1, d, d, 2));
		flts.push(new GlowFilter(0xFFFFFF, 1, 16, 16, 1, 2, true));
		flts.push(new BlurFilter(2, 2));
		flts.push(new BlurFilter(4, 4));
		flts.push(new DropShadowFilter(6, -90, 0x0, 0.6, 8, 8, 1, 1, true));
		flts.push(new DropShadowFilter(12, 90, 0x0, 0.2, 8, 8, 1));
		flts.push(new ColorMatrixFilter());
		var filters:Array<Dynamic> = [];
		for (f in flts) {
			var p = f.toPixi();
			if (p != null)
				filters.push(p);
		}
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		for (f in filters) {
			var holder = new pixi.core.display.Container();
			var s = new pixi.core.sprites.Sprite(pixi.core.textures.Texture.WHITE);
			s.x = s.y = 12;
			s.width = s.height = 8;
			s.filters = [f];
			holder.addChild(s);
			renderer.render(holder, {renderTexture: rt, clear: true});
			holder.destroy({children: true});
		}
		rt.destroy(true);
		var res = untyped PIXI.Loader.shared.resources;
		for (k in Reflect.fields(res)) {
			var r = Reflect.field(res, k);
			var url:String = r.url != null ? r.url : k;
			if (r.spritesheet != null && url.indexOf("/charlottesquest") >= 0)
				renderer.texture.bind(r.spritesheet.baseTexture);
		}
	}

	#if debug
	// (test modes of the harness)
	public var testNoScroll:Bool = false;

	// (test mode) the difficulty, the level of the rooms made from now on (their theme) and the build from the start (pow < 0:
	// unchanged)
	public function testSetup(d:Float, pow:Int, ?lvl:Int = 0) {
		if (d > 0)
			diff = d;
		if (lvl > 0)
			glevel = lvl;
		if (pow >= 0) {
			var b = player.build;
			b.front = b.back = b.up = b.down = b.capture = pow;
			b.speed = pow > Player.PlayerBuild.SMAX ? Player.PlayerBuild.SMAX : pow;
			player.applyBuild();
		}
	}

	// (test mode) Charlotte keeps her lives and is not killed by the scrolling
	public function testInvincible() {
		if (player.dead())
			return;
		if (player.life < 2)
			player.life = 2;
		player.setCD("shield", 2);
		player.testKeepOnScreen();
	}

	// (test mode) the Uber
	public function testUber() {
		if (!player.dead() && !ended)
			player.uber();
	}

	// (the test bot) what it sees on the screen
	public function botState():Dynamic {
		var pt = player.getScreenPoint();
		var d = curRoom.getNextDir();
		var en = [];
		for (e in enemies)
			if (!e.dead()) {
				var p = e.getScreenPoint();
				en.push({x: p.x, y: p.y, r: e.radius, h: e.hitsPlayer});
			}
		var bu = [];
		for (b in bullets)
			if (b.hitPlayer && !b.dead()) {
				var p = b.getScreenPoint();
				bu.push({x: p.x, y: p.y, dx: b.dx * Room.GRID, dy: b.dy * Room.GRID});
			}
		var it = [];
		for (i in items)
			if (!i.dead()) {
				var p = i.getScreenPoint();
				it.push({x: p.x, y: p.y});
			}
		var walls = [];
		for (gx in player.cx - 4...player.cx + 5)
			for (gy in player.cy - 4...player.cy + 5)
				if (player.getCol(gx, gy))
					walls.push({x: gx * Room.GRID + Room.GRID * 0.5 + scroller.x, y: gy * Room.GRID + Room.GRID * 0.5 + scroller.y});
		return {
			over: over,
			ended: ended,
			dead: player.dead(),
			locked: lockControls || skipFrames > 0,
			px: pt.x,
			py: pt.y,
			sdx: d.dx,
			sdy: d.dy,
			mouse: mouseControls,
			uber: player.hasCD("uber"),
			frame: frameCount,
			en: en,
			bu: bu,
			it: it,
			walls: walls,
		};
	}

	// the state compared between a game and its replay
	public function debugState():Dynamic {
		return {
			frame: frameCount,
			time: time,
			score: KadoKadeoManager.kkm.score.get(),
			rooms: Room.ALL.length,
			room: curRoom != null ? curRoom.distance : -1,
			glevel: glevel,
			diff: diff,
			skill: skill,
			px: player.rx,
			py: player.ry,
			life: player.life,
			enemies: enemies.length,
			items: items.length,
			bullets: bullets.length,
			waves: Enemy.WAVE_ID,
			uniq: uniq,
			build: player.build.toString(),
			vx: viewport.x,
			vy: viewport.y,
		};
	}
	#end
}

// The OVERLAY of the plasma (plasmaCont: a Bitmap of the plasma x6, blendMode OVERLAY, alpha up to 0.4) over the
// background under it: a filter of the background drawing the plasma over it (OverlayFilter, mixed by the alpha of
// plasmaCont)
class PlasmaOverlay extends OverlayFilter {
	public function new(bd:BitmapData, scale:Int) {
		super(bd.getTexture(), bd.width * scale, bd.height * scale);
	}

	public function update(bd:BitmapData, alpha:Float) {
		setPicture(bd.getTexture());
		this.alpha = alpha;
		enabled = alpha > 0;
	}
}

package kanjisnightmare;

import pixi.filters.extras.GlowFilter;
import common_haxe_avm1.KeyboardManager;
import common_haxe_avm1.MouseManager;
import haxe.io.Bytes;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import mt.DepthManager;
import pixi.core.Pixi.BlendModes;
import pixi.core.graphics.Graphics;
import pixi.core.math.shapes.Rectangle;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;
import pixi.filters.colormatrix.ColorMatrixFilter;
import kado.TouchControlsConfig.TouchButtonShape;

// decor plan: the 4 cave layers (type 0, repeated) and the elements that scroll by (type 1)
typedef PlanInfo = {mc:ASprite, c:Float, w:Float, x:Float, y:Float, dy:Float, type:Int};
// Medusa's arm: shoulder ($b), forearm ($ab) and hand ($h) turned by the code
typedef ArmPart = {vr:Float, rot:Float};
typedef Arm = {p:Phys, b:ArmPart, ab:ArmPart, hx:Float, hy:Float, hFrame:Int};

@:expose('GameKanjisNightmare')
class Game implements kado.GameInterface {
	// mobile: a cross of arrows (up: jump and kunai, down: drop and kick) + shuriken button (the layout of Kanji's Adventure)
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "up",
				label: "▲",
				leftPx: 64,
				bottomPx: 76,
				size: 56,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "left",
				label: "◀",
				leftPx: 8,
				bottomPx: 20,
				size: 56,
				keyCode: KeyboardManager.LEFT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 120,
				bottomPx: 20,
				size: 56,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "down",
				label: "▼",
				leftPx: 64,
				bottomPx: 20,
				size: 56,
				keyCode: KeyboardManager.DOWN,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "shoot",
				label: "✦",
				rightPx: 12,
				bottomPx: 20,
				size: 80,
				keyCode: KeyboardManager.SPACE,
			},
		],
	};

	// ZQSD / WASD move like the arrows, Enter shoots like Space and Control
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	public static inline var DP_BG = 1;
	public static inline var DP_MAP = 2;
	public static inline var DP_FRONT = 3;
	public static inline var DP_INTER = 4;

	public static inline var DP_BACK = 2;
	public static inline var DP_PLAT = 2;
	public static inline var DP_ROPE = 3;
	public static inline var DP_MONS = 4;
	public static inline var DP_HERO = 5;
	public static inline var DP_BONUS = 6;
	public static inline var DP_MEDUSA = 7;
	public static inline var DP_SHOT = 8;
	public static inline var DP_PARTS = 9;
	public static inline var DP_DECOR = 10;

	static inline var CL = 60;
	static inline var SCROLL_COLOR = 0x984e71;

	// replay event: the game is played with the touch controls (no mouse pointer)
	static inline var EV_TOUCH = 1;

	var genPlatCoef:Int;

	public var dif:Float;
	public var flMouseDead:Bool;
	public var mouseDeadTimer:Float;

	var parc:Float;
	var handicap:Float;

	public var scrollMin:Float;

	var scrollSpeed:Float;

	public var sList:Array<Sprite>;
	public var mList:Array<Monster>;
	public var nsList:Array<Star>;
	public var bonusList:Array<Bonus>;
	public var platList:Array<Plat>;

	var plans:Array<PlanInfo>;

	public var stats:{
		opt:Array<Int>,
		bads:Array<Int>,
		dif:Int,
		gu:Int
	};
	public var dm:DepthManager;
	public var mdm:DepthManager;
	public var hero:Hero;
	public var root:ASprite;
	public var map:ASprite;

	var bg:ASprite;
	var mcLine:Graphics;
	var caveTop:ASprite;
	var caveSegs:Array<ASprite>;
	var caveBase:Texture;
	var auraLayer:ASprite;

	public var medusa:Phys;

	var medusaBody:Phys;
	var medusaArms:Array<Arm>;
	var mcRedLight:Clip;
	var hitMasks:Array<Bytes>;

	var focus:{x:Float, y:Float};

	var isReplay:Bool;
	var touchMode:Bool;
	var frameCount:Int;
	var over:Bool;
	var cursorHidden:Bool;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		touchMode = !isReplay && isTouchDevice();
		var replayKeys = new UInt16Array(6);
		replayKeys[0] = KeyboardManager.LEFT;
		replayKeys[1] = KeyboardManager.RIGHT;
		replayKeys[2] = KeyboardManager.UP;
		replayKeys[3] = KeyboardManager.DOWN;
		replayKeys[4] = KeyboardManager.SPACE;
		replayKeys[5] = KeyboardManager.CONTROL;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: true,
			recordMousePosition: !touchMode,
			recordedMouseButtons: new UInt16Array(0),
		});

		Cs.game = this;
		Hero.SPEED = 6;
		Bonus.UNIQUE = null;
		frameCount = 0;
		over = false;
		cursorHidden = false;

		// the game runs in the Flash pixels of the original (300 x 300), drawn x2
		this.root = root.createEmptyMovieClip("scene", 0);
		this.root._xscale = this.root._yscale = 100 * Clip.K;
		this.root.updateState();
		dm = new DepthManager(this.root);
		initBg();

		// LISTS
		sList = [];
		mList = [];
		nsList = [];
		platList = [];
		bonusList = [];

		initMap();

		flMouseDead = false;
		mouseDeadTimer = 0;

		scrollSpeed = 0.5;
		dif = 0;
		parc = 0;
		genPlatCoef = 10;
		handicap = 0;

		stats = {
			opt: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			bads: [0, 0, 0],
			dif: null,
			gu: 0, // grapins used
		};

		scrollMin = map._x + 300;

		hero = new Hero(Clip.attach(mdm, "mcHero", DP_HERO));

		initMedusa();

		genPlat(0, 270, 1000);
		genPlat(Cs.mcw * 2, 200, 1000);

		focus = hero;
	}

	function initBg() {
		bg = dm.empty(DP_BG);
		var top = new Clip.Gfx("bgTop");
		bg.addChild(top);
		var grad = new Clip.Gfx("bgGrad");
		grad._x = 0;
		grad._y = Data.BG_GRAD_Y;
		grad._xscale = Cs.mcw * 100;
		bg.addChild(grad);
	}

	function initMap() {
		// INIT PLANS
		plans = [];
		var cl = [0.1, 0.4, 0.8, 1, 1.5];
		for (i in 0...cl.length) {
			var c = cl[i];
			if (c == 1) {
				map = dm.empty(DP_MAP);
				mdm = new DepthManager(map);
			} else {
				for (n in 0...2) {
					var mc = Clip.attach(dm, "mcPlan", DP_MAP);
					mc.gotoAndStop(i + 1);
					var w = Data.PLAN_WIDTH[i + 1];
					plans.push({
						mc: mc,
						c: c,
						w: w,
						x: w * n,
						y: 0,
						dy: 0,
						type: 0
					});
				}
			}
		}

		// CAVE TOP (a bitmap of 4 screens in the original: here 4 strips of sprites, masked to its height)
		caveTop = mdm.empty(DP_DECOR);
		var mask = new Graphics();
		mask.beginFill(0xFFFFFF);
		mask.drawRect(0, 0, Cs.mcw * 4, CL);
		mask.endFill();
		caveTop.addChild(mask);
		caveTop.mask = mask;
		caveSegs = [];
		var src = Tex.get("mcCaveTop_0")[0];
		var px = Clip.K * Clip.getDef("mcCaveTop").r;
		var keep = Math.min(src.frame.width, Cs.mcw * px + src.defaultAnchor.x * src.orig.width - (src.trim != null ? src.trim.x : 0));
		caveBase = new Texture(src.baseTexture, new Rectangle(src.frame.x, src.frame.y, keep, src.frame.height));
		printCaveTop(0);
		printCaveTop(Cs.mcw);
		printCaveTop(Cs.mcw * 2);
		printCaveTop(Cs.mcw * 3);

		// LINE
		var line = mdm.empty(DP_ROPE);
		mcLine = line.getGraphics();

		// AFTERIMAGES of the aura: one white glow for all of them
		auraLayer = mdm.empty(DP_ROPE);
		auraLayer.filters = [glow(4, 4, 0xFFFFFF)];

		warmShaders();
	}

	// Cs.glow(mc, blur, strength, color) of the original: GlowFilter of pixi-filters (its shader depends on the distance
	// and the quality: keep them in this function, warmShaders compiles the same ones)
	static function glow(blur:Float, strength:Float, color:Int):Dynamic {
		return Type.createInstance(GlowFilter, [
			{
				distance: blur * Clip.K,
				outerStrength: strength,
				innerStrength: 0,
				color: color,
				quality: 0.3
			}
		]);
	}

	// The first use of a filter or of a sprite mask compiles its shader on the graphics card: tens of ms (up to 100 and
	// more on a modest PC) during which the game freezes, the hero stopped for a few pictures the first time he was hit
	// (glow of the hero without clothes), had the aura (glow, colour matrix of the afterimages) or was swallowed (lips of
	// Medusa). All of them are compiled now, at the start, by drawing a tiny sprite with each one off screen.
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new pixi.core.display.Container();
		for (f in [new ColorMatrixFilter(), glow(4, 4, 0xFFFFFF), glow(3, 2, 0x662200)]) {
			var s = new PixiSprite(Texture.WHITE);
			s.filters = [f];
			holder.addChild(s);
		}
		var masked = new PixiSprite(Texture.WHITE);
		var mask = new PixiSprite(Texture.WHITE);
		masked.mask = mask;
		holder.addChild(mask);
		holder.addChild(masked);
		var rt = pixi.core.textures.RenderTexture.create(32, 32);
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	// ---------------------------------------------------------------- MAIN
	public function update(delta:Float) {
		if (frameCount == 0 && touchMode)
			KadoKadeoManager.kkm.replay.recordEvent({k: EV_TOUCH, x: 0, y: 0}, 0);
		for (e in KadoKadeoManager.kkm.replay.consumeEvents())
			if (e != null && e.k == EV_TOUCH)
				touchMode = true;
		frameCount++;

		mcLine.clear();
		dif += Timer.tmod;
		stats.dif = Std.int(dif);

		bg._y = map._y * 0.5;

		updateMedusa();
		updateScroll();
		updateEnvFX();
		updateCursor();

		// (the sprites killed during this loop are not updated any more)
		var list = sList.copy();
		for (s in list)
			if (!s.dead)
				s.update();
	}

	// SCROLL
	function updateScroll() {
		var base = focus;
		if (hero.flEat) {
			var c = 0.9;
			base = {
				x: focus.x * c + medusa.x * (1 - c),
				y: focus.y * c + medusa.y * (1 - c)
			};
		}

		var dec = 300;
		scrollMin = Math.min(scrollMin - scrollSpeed * Timer.tmod, map._x + dec);
		scrollSpeed += 0.001 * Timer.tmod;

		var ox = map._x;
		map._x = Cs.mcw * 0.5 - base.x;
		map._y = Math.min(Cs.mcw * 0.5 - base.y, 0);

		// SCROLL PLANS
		scrollDecor(map._x - ox);

		// RECAL
		if (map._x < -Cs.mcw * 2)
			recalScroll(Cs.mcw);

		// CHECK PLAT
		for (pl in platList.copy())
			if (pl.x + pl.w < -scrollMin)
				pl.kill();
	}

	// the world moves back by m (stays in the area of the cave top bitmap): no interpolation glitch
	function recalScroll(m:Float) {
		scrollMin += m;
		map._x += m;
		if (map._prevState != null)
			map._prevState.x += m;
		for (sp in sList) {
			sp.x -= m;
			if (sp.root != null) {
				sp.root._x = sp.x;
				if (sp.root._prevState != null)
					sp.root._prevState.x -= m;
			}
		}
		// CaveTop
		for (s in caveSegs.copy()) {
			s._x -= m;
			if (s._prevState != null)
				s._prevState.x -= m;
			if (s._x < 0) {
				caveSegs.remove(s);
				s.removeMovieClip();
				s.destroy({children: true});
			}
		}
		printCaveTop(Cs.mcw * 3);

		// Build Level
		if (Seed.random(Std.int(Cs.q(Math.pow(dif, 0.24)) * genPlatCoef)) < 40) {
			genPlatCoef = 10;
			genPlat(null, null, null);
		} else {
			genPlatCoef -= 3;
		}
	}

	function scrollDecor(vx:Float) {
		handicap -= vx;
		var lap = 20;
		while (handicap > lap) {
			handicap -= lap;
			addScore(Cs.C10);
		}

		parc -= vx;
		var i = 0;
		while (i < plans.length) {
			var p = plans[i];
			p.x += p.c * vx;
			p.y = map._y * (0.5 + p.c * 0.5);
			switch (p.type) {
				case 0:
					if (p.x > Cs.mcw)
						p.x -= p.w * 2;
					if (p.x + p.w < 0)
						p.x += p.w * 2;
				case 1:
					p.y += p.dy;
					if (p.x < -p.w * 0.5) {
						p.mc.removeMovieClip();
						p.mc.destroy({children: true});
						plans.splice(i--, 1);
					}
			}
			var wrap = Math.abs(p.mc._x - p.x) > Cs.mcw;
			p.mc._x = p.x;
			p.mc._y = p.y;
			if (wrap && p.mc._prevState != null)
				p.mc._prevState.x = p.x;
			i++;
		}

		// ADD SCROLL ELEMENTS
		var lim = 50;
		while (plans.length < 20 && parc > lim) {
			parc -= lim;
			addScrollElement();
		}
	}

	function addScrollElement() {
		var mc = Clip.attach(dm, "mcScrollElement", DP_MAP);
		var fr = Seed.randomVfx(mc._totalframes) + 1;
		mc.gotoAndStop(fr);
		var c = 0.1 + Seed.randVfx() * 1.2;
		var sc = (0.3 + c * 0.7) * 100;
		mc._xscale = sc * (Seed.randomVfx(2) * 2 - 1);
		mc._yscale = sc;
		var w = Data.SCROLL_WIDTH[fr] * sc / 100;
		var p = {
			mc: (mc : ASprite),
			c: c,
			w: w,
			x: Cs.mcw + w * 0.5,
			y: 0.0,
			dy: (1 - c) * 50,
			type: 1
		};
		mc._x = p.x;
		mc.updateState();
		setScrollColour(mc, (1 - c) * 70);
		plans.push(p);
		orderPlans();
	}

	// Cs.setPercentColor(mc, prc, 0x984e71): towards the purple of the cave (tint + additive silhouette), or brighter
	// for the elements in front (prc < 0: colour matrix)
	function setScrollColour(mc:Clip, prc:Float) {
		if (prc >= 0) {
			var m = Std.int(100 - prc) / 100;
			var c = prc / 100;
			var g = Std.int(m * 255);
			var add = (Std.int(c * (SCROLL_COLOR >> 16)) << 16) | (Std.int(c * ((SCROLL_COLOR >> 8) & 0xFF)) << 8) | Std.int(c * (SCROLL_COLOR & 0xFF));
			mc.setColour((g << 16) | (g << 8) | g, add);
		} else {
			Cs.setPercentColor(mc, prc, SCROLL_COLOR);
		}
	}

	function orderPlans() {
		var list:Array<{mc:ASprite, c:Float}> = [for (p in plans) {mc: p.mc, c: p.c}];
		list.push({mc: map, c: 1});
		// same comparison as the original (a < b ? -1 : 1), stable sort
		haxe.ds.ArraySort.sort(list, function(a, b) return a.c < b.c ? -1 : (a.c > b.c ? 1 : 0));
		for (o in list)
			dm.over(o.mc);
	}

	// one screen of the cave ceiling: the base and 5 random hanging elements
	function printCaveTop(x:Float) {
		var seg = caveTop.createEmptyMovieClip("seg", 0);
		seg._x = x;
		seg.updateState();
		var base = new PixiSprite(caveBase);
		var src = Tex.get("mcCaveTop_0")[0];
		var px = Clip.K * Clip.getDef("mcCaveTop").r;
		base.anchor.set(0, 0);
		base.x = (src.trim != null ? src.trim.x : 0) / px - src.defaultAnchor.x * src.orig.width / px;
		base.y = (src.trim != null ? src.trim.y : 0) / px - src.defaultAnchor.y * src.orig.height / px;
		base.scale.set(1 / px, 1 / px);
		seg.addChild(base);
		for (i in 0...5) {
			var mc = new Clip("mcTopElement");
			var fr = Seed.randomVfx(mc._totalframes) + 1;
			mc.gotoAndStop(fr);
			var w = Data.TOP_WIDTH[fr];
			mc._x = w * 0.5 + Seed.randVfx() * (Cs.mcw - w);
			mc._y = Seed.randomVfx(10);
			mc.updateState();
			seg.addChild(mc);
		}
		caveSegs.push(seg);
	}

	// PLATEFORMES
	function genPlat(x:Null<Float>, y:Null<Float>, w:Null<Float>) {
		if (x == null)
			x = Cs.mcw * 3 + 8 + Seed.rand() * 100;
		if (y == null)
			y = 140 + Seed.rand() * 150;
		if (w == null)
			w = Math.max(60, 800 - dif * 0.25) + Seed.rand() * 200;

		var to = 0;
		while (true) {
			var flBreak = true;
			for (pl in platList)
				if (pl.x + pl.w > x && Math.abs(y - pl.y) < 60)
					flBreak = false;
			if (flBreak)
				break;
			x = Cs.mcw * 2 + 8 + Seed.rand() * 100;
			y = 140 + Seed.rand() * 150;
			if (to++ > 20)
				return;
		}

		var pl = new Plat(mdm.empty(DP_PLAT));
		pl.x = x;
		pl.setPlat(x, y, w);

		// MONSTER
		var rand = Seed.random(Std.int(Cs.q(Math.pow(dif, 0.2))));
		var max = Std.int(Math.min(Math.ceil(pl.w * 0.02), rand));
		if (max == 0 && pl.w > 160)
			max++;
		var xl:Array<Float> = [];
		to = 0;
		var i = 0;
		while (i < max) {
			var m = new Monster(Clip.attach(mdm, "mcMonster1", DP_MONS));
			var px:Float = 0;
			while (true) {
				px = pl.x + Seed.rand() * pl.w;
				var flBreak = true;
				for (k in xl) {
					if (Math.abs(k - px) < 20) {
						flBreak = false;
						break;
					}
				}
				if (flBreak)
					break;
				if (to++ > 200)
					break;
			}
			if (max == 1 && platList.length == 1)
				px = pl.x + pl.w - 10;
			xl.push(px);
			m.x = px;
			m.y = pl.y - m.ray;
			m.plat = pl;
			var maxId = 1;
			if (dif > 1000)
				maxId++;
			if (dif > 2800)
				maxId++;
			var id = Seed.random(Std.int(Math.min(maxId, max - i)));
			m.setSkin(id);
			m.updatePos();
			max -= id;
			i++;
		}
	}

	// FX
	function updateEnvFX() {
		if (hero.y > Cs.mch) {
			var c = (hero.y - Cs.mch) / Cs.mch;
			if (Seed.randVfx() * c > 0.2) {
				var p = newPart("partLargeLight");
				p.x = Seed.randVfx() * Cs.mcw - map._x;
				p.y = Cs.mch + 10 + Seed.randVfx() * 20 - map._y;
				p.vy = Seed.randVfx() * 6;
				p.timer = 10 + Seed.randVfx() * 10;
				p.fadeType = 0;
				p.setScale(100 + hero.y * 0.2 + Seed.randVfx() * 100);
				p.root.blendMode = BlendModes.ADD;
			}
		}
		// MOUSEDEAD
		if (mouseDeadTimer > 0)
			mouseDeadTimer -= Timer.tmod;

		// MEDUSE PLONGE
		if (hero.flDeath)
			scrollMin -= 13;
	}

	// ---------------------------------------------------------------- MEDUSA
	function initMedusa() {
		// BODY
		medusaBody = new Phys(Clip.attach(mdm, "mcMedusaBody", DP_MEDUSA));
		medusaBody.x = -2000;

		// HEAD
		medusa = new Phys(Clip.attach(mdm, "mcMedusa", DP_MEDUSA));
		medusa.root._visible = false;
		medusa.x = -scrollMin;

		// ARMS: the back one darker (Cs.setPercentColor(root, 50, 0x9D1E91), baked in mcArmDark)
		medusaArms = [];
		var adp = [DP_BACK, DP_SHOT];
		for (i in 0...2) {
			var sp = new Phys(Clip.attach(mdm, i == 0 ? "mcArmDark" : "mcArm", adp[i]));
			sp.x = medusaBody.x;
			sp.y = medusaBody.y;
			medusaArms.push({
				p: sp,
				b: {vr: 0, rot: 0},
				ab: {vr: 0, rot: 0},
				hx: 0,
				hy: 0,
				hFrame: 1
			});
		}

		mcRedLight = Clip.attach(dm, "mcRedLight", DP_FRONT);
		mcRedLight.blendMode = BlendModes.ADD;
		mcRedLight._alpha = 0;
		mcRedLight._y = Cs.mch * 0.5;

		hitMasks = [for (m in Data.HIT_MASKS) haxe.crypto.Base64.decode(m)];
	}

	function head():Clip {
		return cast medusa.root;
	}

	function updateMedusa() {
		mcRedLight._x = medusa.x + map._x;
		mcRedLight._y = medusa.y + map._y;

		// EAT
		if (hero.flEat) {
			medusa.vx += 2 * Timer.tmod;
			medusa.vy += 1.5 * Timer.tmod;
			var frame = Std.int(Math.max(1, head().frame - 3));
			head().gotoAndStop(frame);
			medusa.root._rotation += 1;
			var lim = 166 * (head().frame / 30);
			if (hero.y > lim && hero.vy > 0) {
				hero.y = 166;
				hero.vy *= -0.5;
			}
		} else {
			var limit = 300;
			var danger = scrollMin + hero.x;
			var c = danger / limit;
			var ty = (hero.y + hero.vy * 2) - (1 - c) * 180;

			mcRedLight._alpha = 100 - c * 100;
			mcRedLight._xscale = 500 - c * 200;
			mcRedLight._yscale = mcRedLight._xscale;

			medusa.x = -scrollMin;
			var lim = 2;
			var dy = ty - medusa.y;
			medusa.vy += Cs.mm(-lim, dy * 0.15, lim);

			if (danger > limit) {
				medusa.root._visible = false;
				mcRedLight._visible = false;
				medusaBody.root._visible = false;
			} else {
				if (!medusa.root._visible) {
					medusa.y = ty;
					medusa.root._visible = true;
					mcRedLight._visible = true;
					medusaBody.root._visible = true;
				}
				if (c < 0.7) {
					var frame = 1 + Std.int((1 - (c / 0.7)) * 40);
					head().gotoAndStop(frame);
				}
				medusa.root._rotation = dy * 0.1 + medusa.vy * 0.5;
				if (c < 0.5) {
					var cc = (c / 0.5) * 0.1;
					medusa.y += dy * cc;
				}
				if (c < 0.33)
					eatHero();
			}
		}

		// BODY: MAIN
		var trg = {x: medusa.x - 40, y: medusa.y + 50};
		medusaBody.toward(trg, 0.2, 100);
		var body:Clip = cast medusaBody.root;
		var a = medusaBody.getAng(medusa);
		var dist = medusaBody.getDist(medusa);
		var neckRot = Cs.normRot(a / 0.0174 - Cs.normRot(body._rotation));
		body.setOverride("neck", neckRot, dist, null);
		body._rotation = (neckRot + 45) * 0.5;

		// ARMS
		for (arm in medusaArms) {
			var sp = arm.p;
			var mc:Clip = cast sp.root;
			sp.x = medusaBody.x;
			sp.y = medusaBody.y;
			rotArm(arm.b);
			rotArm(arm.ab);
			// moveToEdge(ab, b, 255, 1.57) / moveToEdge(h, ab, 240, 0): Flash pixels, from the shoulder of the tables
			var k = mc.pxPerUnit();
			var bm = mc.layerMatrix("$b");
			var bx = bm[0] / k;
			var by = bm[1] / k;
			var ang = Cs.normRot(arm.b.rot) * 0.0174 + 1.57;
			var abx = Cs.q(bx + Math.cos(ang) * 255);
			var aby = Cs.q(by + Math.sin(ang) * 255);
			ang = Cs.normRot(arm.ab.rot) * 0.0174;
			arm.hx = Cs.q(abx + Math.cos(ang) * 240);
			arm.hy = Cs.q(aby + Math.sin(ang) * 240);
			mc.setOverride("$b", arm.b.rot, null, null);
			mc.setOverride("$ab", arm.ab.rot, null, null, abx * k, aby * k);
			mc.setOverride("$h", null, null, null, arm.hx * k, arm.hy * k);

			// CHECK PLAT: the hand crushes the platforms
			var hpx = sp.x + arm.hx + map._x;
			var hpy = sp.y + arm.hy + map._y;
			var h = mc.getClip("$h");
			if (hpy < Cs.mch && arm.hFrame == 1) {
				arm.hFrame = 2;
				if (h != null)
					h.gotoAndStop(2);
			}
			if (hpy > Cs.mch && arm.hFrame == 2) {
				arm.hFrame = 1;
				if (h != null)
					h.gotoAndStop(1);
			}
			hpx += 70 - map._x;
			hpy += 70 - map._y;
			if (hpx + map._x > 0 && hpy + map._y < Cs.mcw) {
				for (pl in platList) {
					if (hpx > pl.x && hpx < pl.x + pl.w && Math.abs(hpy - pl.y) < 16) {
						arm.b.vr -= 6;
						pl.explode(hpx);
						break;
					}
				}
			}
		}

		if (medusa.root._visible != true)
			return;

		// HEAD DESTRUCT PLAT (like the original, the platform after a destroyed one is skipped)
		var hray = 120;
		var n = 0;
		while (n < platList.length) {
			var pl = platList[n];
			if (medusa.x + hray > pl.x && medusa.x - hray < pl.x + pl.w && Math.abs(medusa.y - pl.y) < hray * 1.2)
				pl.explode(medusa.x + hray + 30 + Seed.rand() * 50);
			n++;
		}

		// RECAL HEAD
		if (medusa.y < 80) {
			var i = 0;
			while (i < -medusa.vy) {
				var p = newPart("partDust");
				p.x = medusa.x + Seed.randVfx() * 120;
				p.y = 16;
				p.weight = 0.2 + Seed.randVfx() * 0.3;
				p.vx = (Seed.randVfx() * 2 - 1) * 6;
				p.timer = 10 + Seed.randVfx() * 30;
				p.fadeType = 0;
				i++;
			}
			medusa.y = 80;
			medusa.vy = 0;
		}
	}

	// the hero goes into Medusa's mouth
	function eatHero() {
		focus = {x: hero.x, y: hero.y};
		var hd = head();
		var zone = hd.get("eatZone");
		hero.flEat = true;
		hero.releaseGrap();
		hero.setSens(hero.sens);
		hero.initStep(Hero.FLY);
		hero.vx = -6;
		hero.vy -= medusa.vy;
		hero.weight = -4;
		// globalToLocal(eatZone): the zone is at the origin of the head
		var dx = hero.x - medusa.x;
		var dy = hero.y - medusa.y;
		var a = -Cs.normRot(medusa.root._rotation) * Math.PI / 180;
		var lx = Cs.q(dx * Math.cos(a) - dy * Math.sin(a));
		var ly = Cs.q(dx * Math.sin(a) + dy * Math.cos(a));
		hero.eaten(zone, lx, ly, hd.pxPerUnit());
		hero.setSens(hero.sens);
		gameOver();
	}

	function rotArm(m:ArmPart) {
		m.vr += (Seed.rand() * 2 - 1) * 0.8 * Timer.tmod;
		m.vr *= Math.pow(0.9, Timer.tmod);
		m.rot += m.vr * Timer.tmod;
		m.rot *= Math.pow(0.98, Timer.tmod);
	}

	// medusa.root.hitTest(x + map._x, y + map._y, true): shape of the head (bitmask of each frame)
	public function medusaHitTest(x:Float, y:Float):Bool {
		var dx = x - medusa.x;
		var dy = y - medusa.y;
		var a = -Cs.normRot(medusa.root._rotation) * Math.PI / 180;
		var lx = Cs.q(dx * Math.cos(a) - dy * Math.sin(a));
		var ly = Cs.q(dx * Math.sin(a) + dy * Math.cos(a));
		var cx = Math.floor((lx - Data.HIT_X0) / Data.HIT_CELL);
		var cy = Math.floor((ly - Data.HIT_Y0) / Data.HIT_CELL);
		if (cx < 0 || cy < 0 || cx >= Data.HIT_W || cy >= Data.HIT_H)
			return false;
		var bits = hitMasks[head().frame - 1];
		var idx = cy * Data.HIT_W + cx;
		return (bits.get(idx >> 3) & (0x80 >> (idx & 7))) != 0;
	}

	// ---------------------------------------------------------------- MOUSE
	// the mouse pointer is part of the game (aimed at, it can be shot): not with the touch controls
	public inline function mouseActive():Bool {
		return !touchMode;
	}

	public function mouseMapX():Float {
		return MouseManager.getX() / Clip.K - map._x;
	}

	public function mouseMapY():Float {
		return MouseManager.getY() / Clip.K - map._y;
	}

	public function killMouse() {
		flMouseDead = true;
		mouseDeadTimer = 50;
		setCursor(true);
	}

	function updateCursor() {
		// mouseMove of the original: the pointer comes back when it moves after 50 frames
		var mx = MouseManager.getX();
		var my = MouseManager.getY();
		var moved = mx != lastMouseX || my != lastMouseY;
		lastMouseX = mx;
		lastMouseY = my;
		if (flMouseDead && mouseDeadTimer <= 0 && moved) {
			flMouseDead = false;
			setCursor(false);
		}
	}

	function setCursor(hidden:Bool) {
		if (isReplay || hidden == cursorHidden)
			return;
		cursorHidden = hidden;
		var view = KadoKadeoManager.kkm.canvas;
		if (view != null)
			view.style.cursor = hidden ? "none" : "";
	}

	function isTouchDevice():Bool {
		var nav:Dynamic = js.Browser.navigator;
		if (nav != null && nav.maxTouchPoints != null && nav.maxTouchPoints > 0)
			return true;
		if (Reflect.hasField(js.Browser.window, "ontouchstart"))
			return true;
		var mm = js.Browser.window.matchMedia;
		return mm != null && mm("(pointer: coarse)").matches;
	}

	// ---------------------------------------------------------------- TOOLS
	public function newPart(link:String):Part {
		return new Part(Clip.attach(mdm, link, DP_PARTS));
	}

	public function registerMc(mc:ASprite, ?px:Float, ?py:Float):Sprite {
		// position read before the Sprite hides the clip
		if (px == null)
			px = mc._x;
		if (py == null)
			py = mc._y;
		var sp = new Sprite(mc);
		sp.x = px;
		sp.y = py;
		sp.updatePos();
		return sp;
	}

	public function spawnBonus(x:Float, y:Float, id:Int) {
		if (id == 0)
			return;
		if ((id >= 20 && hero.optList[id - 20] == true) || (id == 7 && hero.hp > 0))
			id = 1;
		if (dif < 500 && hero.hp == 0 && Seed.random(4) == 0)
			id = 7;
		var b = new Bonus(Clip.attach(mdm, "bonus", DP_BONUS));
		b.x = x;
		b.y = y;
		b.setId(id);
		b.updatePos();
	}

	public function genScore(x:Float, y:Float, sc:Int) {
		addScore(sc);
		var p = new Part(mdm.empty(DP_PARTS));
		var field = new Digits(Data.DIGIT_SCORE);
		field.setText(Std.string(KKApi.val(sc)));
		p.root.addChild(field);
		p.x = x;
		p.y = y;
		p.vy = -1;
		p.timer = 24;
		p.updatePos();
	}

	// draw of the rope (lineStyle 4 / 2, round caps like Flash)
	public function drawRope(x0:Float, y0:Float, x1:Float, y1:Float) {
		var st = [[4, 0x7E2301], [2, 0xFEAA8B]];
		for (s in st) {
			(cast mcLine : Dynamic).lineTextureStyle({
				width: s[0],
				color: s[1],
				alpha: 1,
				cap: "round",
				join: "round"
			});
			mcLine.moveTo(x0, y0);
			mcLine.lineTo(x1, y1);
		}
	}

	// hero without clothes: Cs.glow(root, 3, 2, 0x662200)
	public function slipGlow(mc:ASprite) {
		mc.filters = [glow(3, 2, 0x662200)];
	}

	// afterimage of the hero (getSnapshot of the original): aura (coloured, glowing) or kick (magenta)
	public function ghost(src:Clip, x:Float, y:Float, rot:Float, xs:Float, plan:Int, timer:Float, fadeLimit:Float, col:Int, prc:Float, glow:Bool) {
		var holder = glow ? auraLayer.createEmptyMovieClip("ghost", 0) : mdm.empty(plan);
		var p = new Part(holder);
		var pic = src.snapshot();
		pic._rotation = rot;
		pic._xscale = xs;
		if (glow) {
			// coloured halo (Cs.glow(root, 20, 1, col))
			var halo = new Clip("partLargeLight");
			halo._xscale = halo._yscale = 260;
			halo.setColour(col, 0);
			halo._alpha = 70;
			holder.addChild(halo);
		}
		holder.addChild(pic);
		var cm = new ColorMatrixFilter();
		var m = Std.int(100 - prc) / 100;
		var c = prc / 100;
		cm.matrix = [
			m, 0, 0, 0,         Std.int(c * (col >> 16)) / 255,
			0, m, 0, 0, Std.int(c * ((col >> 8) & 0xFF)) / 255,
			0, 0, m, 0,        Std.int(c * (col & 0xFF)) / 255,
			0, 0, 0, 1,                                      0
		];
		pic.filters = [cm];
		p.x = x;
		p.y = y;
		p.timer = timer;
		p.fadeLimit = fadeLimit;
		p.updatePos();
		p.onKill = function() {
			holder.destroy({children: true});
		};
	}

	// ---------------------------------------------------------------- SCORE / END
	public function addScore(n:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	public function gameOver() {
		if (over)
			return;
		over = true;
		setCursor(false);
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			hx: hero.x,
			hy: hero.y,
			dif: dif,
			plats: platList.length,
			mons: mList.length,
			stats: haxe.Json.stringify(stats),
			eat: hero.flEat
		};
		#end
		KadoKadeoManager.kkm.gameOver(stats);
	}

	// TOUCH: joystick -> arrow keys (polled and recorded like the keyboard)
	public function pollTouchControls():Void {
		var joystick = KadoKadeoManager.kkm.getTouchJoystickState();
		if (joystick == null)
			return;
		var axisX = joystick.active ? joystick.dirX : 0;
		var axisY = joystick.active ? joystick.dirY : 0;
		setDirectionalKey(KeyboardManager.LEFT, axisX < 0);
		setDirectionalKey(KeyboardManager.RIGHT, axisX > 0);
		setDirectionalKey(KeyboardManager.DOWN, axisY > 0);
		// up: the jump button also gives it
		if (axisY < 0)
			KeyboardManager.setKeyDown(KeyboardManager.UP);
		else if (upFromStick)
			KeyboardManager.setKeyUp(KeyboardManager.UP);
		upFromStick = axisY < 0;
	}

	var upFromStick:Bool = false;
	var lastMouseX:Int = 0;
	var lastMouseY:Int = 0;

	inline function setDirectionalKey(keyCode:Int, down:Bool):Void {
		if (down) {
			KeyboardManager.setKeyDown(keyCode);
		} else {
			KeyboardManager.setKeyUp(keyCode);
		}
	}

	#if debug
	// test harness only: clips drawn on a grid over the game, frozen ([name, frame, x, y, scale] in Flash pixels x2)
	public function debugShow(list:Array<Array<Dynamic>>, bgColor:Int) {
		var stage:Dynamic = untyped KadoKadeoManager.kkm.stage;
		var box = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		for (o in list) {
			var c = new Clip(o[0], 2);
			c.gotoAndStop(o[1]);
			c.freeze();
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
		setCursor(false);
		Hero.SPEED = 6;
		Bonus.UNIQUE = null;
		Cs.game = null;
	}
}

package kslash;

import common_haxe_avm1.KeyboardManager;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import mt.DepthManager;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;
import pixi.filters.colormatrix.ColorMatrixFilter;
import kado.TouchControlsConfig.TouchButtonShape;

typedef Plat = {x:Int, y:Int, w:Int, mc:PlatGfx};
typedef Plan = {mc:ASprite, c:Float};
typedef Square = {block:Bool, list:Array<Monster>};

@:expose('GameKSlash')
class Game implements kado.GameInterface {
	// mobile: a cross of arrows (up: jump, down: through the platform) + shuriken button (the layout of Kanji's Adventure)
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
	public static inline var DP_BACK = 2;
	public static inline var DP_MAP = 3;
	public static inline var DP_FRONT = 4;
	public static inline var DP_INTER = 5;

	//
	public static inline var DP_MAPBG = 1;
	public static inline var DP_DECOR = 2;
	public static inline var DP_SHADE = 3;
	public static inline var DP_BONUS = 4;
	public static inline var DP_MONSTER = 5;
	public static inline var DP_HERO = 7;
	public static inline var DP_SHOOT = 10;
	public static inline var DP_PARTS = 12;

	public static inline var XMAX = 25;
	public static inline var YMAX = 25;

	static var NIGHT_CODE = [78, 73, 71, 72, 84];

	// replay event: the secret code NIGHT was typed (the letters are not recorded keys)
	static inline var EV_NIGHT = 1;

	public var flNight:Bool;

	var nightIndex:Int;
	var nightTyped:Bool;

	public var monsterLevel:Int;

	var monsterLevelMax:Float;

	public var dif:Float;

	public var pList:Array<Part>;
	public var platList:Array<Plat>;
	public var mList:Array<Monster>;
	public var sList:Array<Shoot>;
	public var nsList:Array<Shoot>;
	public var bList:Array<Bonus>;

	var iconList:Array<Clip>;
	var planList:Array<Plan>;

	public var optList:Array<Bool>;

	public var stats:{
		opt:Array<Int>,
		bads:Array<Int>,
		dif:Int,
		k:Array<Int>,
		sk:Array<Int>,
		respawn:Int,
		supak:Int,
		fssc:Int,
		maxs:Int,
		maxb:Int,
	};

	public var dm:DepthManager;
	public var mdm:DepthManager;

	public var hero:Hero;

	var root:ASprite;
	var bg:ASprite;
	var map:ASprite;
	var inter:Clip;
	var starField:Digits;

	var grid:Array<Array<Square>>;

	var isReplay:Bool;
	var frameCount:Int;
	var over:Bool;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
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
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});

		Cs.game = this;
		Hero.SPEED = 5;
		Clip.flushRemoved();
		frameCount = 0;
		over = false;
		nightTyped = false;

		// the game runs in the Flash pixels of the original (300 x 300), drawn x2
		this.root = root.createEmptyMovieClip("scene", 0);
		this.root._xscale = this.root._yscale = 100 * Clip.K;
		this.root.updateState();
		dm = new DepthManager(this.root);
		bg = decorPlan(Data.DECOR_BG, 1, DP_BG);
		inter = Clip.attach(dm, "inter", DP_INTER);
		// the clip is in its texture pixels (pxPerUnit per Flash pixel)
		starField = new Digits(Data.DIGIT_STAR, inter.pxPerUnit());
		inter.addChild(starField);

		mList = [];
		sList = [];
		bList = [];
		pList = [];
		nsList = [];
		iconList = [];
		planList = [];
		stats = {
			opt: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			bads: [0, 0, 0, 0, 0],
			dif: null,
			k: [0, 0, 0, 0, 0],
			sk: [0, 0, 0, 0, 0],
			respawn: 0,
			supak: 0,
			fssc: 0,
			maxs: 0,
			maxb: 0,
		};

		initMap();
		planList.push({mc: bg, c: 0.13});
		planList.push({mc: map, c: 1});

		for (n in 0...2) {
			var frames = n == 0 ? Data.DECOR_FRONT : Data.DECOR_BACK;
			var widths = n == 0 ? Data.FRONT_WIDTH : Data.BACK_WIDTH;
			for (i in 0...10) {
				var m = decorPlan(frames, i + 1, n == 0 ? DP_FRONT : DP_BACK);
				var c = (widths[i] - 300) / 300;
				planList.push({mc: m, c: c});
				if (i + 1 == frames.length)
					break;
			}
		}

		hero = new Hero(Clip.attach(mdm, "mcHero", DP_HERO));

		initGrid();
		initPlat();

		monsterLevelMax = 2;
		monsterLevel = 0;

		dif = 0;

		optList = [false, false, false];
		updateIcons();

		flNight = false;
		// (only the colours change: random of the decor)
		if (Seed.randVfx() * 500 < 1)
			setNight();

		nightIndex = 0;

		warmShaders();
	}

	function pushKey(n:Int) {
		if (n == NIGHT_CODE[nightIndex]) {
			nightIndex++;
			if (nightIndex == NIGHT_CODE.length) {
				// shown at the next frame, when the replay plays the event
				KadoKadeoManager.kkm.replay.recordEvent({k: EV_NIGHT});
				nightTyped = true;
			}
		} else {
			nightIndex = 0;
		}
	}

	function initMap() {
		map = dm.empty(DP_MAP);
		mdm = new DepthManager(map);
	}

	// a decor sprite (bg, bgFront, bgBack) on a frame: its bitmaps at their resolution, placed by the matrices of their
	// shapes
	function decorPlan(frames:Array<Array<Array<Float>>>, f:Int, plan:Int):ASprite {
		var mc = dm.empty(plan);
		setDecorFrame(mc, frames[f - 1]);
		return mc;
	}

	function setDecorFrame(mc:ASprite, bitmaps:Array<Array<Float>>) {
		mc.removeChildren();
		for (b in bitmaps) {
			var t = Tex.get("decor" + Std.int(b[0]))[0];
			var s = new PixiSprite(t);
			// (no rotation or skew in these matrices)
			s.scale.set(b[1], b[4]);
			s.position.set(b[5], b[6]);
			mc.addChild(s);
		}
	}

	function initGrid() {
		grid = [];
		for (x in 0...XMAX) {
			grid[x] = [];
			for (y in 0...YMAX) {
				grid[x][y] = {block: false, list: []};
			}
		}
	}

	function initPlat() {
		platList = [
			{
				x: 0,
				y: YMAX - 1,
				w: XMAX,
				mc: null
			}
		];
		var y = YMAX - 1;

		while (y > 8) {
			y -= Cs.PLAT_ECART;
			var x = Seed.random(4);
			while (x < XMAX) {
				var w = 2 + Seed.random(8);
				platList.push({
					x: x,
					y: y,
					w: w,
					mc: null
				});
				x += w + 2 + Std.int(Seed.random(8) * (1 - (y / YMAX)));
			}
		}

		for (o in platList) {
			o.mc = new PlatGfx(mdm.empty(DP_DECOR));
			setPlat(o);
		}
	}

	function setPlat(o:Plat) {
		var c = 19;
		var mc = o.mc;
		mc.root._x = Cs.SIZE * o.x;
		mc.root._y = Cs.SIZE * o.y;
		mc.set((o.w * Cs.SIZE) - 2 * c, flNight ? 2 : 1);
		mc.root.updateState();

		for (n in 0...o.w) {
			var sq = square(o.x + n, o.y);
			if (sq != null)
				sq.block = true;
		}
	}

	// The first use of a filter compiles its shader on the graphics card: tens of ms during which the game freezes (the
	// first monster hit, the super hero). The colour matrix is compiled now, at the start, on a tiny sprite off screen.
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new pixi.core.display.Container();
		var s = new PixiSprite(Texture.WHITE);
		s.filters = [new ColorMatrixFilter()];
		holder.addChild(s);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	// ---------------------------------------------------------------- MAIN
	public function update(delta:Float) {
		// clips removed by their own timeline during the update of the display (taken out now: not in the middle of
		// the loop on their parent)
		Clip.flushRemoved();
		for (e in KadoKadeoManager.kkm.replay.consumeEvents())
			if (e != null && e.k == EV_NIGHT)
				setNight();
		if (nightTyped) {
			nightTyped = false;
			setNight();
		}
		if (!isReplay)
			for (c in KeyboardManager.getFrameKeyChanges())
				if (c.isDown)
					pushKey(c.keyCode);
		frameCount++;

		// (lists walked like the original: an element removed during the loop makes the next one wait for the next
		// frame, the kunais are twice in sList)
		hero.update();
		var i = 0;
		while (i < mList.length) {
			mList[i].update();
			i++;
		}
		i = 0;
		while (i < sList.length) {
			sList[i].update();
			i++;
		}
		i = 0;
		while (i < bList.length) {
			bList[i].update();
			i++;
		}
		updateScroll();
		updateParts();

		if (monsterLevel < monsterLevelMax) {
			addMonster();
		}

		monsterLevelMax += 0.0025 * Timer.tmod;
		dif += 1.5 * Timer.tmod;
	}

	function updateScroll() {
		var snap = hero.snapped;
		hero.snapped = false;
		for (info in planList) {
			var mx = 0;
			var tx = Math.min(Math.max(2 * mx - (XMAX) * Cs.SIZE * 0.5, (Cs.mcw * 0.5 - hero.root._x)), -mx);
			var ty = Math.min(Math.max(-YMAX * Cs.SIZE * 0.5, (Cs.mch * 0.5 - hero.root._y)), 0);
			info.mc._x = tx * info.c;
			info.mc._y = ty * info.c;
			// the hero appears somewhere else: the view jumps there (no slide)
			if (snap && info.mc._prevState != null)
				info.mc._prevState.copyFrom(info.mc._curState);
		}
	}

	//
	function addMonster() {
		// TANKER
		if (dif > 4000 && Seed.random(4) == 0) {
			newMonster(4);
		}
		// FLIER
		if (dif > 1800 && Seed.random(4) == 0) {
			newMonster(3);
		}
		// RUNNER
		newMonster(Seed.random(Std.int(Math.min(Math.ceil(dif / 1300), 3))));
	}

	public function newMonster(id:Int):Monster {
		stats.bads[id]++;
		var sens = (hero.x < XMAX * 0.5) ? 1 : 0;
		var m:Monster = null;
		switch (id) {
			case 0 | 1 | 2:
				var s = new Soldier(Clip.attach(mdm, "mcMonster", DP_MONSTER));
				s.x = sens * XMAX;
				s.y = YMAX - (2 + (Seed.random(6)) * Cs.PLAT_ECART);
				s.dx = Seed.rand() * 10;
				s.setSens(-(sens * 2 - 1));
				s.setLevel(id + 1);
				m = s;
			case 3:
				m = new Flyer(Clip.attach(mdm, "mcFlyer", DP_MONSTER));
				m.x = Seed.random(XMAX);
				m.y = 0;
			case 4:
				m = new Tanker(Clip.attach(mdm, "mcTanker", DP_MONSTER));
				m.x = sens * XMAX;
				m.y = YMAX - (2 + (Seed.random(6)) * Cs.PLAT_ECART);
		}

		m.id = id;
		monsterLevel += m.stLevel;
		return m;
	}

	public function spawnBonus(x:Float, y:Float, id:Int) {
		if (id == 0)
			return;
		if (id >= 6 && id < 9) {
			if (optList[id - 6])
				id = 1;
		}
		var b = new Bonus(Clip.attach(mdm, "bonus", DP_BONUS));
		b.root._x = x;
		b.root._y = y;
		b.setId(id);
	}

	//
	public function updateIcons() {
		while (iconList.length > 0)
			iconList.pop().removeMovieClip();
		var x = Cs.mcw;
		var max = 0;
		for (i in 0...optList.length) {
			if (optList[i]) {
				max += i << i;
				var mc = Clip.attach(dm, "mcIcon", DP_INTER);
				mc.gotoAndStop(i + 1);
				mc._x = x;
				x -= 20;
				mc.updateState();
				iconList.push(mc);
			}
		}
		stats.maxb = Std.int(Math.max(stats.maxb, max));
	}

	public function setStarField(n:Int) {
		starField.setText(Std.string(n));
	}

	// GRID (outside of it: undefined in Flash, a free square without monsters)
	inline function square(x:Int, y:Int):Square {
		return (x >= 0 && x < XMAX && y >= 0 && y < YMAX) ? grid[x][y] : null;
	}

	public function checkFree(x:Int, y:Int):Bool {
		var sq = square(x, y);
		return sq == null || !sq.block;
	}

	public function gridList(x:Int, y:Int):Array<Monster> {
		var sq = square(x, y);
		return sq == null ? null : sq.list;
	}

	public function getClosestMonsters():Array<{m:Monster, d:Float}> {
		var list:Array<{m:Monster, d:Float}> = [];

		for (m in mList) {
			var d = Math.max(Math.abs(m.x - hero.x), Math.abs(m.y - hero.y));
			var n = 0;
			do {
				if (n < list.length && list[n].d > d)
					break;
				n++;
			} while (n < list.length);
			list.insert(n, {m: m, d: d});
		}
		return list;
	}

	function setNight() {
		if (!flNight) {
			flNight = true;
			for (o in platList)
				setPlat(o);
			setDecorFrame(bg, Data.DECOR_BG[1]);

			for (o in planList) {
				if (o.c != 1 && o.c > 0.5)
					Cs.setPercentColor(o.mc, 40, 0x000044);
			}
		}
	}

	// PARTS
	function updateParts() {
		var i = 0;
		while (i < pList.length) {
			var p = pList[i];
			if (p.wt != null && p.wt > 0) {
				p.wt -= Timer.tmod;
				if (p.wt <= 0)
					p.root._visible = true;
			} else {
				if (p.weight != null) {
					p.vy += p.weight * Timer.tmod;
				}
				if (p.frict != null) {
					p.vx *= p.frict;
					p.vy *= p.frict;
				}
				if (p.vs != null) {
					p.root._xscale += p.vs * Timer.tmod;
					p.root._yscale += p.vs * Timer.tmod;
				}
				if (p.vr != null) {
					p.root._rotation += p.vr * Timer.tmod;
				}

				p.root._x += p.vx * Timer.tmod;
				p.root._y += p.vy * Timer.tmod;

				if (p.t != null) {
					p.t -= Timer.tmod;
					if (p.t < 0) {
						p.root.removeMovieClip();
						pList.splice(i--, 1);
					} else if (p.t < 10) {
						switch (p.ft) {
							case 0:
								p.root._xscale = p.scale * (p.t / 10);
								p.root._yscale = p.root._xscale;
							default:
								p.root._alpha = p.t * 10;
						}
					}
				}
			}
			i++;
		}
	}

	public function newPart(link:String):Part {
		var mc = Clip.attach(mdm, link, DP_PARTS);
		var p = new Part(mc);
		pList.push(p);
		// partSmoke: t = 0 on its last frame
		mc.onScript = function(name) {
			if (name == "t0")
				p.t = 0;
		};
		return p;
	}

	// mcScore: its text field
	public function newScore(n:Int):Part {
		var mc = mdm.empty(DP_PARTS);
		var field = new Digits(Data.DIGIT_SCORE);
		field.setText(Std.string(n));
		mc.addChild(field);
		var p = new Part(mc);
		pList.push(p);
		return p;
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
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			hx: hero.x,
			hy: hero.y,
			dif: dif,
			mons: mList.length,
			stars: hero.star,
			stats: haxe.Json.stringify(stats),
			night: flNight
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
			// nested clips driven by the code ([name, frame, x, y, scale, {instance: frame}]): before and after the
			// frame change (the clips created on the new frame read them)
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
		Hero.SPEED = 5;
		Clip.flushRemoved();
		Cs.game = null;
	}
}

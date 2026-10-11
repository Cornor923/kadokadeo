package judocommando;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import pixi.core.graphics.Graphics;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;
import pixi.filters.colormatrix.ColorMatrixFilter;

enum Step {
	Trans;
	Play;
	GameOver;
	Editor;
}

// typedef Plan = {>flash.MovieClip, coef:Float}
typedef Plan = {mc:MC, coef:Float};

typedef PlayInfo = {
	_k:Array<Int>,
	_g:Array<Int>,
	_t:Array<Int>,
	_b:Array<Int>,
	_lm:Int
};

@:expose('GameJudoCommando')
class Game implements kado.GameInterface {
	// mobile: a floating joystick (run, up / down: ladders and throws, crouch) + the jump button (Space)
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.JOYSTICK,
		joystick: {
			x: 0.18,
			y: 0.8,
			radius: 84,
			deadZone: 0.3,
			dynamicCenter: true,
		},
		buttons: [
			{
				id: "jump",
				label: "⬆",
				rightPx: 18,
				bottomPx: 30,
				size: 92,
				keyCode: KeyboardManager.SPACE,
			}
		],
	};

	// ZQSD / WASD move like the arrows, Enter jumps like Space
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	// Flash played Judo Commando at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32: tmod = 0.8
	public static inline var FLASH_FPS = 40;

	public static var FL_TEST = false;

	var step:Step;

	public static var DP_MASK = 9;
	public static var DP_FX = 8;
	public static var DP_SCORE = 7;
	public static var DP_PROJECTILES = 6;
	public static var DP_ENT = 4;
	public static var DP_BONUS = 3;
	public static var DP_LEVEL = 2;
	public static var DP_TOWER = 1;
	public static var DP_BG = 0;

	public static var FLOOR = 4;
	public static var START_X = 4;
	public static var START_Y = 17;

	var lvl:Int;
	var rlvl:Int;
	var flGameOver:Bool;
	var flZoom:Bool;
	var levels:Array<Array<Int>>;
	var levelOrder:Array<Int>;

	public var tags:Array<Bool>;

	var coef:Float;

	public var gry:Float;

	public var hero:Hero;

	var grid:Array<Array<Square>>;

	public var monsters:Array<Mon>;
	public var ents:Array<Ent>;

	public var focus:Ent;

	public var mcLevel:MC;
	public var bmpLevel:Bitmap;

	public static var me:Game;

	public var mdm:DM;
	public var dm:DM;
	public var map:MC;
	public var root:MC;
	public var bg:MC;
	public var mcTowerMask:MC;

	public var timestamp:Float;
	public var playInfo:PlayInfo;

	// KadoKadeo
	var scene:ASprite;
	var isReplay:Bool;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	var over:Bool = false;
	var bitmaps:Array<Bitmap> = [];

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(5);
		keys[0] = KeyboardManager.LEFT;
		keys[1] = KeyboardManager.RIGHT;
		keys[2] = KeyboardManager.UP;
		keys[3] = KeyboardManager.DOWN;
		keys[4] = KeyboardManager.SPACE;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		MC.clearAll();
		Clip.reset();
		Sprite.spriteList = [];
		// mt.Timer before its first update (Manager.init creates the game before the first Manager.main)
		mt.Timer.tmod = 1;
		me = this;

		// the original's 300 x 300 stage, drawn x2
		scene = mc.createEmptyMovieClip("scene", 0);
		scene._xscale = scene._yscale = 100 * Clip.K;
		scene.updateState();
		root = new MC();
		scene.addChild(root.spr);

		mdm = root.dm;
		map = mdm.empty(1);
		dm = map.dm;

		initBg();

		lvl = 0;
		rlvl = 0;
		tags = [];
		for (i in 0...Cs.DIAMS)
			tags.push(false);

		timestamp = 0;
		playInfo = {
			_k: [0, 0, 0, 0, 0, 0, 0],
			_g: [0, 0, 0, 0, 0, 0, 0, 0],
			_t: [0, 0, 0, 0, 0, 0, 0, 0],
			_b: [0, 0],
			_lm: 0,
		}

		ents = [];
		monsters = [];

		flZoom = false;
		initScroll();

		// LEVELS (Levels.data, a resource of the original: StringTools.urlDecode + mt.PersistCodec)
		var str = StringTools.urlDecode(Data.LEVELS_ENCRYPTED);
		levels = new mt.PersistCodec().decode(str);

		var a = [];
		for (i in 0...10)
			a.push(i + 3);
		levelOrder = [];
		while (a.length > 0) {
			var coef = Math.min(0.5 + levelOrder.length * 0.2, 1);
			var index = Seed.random(Math.ceil(a.length * coef));
			levelOrder.push(a[index]);
			a.splice(index, 1);
		}
		levelOrder.unshift(Seed.random(3));

		toggleZoom();
		initGame();

		// (mcTracer = dm.empty(10): debug drawings)

		initInter();

		Clip.flushParts();
		flushBitmaps();
		MC.displayAll(1);
		warmShaders();
	}

	// the ColorMatrixFilter of the colour flashes (a monster hit turns red) compiles its shader now, not at the first hit
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null)
			return;
		var holder = new pixi.core.display.Container();
		var s = new PixiSprite(Texture.WHITE);
		s.filters = [new ColorMatrixFilter()];
		holder.addChild(s);
		var g = new Graphics();
		g.beginFill(0xFFFFFF);
		g.drawRect(0, 0, 4, 4);
		g.endFill();
		g.blendMode = untyped PIXI.BLEND_MODES.ERASE;
		holder.addChild(g);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	// ---------------------------------------------------------------- KadoKadeo step: 5 Flash frames every 4 steps
	public function update(delta:Float) {
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame();
		}
		MC.displayAll(frameAcc / 4);
	}

	// one Flash frame: the timelines advance, then Manager.main (tmod ~0.8: Timer settles on 32 / 40)
	function flashFrame() {
		mt.Timer.tmod = 32 / FLASH_FPS;
		MC.frameStart();
		flashUpdate();
		// the first frame scripts of the clips created by the code (head / body / gun of the soldiers)
		Clip.flushParts();
		flushBitmaps();
		frameCount++;
		#if debug
		untyped js.Browser.window.__state = debugState();
		#end
	}

	function flushBitmaps() {
		for (b in bitmaps)
			b.flush();
	}

	// the original update()
	function flashUpdate() {
		switch (step) {
			case Play:
				updatePlay();
			case Trans:
				updateTrans();
			case null:
			default:
		}

		updateInter();
		updateSprites();
	}

	public function updateSprites() {
		var a = Sprite.spriteList.copy();
		for (sp in a)
			sp.update();
	}

	// GAME
	function initGame() {
		hero = new Hero();
		hero.root._x = Cs.mcw * Seed.rand();
		hero.root._y = Cs.mch * Seed.rand();
		initTrans();
		coef = 1;
	}

	// TRANS
	var ttw:Tween;
	var flSwapLevel:Bool;
	var transDec:Float;
	var opx:Float;
	var opy:Float;

	// (the wind particles of the transition are commented out in the original: wind stays null, its loops do nothing)

	function initTrans() {
		step = Trans;
		hero.state = null;
		coef = 0;
		hero.playAnim("jump");

		transDec = Cs.mcw * 2 + 50;

		ttw = new Tween();
		ttw.sx = hero.root._x;
		ttw.sy = hero.root._y;
		ttw.ex = transDec + Cs.getX(START_X + 0.5);
		ttw.ey = Cs.getY(START_Y + 0.5);

		flSwapLevel = false;
	}

	function updateTrans() {
		coef = Math.min(coef + 0.012, 1);

		if (coef > 0.5 && !flSwapLevel)
			decale();

		var p = ttw.getPos(coef);
		p.y -= Cs.q(Math.sin(coef * 3.14) * 150);
		hero.root._x = p.x;
		hero.root._y = p.y;

		if (Math.isNaN(opx)) {
			opx = p.x;
			opy = p.y;
		}
		var vx = p.x - opx;
		var vy = p.y - opy;

		updateScroll();

		mcTowerMask._visible = hero.root._x > Cs.mcw || hero.root._x < 0;

		// CASSE BRIQUE
		var px = Cs.getPX(hero.root._x);
		var py = Cs.getPY(hero.root._y);
		var sq = cell(px, py);
		if (sq != null && (sq.type == BLOCK || sq.type == PLAT)) {
			var c = 1;
			explodeSquare(px, py, vx * c, vy * c);
		}

		// START
		if (coef == 1) {
			endTrans();
			return;
		}

		// ENTS
		var a = ents.copy();
		for (e in a) {
			if (e.type == PART)
				e.update();
		}

		// SPARK
		hero.fxSpark();

		opx = p.x;
		opy = p.y;
	}

	function decale() {
		for (e in ents) {
			e.setPos(e.root._x - transDec, e.root._y);
			e.root.teleport();
		}
		for (sp in Sprite.spriteList) {
			sp.x -= transDec;
			sp.root.teleport();
		}
		cutCamera();
		loadLevel(levelOrder[lvl]);
		opx -= transDec;
		ttw.sx -= transDec;
		ttw.ex -= transDec;
		flSwapLevel = true;
		initEnemies();

		updateLevelInfo();

		hero.playAnim("jumpDown");
	}

	function endTrans() {
		initPlay();
		hero.playAnim("land");
		hero.initStand();
		hero.moveTo(START_X, START_Y);
		hero.blast(30, 0, Cs.CS);
	}

	// PLAY
	var chrono:Int;
	var gorilla:Int;

	function initPlay() {
		gorilla = 0;
		chrono = 2000;
		if (lvl == 0)
			chrono += 4000;
		if (lvl == 1)
			chrono += 2000;
		step = Play;
	}

	function updatePlay() {
		if (hero != null) {
			// CHONO
			if (chrono-- == 0)
				newGorilla();

			// END LEVEL
			if (!hero.flEndLevelOk && monsters.length - gorilla == 0) {
				fxScore(hero.root._x, hero.root._y - 15, Cs.SCORE_FINISH);
				hero.flEndLevelOk = true;
			}
			// (Enter: the end of the time, test build only)
		}

		var a = ents.copy();
		for (e in a)
			e.update();

		updateScroll();
	}

	public function endLevel() {
		var a = ents.copy();
		for (e in a) {
			if (e.type != HERO)
				e.kill();
		}
		lvl++;
		rlvl++;
		initTrans();
	}

	// ENNEMIES
	function initEnemies() {
		var a = [];
		var dxlim = 3;
		if (lvl > 0)
			dxlim = 0;

		for (x in 0...Cs.XMAX) {
			for (y in 0...Cs.YMAX) {
				var sq = grid[x][y];
				var gr = cell(x, y + 1);
				if (sq.type == EMPTY && gr != null && isGround(gr.type)) {
					var dx = Math.abs(x - START_X);
					if (y != START_Y || dx > dxlim)
						a.push(sq);
				}
			}
		}

		var max = 2 + lvl * 4;
		for (i in 0...max) {
			var index = Seed.random(a.length);
			var sq = a[index];
			a.splice(index, 1);
			var m = new Mon();
			m.setType(Standard);
			if (lvl > 0 && i % 3 == 0)
				m.setType(Soldat);
			if (lvl > 1 && i % 4 == 0)
				m.setType(Heavy);
			if (lvl > 1 && i % 5 == 0)
				m.setType(Sapper);
			if (lvl > 2 && i % 6 == 0)
				m.setType(Ninja);

			if (sq == null) {
				// no free square left (from level 16 on): Flash placed the monster at undefined coordinates, out of
				// the grid, where it never moves again; it still counts in the monsters of the level
				m.ghost();
				m.ox = 0.3 + Seed.rand() * 0.4;
				m.playAnim("stand");
				continue;
			}
			m.moveTo(sq.x, sq.y);
			m.ox = 0.3 + Seed.rand() * 0.4;
			m.playAnim("stand");
			m.updatePos();
		}

		ents.remove(Game.me.hero);
		ents.push(Game.me.hero);
		dm.over(Game.me.hero.root);
	}

	function newGorilla() {
		var m = new Mon();
		m.setType(Gorilla);
		m.moveTo(-5, START_Y);
		m.setSens(1);
		m.jump();
		m.vx = 7;
		m.vy = -6;
		m.flDestructor = true;

		m.updatePos();
		chrono = 1500;
		gorilla++;
	}

	// LEVEL
	function loadLevel(n:Int) {
		// BASE
		grid = [];
		for (x in 0...Cs.XMAX) {
			grid[x] = [];
			for (y in 0...Cs.YMAX) {
				var o:Square = {
					type: (x == 0 || y == 0 || x == Cs.XMAX - 1 || y == Cs.YMAX - 1) ? BLOCK : EMPTY,
					ent: [],
					ladder: false,
					x: x,
					y: y,
				}
				grid[x][y] = o;
			}
		}

		// MODEL (levels[n] of a level past the list: undefined, the custom level)
		var model = n >= 0 && n < levels.length ? levels[n] : null;

		if (model != null) {
			var id = 0;
			var ec = 3;
			for (n in model) {
				var x = Std.int(id / Cs.XMAX);
				var y = id % Cs.YMAX;
				grid[x][y] = {
					type: [EMPTY, BLOCK, PLAT][n % ec],
					ladder: n >= ec,
					ent: [],
					x: x,
					y: y,
				}
				id++;
			}
		} else { // CUSTOM
			for (i in 0...6)
				grid[5 + i][13].type = BLOCK;
			for (i in 0...6)
				grid[10 + i][11].type = BLOCK;
			grid[10][12].type = BLOCK;
			for (i in 0...6)
				grid[15][10 - i].ladder = true;

			for (i in 0...12)
				grid[4 + i][5].type = BLOCK;

			for (i in 0...4)
				grid[14 + i][14].type = BLOCK;
			for (i in 0...3)
				grid[12 + i][15].type = BLOCK;

			for (i in 0...5)
				grid[1 + i][16].type = PLAT;
		}

		// DRAW
		drawLevel();
	}

	function drawLevel() {
		if (mcLevel == null) {
			mcLevel = dm.empty(DP_LEVEL);
			bmpLevel = newBitmap(Cs.mcw, Cs.mch);
			mcLevel.attachBitmap(bmpLevel.tex);
		}

		bmpLevel.clear();
		// mcSquare: frame 1 empty, 2 brick, 3 plank (smc on a random frame, Col.setColor(mc.smc, 0, -30)), ladder on
		// top when the square has one
		for (x in 0...Cs.XMAX) {
			for (y in 0...Cs.YMAX) {
				var sq = grid[x][y];
				var sx = Cs.getX(x);
				var sy = Cs.getY(y);
				switch (sq.type) {
					case BLOCK:
						bmpLevel.draw("tileBrickD", Seed.randomVfx(Data.N_BRICK) + 1, sx, sy);
					case PLAT:
						bmpLevel.draw("tilePlankD", Seed.randomVfx(Data.N_PLANK) + 1, sx, sy);
					default:
				}
				if (sq.ladder)
					bmpLevel.draw("tileLadder", 1, sx, sy);
			}
		}
		bmpLevel.flush();
	}

	var bmpTower:Bitmap;

	function newBitmap(w:Int, h:Int, ?fill:Null<Int>):Bitmap {
		var b = new Bitmap(w, h, fill);
		bitmaps.push(b);
		return b;
	}

	function initBg() {
		// CIEL: mcBg drawn, then each band of 15 px filled with the colour of its pixel at the left (Data.SKY)
		bg = mdm.empty(DP_BG);
		var g = new Graphics();
		var ec = 15;
		var max = Math.ceil(Cs.mch / ec);
		for (i in 0...max) {
			g.beginFill(Data.SKY[i]);
			g.drawRect(0, i * ec, Cs.mcw, ec);
			g.endFill();
		}
		bg.spr.addChild(g);

		// DRAW BG: mcTiles, its smc on a random frame every 10 px
		var bgm = dm.empty(DP_BG);
		var bmp = newBitmap(Cs.mcw, Cs.mch);
		bgm.attachBitmap(bmp.tex);
		var ec = 10;
		var max = Math.ceil(Cs.mcw / ec);
		for (x in 0...max) {
			for (y in 0...max) {
				bmp.draw("bgTile", Seed.randomVfx(Data.N_TILES) + 1, x * ec, y * ec);
			}
		}

		// TOWER: the bricks of mcSquare on a dark red, and the windows
		var bmp = newBitmap(Cs.mcw, Cs.mch, 0x440000);
		for (x in 0...Cs.XMAX) {
			for (y in 0...Cs.YMAX) {
				bmp.draw("tileBrick", Seed.randomVfx(Data.N_BRICK) + 1, Cs.getX(x), Cs.getY(y));
			}
		}
		bmpTower = bmp;

		// FENETRE
		var xmax = 5;
		var ymax = 4;
		var ecx = (Cs.mcw - xmax * 26) / (xmax + 1);
		var ecy = (Cs.mch - ymax * 40) / (ymax + 1);
		for (x in 0...xmax) {
			for (y in 0...ymax) {
				bmp.draw("bgWindow", 1, ecx + x * (26 + ecx), ecy + y * (40 + ecy));
			}
		}

		// ETAGE
		for (i in 0...3) {
			var dp = (i == 1) ? DP_MASK : DP_TOWER;
			var mc = dm.empty(dp);
			mc._x = 0;
			mc._y = (i - 1) * Cs.mch;
			mc.attachBitmap(bmp.tex);
			if (i == 1)
				mcTowerMask = mc;
		}

		// GROUND
		gry = FLOOR * Cs.mch;
	}

	// FALL
	public function initFall() {
		// TOWER
		for (i in 0...FLOOR - 2) {
			var mc = dm.empty(DP_TOWER);
			mc._x = 0;
			mc._y = (i + 2) * Cs.mch;
			mc.attachBitmap(bmpTower.tex);
		}

		var side = Game.me.hero.px <= 0 ? 0 : 1;
		var mc = dm.attach("mcGround", DP_TOWER);
		mc._x = side * Cs.mcw;
		mc._y = gry;
		mc._xscale = -(side * 2 - 1) * 100;
	}

	// GAMEOVER
	public function initGameOver() {
		coef = 0;
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver(playInfo);
	}

	// ZOOM
	var zoom:Float;

	public function toggleZoom() {
		flZoom = !flZoom;
		if (flZoom) {
			zoom = 2;
			map._xscale = map._yscale = 100 * zoom;
		} else {
			zoom = 1;
			map._xscale = map._yscale = 100;
			map._x = 0;
			map._y = 0;
		}
	}

	// SCROLL
	var plans:Array<Plan>;
	var pvx:Float;
	// display: the camera jumps during this Flash frame (the focus put somewhere else at once, a new focus)
	var camCut:Bool = false;

	public function cutCamera() {
		camCut = true;
	}

	function initScroll() {
		plans = [];
		var coef = [0.2, 0.5];
		for (i in 0...2) {
			// (plane 0 under Col.setPercentColor(mc, 50, 0xDD00DD): its picture baked so, mcScrolling0)
			var mc = mdm.attach(i == 0 ? "mcScrolling0" : "mcScrolling", 0);
			mc._y = Cs.mch;
			mc._xscale = mc._yscale = 200;
			mc.gotoAndStop(i + 1);
			mc.wrapX = 480;
			plans.push({mc: mc, coef: coef[i]});
		}
	}

	public function updateScroll() {
		if (flZoom) {
			var p = focus.getPos();

			var lim = gry - 50;
			if (p.y > lim)
				p.y = lim;

			var vx = Cs.mcw * 0.5 - p.x * zoom - map._x;
			var vy = Cs.mch * 0.5 - p.y * zoom - map._y;

			map._x += vx;
			map._y += vy;

			// SHAKE
			if (shake != null) {
				if (shakeTimer-- < 0) {
					shakeTimer = 1;
					shake *= 0.5;
					map._y += shake * shakeSens;
					shakeSens *= -1;
					if (Math.abs(shake) < 1)
						shake = null;
				}
			}

			// SCROLL (the hero removed by a fatality: undefined, NaN, Flash ignores it)
			var by = hero != null ? gry - hero.root._y : Math.NaN;

			if (Math.abs(vx) > 100)
				vx = pvx;
			var bdy = Cs.mch * 0.5 + 106;
			for (p in plans) {
				var mc = p.mc;
				mc._x = Num.sMod(mc._x + vx * p.coef, 480);
				mc._y = bdy + by * p.coef * 0.5;
				if (mc._y < bdy)
					mc._y = bdy;
			}
			pvx = vx;
		}
		if (camCut) {
			map.teleport();
			camCut = false;
		}
	}

	// INTER
	var mcInter:MC;
	var mcInterLevel:MC;
	var gemTimer:Null<Int>;
	var gemStep:Null<Int>;

	public function initInter() {
		mcInter = mdm.empty(5);
		mcInter._y = Cs.mch;
		mcInter._y = 19;
		mcInter._xscale = mcInter._yscale = 200;

		// LIFE BAR
		var mc = mcInter.dm.attach("mcLifeBar", 0);
		mc._x = 1;
		mc._y = -2;

		// LEVEL
		var mc = mcInter.dm.attach("mcLevel", 0);
		mc._x = 44;
		mc._y = -9;
		mcInterLevel = mc;

		updateGems();
		updateLifeBar();
	}

	public function updateLifeBar() {
		mcInter.dm.clear(3);
		var max = hero == null ? 0 : Std.int(hero.life);
		for (i in 0...max) {
			var mc = mcInter.dm.attach("mcLifePoint", 3);
			mc.showAtOnce = true;
			mc._x = 5 + i * 3;
			mc._y = -7;
		}
	}

	function updateLevelInfo() {
		var smc = mcInterLevel.sub("smc");
		if (smc != null)
			smc.gotoAndStop(lvl + 2);
	}

	public function updateGems(?index:Null<Int>) {
		var flAll = true;
		var a = tags;
		if (gemStep != null) {
			a = [];
			flAll = false;
			for (i in 0...Cs.DIAMS)
				a[i] = gemStep <= i;
		}

		mcInter.dm.clear(4);

		for (i in 0...Cs.DIAMS) {
			var mc = mcInter.dm.attach("mcGem", 4);
			mc.showAtOnce = true;
			var p = getGemPos(i);
			mc._x = p.x;
			mc._y = p.y;
			var fr = i + 1;
			if (gemStep == 0)
				fr = (fr + gemTimer) % Cs.DIAMS + 1;
			mc.gotoAndStop(a[i] ? fr : 11);
			if (i != index || gemStep != null) {
				var smc = mc.sub("smc");
				if (smc != null)
					smc.gotoAndStop(smc.def.n);
			}
			if (!a[i])
				flAll = false;
		}
		if (flAll) {
			tags = [];
			gemTimer = 50;
			gemStep = 0;
		}
	}

	function getGemPos(i:Int):{x:Float, y:Float} {
		return {x: 88 + i * 8, y: -5};
	}

	function updateInter() {
		if (gemTimer != null) {
			if (gemTimer-- < 0) {
				// FX
				var max = 16;
				for (i in 0...max) {
					var mc = mcInter.dm.attach("mcBlinkPix", 5);
					var smc = mc.sub("smc");
					if (smc != null)
						smc.setTint(Cs.RAINBOW[gemStep]);
					Cs.randomize(mc);
					mc.play();

					var p = new Phys(mc);
					var pos = getGemPos(gemStep);
					p.x = pos.x + Seed.randomVfx(9) - 4;
					p.y = pos.y + Seed.randomVfx(9) - 4;
					p.fadeType = 1;
					p.timer = 10 + Seed.randomVfx(10);
					p.weight = 0.1 + Seed.randVfx() * 0.1;
					p.frict = 0.8;
				}

				// SCORE (the hero removed by a fatality: undefined.getPos() is undefined, the score popup at NaN)
				var hp = hero != null ? hero.getPos() : {x: Math.NaN, y: Math.NaN};
				if (gemStep == 0) {
					fxScore(hp.x, hp.y, Cs.SCORE_ALL_GEM);
				}

				gemStep++;
				gemTimer = 5;
				if (gemStep == Cs.DIAMS) {
					gemStep = null;
					gemTimer = null;
				}
			}
			updateGems();
		}
	}

	// LEVEL
	public function explodeSquare(px:Int, py:Int, vx = 0.0, vy = 0.0) {
		var sq = cell(px, py);
		if (sq == null) {
			// out of the grid: undefined, Flash goes on with nothing to clear or to change but the shake
			fxShake(10);
			return;
		}
		if (sq.type == EMPTY)
			return;
		var x = Std.int(Cs.getX(px));
		var y = Std.int(Cs.getY(py));
		bmpLevel.clearRect(x, y, Cs.CS, Cs.CS);

		switch (sq.type) {
			case BLOCK:
				for (i in 0...12) {
					var p = newSquarePart(px, py, 4, vx, vy);
				}
				var max = 1 + Seed.randomVfx(2);
				for (i in 0...max) {
					// (Col.setColor(p.root, 0, -30): the picture is baked darker, partBrick)
					var p = newSquarePart(px, py, 4, vx, vy, "partBrick");
					p.root.gotoAndStop(i + 1);
					p.vr = (Seed.randVfx() * 2 - 1) * 8;
					p.ray = 0.15;
					p.fadeType = 0;
					p.fadeLimit = 15;
					p.timer += 30;
					p.groundFrict = 0.75;
				}
			case PLAT:
				var impact = 4;
				for (i in 0...5) {
					var p = newSquarePart(px, py, 4, vx, vy, "partWood");
					p.root.gotoAndStop(i + 1);
					p.vr = (Seed.randVfx() * 2 - 1) * 8;
					p.ray = 0.15;
					p.fadeType = 0;
					p.fadeLimit = 15;
					p.timer += 30;
					p.groundFrict = 0.75;
				}
			default:
		}
		fxShake(10);
		sq.type = EMPTY;
		sq.ladder = false;
	}

	public function newSquarePart(px:Int, py:Int, impact:Float, vx:Float, vy:Float, ?link:String):Part {
		var p = newShard(link);
		p.moveTo(px, py);
		p.ox = Seed.randVfx();
		p.oy = Seed.randVfx();
		p.vx = (Seed.randVfx() * 2 - 1) * impact + vx * Seed.randVfx();
		p.vy = (Seed.randVfx() * 2 - 1) * impact + vy * Seed.randVfx();
		return p;
	}

	// FX
	var shake:Null<Float>;
	var shakeTimer:Int;
	var shakeSens:Int;

	public function fxShake(shakeAmount:Float) {
		if (step == Trans)
			return;
		shake = shakeAmount;
		shakeTimer = 0;
		shakeSens = 1;
	}

	public function fxBrickDust(sq:Square, sx:Int, sy:Int) {
		// (sq: the square of an entity out of the grid is null, Flash read undefined: the dust at NaN, never shown)
		if (sq == null)
			return;
		var ox = 0.5 + sx * 0.4;
		var oy = 0.5 + sy * 0.4;

		var impact = 3;
		var max = Std.int(3 + impact * 2);

		for (i in 0...max) {
			if (sx == 0)
				ox = Seed.randVfx();
			if (sy == 0)
				oy = Seed.randVfx();
			var p = newShard();
			p.moveTo(sq.x, sq.y);
			p.ox = ox;
			p.oy = oy;
			p.vx = (Seed.randVfx() * 2 - 1) * impact;
			p.vy = (Seed.randVfx() * 2 - 1) * impact;
			p.frict = 0.97;
			p.updatePos();
		}
	}

	public function fxScore(x:Float, y:Float, sc:KKConst) {
		addScore(KKApi.val(sc));
		if (KKApi.val(sc) < 200)
			return;

		var root = dm.empty(DP_SCORE);
		var score = Std.string(KKApi.val(sc));
		var dm = root.dm;
		var ec = 4;
		var id = 0;
		var dx = -Std.int(score.length * ec * 0.5);
		while (score.length > 0) {
			var ch = score.charAt(0);
			score = score.substr(1, score.length);
			var mc = dm.attach("mcNum", 0);
			mc.gotoAndStop(Std.parseInt(ch) + 1);
			mc._x = id * ec + dx;
			mc._y = -3;
			id++;
		}

		var p = new Phys(root);
		p.x = x;
		p.y = y;
		p.weight = -0.1;
		p.timer = 30;
		p.frict = 0.7;
		p.fadeType = 1;
	}

	// KKApi.addScore: nothing after the game over
	function addScore(n:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	public function fxAttach(link:String, x:Float, y:Float):MC {
		var mc = dm.attach(link, DP_FX);
		mc._x = x;
		mc._y = y;
		return mc;
	}

	function newShard(link = "fxBrickDust"):Part {
		if (link == null)
			link = "fxBrickDust";
		var p = new Part(dm.attach(link, DP_FX));
		p.initPhys();
		p.weight = 0.1 + Seed.randVfx() * 0.1;
		p.timer = 30 + Seed.randVfx() * 50;
		p.ray = 0.01;
		p.bounceFrict = 0.5;
		p.groundFrict = 0.9;
		Cs.randomize(p.root);
		return p;
	}

	public function fxFlash(fr:Int) {
		var mc = mdm.attach("mcFlash", 12);
		var smc = mc.sub("smc");
		if (smc != null)
			smc.gotoAndStop(fr);
	}

	// GET
	// (null in the grid before the first level is loaded: Flash read grid[px][py] as undefined, see Ent.insertInGrid)
	public function getSq(px:Int, py:Int):Square {
		if (px < 0 || px >= Cs.XMAX)
			return {type: EMPTY, ladder: false, ent: [], x: px, y: py};
		if (py < 0 || py >= Cs.YMAX)
			return {type: BLOCK, ladder: false, ent: [], x: px, y: py};
		if (grid == null)
			return null;
		// (a monster before its first moveTo: px undefined, grid[undefined] is undefined)
		var col = grid[px];
		return col == null ? null : col[py];
	}

	// grid[px][py] (undefined out of the grid, or before the first level)
	inline function cell(px:Int, py:Int):Square {
		return grid != null && px >= 0 && px < Cs.XMAX && py >= 0 && py < Cs.YMAX ? grid[px][py] : null;
	}

	// IS
	public function isGround(t:SquareType):Bool {
		return t == BLOCK || t == PLAT;
	}

	public function isJumpFree(px:Int, py:Int):Bool {
		var sq = cell(px, py);
		var type = sq != null ? sq.type : null;
		return type == EMPTY || type == PLAT;
	}

	public function isFree(px:Int, py:Int):Bool {
		var sq = cell(px, py);
		var type = sq != null ? sq.type : null;
		return type == EMPTY || type == PLAT;
	}

	public function isHangable(px:Int, py:Int):Bool {
		var sq = cell(px, py);
		var type = sq != null ? sq.type : null;
		return type == PLAT;
	}

	// TOUCH: joystick -> arrow keys (polled and recorded like the keyboard)
	public function pollTouchControls():Void {
		var j = KadoKadeoManager.kkm.getTouchJoystickState();
		if (j == null)
			return;
		var ax = j.active ? j.dirX : 0;
		var ay = j.active ? j.dirY : 0;
		setKey(KeyboardManager.LEFT, ax < 0);
		setKey(KeyboardManager.RIGHT, ax > 0);
		setKey(KeyboardManager.UP, ay < 0);
		setKey(KeyboardManager.DOWN, ay > 0);
	}

	inline function setKey(keyCode:Int, down:Bool):Void {
		if (down)
			KeyboardManager.setKeyDown(keyCode);
		else
			KeyboardManager.setKeyUp(keyCode);
	}

	#if debug
	// state compared between a game and its replay (test harness)
	function debugState():Dynamic {
		var h = hero;
		var ms = [for (m in monsters) m.px + ":" + m.py + ":" + Math.round(m.ox * 1000) + ":" + Std.string(m.state) + ":" + m.life];
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			lvl: lvl,
			step: Std.string(step),
			hx: h != null ? h.px : -1,
			hy: h != null ? h.py : -1,
			hox: h != null ? Math.round(h.ox * 1000) : -1,
			hoy: h != null ? Math.round(h.oy * 1000) : -1,
			hst: h != null ? Std.string(h.state) : "dead",
			life: h != null ? h.life : -1,
			chrono: chrono,
			mons: monsters.length,
			monsHash: haxe.crypto.Md5.encode(ms.join(",")),
			ents: ents.length,
			over: over,
			info: haxe.Json.stringify(playInfo),
		};
	}

	// test harness: clips drawn by the runtime on a page, to compare with the SWF (examples/judocommando/ncheck.mjs,
	// ref.py): [name, frame or label, x, y, scale, {path of a nested clip ("smc", "smc.smc"): frame}, {var: n}]
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
			var subs:Dynamic = o[5];
			var paths = Reflect.fields(subs);
			paths.sort((a, b) -> a.split(".").length - b.split(".").length);
			for (p in paths) {
				var cl = c;
				for (nm in p.split("."))
					cl = cl != null ? cl.getClip(nm) : null;
				if (cl != null)
					cl.gotoAndStop(Reflect.field(subs, p));
			}
			// _hfr / _bfr / _gfr on root.smc (Mon.setType), _afr on the hero
			var vars:Dynamic = o[6];
			for (k in Reflect.fields(vars)) {
				var t = k == "afr" ? c : c.getClip("smc");
				if (t != null)
					t.setVar(k, Reflect.field(vars, k));
			}
			c._x = o[2];
			c._y = o[3];
			c._xscale = c._yscale = o[4] * 100;
			box.addChild(c);
		}
		Clip.flushParts();
		box.updateState();
		box.updateGraphics(1);
		stage.addChild(box);
	}
	#end

	public function destroy():Void {
		me = null;
		MC.clearAll();
		Clip.reset();
		Sprite.spriteList = [];
		for (b in bitmaps)
			b.dispose();
		bitmaps = [];
	}
}

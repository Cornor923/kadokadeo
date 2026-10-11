package digestomax;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import digestomax.Cs.Num;
import digestomax.MC.Plans;
import pixi.core.Pixi.BlendModes;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;

typedef Spawn = {x:Float, y:Float, sc:KKConst, color:Int};

// Game.hx of the original (Haxe for Flash 8), line by line; the port's own parts are at the end

@:expose('GameDigestomax')
class Game implements kado.GameInterface {
	// left / right walk (and swallow the fruit beside), down swallows the fruit below, up the fruit above (held: the
	// next ones) or poops the stomach upwards
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
		],
	};

	// ZQSD / WASD move like the arrows, Enter = Space
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	// Flash played Digestomax at 40 frames/s (the rate of the SWF and of the KadoKado loader) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	public static var FL_TEST = true;

	public static var DP_FX = 8;

	public static var DP_DECOR = 7;
	public static var DP_PIOU = 6;
	public static var DP_BALLS = 5;

	public static var DP_STOMACH_1 = 4;
	public static var DP_STOMACH_0 = 3;
	public static var DP_INTER = 2;
	public static var DP_MAP = 1;
	public static var DP_BG = 0;

	public var coef:Float;
	// (null at the game over: NaN in a calculation, like Flash)
	public var upc:Float;
	public var heightMax:Int;
	public var lvl:Int;
	public var lineCount:Int;
	public var bonusStomach:Int;

	var flhColor:Int;
	var flh:Null<Float>;

	public var grid:Array<Array<Ball>>;
	public var balls:Array<Ball>;
	public var work:Array<Ball>;
	public var fallList:Array<Ball>;

	public var scoreSpawn:Array<Spawn>;

	public var hero:Piou;

	public var action:Void->Void;

	public static var me:Game;

	public var mdm:Plans;
	public var dm:Plans;
	public var root:ASprite;
	public var bg:MC;
	public var map:MC;
	public var mcShow:MC;
	public var mcInter:MC;
	public var mcTimer:TimerMC;
	public var mcLevel:LevelMC;

	// port
	var isReplay:Bool;
	var stage:ASprite;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	// Col.setPercentColor(root, prc, flhColor) of updateFlash: the colour transform of the whole game, drawn as a
	// multiply quad and an add quad over it (the game covers the screen with opaque pictures)
	var flashMul:PixiSprite;
	var flashAdd:PixiSprite;
	var flashPrc:Float = 0;
	var flashPrcPrev:Float = 0;
	var flashCol:Int = 0;
	// the score of KKApi (addScore), nothing after the game over
	var score:Int = 0;
	var over:Bool = false;

	#if debug
	// test harness: events of the game (coverage)
	public var stats = {
		eaten: 0,
		eatUp: 0,
		dig: 0,
		poops: 0,
		combos: 0,
		lines: 0,
		levels: 0,
		perfect: 0,
		flash: 0,
		gulp: 0,
		stomachUp: 0,
		full: 0
	};
	#end

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
		Cs.reset();
		Piou.reset();
		// mt.Timer before its first update (Manager.init creates the game before the first Manager.main)
		Timer.tmod = 1;
		Clip.deferring = true;
		stage = mc;

		Cs.init();
		// the original's 300x300 pixels, drawn x2
		root = mc.createEmptyMovieClip("scene", 0);
		root._xscale = root._yscale = 100 * Clip.K;
		root.updateState();
		me = this;
		mdm = new Plans(root);
		bg = mdm.attach("mcBg", DP_BG);

		fallList = [];
		balls = [];
		work = [];

		initMap();
		initGrid();
		initPlay();

		upc = 0;
		heightMax = 0;

		hero = new Piou(4, Cs.YMAX - 1);
		initInter();

		lvl = 0;
		levelUp();

		initFlash();
		Clip.deferring = false;
		Clip.runLater();
		MC.displayAll(1);
		mcTimer.show(1);
		// Flash shows the first picture after the first frame (Manager.init, then Manager.main): nothing before
		root.visible = false;
		warmShaders();
	}

	public function initGrid() {
		var lim = 7;

		grid = [];
		for (x in 0...Cs.XMAX)
			grid[x] = [];

		// (no hero yet: undefined, nothing)
		dm.over(hero != null ? hero.root : null);
	}

	public function initMap() {
		map = mdm.empty(DP_MAP);
		map._y = 14;
		dm = new Plans(map.clip, map);

		// GROUND: mcTile drawn into a white 300 x 200 BitmapData (see Ground)
		var mc = dm.empty(DP_DECOR);
		mc.clip.addChild(new Ground(Cs.mcw, 200));
		mc._y = Cs.YMAX * Cs.CS;
	}

	//
	public function levelUp() {
		bonusStomach = 0;
		upc = 0;
		lvl++;
		lineCount = lvl + 1;
		if (lineCount > 5)
			lineCount = 5;
		Cs.COMBO_LIMIT = lvl + 1;

		mcLevel.setText(Cs.COMBO_LIMIT);
		newLine();
		#if debug
		stats.levels++;
		#end
	}

	//
	public function origUpdate() {
		if (action != null)
			action();

		var a = Sprite.spriteList.copy();
		for (sp in a)
			sp.update();

		if (flh != null)
			updateFlash();
	}

	// SCROLL (never called)
	public function updateScroll() {
		var ty = Cs.mch * 0.5 - hero.root._y;
		var dy = ty - map._y;
		var lim = 12;
		map._y += Num.mm(-lim, dy * 0.1, lim);

		var lim = Cs.mch - (Cs.YMAX * Cs.CS + 60);
		if (map._y < lim)
			map._y = lim;
	}

	// PLAY
	public function initPlay() {
		action = updatePlay;
	}

	function updatePlay() {
		upc = Math.min(upc + 0.0001 * Math.min(lvl + 1, 6), 1);
		updateTimer(0.3);
		if (upc == 1)
			initGameOver();

		hero.update();
	}

	// COMBOS
	public function checkCombo() {
		scoreSpawn = [];
		work = [];
		var list = getGroups(grid);

		for (a in list) {
			var n = a.length;
			if (n >= Cs.COMBO_LIMIT) {
				var mx = 0;
				var my = 0;
				var col = 0;
				for (bl in a) {
					mx += bl.px;
					my += bl.py;
					work.push(bl);
					col = bl.color;
				}
				var x = Cs.getX(mx / n);
				// (sic: getX, the score of a group appears higher than the group)
				var y = Cs.getX(my / n);
				var sc = Cs.getScore(n);
				scoreSpawn.push({
					x: x,
					y: y,
					sc: sc,
					color: col
				});
				#if debug
				stats.combos++;
				#end
			}
		}
		if (work.length > 0) {
			initExplode();
		} else {
			if (!checkEnd(false))
				initPlay();
		}
	}

	function getGroups(gr:Array<Array<Ball>>) {
		var gList:Array<Array<Ball>> = [];
		for (bl in balls)
			bl.gid = null;
		for (b in balls) {
			if (!b.flIce) {
				if (b.gid == null) {
					b.gid = gList.length;
					gList.push([b]);
				}

				for (d in Cs.CDIR) {
					var nx = b.px + d[0];
					var ny = b.py + d[1];
					// (gr[nx][ny] out of the grid or empty: undefined, its colour is never equal)
					var b2 = cell(nx, ny);

					if (b2 != null && b.color == b2.color && b.color != null && !b2.flIce && b.color != 10) {
						if (b2.gid == null) {
							b2.gid = b.gid;
							gList[b.gid].push(b2);
						} else if (b2.gid == b.gid) {} else {
							var kgid = b2.gid;
							var list = gList[kgid];

							for (b3 in list) {
								b3.gid = b.gid;
								gList[b.gid].push(b3);
							}
							gList[kgid] = null;
						}
					}
				}
			}
		}

		var i = 0;
		while (i < gList.length) {
			if (gList[i] == null)
				gList.splice(i, 1);
			else
				i++;
		}

		return gList;
	}

	// EXPLOSION
	public function initExplode() {
		action = updateExplode;
		coef = 0;
	}

	public function updateExplode() {
		coef = Math.min(coef + 0.1, 1);
		var a = [];

		for (b in work) {
			b.setExplodeFx(coef);
			if (coef == 1) {
				a.push([b.px, b.py]);
				b.explode();
			}
		}
		if (coef == 1) {
			// (a flash fruit swallowed before any combo: explodeAll leaves scoreSpawn undefined, undefined.length > 0 is
			// false in Flash)
			while (scoreSpawn != null && scoreSpawn.length > 0) {
				var o = scoreSpawn.pop();
				addScore(o.sc);
				var p = newScore(o.x, o.y, KKApi.val(o.sc), Cs.FRUIT_COLOR[o.color]);
			};
			action = null;
			initFall();
			if (action == null) {
				if (!checkEnd(false))
					initPlay();
			}
		}
	}

	public function explodeAll(color:Int) {
		work = [];
		for (b in balls) {
			if (b.color == color)
				work.push(b);
		}
		initExplode();
	}

	// FALL
	public function initFall() {
		fallList = [];
		coef = 0;
		heightMax = 0;
		for (x in 0...Cs.XMAX) {
			var a = grid[x];
			var hole = 0;
			for (y in 0...Cs.YMAX) {
				var ball = grid[x][Cs.YMAX - (1 + y)];
				if (ball == null)
					hole++;
				else {
					if (y - hole >= heightMax && ball != Game.me.hero)
						heightMax = y - hole;
					if (hole > 0) {
						ball.fallAmount = hole;
						fallList.push(ball);
					}
				}
			}
		}

		if (fallList.length > 0)
			action = updateFall;
	}

	public function updateFall() {
		hero.update();

		coef += 0.25;
		var a = fallList.copy();
		for (ball in a) {
			ball.display(ball.px, ball.py + coef);
			if (coef >= 1) {
				ball.fallAmount--;
				ball.move(0, 1);
				if (ball.fallAmount == 0)
					fallList.remove(ball);
			}
		}

		if (coef >= 1) {
			if (fallList.length > 0) {
				coef -= 1;
			} else {
				checkCombo();
			}
		}
	}

	public function newUpLine() {
		for (x in 0...Cs.XMAX) {
			var b = new Ball(x, 0);
		}
	}

	public function newLine() {
		lineCount--;

		heightMax++;
		action = updateLine;
		for (x in 0...Cs.XMAX) {
			var top = grid[x][0];
			if (top != null)
				top.explode();
			for (y in 1...Cs.YMAX) {
				var b = grid[x][y];
				// (an empty cell: undefined.move() does nothing)
				if (b != null)
					b.move(0, -1);
			}
		}

		var flTimeout = false;

		for (x in 0...Cs.XMAX) {
			var ball = new Ball(x, Cs.YMAX - 1);
			var to = 0;
			while (true) {
				var flBreak = true;
				var list = getGroups(grid);
				for (a in list) {
					if (a.length >= Cs.COMBO_LIMIT) {
						flBreak = false;
						break;
					}
				}
				if (flBreak)
					break;
				ball.setColor(null);

				if (to++ > 100) {
					flTimeout = true;
					break;
				}
			}
			ball.display(ball.px, ball.py + 1);
			if (flTimeout)
				break;
		}

		coef = 0;
		#if debug
		stats.lines++;
		#end
	}

	public function updateLine() {
		coef = Math.min(coef + 0.15, 1);
		for (b in balls)
			b.display(b.px, b.py + 1 - coef);
		if (coef == 1) {
			if (lineCount > 0)
				newLine()
			else {
				initPlay();
				hero.init();
			}
		}
	}

	//
	public function checkEnd(?flControl:Bool) {
		if (flControl == null)
			flControl = true;

		if (hero.stomachSize <= 0) {
			Game.me.initGameOver();
			return true;
		}

		if (balls.length > 1) {
			if (flControl)
				hero.setAction(hero.control);
			return false;
		} else {
			initBonus();
			return true;
		}
	}

	// TIME SCORE
	public function initBonus() {
		if (hero.stomach.length == 0) {
			var sc = Cs.SCORE_PERFECT;
			addScore(sc);

			var lim = 30;
			var x = Num.mm(lim, hero.root._x, Cs.mcw - lim);

			var p = newScore(x, hero.root._y, KKApi.val(sc));
			p.setScale(150);
			p.vy = -4;
			#if debug
			stats.perfect++;
			#end
		}

		action = updateBonus;
	}

	public function updateBonus() {
		upc = Math.min(upc + 0.02, 1);
		addScore(KKApi.const(15));
		if (upc == 1)
			levelUp();
		updateTimer(1);
	}

	public function initPerfect() {}

	// GAMEVOER
	public function initGameOver() {
		action = gameOver;
		upc = Math.NaN;
		hero.explode();
		endGame();
	}

	function gameOver() {
		updateTimer(0.5);
	}

	// INTER
	static var JMARGIN = 13;
	static var JSIZE = 12;

	public function initInter() {
		// TIMER
		mcTimer = new TimerMC();
		mdm.get(DP_INTER).addChild(mcTimer.clip);
		mcTimer._x = Cs.mcw - (7 + 32);
		mcTimer._y = Cs.mch - 16;
		mcTimer._xscale *= -1;

		//
		mcLevel = new LevelMC();
		mdm.get(DP_INTER).addChild(mcLevel.clip);
		mcLevel._x = Cs.mcw;
		mcLevel._y = Cs.mch;

		// JAUGE
		displayJauge();
	}

	public function displayJauge() {
		mdm.clear(DP_STOMACH_0);
		var mmc = mdm.empty(DP_STOMACH_0);
		var ddm = new Plans(mmc.clip, mmc);
		mmc.clip.filters = [new FlashGlow(2, 2, 4, 0xC17746)];
		for (n in 0...hero.stomachSize) {
			// (mcJauge at 36 %: its picture drawn for that size)
			var mc = ddm.attach("mcJaugeS", DP_STOMACH_0);
			mc._x = JMARGIN + n * JSIZE;
			mc._y = Cs.mch - JMARGIN;
			mc._xscale = mc._yscale = 36;
		}
	}

	public function displayStomach() {
		mdm.clear(DP_STOMACH_1);
		var dif = hero.stomach.length - hero.stomachSize;

		if (dif > 0) {
			mdm.clear(DP_STOMACH_0);
			return;
		}
		for (n in 0...hero.stomach.length) {
			var id = hero.stomach[hero.stomach.length - (1 + n)];
			// (mcBall at 36 %: its fruits drawn for that size)
			var mc = mdm.attach("mcBallS", DP_STOMACH_1);
			mc._x = JMARGIN + n * JSIZE;
			mc._y = Cs.mch - JMARGIN;
			mc._xscale = mc._yscale = 36;
			mc.gotoAndStop(id + 1);
		}
		if (dif == 0) {
			var mc = mdm.attach("mcWarning", DP_STOMACH_1);
			mc._x = JMARGIN + hero.stomachSize * JSIZE + 2;
			mc._y = Cs.mch - JMARGIN;
			mc.clip.filters = [new FlashGlow(2, 2, 4, 0)];
			#if debug
			stats.full++;
			#end
		}
	}

	public function updateTimer(c:Float) {
		var ds = Math.max(0, 98 - upc * 100) - mcTimer.maskXScale;
		// (upc undefined after the game over: NaN, a scale Flash ignores, the gauge stays)
		var v = mcTimer.maskXScale + ds * c;
		if (Math.isFinite(v))
			mcTimer.maskXScale = v;
	}

	// FX
	public function newScore(x:Float, y:Float, n:Int, ?col:Int):Phys {
		if (n == 0)
			return null;
		var p = new Phys(dm.attach("partScore", DP_FX));
		p.x = x;
		p.y = y;
		p.timer = 30;
		p.frict = 0.95;
		p.vy = -1;
		p.fadeType = 0;
		// Reflect.setField(p.root, "_score", Std.string(n)): the text field of its smc shows it
		var smc = p.root.clip.get("smc");
		var d = new Digits();
		d.setText(Std.string(n));
		if (smc != null)
			smc.addChild(d);
		p.root.clip.filters = [new FlashGlow(4, 4, 10, 0xFFFFFF)];
		// Col.setPercentColor(p.root.smc.smc, 70, col): the black text gets the offsets int(0.7 * colour)
		if (col != null)
			d.setColour((Std.int(0.7 * ((col >> 16) & 0xFF)) << 16) | (Std.int(0.7 * ((col >> 8) & 0xFF)) << 8) | Std.int(0.7 * (col & 0xFF)));
		return p;
	}

	public function updateFlash() {
		var prc = flh;
		flh *= 0.6;
		if (flh < 0.1) {
			flh = null;
			prc = 0;
		}
		// Col.setPercentColor(root, prc, flhColor)
		flashPrc = prc;
		flashCol = flhColor;
	}

	public function fxFlash(col:Int) {
		flhColor = col;
		flh = 100;
		#if debug
		if (col == 0xFF88FF)
			stats.stomachUp++;
		else if (col == 0x00FFFF)
			stats.gulp++;
		else if (col != 0xFF0000)
			stats.flash++;
		#end
	}

	// ---------------------------------------------------------------- port
	// grid[x][y]: undefined out of the grid (Flash reads undefined there, JS would throw)
	public inline function cell(x:Int, y:Int):Ball {
		var c = grid[x];
		return c != null ? c[y] : null;
	}

	public function setCell(x:Int, y:Int, b:Ball) {
		var c = grid[x];
		if (c != null)
			c[y] = b;
	}

	// KKApi.addScore: nothing after the game over
	public function addScore(n:KKConst) {
		if (over)
			return;
		var v:Int = n;
		score += v;
		if (v != 0)
			KadoKadeoManager.kkm.addScore(v);
	}

	// KKApi.gameOver({})
	function endGame() {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	function initFlash() {
		flashMul = new PixiSprite(Texture.WHITE);
		flashMul.blendMode = BlendModes.MULTIPLY;
		flashAdd = new PixiSprite(Texture.WHITE);
		flashAdd.blendMode = BlendModes.ADD;
		for (s in [flashMul, flashAdd]) {
			s.width = Cs.mcw * Clip.K;
			s.height = Cs.mch * Clip.K;
			s.visible = false;
			stage.addChild(s);
		}
	}

	// the colour transform of updateFlash, one Flash frame late like the clips: multipliers int(100 - prc) %, offsets
	// int(prc / 100 * colour)
	function displayFlash(f:Float) {
		var prc = flashPrcPrev + (flashPrc - flashPrcPrev) * f;
		var on = prc > 0 && root.visible;
		flashMul.visible = flashAdd.visible = on;
		if (!on)
			return;
		var m = Std.int(Math.round(Std.int(100 - prc) / 100 * 255));
		flashMul.tint = (m << 16) | (m << 8) | m;
		var c = prc / 100;
		flashAdd.tint = (Std.int(c * ((flashCol >> 16) & 0xFF)) << 16) | (Std.int(c * ((flashCol >> 8) & 0xFF)) << 8) | Std.int(c * (flashCol & 0xFF));
	}

	// the glow filters and the masks of the beak compile their shaders now, not at the first fruit
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null)
			return;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		var g = new FlashGlow(3, 3, 1, 0xFFFFFF);
		g.setWhite(50);
		s.filters = [g];
		holder.addChild(s);
		var m = new PixiSprite(Texture.WHITE);
		var s2 = new PixiSprite(Texture.WHITE);
		s2.mask = m;
		holder.addChild(m);
		holder.addChild(s2);
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
		var f = frameAcc / 4;
		MC.displayAll(f);
		mcTimer.show(f);
		displayFlash(f);
	}

	// one Flash frame: the timelines advance, then Manager.main (tmod ~0.8: Timer settles on 32 / 40), then the frame
	// scripts the code triggered
	function flashFrame() {
		Timer.tmod = 32 / FLASH_FPS;
		flashPrcPrev = flashPrc;
		MC.frameStart();
		mcTimer.tick();
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

	#if debug
	// state compared between a game and its replay (test harness)
	function debugState():Dynamic {
		var g = [];
		for (y in 0...Cs.YMAX)
			for (x in 0...Cs.XMAX) {
				var b = cell(x, y);
				g.push(b == null ? "." : b == hero ? "P" : b.color < 10 ? Std.string(b.color) : String.fromCharCode(97 + b.color - 10));
			}
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: score,
			lvl: lvl,
			upc: upc,
			hx: hero.px,
			hy: hero.py,
			ox: hero.ox,
			stomach: hero.stomach.join(""),
			size: hero.stomachSize,
			balls: balls.length,
			grid: g.join(""),
			stats: haxe.Json.stringify(stats),
			over: over,
		};
	}

	// test bot: the grid (colours, -1 empty, 20 the hero), the hero, the stomach (the next poop last), whether the game
	// waits for a key (the hero's control in updatePlay)
	public function debugBot():Dynamic {
		var g = [
			for (x in 0...Cs.XMAX) [
				for (y in 0...Cs.YMAX) {
					var b = cell(x, y);
					b == null ? -1 : b.color;
				}
			]
		];
		return {
			grid: g,
			hx: hero.px,
			hy: hero.py,
			ox: hero.ox,
			stomach: hero.stomach.copy(),
			size: hero.stomachSize,
			limit: Cs.COMBO_LIMIT,
			idle: Reflect.compareMethods(action, updatePlay) && Reflect.compareMethods(hero.action, hero.control),
			lvl: lvl,
			upc: upc,
			frame: frameCount,
			over: over,
		};
	}

	// test harness: clips drawn by the runtime on a page ([name, frame, x, y, scale, {nested instance: frame}]), to
	// compare with the SWF
	public function debugShow(list:Array<Array<Dynamic>>, bgColor:Int) {
		var st:Dynamic = untyped KadoKadeoManager.kkm.stage;
		var box = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		for (o in list) {
			var c = new Clip(o[0], 2);
			Clip.deferring = true;
			for (pass in 0...2) {
				if (pass == 1)
					c.gotoAndStop(o[1]);
				if (o.length > 5)
					for (k in Reflect.fields(o[5])) {
						// a path of nested instances ("smc.smc"); a number: a sprite id of the SWF reference, skipped
						if (Std.parseInt(k) != null)
							continue;
						var sub = c;
						for (nm in k.split("."))
							sub = sub != null ? sub.getClip(nm) : null;
						if (sub != null) {
							// the fields the frame scripts read: cheeks at their full size, the fruit swallowed upwards
							sub.big = 5;
							sub.fruit = 2;
							sub.sens = 1;
							sub.gotoAndStop(Reflect.field(o[5], k));
						}
					}
			}
			Clip.deferring = false;
			Clip.runLater();
			c._x = o[2];
			c._y = o[3];
			c._xscale = c._yscale = o[4] * 100;
			box.addChild(c);
		}
		box.updateState();
		box.updateGraphics(1);
		st.addChild(box);
	}
	#end

	public function destroy():Void {
		me = null;
		MC.clearAll();
		Clip.reset();
		Sprite.spriteList = [];
		Cs.reset();
		Piou.reset();
	}
}

// mcTimer (sprite 26): its frame (shape 19) and its smc (sprite 25), the band of sprite 24 sliding 0.6 px per frame
// under smc.smc, a 100 x 8 rectangle mask whose _xscale the code sets (Game.updateTimer). The smc's filters (a glow,
// then a colour matrix) are applied to the band cut by the mask: the colour matrix is baked in the band picture and in
// the colour of the glow, the mask is a piece of the band picture (no mask, no shader).
class TimerMC extends MC {
	// smc.smc._xscale, and its value one Flash frame ago (shown interpolated, like the clips)
	public var maskXScale:Float = 100;

	var shownXScale:Float = 100;
	// the playhead of the smc (frame 11: gotoAndPlay(1))
	var smcFrame:Int = 1;
	var band:PixiSprite;
	var bandTex:Texture;
	var crop:Texture;

	public function new() {
		super(Clip.EMPTY);
		var fr = Tex.get("timerFrame")[0];
		var s = new PixiSprite(fr);
		s.anchor.copyFrom(fr.defaultAnchor);
		s.scale.set(1 / Clip.K, 1 / Clip.K);
		clip.addChild(s);
		var holder = new Container();
		holder.scale.y = Data.TIMER_SMC_YSCALE;
		var gl = Data.TIMER_GLOW;
		holder.filters = [new FlashGlow(gl[0], gl[1], gl[2], Data.TIMER_GLOW_COLOR)];
		bandTex = Tex.get("timerBand")[0];
		crop = new Texture(bandTex.baseTexture, bandTex.frame.clone());
		band = new PixiSprite(crop);
		band.scale.set(1 / Clip.K, 1 / Clip.K);
		holder.addChild(band);
		clip.addChild(holder);
	}

	// a Flash frame starts: the playhead of the smc advances
	public function tick() {
		shownXScale = maskXScale;
		smcFrame = smcFrame >= 10 ? 1 : smcFrame + 1;
	}

	public function show(f:Float) {
		var xs = shownXScale + (maskXScale - shownXScale) * f;
		var w = Data.TIMER_MASK_W * xs / 100;
		var tx = Data.TIMER_BAND_TX[smcFrame - 1];
		// the band (band coordinates u: tx + u in the smc) seen through the mask [0, w]
		var u0 = Math.max(0, -tx - Data.TIMER_BAND_X);
		var u1 = Math.min(Data.TIMER_BAND_W, w - tx - Data.TIMER_BAND_X);
		var t:Dynamic = bandTex;
		var fr = bandTex.frame;
		var tr:Dynamic = t.trim;
		var trX:Float = tr != null ? tr.x : 0;
		var trY:Float = tr != null ? tr.y : 0;
		var ox:Float = bandTex.defaultAnchor.x * t.orig.width;
		var oy:Float = bandTex.defaultAnchor.y * t.orig.height;
		var fx0 = Math.max(fr.x, fr.x + ox + u0 * Clip.K - trX);
		var fx1 = Math.min(fr.x + fr.width, fr.x + ox + u1 * Clip.K - trX);
		if (!Math.isFinite(xs) || fx1 <= fx0) {
			band.visible = false;
			return;
		}
		band.visible = true;
		var c:Dynamic = crop;
		c.frame = new pixi.core.math.shapes.Rectangle(fx0, fr.y, fx1 - fx0, fr.height);
		c.orig = new pixi.core.math.shapes.Rectangle(0, 0, fx1 - fx0, fr.height);
		c.trim = null;
		c.updateUvs();
		band.texture = crop;
		band.x = tx + Data.TIMER_BAND_X + (fx0 - fr.x + trX - ox) / Clip.K;
		band.y = (trY - oy) / Clip.K;
	}
}

// mcLevel: its field shows "x" + Cs.COMBO_LIMIT (anim "levelText": the text with the filters of the field)
class LevelMC extends MC {
	var pic:PixiSprite;

	public function new() {
		super(Clip.EMPTY);
		var fr = Tex.get("levelText");
		pic = new PixiSprite(fr[0]);
		pic.anchor.copyFrom(fr[0].defaultAnchor);
		pic.scale.set(1 / Clip.K, 1 / Clip.K);
		clip.addChild(pic);
	}

	// (the pictures go up to x40: a level the game never reaches)
	public function setText(n:Int) {
		var fr = Tex.get("levelText");
		var i = Std.int(Math.max(Data.LEVEL_MIN, Math.min(Data.LEVEL_MAX, n))) - Data.LEVEL_MIN;
		pic.texture = fr[i];
	}
}

// Game.initMap: mcTile drawn into a white 300 x 200 BitmapData at 32 px steps, frame 2 on the first row, frame 1 (its
// smc on a random frame: only pictures, visual random) below, in the order of the loops. The bitmap has 1 px per Flash
// pixel and attachBitmap shows it unsmoothed: the zoomed game shows its pixels (the tiles drawn at that resolution into a
// RenderTexture shown without smoothing)
class Ground extends Container {
	public function new(w:Int, h:Int) {
		super();
		var src = new Container();
		var white = new PixiSprite(Texture.WHITE);
		white.width = w;
		white.height = h;
		src.addChild(white);
		var c = 32;
		var xmax = Math.ceil(w / c);
		var ymax = Math.ceil(h / c);
		var tiles = Tex.get("tile");
		for (x in 0...xmax) {
			for (y in 0...ymax) {
				var t = tiles[y == 0 ? 0 : Seed.randomVfx(Data.TILE_FRAMES) + 1];
				var s = new PixiSprite(t);
				s.anchor.copyFrom(t.defaultAnchor);
				s.x = x * c;
				s.y = y * c;
				src.addChild(s);
			}
		}
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null) {
			addChild(src);
			return;
		}
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({
			width: w,
			height: h,
			resolution: 1,
			scaleMode: pixi.core.Pixi.ScaleModes.NEAREST
		});
		renderer.render(src, {renderTexture: rt, clear: true});
		src.destroy({children: true});
		addChild(new PixiSprite(rt));
	}
}

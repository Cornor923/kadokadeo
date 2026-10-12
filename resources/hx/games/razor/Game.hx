package razor;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import razor.Cs.Num;
import razor.Cs.Geom;
import razor.MC.Plans;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;

enum Step {
	Move;
	Play;
	Slice;
	Fall;
	Spawn;
	GameOver;
}

// Game.hx of the original (Haxe for Flash 8), line by line; the port's own parts are at the end

@:expose('GameRazor')
class Game implements kado.GameInterface {
	// left / right move the razor around the board, up slices the fruit in front of it. The board turns the razor's side
	// to the bottom: the buttons are in the corners, clear of it
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left",
				label: "◀",
				leftPx: 8,
				bottomPx: 25,
				size: 50,
				keyCode: KeyboardManager.LEFT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "right",
				label: "▶",
				rightPx: 8,
				bottomPx: 25,
				size: 50,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "slice",
				label: "▲",
				rightPx: 8,
				topPx: 8,
				size: 50,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.CIRCLE,
			},
		],
	};

	// ZQSD / WASD move like the arrows
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	// Flash played Razor at 40 frames/s (the rate of the SWF and of the KadoKado loader) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	public static var FL_VISEW_SCORE = false;

	var step:Step;

	public static var DP_BALL = 1;

	public static var DP_FRONT = 10;
	public static var DP_FX = 8;
	public static var DP_RAZOR = 6;
	public static var DP_SHADE = 5;
	public static var DP_UNDER_FX = 4;
	public static var DP_BOARD = 2;
	public static var DP_BG = 0;

	var flGameOver:Bool = false;

	var rtx:Int;
	var rty:Int;
	var rx:Int;
	var ry:Int;
	var move:Int;

	public var probaSpecial:Int;

	// (null until the razor stands on a side, and once the board has turned to it)
	var trot:Null<Float> = null;
	var sc:Float;
	var vrot:Float;
	var bdir:Int;
	var vibe:Int;
	var sliceIndex:Int;
	var sliceDirection:Int;

	public var comboScore:Int;
	// (mt.flash.Volatile<Int>: anti-cheat storage of the original)
	public var bonus:Int;
	public var board:MC;

	public var grid:Array<Array<Ball>>;
	public var balls:Array<Ball>;
	public var work:Array<Ball>;
	// (indexed by colour: a Pioupiou, colour COL_MAX, reads undefined there)
	public var pool:Array<Array<MC>>;
	public var limits:Array<Float>;
	public var mcWarning:MC;

	public var razor:MC;
	public var razorReal:MC;

	public static var me:Game;

	public var bdm:Plans;
	public var dm:Plans;
	public var root:ASprite;
	public var bg:MC;

	// port
	var isReplay:Bool;
	var stage:ASprite;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	// the score of KKApi (addScore), nothing after the game over
	var score:Int = 0;
	var over:Bool = false;

	#if debug
	// test harness: events of the game (coverage)
	public var stats = {
		slices: 0,
		fruits: 0,
		pious: 0,
		maxCombo: 0,
		comments: 0,
		turns: 0,
		moves: 0,
	};
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
		Sprite.spriteList = [];
		// mt.Timer before its first update (Manager.init creates the game before the first Manager.main)
		Timer.tmod = 1;
		Clip.deferring = true;
		stage = mc;

		// the original's 300x300 pixels, drawn x2
		root = mc.createEmptyMovieClip("scene", 0);
		root._xscale = root._yscale = 100 * Clip.K;
		root.updateState();
		me = this;
		dm = new Plans(root);

		bg = dm.attach("mcBg", Game.DP_BG);
		balls = [];

		move = 0;
		vibe = 1;
		probaSpecial = 100000;

		initInter();
		initBoard();

		// RAZOR
		razor = bdm.empty(0);
		razorReal = dm.attach("mcRazor", DP_RAZOR);
		moveRazorTo(3, 6);

		step = Play;

		Clip.deferring = false;
		Clip.runLater();
		MC.displayAll(1);
		// Flash shows the first picture after the first frame (Manager.init, then Manager.main): nothing before
		root.visible = false;
		warmShaders();
	}

	//
	public function origUpdate() {
		switch (step) {
			case Move:
				updateMove();
			case Play:
				updatePlay();
			case Slice:
				updateSlice();
			case Fall:
				updateFall();
			case Spawn:
				updateSpawn();
			case GameOver:
				updateGameOver();
		}

		updateBoard();

		var p = Geom.getParentCoord(razor);
		// (only the picture shakes: visual random)
		razorReal._x = p.x + Seed.randomVfx(3) - 1;
		razorReal._y = p.y + Seed.randomVfx(3) - 1;

		// razorReal.smc._rotation += 11
		razorReal.setSub("smc", null, null, null, null, razorReal.subRotation("smc") + 11);

		updateSprites();
	}

	public function updateSprites() {
		var a = Sprite.spriteList.copy();
		for (sp in a)
			sp.update();
	}

	// PLAY
	function initPlay() {
		step = Play;

		var ball = getSliceTarget();

		if (limits[ball.col] >= Cs.POOL_MAX)
			attachWarning(ball);
	}

	function updatePlay() {
		if (KeyboardManager.isDown(KeyboardManager.LEFT))
			slip(-1);
		else if (KeyboardManager.isDown(KeyboardManager.RIGHT))
			slip(1);
		else if (KeyboardManager.isDown(KeyboardManager.UP))
			initSlice();

		// a fruit blinks (only the picture: visual random)
		if (Seed.randVfx() / Timer.tmod < 0.1) {
			var smc = balls[Seed.randomVfx(balls.length)].root.sub("smc");
			if (smc != null)
				smc.play();
		}
	}

	function slip(sens:Int) {
		var di = (bdir + 1 - sens) % 4;
		var dx = Cs.DIR[di][0];
		var dy = Cs.DIR[di][1];
		rtx = rx + dx;
		rty = ry + dy;

		if (dx != 0 && (rtx == -1 || rtx == Cs.SIDE) || dy != 0 && (rty == -1 || rty == Cs.SIDE)) {
			di = Std.int(Num.sMod(di - sens, 4));
			bdir = Std.int(Num.sMod(bdir - sens, 4));
			rtx += Cs.DIR[di][0];
			rty += Cs.DIR[di][1];
			#if debug
			stats.turns++;
			#end
		}
		#if debug
		stats.moves++;
		#end

		initMove();
		removeWarning();
	}

	// SLICE
	function initSlice() {
		// (move grows twice per slice: the second test, move == 10, is never true)
		if (move++ == 2)
			probaSpecial = 16;
		if (move++ == 10)
			probaSpecial = 10;

		var ball = getSliceTarget();
		incPool(ball.col);

		work = getPath(ball.col, ball, []);
		step = Slice;
		sliceIndex = 0;
		sliceDirection = 1;
		comboScore = 0;
		sc = 0;
		var trg = work[sliceIndex];
		rtx = trg.x;
		rty = trg.y;

		bonus = 0;
		removeWarning();
		#if debug
		stats.slices++;
		if (work.length > stats.maxCombo)
			stats.maxCombo = work.length;
		#end
	}

	function updateSlice() {
		var speed = 0.1;
		speed *= 1 + (work.length - sliceIndex);
		if (sliceIndex == -1)
			speed = 0.15;
		if (speed > 0.5)
			speed = 0.5;
		sc += speed * Timer.tmod;

		while (sc > 1) {
			sc--;
			rx = rtx;
			ry = rty;

			sliceIndex += sliceDirection;

			if (sliceDirection == 1) {
				var b = grid[rx][ry];
				#if debug
				stats.fruits++;
				if (b.col == Cs.COL_MAX)
					stats.pious++;
				#end
				b.sliced();
				bonus++;
			}

			if (sliceIndex == work.length) {
				sc = 0;
				sliceIndex -= 2;
				sliceDirection = -1;
				fxComment(work.length);
			}
			if (sliceIndex >= 0) {
				var trg = work[sliceIndex];
				rtx = trg.x;
				rty = trg.y;
			}
			if (sliceIndex == -1) {
				var di = Std.int(Num.sMod(bdir + 1, 4));
				rtx = rx + Cs.DIR[di][0];
				rty = ry + Cs.DIR[di][1];
			}
			if (sliceIndex == -2) {
				initFall();
			}
		}
		moveRazor(sc);

		fxShade();
	}

	// the longest path of fruits of the colour (or Pioupious) from `ball`, every path tried; between two of the same
	// length, the one with fewer Pioupious
	function getPath(col:Int, ball:Ball, list:Array<Ball>):Array<Ball> {
		list.push(ball);
		var a = [];

		for (d in Cs.DIR) {
			var x = ball.x + d[0];
			var y = ball.y + d[1];
			// (out of the grid: undefined, never of the colour)
			var b = cell(x, y);
			if (b != null && (b.col == col || b.col == Cs.COL_MAX)) {
				var flOk = true;
				for (b2 in list)
					if (b2 == b) {
						flOk = false;
						break;
					};
				if (flOk) {
					var work = getPath(col, b, list.copy());
					if (work.length > a.length) {
						a = work;
					} else if (work.length == a.length) {
						var sp0 = 0;
						var sp1 = 0;
						for (b in work)
							if (b.col == Cs.COL_MAX)
								sp0++;
						for (b in a)
							if (b.col == Cs.COL_MAX)
								sp1++;
						if (sp0 < sp1)
							a = work;
					}
				}
			}
		}

		a.unshift(ball);

		return a;
	}

	function getSliceTarget() {
		var di = Std.int(Num.sMod(bdir - 1, 4));
		var bx = rx + Cs.DIR[di][0];
		var by = ry + Cs.DIR[di][1];
		return grid[bx][by];
	}

	// FALL
	function initFall() {
		step = Fall;
		var d = Cs.DIR[(bdir + 1) % 4];

		sc = 0;

		var fx:Int->Int->Int = null;
		var fy:Int->Int->Int = null;

		if (d[1] == 1) {
			fx = function(col, et) return col;
			fy = function(col, et) return Cs.SIDE - (1 + et);
		}
		if (d[1] == -1) {
			fx = function(col, et) return col;
			fy = function(col, et) return et;
		}

		if (d[0] == 1) {
			fx = function(col, et) return Cs.SIDE - (1 + et);
			fy = function(col, et) return col;
		}
		if (d[0] == -1) {
			fx = function(col, et) return et;
			fy = function(col, et) return col;
		}

		for (col in 0...Cs.SIDE) {
			var fall = 0;
			for (et in 0...Cs.SIDE) {
				var x = fx(col, et);
				var y = fy(col, et);
				var b = grid[x][y];
				if (b == null) {
					fall++;
				} else {
					b.fall = fall;
					if (fall > 0)
						b.removeFromGrid();
				}
			}
		}
	}

	function updateFall() {
		sc = sc + 0.34 * Timer.tmod;
		var d = Cs.DIR[(bdir + 1) % 4];

		var flEndFall = true;

		for (b in balls) {
			if (b.fall > 0) {
				flEndFall = false;
				b.root._x = Cs.getX(b.x + d[0] * sc);
				b.root._y = Cs.getY(b.y + d[1] * sc);
				if (sc >= 1) {
					b.x += d[0];
					b.y += d[1];
					b.fall--;
					if (b.fall == 0) {
						b.insertInGrid();
						b.updatePos();
					}
				}
			}
		}

		if (sc > 1)
			sc--;
		if (flEndFall)
			initSpawn();
	}

	// SPAWN
	function initSpawn() {
		step = Spawn;
		work = [];
		sc = 0;
		for (x in 0...Cs.SIDE) {
			for (y in 0...Cs.SIDE) {
				var b = Game.me.grid[x][y];
				if (b == null) {
					b = new Ball(x, y);
					// (pushed twice: scaled twice, the same value)
					work.push(b);
					b.root._xscale = b.root._yscale = 0;
					work.push(b);
				}
			}
		}
	}

	function updateSpawn() {
		sc = Math.min(sc + 0.1, 1);
		for (b in work) {
			b.root._xscale = b.root._yscale = sc * 100;
		}
		if (sc == 1) {
			if (flGameOver)
				initGameOver();
			else
				initPlay();
		}
	}

	// MOVE
	public function initMove() {
		sc = 0;
		step = Move;
		updateMove();
	}

	public function updateMove() {
		var speed = Cs.RAZOR_SPEED;
		sc = sc + speed;
		var c = sc;
		if (sc > 1) {
			sc = 1;
			moveRazorTo(rtx, rty);
			initPlay();
			updatePlay();
		} else {
			moveRazor(c);
		}
	}

	public function moveRazor(c:Float) {
		razor._x = Cs.getX(rx * (1 - c) + rtx * c);
		razor._y = Cs.getY(ry * (1 - c) + rty * c);
	}

	// BOARD
	public function initBoard() {
		board = dm.empty(DP_BOARD);
		board._x = Cs.mcw * 0.5;
		board._y = Cs.mch * 0.5;
		bdm = new Plans(board.clip, board);
		bdir = 0;
		vrot = 0;

		grid = [];
		for (x in 0...Cs.SIDE) {
			grid[x] = [];
			for (y in 0...Cs.SIDE) {
				new Ball(x, y);
			}
		}

		// new DropShadowFilter(): alpha 0.2, distance 15 (angle 45, blur 4 x 4, strength 1, quality 1: the defaults)
		board.clip.filters = [new FlashGlow(4, 4, 1, 0x000000, 0.2, false, 15, 45)];
	}

	public function updateBoard() {
		var factor = 5;

		if (rx == -1)
			trot = -90 + (ry - 2.5) * factor;
		if (ry == -1)
			trot = 180 - (rx - 2.5) * factor;
		if (rx == Cs.SIDE)
			trot = 90 - (ry - 2.5) * factor;
		if (ry == Cs.SIDE)
			trot = 0 + (rx - 2.5) * factor;

		if (trot == null)
			return;
		var dr = Num.hMod(trot - board._rotation, 180);

		vrot += dr * 0.1;
		vrot *= 0.6;
		board._rotation += vrot;

		for (b in balls)
			b.updateRot();

		var speed = Math.abs(dr);
		if (speed < 0.1)
			trot = null;
	}

	// INTER
	function initInter() {
		limits = [];
		pool = [];
		for (i in 0...Cs.COL_MAX) {
			limits[i] = 0;
			pool[i] = [];
			for (n in 0...Cs.POOL_MAX) {
				var mc = dm.attach("mcIcon", DP_BG);
				mc._x = getPoolX(i, n);
				mc._y = 19;
				mc.setSubVisible("smc", false);
				mc.sub("smc").gotoAndStop(i + 1);
				pool[i].push(mc);
				// Filt.glow(mc, 2, 2, 0x7D421C): baked in the pictures of the icons
			}
		}
	}

	// (returns at once in the original: no warning is ever shown)
	function attachWarning(ball:Ball) {
		return;
	}

	// (mcWarning is never attached: undefined.removeMovieClip() does nothing)
	function removeWarning() {
		if (mcWarning != null)
			mcWarning.removeMovieClip();
	}

	function getPoolX(col:Int, n:Int):Float {
		return 22 + n * 20.5 + col * 97;
	}

	function incPool(col:Int) {
		// (a Pioupiou, colour COL_MAX: limits[col] undefined, pool[col] undefined: nothing shown, and limits[col]++ is
		// NaN, never equal to POOL_MAX)
		var id = limits[col];

		var mc = pool[col] != null ? pool[col][Std.int(id)] : null;
		if (mc != null)
			mc.setSubVisible("smc", true);
		limits[col]++;
		if (id == Cs.POOL_MAX)
			flGameOver = true;
	}

	function updateInter() {}

	// RZAOR
	public function moveRazorTo(x:Int, y:Int) {
		rx = x;
		ry = y;
		razor._x = Cs.getX(x);
		razor._y = Cs.getY(y);
	}

	// GAMEOVER
	public function initGameOver() {
		step = GameOver;
		endGame();
	}

	function updateGameOver() {}

	// FX
	function fxShade() {
		var mc = bdm.attach("mcShade", 0);
		mc._x = razor._x;
		mc._y = razor._y;
		mc._rotation = Seed.randVfx() * 360;
	}

	function fxComment(n:Int) {
		if (n < 8)
			return;

		var str = "COMBO!";
		if (n >= 10)
			str = "SUPER COMBO!";
		if (n >= 12)
			str = "MONSTRUEUX!";
		if (n >= 16)
			str = "ARCHI-GORE!";
		if (n >= 20)
			str = "ORGIE DANS LE SANG!";

		var mc = dm.attach("mcCommentAnim", DP_FRONT);
		// (mc._txt, mc._score: the text fields of its smc, drawn by Comment; mc._compt: the hold of its frame 11;
		// mc.fxBam: called by its frame 6)
		var i = Data.COMMENT_TEXTS.indexOf(str);
		mc.clip.compt = n * 2;

		// field.textWidth, measured in the SWF
		var width = Data.COMMENT_WIDTHS[i];
		var ratio = (Cs.mcw - 50) / width;

		Comment.fill(mc, i, "+" + comboScore, ratio);
		#if debug
		stats.comments++;
		#end
	}

	// 100 particles of "mcPix", a symbol the SWF does not have: attachMovie returns undefined and the Phys of the
	// original move nothing (nothing on the screen)
	public function fxBam() {}

	// ---------------------------------------------------------------- port
	// grid[x][y]: undefined out of the grid (Flash reads undefined there, JS would throw)
	public inline function cell(x:Int, y:Int):Ball {
		var c = grid[x];
		return c != null ? c[y] : null;
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

	// the glow filters compile their shader now, not at the first combo
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null)
			return;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		s.filters = [new FlashGlow(3, 3, 1, 0xFFFFFF, 1, true)];
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

	#if debug
	// state compared between a game and its replay (test harness)
	function debugState():Dynamic {
		var g = [];
		for (y in 0...Cs.SIDE)
			for (x in 0...Cs.SIDE) {
				var b = cell(x, y);
				g.push(b == null ? "." : Std.string(b.col));
			}
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: score,
			step: Std.string(step),
			rx: rx,
			ry: ry,
			bdir: bdir,
			rot: Math.round(board._rotation * 1000) / 1000,
			limits: limits.join(","),
			proba: probaSpecial,
			move: move,
			balls: balls.length,
			grid: g.join(""),
			stats: haxe.Json.stringify(stats),
			over: over,
		};
	}

	// test bot: the grid (colours, -1 empty), the razor, the side it is on, whether the game waits for a key
	public function debugBot():Dynamic {
		var g = [
			for (x in 0...Cs.SIDE) [
				for (y in 0...Cs.SIDE) {
					var b = cell(x, y);
					b == null ? -1 : b.col;
				}
			]
		];
		return {
			grid: g,
			rx: rx,
			ry: ry,
			bdir: bdir,
			idle: step == Play,
			limits: [for (i in 0...Cs.COL_MAX) limits[i]],
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
						if (Std.parseInt(k) != null)
							continue;
						var sub = c;
						for (nm in k.split("."))
							sub = sub != null ? sub.getClip(nm) : null;
						if (sub != null)
							sub.gotoAndStop(Reflect.field(o[5], k));
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
	}
}

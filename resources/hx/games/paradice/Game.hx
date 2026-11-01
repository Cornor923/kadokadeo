package paradice;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import paradice.MC.Plans;

// Game.mt of the original
@:expose('GameParadice')
class Game implements kado.GameInterface {
	// buttons pressing the keys of the original: move the row left / right, validate (Up)
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

	// ZQSD / WASD move like the arrows, Enter validates like Space
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	// Flash played Paradice at 40 frames/s (the rate of temple.swf) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	public static var DP_BG = 1;
	public static var DP_BALL = 2;
	public static var DP_GROUND = 3;
	public static var DP_PART = 4;
	public static var DP_CACHE = 5;

	static var CDIR = [[0, 1], [-1, 0]];

	var flIceFall:Bool;

	var step:Int;

	public var dm:Plans;

	public var grid:Array<Array<Ball>>;
	public var bList:Array<Ball>;

	var fList:Array<Ball>;
	var dList:Array<Ball>;

	public var sList:Array<Sprite>;
	public var sbList:Array<ScoreBubble>;

	var spawnBubbleList:Array<{x:Float, y:Float, sc:Int, col:Int}>;

	public var ground:Ground;

	var bg:MC;
	var cache:MC;

	var timer:Float;
	var cTimer:Float;

	public var playTimer:Float;

	var trgTimer:Float;

	var nextScore:KKConst;
	var multi:Int;

	public var play:Int;

	var pan:MC;

	var root:ASprite;
	var isReplay:Bool;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	var over:Bool = false;
	var stats = {groups: 0, specials: [0, 0, 0], best: 0};

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(4);
		keys[0] = KeyboardManager.LEFT;
		keys[1] = KeyboardManager.RIGHT;
		keys[2] = KeyboardManager.UP;
		keys[3] = KeyboardManager.SPACE;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		MC.clearAll();
		Clip.reset();
		setTiming();

		// the original's 300x300 pixels, drawn x2
		root = mc.createEmptyMovieClip("scene", 0);
		root._xscale = root._yscale = 100 * Clip.K;
		root.updateState();

		Cs.init();
		Cs.game = this;
		dm = new Plans(root);
		bList = new Array();
		sList = new Array();
		sbList = new Array();

		bg = dm.attach("bg", DP_BG);
		cache = dm.attach("cache", DP_CACHE);
		var gl = dm.attach("groundLimit", DP_BG);
		gl._y = Cs.MD;

		flIceFall = false;

		cTimer = 1;
		trgTimer = 1;
		multi = 1;
		play = 0;

		while (true) {
			var flBreak = true;
			initGrid();
			var groups = getGroups();
			for (i in 0...groups.length) {
				var g = groups[i];
				while (g != null && g.length >= Cs.COMBO_SIZE) {
					var index = Seed.random(g.length);
					var b:Gem = cast g[index];
					b.flIce = true;
					b.setSkin(b.root);
					g.splice(index, 1);
				}
			}
			if (flBreak)
				break;
		}
		initGround();
		initStep(1);

		// (bg.base._height = Cs.mch - Cs.MD: mcBg has no "base", Flash sets nothing)

		MC.displayAll(1);
	}

	// one Flash frame of the original: tmod ~0.8 (Timer: 0.95 * tmod + 0.05 * deltaT * 32 settles on 32 / 40)
	static function setTiming() {
		Timer.tmod = 32 / FLASH_FPS;
		Timer.deltaT = 1 / FLASH_FPS;
	}

	function initGround() {
		ground = new Ground();
	}

	public function initStep(s:Int) {
		step = s;
		switch (step) {
			case 0: // CHECK GROUP ---> DESTROY
				var list = getGroups();
				dList = new Array();
				spawnBubbleList = new Array();
				nextScore = Cs.C0;
				for (i in 0...list.length) {
					var g = list[i];
					if (g != null && g.length >= Cs.COMBO_SIZE) {
						// int(Math.pow(g.length * 3, 2) * 0.1) * 25 * multi (the square of an integer: exact)
						var n = g.length * 3;
						var sc = Std.int(n * n * 0.1) * 25 * multi;

						//
						var b = {
							xmin: 99999.0,
							xmax: 0.0,
							ymin: 99999.0,
							ymax: 0.0
						};
						for (n in 0...g.length) {
							var ball = g[n];
							b.xmin = Math.min(b.xmin, ball.root._x);
							b.ymin = Math.min(b.ymin, ball.root._y);
							b.xmax = Math.max(b.xmax, ball.root._x);
							b.ymax = Math.max(b.ymax, ball.root._y);
							dList.push(ball);
						}

						spawnBubbleList.push({
							x: (b.xmin + b.xmax) * 0.5,
							y: (b.ymin + b.ymax) * 0.5,
							sc: sc,
							col: g[0].col
						});
						nextScore = KKApi.cadd(nextScore, KKApi.const(sc));
						stats.groups++;
						if (sc > stats.best)
							stats.best = sc;
					}
				}

				if (dList.length > 0) {
					timer = Cs.DESTROY_TIMER;
					multi++;
					if (pan != null && !pan.removed)
						pan.gotoAndPlay("leave");
				} else {
					multi = 1;
					if (checkEnd()) {
						initStep(10);
					} else {
						if (flIceFall) {
							iceFall();
							initStep(1);
						} else {
							initStep(2);
						}
					}
				}

			case 1: // FALLING
				fList = new Array();
				for (x in 0...Cs.XMAX) {
					for (y in 0...Cs.YMAX) {
						var b = grid[x][y];
						if (b != null && isFree(x, y - 1)) {
							b.setPos(x, y - 1);
							b.dy -= Cs.SQ;
							fList.push(b);
						}
					}
				}
			case 2: // LOADING
				ground.initLoad();
			case 3: // PLAYING
				play++;
				ground.step = 0;
				playTimer = Cs.PLAY_TIMER;

			case 10: // BLAST PINGUIN
				ground.initBlastPinguin();
			case 11: // GAMEOVER
				timer = 30;
		}
	}

	function checkEnd():Bool {
		for (x in 0...Cs.XMAX) {
			if (grid[x][Cs.LIMIT_GAMEOVER] != null)
				return true;
		}
		return false;
	}

	function initGrid() {
		grid = new Array();
		for (x in 0...Cs.XMAX) {
			grid[x] = new Array();
			for (y in 0...Cs.YMAX) {
				grid[x][y] = null;
				if (y < 4) {
					var b = new Gem();
					b.setPos(x, y);
					b.updatePos();
				}
			}
		}
	}

	// grid[x][y] of the original: out of the grid, Flash reads undefined (an empty square)
	public function cell(x:Null<Int>, y:Null<Int>):Ball {
		if (x == null || y == null || x < 0 || x >= grid.length)
			return null;
		var b = grid[x][y];
		return b == null ? null : b;
	}

	// grid[x][y] = b: a ball that has no square yet (Flash's grid[undefined]) changes nothing
	public function setCell(x:Null<Int>, y:Null<Int>, b:Ball) {
		if (x == null || y == null || x < 0 || x >= grid.length)
			return;
		grid[x][y] = b;
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

	function flashFrame() {
		setTiming();
		MC.frameStart();
		main();
		frameCount++;
	}

	// main() of the original: one Flash frame
	function main() {
		switch (step) {
			case 0:
				timer -= Timer.tmod;
				var prc = Math.min(100 * (1 - timer / Cs.DESTROY_TIMER), 100);
				var flDestroy = timer < 0;
				for (i in 0...dList.length) {
					var b = dList[i];
					if (flDestroy) {
						b.explode();
						b.checkBlast();
					} else {
						Cs.setPercentColor(b.root, prc, 0xFFFFFF);
					}
				}
				if (flDestroy) {
					spawnBubble();
					addScore(nextScore);
					if (multi >= 3)
						spawnMultiPanel();
					initStep(1);
				}
			case 1: // FALLING
				var i = 0;
				while (i < fList.length) {
					var b = fList[i];
					b.dy += 10 * Timer.tmod;
					while (b.dy > 0) {
						if (isFree(b.x, b.y - 1)) {
							b.setPos(b.x, b.y - 1);
							b.dy -= Cs.SQ;
						} else {
							b.dy = 0;
							fList.splice(i--, 1);
						}
					}
					b.updatePos();
					i++;
				}
				if (fList.length == 0) {
					if (flIceFall) {
						initStep(0);
					} else {
						initStep(2);
					}
				}
			case 2: // LOADING
				flIceFall = true;
				ground.loading();
			case 3: // PLAYING
				ground.control();
				playTimer -= Timer.tmod;
				trgTimer = playTimer / Cs.PLAY_TIMER;

			case 10:
				ground.blastPinguin();
			case 11: // GAMEOVER
				timer -= Timer.tmod;
				if (timer < 0)
					gameOver();
		}

		// BLINK (a gem shines now and then: the visual random)
		if (Seed.randVfx() / Timer.tmod < 0.02) {
			var b = bList[Seed.randomVfx(bList.length)];
			if (b != null && b.col != null)
				b.root.play();
		}

		// SCOREBUBBLE
		updateScoreBubble();

		// SPRITES
		// (an index loop: a sprite removed during its update makes the next one wait until the next frame)
		var i = 0;
		while (i < sList.length) {
			sList[i].update();
			i++;
		}
	}

	function addScore(n:KKConst) {
		// (nothing after KKApi.gameOver: the end screen is up)
		if (!over)
			KadoKadeoManager.kkm.addScore(KKApi.val(n));
	}

	// KKApi.gameOver({}), called by the original on every frame once the timer is out: the end of the game once
	function gameOver() {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = state();
		#end
		KadoKadeoManager.kkm.gameOver(stats);
	}

	//
	function iceFall() {
		var a:Array<{x:Int, y:Int}> = new Array();
		for (x in 0...Cs.XMAX) {
			for (y in 0...Cs.XMAX) {
				if (grid[x][y] == null) {
					for (i in 0...a.length + 1) {
						if (i == a.length || a[i].y > y) {
							a.insert(i, {x: x, y: y});
							break;
						}
					}
					break;
				}
			}
		}

		var max = 1 + Std.int(Math.sqrt(Cs.game.play * 0.1));
		for (i in 0...max) {
			var p = a[i];

			// (fewer free columns than max: a[i] is undefined, Flash's test is false)
			if (p != null && p.y < Cs.LIMIT_GAMEOVER - 1) {
				var b = new Gem();

				b.setPos(p.x, Cs.LIMIT_GAMEOVER);
				b.flIce = true;
				b.setSkin(b.root);
				b.updatePos();
			}
		}

		flIceFall = false;
	}

	function spawnBubble() {
		for (i in 0...spawnBubbleList.length) {
			var o = spawnBubbleList[i];
			var p = new ScoreBubble(dm.attach("scoreBubble", DP_PART));
			p.x = o.x;
			p.y = o.y;
			p.timer = 28;
			p.fadeType = 0;
			p.fadeLimit = 6;
			p.vy = -0.2;
			p.setScore(o.sc, o.col);
		}
	}

	//
	function getGroups():Array<Array<Ball>> {
		var gList:Array<Array<Ball>> = new Array();
		for (i in 0...bList.length) {
			bList[i].gid = null;
		}

		for (i in 0...bList.length) {
			var b = bList[i];
			if (!b.flIce) {
				if (b.gid == null) {
					b.gid = gList.length;
					gList.push([b]);
				}

				for (n in 0...CDIR.length) {
					var nx = b.x + CDIR[n][0];
					var ny = b.y + CDIR[n][1];
					var b2 = cell(nx, ny);

					if (b2 != null && b.col == b2.col && b.col != null && !b2.flIce) {
						if (b2.gid == null) {
							b2.gid = b.gid;
							gList[b.gid].push(b2);
						} else if (b2.gid == b.gid) {} else {
							var kgid = b2.gid;
							var list = gList[kgid];
							for (g in 0...list.length) {
								var b3 = list[g];
								b3.gid = b.gid;
								gList[b.gid].push(b3);
							}
							gList[kgid] = null;
						}
					}
				}
			}
		}
		return gList;
	}

	function updateScoreBubble() {
		var max = 32;
		for (i in 0...sbList.length) {
			var sb = sbList[i];
			for (n in i + 1...sbList.length) {
				var sb2 = sbList[n];
				var dist = sb.getDist(sb2);
				if (dist < max) {
					var d = (max - dist) * 0.5;
					var a = sb.getAng(sb2);
					var ca = Math.cos(a);
					var sa = Math.sin(a);
					sb.x -= ca * d;
					sb.y -= sa * d;
					sb2.x += ca * d;
					sb2.y += sa * d;
				}
			}
		}
	}

	//
	function isFree(x:Null<Int>, y:Null<Int>):Bool {
		return cell(x, y) == null && y >= 0;
	}

	//
	function spawnMultiPanel() {
		pan = dm.attach("multiPanel", DP_CACHE);
		// pan.score = "x" + (multi - 1): the text field "_parent.score" of its board
		var board = pan.clip.get("board");
		var t = new Txt(Data.PANEL_FIELD, Clip.K * Data.BOARD_RES);
		board.addChild(t);
		t.setText("x" + Std.string(multi - 1));
	}

	public function countSpecial(sid:Int) {
		stats.specials[sid]++;
	}

	#if debug
	// end state compared between a game and its replay (test harness)
	function state():Dynamic {
		var g = [];
		for (x in 0...Cs.XMAX)
			for (y in 0...Cs.YMAX + 1) {
				var b = cell(x, y);
				g.push(b == null ? "." : b.flIce ? "i" : Std.string(b.col));
			}
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			play: play,
			step: step,
			balls: bList.length,
			grid: g.join(""),
			stats: haxe.Json.stringify(stats),
		};
	}

	// test harness: clips drawn by the runtime on a page ([name, frame, x, y, scale, {nested instance: frame}]), to
	// compare with the SWF (examples/paradice/ncheck.mjs, ref.py)
	public function debugShow(list:Array<Array<Dynamic>>, bgColor:Int) {
		var stage:Dynamic = untyped KadoKadeoManager.kkm.stage;
		var box = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		// the random first frames on their first frame, like the reference
		Clip.random = n -> 0;
		Clip.randomB = n -> 0;
		for (o in list) {
			// the penguin body drawn by its script: the frame asked for
			var bf:Null<Int> = o.length > 5 ? Reflect.field(o[5], "b") : null;
			Clip.randomB = bf != null ? n -> bf - 1 : n -> 0;
			var c = new Clip(o[0], 2);
			// nested clips driven by the code: before and after the frame change (clips created on the new frame)
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
			c._x = o[2];
			c._y = o[3];
			c._xscale = c._yscale = o[4] * 100;
			box.addChild(c);
		}
		Clip.random = Seed.randomVfx;
		Clip.randomB = Seed.random;
		box.updateState();
		box.updateGraphics(1);
		stage.addChild(box);
	}
	#end

	public function destroy():Void {
		MC.clearAll();
		Clip.reset();
	}
}

package nosushi;

import haxe.io.UInt16Array;
import common_haxe_avm1.display.ASprite;

enum Step {
	S_InitCreate;
	S_Play;
	S_Bombe;
	S_Break;
	S_TurnBonus;
	S_Gravity;
	S_Create;
	S_End;
	S_Void;
}

enum Bonus {
	@proba(1400) B_None;
	@proba(5) B_Dynamite;
	@proba(5) B_Bombe;
	@proba(3) B_MorePlay;
	@proba(10) B_X2;
	@proba(0) B_AK1;
	@proba(0) B_AK2;
	@proba(0) B_AK3;
	@proba(0) B_AK4;
}

// NosuShi (Arkadeo, Motion Twin, 600 x 460 at 40 frames/s), its League: 20 plates (moves), a click on a group of at least
// 2 foods of the same kind next to each other takes it away for n x (n - 1) / 2 x 10 points (x 2 for each x2 icon of the
// group), the columns fall and new foods come in; the aspirin gives 5 plates (twice a game at most), the bomb and the
// dynamite blow up after 3 moves. The code is the original Game (Haxe 2, AS3) on the AS3 display list of the lib (arkadeo);
// this class is also the game KadoKadeo creates, steps and records (the mouse) instead of the Arkadeo loader (AKApi).
//
// What changes from the original, and why:
//  - the LvUP campaign (the orders of 20 levels: initContracts, contractStart / End / Add, the stones, the checks) and the
//    in-game prizes of Arkadeo (the B_AK1 to 4 gems: filteredPrizeTokens) are not ported: the League gives neither;
//  - the inputs: the CLICK of the original (fg.onClick: AKApi.emitEvent(x * 100 + y), read by getEvent in the next frame)
//    is the left button released over the game, polled at each step of KadoKadeo, the event played in the next frame of
//    the game; the mouse is recorded, so the groups under it light up in a replay too (the original only did it in a live
//    game: updateSelection only changes the look);
//  - the random: Game.rand draws from the gameplay random of KadoKadeo (Seed.random) instead of the mt.Rand of the seed
//    of Arkadeo, in the same order;
//  - the 40 frames/s of the SWF on the 32 steps/s of KadoKadeo: 5 frames of the game every 4 steps, shown interpolated
//    (arkadeo.Flash);
//  - the pictures of the original drawn at run time and never changed afterwards are drawn by the asset pipeline: the
//    flattened blocks (Game.flatten), gfx.Bg on its League frame with gfx.Plateau over it (one picture: they never move),
//    the 21 values of the moves counter; the points use the system Arial Bold (the device font "arial" of the original).
@:expose('GameNosushi')
class Game extends Sprite implements kado.GameInterface {
	public static var GRID_SIZE = 9;

	public static var WIDTH = 600;
	public static var HEIGHT = 480;

	public static var DP_BG = 0;
	public static var DP_CONTRACT = 1;
	public static var DP_TRAY = 4;
	public static var DP_BLOCKS = 5;
	public static var DP_PART = 6;
	public static var DP_TOPPART = 7;
	public static var DP_FG = 10;

	public static var DELTA_X:Int;
	public static var DELTA_Y:Int;

	public static var RAY = 24;
	public static var TRAY_SIZE = RAY * GRID_SIZE * 2;

	public static var me:Game;

	// (AKApi.const: the protected numbers of Arkadeo)
	public static var START_PLAY = 20;
	public static var BONUS_ASPIRINE = 5;
	public static var PTS = 10;

	public static var MAX_ID = 3;
	public static var BLACK_ID = 4;

	public static var BOMBE_TIMER = 3;

	public static var MAX_MOREPLAY = 2;

	public static var ID_COLORS = [0xE07450, 0xF09585, 0xFAD777];

	public var leftPlay:Int;
	public var emptyCells:Int;

	// the orders of the LvUP: none in the League
	public var contractSteps:Int;

	public var blackProba:Int;

	public var grid:Array<Array<Block>>;
	public var dm:DepthManager;
	public var bg:Sprite;
	public var tray:Sprite;
	public var dmtray:DepthManager;
	public var dmplates:DepthManager;
	public var plates:Array<MovieClip>;
	public var curPlate:MovieClip;
	public var fxm:mt.fx.Manager;

	public var step:Step;
	public var waitingFx:Int;
	public var lockPlay:Int;
	public var lockFrames:Int;

	public var rotate:Array<Bool>;
	public var bombs:Array<Block>;

	var curGroup:Null<Group>;

	public var curMoreplay:Int;

	// ---------------------------------------------------------------- the port
	public static inline var STEPS_PER_SECOND = 32;
	// the game area of Arkadeo under the bar of KadoKadeo
	public static inline var AREA_HEIGHT = 460;

	var gameRoot:ASprite;
	var gameMask:pixi.core.graphics.Graphics;
	var isReplay:Bool;
	var frameAcc:Int;
	var frameCount:Int;
	var over:Bool;
	// gfx.Bg: the `_moves` field (a picture per value)
	var moves:Bitmap;
	// AKApi.emitEvent / getEvent
	var events:Array<Int>;
	var pressedIn:Bool;
	var clicked:Bool;
	var onPointerDown:Dynamic->Void;
	// the points of a group (sp.cacheAsBitmap): one picture per value and colour
	var ptsCache:Map<String, BitmapData>;

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		super();
		this.isReplay = isReplay;
		var buttons = new UInt16Array(1);
		buttons[0] = MouseManager.BUTTON_LEFT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: buttons,
		});

		resetStatics();
		frameAcc = 0;
		frameCount = 0;
		over = false;
		events = [];
		pressedIn = false;
		clicked = false;
		ptsCache = new Map();
		Tex.init("/nosushi");
		Clip.init(Data.clips);
		TextField.init(Data.fonts);

		gameRoot = mc;
		mc.addChild(node);
		// the game area of Arkadeo (600 x 460): what goes out of it is not drawn (under the bar of KadoKadeo)
		gameMask = new pixi.core.graphics.Graphics();
		gameMask.beginFill(0xFFFFFF);
		gameMask.drawRect(0, 0, WIDTH, AREA_HEIGHT);
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

		// ---- the constructor of the original
		me = this;
		dm = new DepthManager(this);

		tray = new Sprite();
		dm.add(tray, DP_TRAY);
		dmtray = new DepthManager(tray);

		var plates = new Sprite();
		dm.add(plates, DP_TRAY);
		dmplates = new DepthManager(plates);

		// (a rectangle: drawn with drawRect, the scissor of PIXI instead of a stencil)
		var mcMask = new Sprite();
		dmplates.add(mcMask, 0);
		plates.mask = mcMask;
		var x = 459;
		mcMask.graphics.beginFill(0xFF00FF);
		mcMask.graphics.drawRect(x, 0, 600 - x, 480);
		mcMask.graphics.endFill();

		fxm = new mt.fx.Manager();

		waitingFx = 0;
		leftPlay = START_PLAY;
		curMoreplay = 0;

		rotate = [];
		bombs = [];

		initStage();

		// (GM_LEAGUE)
		contractSteps = 0;
		blackProba = 0;

		setStep(S_InitCreate);
		lockPlay = 0;

		warmShaders();
		Flash.display(this, 1);
	}

	public function rand(n:Int):Int {
		return Seed.random(n);
	}

	function initStage() {
		// gfx.Bg on its League frame, gfx.Plateau (in the tray, under the blocks) drawn over it: one picture
		bg = new Sprite();
		bg.addChild(new Bitmap("decor"));
		moves = new Bitmap("moves", leftPlay + 1);
		moves.x = Data.MOVES_X;
		moves.y = Data.MOVES_Y;
		bg.addChild(moves);
		dm.add(bg, DP_BG);

		// (fg: the transparent 600 x 480 button over the game, its onClick: pollMouse)

		DELTA_X = Std.int(TRAY_SIZE / 2) + 7;
		DELTA_Y = RAY + 4;

		grid = [];
		for (x in 0...GRID_SIZE) {
			grid[x] = [];
		}
	}

	public function enqueueBomb(b:Block) {
		bombs.push(b);
	}

	public function addPlay(p:Int) {
		if (leftPlay + p > START_PLAY)
			p = START_PLAY - leftPlay;
		leftPlay += p;

		for (i in 0...p)
			addPlate();
		updateMoves();
	}

	public function updateMoves() {
		moves.setAnim("moves", leftPlay + 1);
	}

	function addPlate(init = false) {
		var p = new MovieClip(Data.PLATE);
		dmplates.add(p, 1);
		p.x = 400;
		var fy = 340 - plates.length * 6;
		if (init) {
			p.y = fy;
		} else {
			p.y = fy - 80;
			new mt.fx.Tween(p, p.x, fy);
			new mt.fx.Spawn(p);
		}
		plates.push(p);
	}

	function checkEnd() {
		if (leftPlay <= 0) {
			setStep(S_End);
			return true;
		}

		return false;
	}

	public function setStep(s:Step) {
		if (s == S_Play && lockPlay > 0)
			return;
		step = s;
		switch (step) {
			case S_InitCreate:
				create(true);
				plates = new Array();
				for (i in 0...leftPlay)
					addPlate(true);
			case S_Play:
				if (checkEnd())
					return;
				initGroups();

				curPlate = plates.shift();
				new mt.fx.Tween(curPlate, 495, curPlate.y);

				var i = 0;
				for (p in plates) {
					new mt.fx.Sleep(new mt.fx.Tween(p, p.x, p.y + 6, 0.4), null, i * 2);
					i++;
				}
			case S_Break:

			case S_TurnBonus:
				for (x in 0...GRID_SIZE) {
					for (y in 0...GRID_SIZE) {
						var b = grid[x][y];
						if (b != null)
							b.turnBonus();
					}
				}
				if (waitingFx == 0)
					setStep(S_Gravity);
			case S_Gravity:
				if (bombs.length > 0) {
					setStep(S_Bombe);
					return;
				}

				if (checkEnd())
					return;
				lockFrames = 25;
				gravity();
			case S_Create:
				create(false);
			case S_Bombe:
				var bomb = bombs.shift();
				bomb.showBombe();

				var a = new Array<Block>();

				function bombBlocks() {
					for (b in a) {
						bombs.remove(b);
						b.breakBmp();
						var f = new mt.fx.Part(b.mc);
						f.timer = 6;
						var mc = new MovieClip(Data.EXPLODE);
						mc.x = b.mc.x + tray.x;
						mc.y = b.mc.y + tray.y;
						mc.scaleX = mc.scaleY = b.mc.scaleX;
						dm.add(mc, DP_PART);

						var p = new mt.fx.Part(mc);
						p.setScale(mc.scaleX);
						p.timer = 25;
						addFx(p, function() {
							b.exec(false, false, a.length, 0);
						});
					}
				}

				if (bomb.bonus == B_Bombe) {
					var d = 2;
					for (x in 0...GRID_SIZE) {
						for (y in 0...Game.GRID_SIZE) {
							var b = Game.me.grid[x][y];
							if (b != null) {
								var dx = (bomb.x - x);
								var dy = (bomb.y - y);
								if (dx * dx + dy * dy <= d * d)
									a.push(b);
							}
						}
					}

					var mc = new Sprite();
					mc.graphics.beginFill(0xFFFFFF, 1);
					mc.graphics.drawCircle(0, 0, (RAY / Math.cos(Math.PI / 4)) * d);
					mc.graphics.endFill();
					mc.x = bomb.mc.x + tray.x;
					mc.y = bomb.mc.y + tray.y;
					mc.filters = [new GlowFilter(0xFFCC00, 1, 30, 30, 2)];
					mc.scaleX = mc.scaleY = 0.01;
					dm.add(mc, DP_PART);

					var fx = new mt.fx.Grow(mc, 0.1, 1);
					addFx(fx, function() {
						mc.parent.removeChild(mc);
						bombBlocks();
					});
				} else if (bomb.bonus == B_Dynamite) {
					for (i in 0...GRID_SIZE) {
						var b = grid[bomb.x][i];
						if (b != null)
							a.push(b);
						var b = grid[i][bomb.y];
						if (b != null && b != bomb)
							a.push(b);
					}

					var l = RAY / Math.cos(Math.PI / 4);

					var n = [bomb.x, bomb.y, GRID_SIZE - bomb.x - 1, GRID_SIZE - bomb.y - 1];

					var mc = new Sprite();
					mc.x = bomb.mc.x + tray.x;
					mc.y = bomb.mc.y + tray.y;
					dm.add(mc, DP_PART);
					var f = 4;
					for (i in 0...4) {
						var line = new Sprite();
						// lineStyle(l * 0.7, 0xeefd9a) + drawRect(0, 0, 0, l * n[i]): Flash strokes the empty rectangle with its
						// default round caps and joints, a capsule from (0, 0) to (0, l * n[i])
						(line.graphics : Dynamic).lineStyle({width: l * 0.7, color: 0xeefd9a, cap: "round", join: "round"});
						line.graphics.moveTo(0, 0);
						line.graphics.lineTo(0, l * n[i]);
						line.rotation = 135 + 90 * i;
						mc.addChild(line);
						line.scaleY = 0;
						var fx = new mt.fx.Grow(line, 1.2 / n[i], 1, 2);
						addFx(fx, function() {
							f--;
							if (f == 0) {
								line.parent.removeChild(line);
								mc.parent.removeChild(mc);
								bombBlocks();
							}
						});
					}
					mc.filters = [new GlowFilter(0xFFCC00, 1, 30, 30, 2)];
				}
			case S_End:
				for (x in 0...GRID_SIZE) {
					for (y in 0...GRID_SIZE) {
						var b = grid[x][y];
						if (b != null) {
							b.vanish();
						}
					}
				}
				Game.me.addFx(new nosushi.fx.Sleep(50));

			case S_Void:
		}
	}

	public function addFx<T:mt.fx.Fx>(x:T, ?onEnd:Void->Void):T {
		waitingFx++;
		x.onFinish = function() {
			if (onEnd != null)
				onEnd();
			fxEnd();
		}
		return x;
	}

	function fxEnd() {
		waitingFx--;
	}

	function initGroups() {
		for (x in 0...GRID_SIZE) {
			for (y in 0...GRID_SIZE) {
				grid[x][y].group = null;
			}
		}

		for (x in 0...GRID_SIZE) {
			for (y in 0...GRID_SIZE) {
				var b = grid[x][y];
				if (b.group != null)
					continue;
				b.makeGroup(new Group(b.id));
			}
		}
	}

	// one frame of the original (Game.update, called by the Arkadeo loader at each frame)
	public function updateGame() {
		fxm.update();

		switch (step) {
			case S_Void:
			case S_End:
				if (waitingFx == 0) {
					gameOver();
					setStep(S_Void);
				}
			case S_Play:
				updateSelection();
				var e = getEvent();
				if (e != null) {
					var x = Math.floor(e / 100);
					var y = e % 100;
					var b = grid[x][y];
					if (b != null && b.group != null) {
						b.group.onClick();
					}
				}
			case S_Break:
				if (waitingFx == 0)
					setStep(S_TurnBonus);
			case S_TurnBonus:
				if (waitingFx == 0)
					setStep(S_Gravity);
			case S_Gravity:
				lockFrames--;
				dmtray.ysort(DP_BLOCKS);
				if (waitingFx == 0)
					gravity();
			case S_Create, S_InitCreate:
				if (waitingFx == 0)
					setStep(S_Play);
			case S_Bombe:
				if (waitingFx == 0)
					setStep(S_Gravity);
		}
	}

	function gravity() {
		var l = 0;
		for (y in 0...GRID_SIZE) {
			var empty = false;
			for (x in 0...GRID_SIZE) {
				var rx = GRID_SIZE - x - 1;
				var b = grid[rx][y];
				if (b == null)
					empty = true;
				else if (empty) {
					b.gravityLeft();
					l++;
				}
			}
		}
		if (l > 0)
			return;
		for (x in 0...GRID_SIZE) {
			var empty = false;
			for (y in 0...GRID_SIZE) {
				var ry = GRID_SIZE - y - 1;
				var b = grid[x][ry];
				if (b == null)
					empty = true;
				else if (empty) {
					b.gravityDown();
					l++;
				}
			}
		}

		if (l == 0 && lockFrames <= 0)
			setStep(S_Create);
	}

	function create(isInit:Bool) {
		emptyCells = 0;
		for (x in 0...GRID_SIZE) {
			for (y in 0...GRID_SIZE) {
				if (grid[x][y] == null) {
					emptyCells++;
				}
			}
		}

		for (x in 0...GRID_SIZE) {
			for (y in 0...GRID_SIZE) {
				if (grid[x][y] == null) {
					grid[x][y] = new Block(x, y, isInit);
				}
			}
		}
		dmtray.ysort(DP_BLOCKS);
	}

	function updateSelection() {
		var p = convertPos(mouseX, mouseY);

		var b = null;
		if (grid[p.x] != null)
			b = grid[p.x][p.y];

		var g = b != null ? b.group : null;

		if (g != curGroup) {
			if (curGroup != null)
				curGroup.onOut();
			curGroup = g;
			if (curGroup != null)
				curGroup.onOver();
		}
	}

	function onClick() {
		if (step != S_Play)
			return;

		var p = convertPos(mouseX, mouseY);
		var b = null;
		if (grid[p.x] != null)
			b = grid[p.x][p.y];
		if (b != null)
			emitEvent(b.x * 100 + b.y);
	}

	function convertPos(x:Float, y:Float) {
		var cx = x - DELTA_X - tray.x;
		var cy = y - DELTA_Y + RAY - tray.y;

		var ax = (cy / RAY + cx / RAY) / 2;
		var ay = (-cx / RAY + cy / RAY) / 2;

		return {
			x: Math.floor(ax),
			y: Math.floor(ay)
		};
	}

	public function findSameBlock(block:Block) {
		for (x in 0...GRID_SIZE) {
			for (y in 0...GRID_SIZE) {
				var b = grid[x][y];
				if (b == null || b == block)
					continue;
				if (b.id == block.id && b.bonus == block.bonus)
					return true;
			}
		}
		return false;
	}

	// Game.flatten of a Bloc: its picture drawn by the asset pipeline (the `_block` on its first frame, the `_bonus` icon),
	// a Bitmap at the top left of the bounds of the clip in a Sprite (bmpOffset is (0, 0))
	public static function flatten(id:Int, bonus:Bonus) {
		var i = id * 5 + Type.enumIndex(bonus);
		var bmp = new Bitmap("blk", i + 1);
		bmp.x = Data.BLK_X[i];
		bmp.y = Data.BLK_Y[i];
		var sp = new Sprite();
		sp.addChild(bmp);
		return sp;
	}

	// ---------------------------------------------------------------- the port
	// the mouse: mouseX / mouseY of the Game (at (0, 0) of the stage), as KadoKadeo records it
	public var mouseX(get, never):Float;
	public var mouseY(get, never):Float;

	inline function get_mouseX():Float
		return MouseManager.getX();

	inline function get_mouseY():Float
		return MouseManager.getY();

	// AKApi.emitEvent / getEvent: an event of a frame is read by the next one
	function emitEvent(e:Int) {
		events.push(e);
	}

	function getEvent():Null<Int> {
		return events.length == 0 ? null : events.shift();
	}

	// The CLICK of the transparent button over the stage (fg): the left button pressed and released over the game
	function pollMouse() {
		var inside = mouseX < WIDTH && mouseY < AREA_HEIGHT;
		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT))
			pressedIn = inside;
		if (MouseManager.isButtonJustReleased(MouseManager.BUTTON_LEFT)) {
			if (pressedIn && inside)
				clicked = true;
			pressedIn = false;
		}
	}

	// sp.cacheAsBitmap with its GlowFilter (the points of Block.exec): the field and its glow drawn once into a bitmap, so
	// that the alpha of sp applies to the whole picture like in Flash; the same picture for every block of a group (same
	// points, same colour)
	public function cachedPicture(tf:TextField, key:String, glow:GlowFilter):Bitmap {
		var m = Std.int(Math.ceil(glow.blurX / 2)) + 1;
		var bd = ptsCache.get(key);
		if (bd == null) {
			var w = Std.int(Math.ceil(tf.textWidth)) + 4 + m * 2;
			var h = Std.int(Math.ceil(tf.textHeight)) + 4 + m * 2;
			bd = new BitmapData(w, h, true, 0);
			var mat = new Matrix();
			mat.translate(m, m);
			bd.draw(tf, mat);
			bd.applyFilter(bd, bd.rect, new Point(0, 0), glow);
			ptsCache.set(key, bd);
		}
		var bmp = new Bitmap(null, 1, bd);
		bmp.x = bmp.y = -m;
		return bmp;
	}

	public function getFrame():Int {
		return frameCount;
	}

	public function isReplayGame():Bool {
		return isReplay;
	}

	// ---------------------------------------------------------------- KadoKadeo step: 5 frames of the game every 4 steps
	public function update(delta:Float) {
		pollMouse();
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame();
		}
		Flash.display(this, frameAcc / 4);
	}

	// one Flash frame: the playheads advance, the mouse event of the frame (between two frames in Flash), the game
	// (enterFrame), then the frame scripts of the timelines
	function flashFrame() {
		Flash.frameStart(this);
		MovieClip.tickAll();
		if (clicked) {
			clicked = false;
			onClick();
		}
		updateGame();
		Clip.runPending();
		frameCount++;
		Flash.frameEnd(this);
		#if debug
		untyped js.Browser.window.__nosushi = endState();
		#end
	}

	#if debug
	// the state compared between a game and its replay (test bots)
	public function endState():Dynamic {
		var cells = [];
		for (x in 0...GRID_SIZE)
			for (y in 0...GRID_SIZE) {
				var b = grid[x][y];
				cells.push(b == null ? -1 : b.id * 10 + Type.enumIndex(b.bonus));
			}
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			step: Std.string(step),
			leftPlay: leftPlay,
			moreplay: curMoreplay,
			waitingFx: waitingFx,
			bombs: bombs.length,
			fx: fxm.fxs.length,
			cells: cells,
			over: over,
		};
	}
	#end

	// AKApi.addScore
	public function addScore(n:Int) {
		if (over)
			return;
		KadoKadeoManager.kkm.addScore(n);
	}

	// AKApi.gameOver
	public function gameOver() {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = endState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	// the shaders of the filters used during the game, compiled now (a freeze of 10-80 ms otherwise)
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new pixi.core.display.Container();
		var fl:Array<BitmapFilter> = [
			new GlowFilter(0xFFCC00, 1, 30, 30, 2),
			new GlowFilter(0xFFFFFF, 1, 4, 4, 4),
			new ColorMatrixFilter(new mt.flash.ColorMatrix().matrix)
		];
		for (f in fl) {
			var d = new Shape();
			d.graphics.beginFill(0xFFFFFF);
			d.graphics.drawRect(0, 0, 8, 8);
			d.graphics.endFill();
			d.filters = [f];
			holder.addChild(d.node);
		}
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null)
				canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		over = true;
		for (bd in ptsCache)
			bd.dispose();
		ptsCache = new Map();
		resetStatics();
		node.mask = null;
		if (gameMask.parent != null)
			gameMask.parent.removeChild(gameMask);
		gameMask.destroy();
		if (node.parent != null)
			node.parent.removeChild(node);
		node.destroy({children: true});
	}

	// statics of the game: one page plays several games and replays
	static function resetStatics() {
		Flash.reset();
		mt.fx.Fx.DEFAULT_MANAGER = null;
		DELTA_X = 0;
		DELTA_Y = 0;
		me = null;
	}
}

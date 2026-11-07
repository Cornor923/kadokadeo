package trigo;

import haxe.io.UInt16Array;
import common_haxe_avm1.display.ASprite;

enum Step {
	S_Create;
	S_Play;
	S_FPlay;
	S_Gather;
	S_Destroy;
	S_GameOver;
	S_TutoLast;
	S_Void;
}

enum EventType {
	E_Over;
	E_Click;
}

// Trigo (Arkadeo, Motion Twin, 600 x 460 at 40 frames/s), its League: blocks of 5 colours on a grid of 15 x 15, a clock of
// 60 s. Three blocks of the same colour clicked make a triangle: the blocks in it join it; another triangle made around
// all of them within the time of a combo makes a combo, a click on the triangle takes it away for
// n x (n - 1) / 2 x combo points and gives the clock 5 s x combo (less and less), the end of the time of a combo destroys
// it. The code is the original Game (Haxe 2, AS3) on the AS3 display list of the lib (arkadeo); this class is also the
// game KadoKadeo creates, steps and records (the mouse) instead of the Arkadeo loader (AKApi).
//
// What changes from the original, and why:
//  - the LvUP campaign (the orders of 20 levels: Contract, setProgression; its tutorial: TUTO_POS, showTutoText, Shine,
//    S_TutoLast) and the in-game prizes of Arkadeo (filteredPrizeTokens, getPrizeToken) are not ported: the League has
//    neither;
//  - the inputs: the CLICK of the original (fg.onClick: emitClick, the event of the block under the mouse read by
//    getEvent in the next frame) is the left button released over the game, polled at each step of KadoKadeo, its event
//    played in the next frame of the game; the mouse is recorded, so the event of the block under the mouse (E_Over) is
//    made in a replay too (the original took it from the record of the replay);
//  - the random: `seed` is the gameplay random of KadoKadeo (Seed.random) instead of the mt.Rand of the seed of Arkadeo,
//    and `fxSeed` an mt.Rand seeded from it like the original: its draws (the order the new blocks come in, the particles)
//    are gameplay, the steps wait for every effect to end (fxm.fxs.length) while the clock runs;
//  - the blocks of a triangle (Group.isInside): the bitmap drawn by the Flash player is a test on the centres of the
//    blocks, in integer arithmetic (see Group.computeMask);
//  - the 40 frames/s of the SWF on the 32 steps/s of KadoKadeo: 5 frames of the game every 4 steps, shown interpolated
//    (arkadeo.Flash);
//  - the pictures of the original drawn at run time and never changed afterwards are drawn by the asset pipeline: the
//    flattened blocks (Game.flatten), gfx.BG and gfx.Board (one picture: they never move); gfx.Render, the paper over the
//    game in the blend mode OVERLAY, is drawn by a filter of the game (arkadeo.OverlayFilter: PIXI's blend modes cannot
//    read what is under a picture); the texts of showText use the system Arial Bold (the device font "arial").
@:expose('GameTrigo')
class Game extends Sprite implements kado.GameInterface {
	public static var W = 600;
	public static var H = 460;

	public static var DP_BOARD = 3;
	public static var DP_BLOCKS = 5;
	public static var DP_GROUP = 6;
	public static var DP_WGROUP = 7;
	public static var DP_PART = 8;

	// (AKApi.const: the protected numbers of Arkadeo)
	public static var PTS = 1;

	public static var DP_UI = 10;

	public static var DP_RENDER = 40;
	public static var DP_TUTO_TEXT = 41;

	public static var DP_FG = 50;

	public static var GRID_SIZE = 15;
	public static var BLOCK_SIZE = 26;
	public static var PADDING = 12;
	public static var DELTA_X = PADDING + BLOCK_SIZE / 2;
	public static var DELTA_Y = PADDING + BLOCK_SIZE / 2;

	public static var FP_TIMER_DELTA = -30;

	// (changed by every triangle: getFPTimer)
	public static var FP_TIMER = 800;
	public static var FP_TIMER_MIN = 320;

	public static var START_TIMER = 60 * 40;
	public static var MAX_TIMER = 60 * 40;

	// (changed by every triangle taken: setStep(S_Gather))
	public static var TIMER_DELTA = 5 * 40;
	public static var TIMER_DELTA_DECR = -40;
	public static var TIMER_DELTA_MIN = 1 * 40;
	public static var TIMER_DELTA_DECR2 = -10;

	public static var COMBO_RAINBOW = 10;
	public static var COMBO_ONECOLOR = [0, 0, 2, 3, 5, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4];

	public static var MAX_ID = 5;

	public static var COLORS = [
		0x6AC24D, // vert
		0xEEC55F, // jaune
		0x5FC7EE, // bleu
		0xB45FEE, // violet
		0xEE7B5F // rouge
	];

	public static var me:Game;

	public var dm:DepthManager;
	public var fxSeed:mt.Rand;
	public var fxm:mt.fx.Manager;

	public var group:Null<Group>;
	public var lastGroup:Null<Group>;

	public var fpTimer:Int;
	public var gTimer:Int;
	public var started:Bool;

	public var gblocks:Null<List<Block>>;
	public var combo:Int;
	public var colors:Null<Array<Int>>;
	public var groups:Null<Int>;

	public var grid:Array<Array<Block>>;

	public var overTimer:Null<Int>;

	public var rainbowCombo:Bool;
	public var sameColorGroups:Int;

	public var swapingBlocks:Int;

	var clock:MovieClip;
	var comboMeter:MovieClip;
	var step:Step;

	var overBlock:Null<Block>;
	var gatherBlock:Null<Block>;

	public var emptyCells:Int;

	// ---------------------------------------------------------------- the port
	public static inline var STEPS_PER_SECOND = 32;

	var gameRoot:ASprite;
	var gameMask:pixi.core.graphics.Graphics;
	var isReplay:Bool;
	var frameAcc:Int;
	var frameCount:Int;
	var over:Bool;
	// AKApi.emitEvent / getEvent
	var events:Array<Int>;
	var pressedIn:Bool;
	var clicked:Bool;
	var onPointerDown:Dynamic->Void;
	// the texts of showText (sp.cacheAsBitmap): one picture per text, size and colour
	var textCache:Map<String, BitmapData>;
	// the number of the combo meter: the `_txt` fields of its boxes _current / _next
	var currentTxt:TextField;
	var nextTxt:TextField;

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
		textCache = new Map();
		Tex.init("/trigo");
		Clip.init(Data.clips);
		TextField.init(Data.fonts);

		gameRoot = mc;
		mc.addChild(node);
		// the game area of Arkadeo (600 x 460): what goes out of it is not drawn (under the bar of KadoKadeo)
		gameMask = new pixi.core.graphics.Graphics();
		gameMask.beginFill(0xFFFFFF);
		gameMask.drawRect(0, 0, W, H);
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
		swapingBlocks = 0;

		me = this;
		fxSeed = new mt.Rand(rand(0xFFFFFF));
		dm = new DepthManager(this);
		fxm = new mt.fx.Manager();

		initStage();

		gTimer = START_TIMER;

		setStep(S_Create);

		started = false;

		warmShaders();
		Flash.display(this, 1);
		#if debug
		untyped js.Browser.window.__trigoMask = Group.maskOf;
		#end
	}

	// seed.random of the original
	public function rand(n:Int):Int {
		return Seed.random(n);
	}

	public function setStep(s:Step) {
		if (step == s)
			return;
		step = s;
		switch (step) {
			case S_Create:
				if (gTimer == 0) {
					gameOver();
					return;
				}
				initGrid();
			// (GM_PROGRESSION: the orders done, setProgression)
			case S_TutoLast:
			case S_Play:
				if (!started)
					started = true;
				overBlock = null;
				combo = 0;
				comboTxt._visible = false;
				colors = [];
				groups = 0;
				rainbowCombo = false;
				sameColorGroups = 0;
				gblocks = null;
			case S_FPlay:
			case S_Gather:
				if (group != null)
					group.deselect();

				var pts = lastGroup.calcPts();
				addScore(pts);

				// (the orders of the LvUP: contracts.onValidate)

				var center = lastGroup.center();
				var size = 17 + Math.ceil(Math.min(pts / 10000, 7));
				showText(Std.string(pts), lastGroup.id, center.x * BLOCK_SIZE + DELTA_X, center.y * BLOCK_SIZE + DELTA_Y, size);

				var m = gatherBlock.center();
				for (b in gblocks) {
					var c = b.center();
					b.gather(lastGroup, Std.int((Math.abs(c.x - m.x) + Math.abs(c.y - m.y)) / 16));
				}

				if (gTimer > 0)
					gTimer += TIMER_DELTA * combo;
				if (gTimer > MAX_TIMER)
					gTimer = MAX_TIMER;
				updateClock(true);

				if (TIMER_DELTA > TIMER_DELTA_MIN) {
					TIMER_DELTA += TIMER_DELTA_DECR;
				} else if (TIMER_DELTA > -TIMER_DELTA_DECR2) {
					TIMER_DELTA += TIMER_DELTA_DECR2;
				}

				lastGroup.hide();
				lastGroup = null;
			case S_Destroy:
				if (group != null)
					group.deselect();
				lastGroup.hide();
				lastGroup = null;
				for (b in gblocks)
					b.destroy();
			case S_GameOver:
				overTimer = 25;
			case S_Void:
		}
	}

	// AKApi.gameOver(win): the League is never won
	function gameOver() {
		endGame();
		setStep(S_Void);
	}

	function initStage() {
		// gfx.BG (plane 0) and gfx.Board at (5, 5) (DP_BOARD), flattened: one picture
		dm.add(new Bitmap("decor"), 0);

		// gfx.Render, flattened, in the blend mode OVERLAY on the plane DP_RENDER (above everything the League shows): the
		// filter of the game
		var overlay = new OverlayFilter(Tex.get("render")[0], W, H);
		node.filters = [cast overlay];

		// (fg: the transparent W x H button over the game, its CLICK: pollMouse; Game.bmd: the triangle, Group.computeMask)

		clock = new MovieClip(Data.CLOCK);
		clock.x = 429;
		clock.y = 33;
		clockTime.gotoAndStop(1);
		clockTime._rotation = 0;
		dm.add(clock, DP_UI);

		comboMeter = new MovieClip(Data.COMBO_METER);
		comboMeter.x = 426;
		comboMeter.y = 223;
		comboTxt._visible = false;
		currentTxt = numField(comboTxt.getClip("_current"));
		nextTxt = numField(comboTxt.getClip("_next"));
		dm.add(comboMeter, DP_UI);

		// (GM_PROGRESSION: the orders of the level, Contract)
	}

	// the named children of gfx.Clock and gfx.ComboMeter
	var clockTime(get, never):Clip;
	var clockCol(get, never):Clip;
	var comboTxt(get, never):Clip;

	inline function get_clockTime()
		return clock.getClip("_time");

	inline function get_clockCol()
		return clock.getClip("_clock").getClip("_col");

	inline function get_comboTxt()
		return comboMeter.getClip("_txt");

	// the `_txt` field of a box of the combo meter (Fredoka One 120 embedded, orange, centred, its drop shadows baked in the
	// glyphs), in the box clip: it moves and darkens with it
	function numField(box:Clip):TextField {
		var tf = new TextField("num");
		tf.textColor = 0xFFFFFF;
		tf.fieldWidth = Data.NUM_W;
		tf.align = "center";
		tf.text = "";
		box.attach(tf);
		tf.node.x = Data.NUM_X;
		tf.node.y = Data.NUM_Y;
		return tf;
	}

	function emitClick() {
		// (S_TutoLast: the tutorial of the LvUP)
		if (!started)
			return;
		if (step != S_Play && step != S_FPlay)
			return;
		emitEvent(E_Click);
	}

	function initGrid() {
		var init = false;
		if (grid == null) {
			grid = [];
			init = true;
		}

		var gs = GRID_SIZE;

		// (GM_PROGRESSION: 32 the first time)
		var gd = init ? 22 : 0;
		var m = 1;
		var r = init ? 4 : fxSeed.random(7);

		var fd = switch (r) {
			case 0: function(x, y) return x + y;
			case 1: function(x, y) return gs - x + y;
			case 2: function(x, y) return gs + x - y;
			case 3: function(x, y) return 2 * gs - x - y;
			case 4: function(x, y) return Std.int(Math.abs(x - gs / 2) + Math.abs(y - gs / 2));
			case 5: function(x, y) return gs - Std.int(Math.abs(x - gs / 2) + Math.abs(y - gs / 2));
			// (6: r is drawn in 0...7)
			default: function(x, y) return fxSeed.random(Std.int(1.5 * gs));
		}

		emptyCells = 0;
		for (x in 0...gs) {
			if (grid[x] == null)
				grid[x] = [];
			for (y in 0...gs) {
				if (grid[x][y] == null)
					emptyCells++;
			}
		}

		for (x in 0...gs) {
			for (y in 0...gs) {
				var b = grid[x][y];
				if (b == null)
					grid[x][y] = new Block(x, y, Math.round(gd + fd(x, y) * m), 0.1 / m);
			}
		}
	}

	public function updateClock(add = false) {
		var t:Float = gTimer;
		if (t == 0)
			t = 0.1;
		var f = new trigo.fx.ClockRotate(clockTime, -360 * (t / MAX_TIMER), add ? 0.08 : 0.2);

		if (add) {
			new mt.fx.Radiate(clockCol, 0.05, 0xFFFFCC, 10);
		} else if (gTimer <= 5 * 40) {
			var s = Math.round((6 - gTimer / 40));
			new mt.fx.Radiate(clockCol, 0.05 * s, 0xEE7B5F, 10);
		} else if (Math.round(gTimer / 40) == 10) {
			new mt.fx.Radiate(clockCol, 0.05, 0xEEC55F, 10);
		}
	}

	public function emitEvent(t:EventType) {
		if (step == S_GameOver || step == S_Void)
			return;

		var b = getMouseBlock();
		var i = Type.enumIndex(t) * 10000;
		if (b == null)
			i += 9999;
		else
			i += b.x * 100 + b.y;
		events.push(i);
	}

	// one frame of the original (Game.update, called by the Arkadeo loader at each frame)
	public function updateGame() {
		fxm.update();

		// (tuto == null && !tutoEnd: always in the League)
		if (started && gTimer > 0) {
			gTimer--;
			if (gTimer % 40 == 0)
				updateClock();
		}

		if (gTimer == 0 && step != S_Gather) {
			if (step == S_FPlay) {
				onClick(lastGroup.arr[0]);
			} else {
				setStep(S_GameOver);
			}
		}

		switch (step) {
			case S_Create:
				if (fxm.fxs.length == 0)
					setStep(S_Play);
			case S_TutoLast:
			case S_Play, S_FPlay:
				if (started) {
					// (!AKApi.isReplay(): the mouse is recorded, a replay makes these events too)
					var b = getMouseBlock();
					if (b != null && b.grouped && swapingBlocks > 0)
						b = null;
					if (b != overBlock) {
						if (b == null || overBlock == null || !b.grouped || !overBlock.grouped) {
							emitEvent(E_Over);
						}
					}

					while (true) {
						var i = getEvent();
						if (i == null)
							break;

						var eType = Type.createEnumIndex(EventType, Math.floor(i / 10000));
						var eBlock = null;
						if (i % 10000 != 9999) {
							var eX = Math.floor((i % 10000) / 100);
							var eY = i % 100;
							eBlock = grid[eX][eY];
						}

						switch (eType) {
							case E_Click:
								onClick(eBlock);
							case E_Over:
								if (overBlock != null)
									overBlock.mouseOut();
								overBlock = eBlock;

								if (eBlock != null) {
									eBlock.mouseOver();
									if (group != null && !eBlock.grouped)
										group.over(eBlock);
								}
						}
					}
				}

				if (step == S_FPlay) {
					fpTimer--;
					lastGroup.showFPlay(fpTimer / FP_TIMER);
					if (fpTimer == 0)
						setStep(S_Destroy);
				}
			case S_Destroy, S_Gather:
				if (fxm.fxs.length == 0)
					setStep(S_Create);
			case S_GameOver:
				overTimer--;
				if (overTimer <= 0) {
					gameOver();
					return;
				}
			case S_Void:
		}
	}

	public function onClick(block:Block) {
		// (the tutorial of the LvUP: the blocks of TUTO_POS one after the other)

		if (block == null) {
			if (group != null)
				group.deselect();
			return;
		} else if (block.grouped) {
			gatherBlock = block;
			setStep(S_Gather);
			return;
		}

		if (block.id == null)
			return;

		if (group == null) {
			group = new Group(block);
		} else {
			if (group.click(block)) {
				if (block == overBlock) {
					block.mouseOut();
					overBlock = null;
				}

				var center = group.center();
				var pcenter = new Point(center.x * BLOCK_SIZE + DELTA_X, center.y * BLOCK_SIZE + DELTA_Y);

				groups++;
				if (gblocks == null) {
					gblocks = new List();
					combo = 1;
					colors = [group.id];
				} else {
					combo++;
					showText(Text.combo, -1, pcenter.x, pcenter.y, 18);
					if (!Lambda.has(colors, group.id))
						colors.push(group.id);
				}

				if (lastGroup != null && lastGroup.id == group.id)
					sameColorGroups++;
				else
					sameColorGroups = 1;

				var c = COMBO_ONECOLOR[sameColorGroups - 1];
				if (c > 0) {
					combo += c;
					showText(Text.unicombo({_c: c}), group.id, pcenter.x, pcenter.y + 20, 22);
				}

				if (colors.length == MAX_ID && !rainbowCombo) {
					rainbowCombo = true;
					combo += COMBO_RAINBOW;
					showText(Text.rainbowcombo({_c: COMBO_RAINBOW}), -2, pcenter.x, pcenter.y + 20, 22);
				}

				for (b in group.newBlocks) {
					b.group(group, Std.int(Math.abs(b.x - block.x) + Math.abs(b.y - block.y)));
				}

				// (the orders of the LvUP: contracts.onGroup)

				if (groups == 1) {
					comboTxt._visible = true;
					comboTxt._alpha = 0;
					currentTxt.text = Std.string(combo);
					var f = new trigo.fx.Alpha(comboTxt, 1);
					new mt.fx.Sleep(f, null, 15);
				} else {
					nextTxt.text = Std.string(combo);
					var f = new trigo.fx.Play(comboTxt);
					f.onFinish = function() {
						currentTxt.text = Std.string(combo);
						comboTxt.gotoAndStop(1);
					}
					new mt.fx.Sleep(f, null, 25);
				}

				if (lastGroup != null) {
					lastGroup.hide();
					for (b in lastGroup.blocks) {
						b.sp.y += 1;
					}
				}

				lastGroup = group;
				group = null;
				fpTimer = getFPTimer();
				setStep(S_FPlay);
			}
		}
	}

	function getFPTimer() {
		var t = FP_TIMER;
		t += FP_TIMER_DELTA;
		if (t < FP_TIMER_MIN)
			t = FP_TIMER_MIN;
		FP_TIMER = t;
		return t;
	}

	function getMouseBlock() {
		var mx = mouseX;
		var my = mouseY;
		var x = Math.floor((mx - DELTA_X + BLOCK_SIZE / 2) / BLOCK_SIZE);
		var y = Math.floor((my - DELTA_Y + BLOCK_SIZE / 2) / BLOCK_SIZE);

		if (x < 0 || x >= GRID_SIZE)
			return null;
		if (y < 0 || y >= GRID_SIZE)
			return null;

		return grid[x][y];
	}

	public function listBlocks(id:Int) {
		var l = new List();
		for (ix in 0...GRID_SIZE) {
			for (iy in 0...GRID_SIZE) {
				var b = grid[ix][iy];
				if (b != null && b.id == id)
					l.add(b);
			}
		}
		return l;
	}

	// A text that rises and fades (the points of a triangle, the combos): a TextField in the device font "arial", bold,
	// in a sprite with a white glow and cacheAsBitmap (one picture: the alpha applies to the whole of it)
	public function showText(text:String, id:Int, x:Float, y:Float, size = 18) {
		var tf = new TextField("a" + size);
		var col = (id >= 0) ? COLORS[id] : 0x000000;
		if (id == -2) {
			var s = new StringBuf();
			for (i in 0...text.length) {
				var c = COLORS[i % COLORS.length];
				s.add('<font color="#' + StringTools.hex(c, 6) + '">' + text.charAt(i) + '</font>');
			}
			tf.htmlText = s.toString();
		} else {
			tf.textColor = col;
			tf.text = text;
		}

		var f = new GlowFilter();
		f.color = 0xFFFFFF;
		f.strength = 4;
		f.blurX = f.blurY = 4;
		f.alpha = 1;

		var bmp = cachedPicture(tf, text + ":" + id + ":" + size, f);
		bmp.x += -tf.textWidth / 2;
		bmp.y += -tf.textHeight;

		var sp = new Sprite();
		Game.me.dm.add(sp, Game.DP_PART);
		sp.addChild(bmp);
		sp.x = Math.max(x, tf.textWidth / 2);
		sp.y = y;
		sp.alpha = 1;

		var f = new mt.fx.Spawn(sp, 0.1, true, true);
		f.onFinish = function() {
			var p = new mt.fx.Part(sp);
			p.weight = -0.12;
			p.timer = 40;
			p.fadeLimit = 25;
			p.fadeType = 1;
			new mt.fx.Sleep(p, null, 10);
		}

		return sp;
	}

	public function createPart(pos:Point, type:Int) {
		var psp = new MovieClip(Data.PART);
		psp.gotoAndStop(type);
		psp.x = pos.x;
		psp.y = pos.y;

		psp.blendMode = BlendMode.ADD;

		Game.me.dm.add(psp, Game.DP_PART);
		var p = new mt.fx.Part(psp);
		p.weight = 0.1;
		p.vx = 2 * fxSeed.random(100) / 100 - 1;
		p.vy = 2 * fxSeed.random(100) / 100 - 1;
		p.timer = 20;
		p.fadeType = 1;
		// (removed by the end of the effect: its timeline stops, arkadeo.MovieClip.all)
		p.onFinish = psp.dispose;

		return p;
	}

	// Game.flatten of a block: its picture drawn by the asset pipeline (the gfx.Blocks / gfx.Blocks2 on its colour frame,
	// its _blink and _hili hidden), a Bitmap at the top left of the bounds of the clip
	public static function flatten(mc:MovieClip, grouped:Bool, id:Int):Bitmap {
		var i = (grouped ? 5 : 0) + id;
		var bmp = new Bitmap("blk", i + 1);
		bmp.x = Data.BLK_X[i];
		bmp.y = Data.BLK_Y[i];
		return bmp;
	}

	// ---------------------------------------------------------------- the port
	// the mouse: mouseX / mouseY of the Game (at (0, 0) of the stage), as KadoKadeo records it (whole pixels, >= 0)
	public var mouseX(get, never):Float;
	public var mouseY(get, never):Float;

	inline function get_mouseX():Float
		return Math.max(0, MouseManager.getX());

	inline function get_mouseY():Float
		return Math.max(0, MouseManager.getY());

	// AKApi.emitEvent / getEvent: the events of a frame are read by the game in the order they were made
	function getEvent():Null<Int> {
		return events.length == 0 ? null : events.shift();
	}

	// The CLICK of the transparent button over the stage (fg): the left button pressed and released over the game
	function pollMouse() {
		var inside = mouseX < W && mouseY < H;
		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT))
			pressedIn = inside;
		if (MouseManager.isButtonJustReleased(MouseManager.BUTTON_LEFT)) {
			if (pressedIn && inside)
				clicked = true;
			pressedIn = false;
		}
	}

	// sp.cacheAsBitmap with its GlowFilter (the texts of showText): the field and its glow drawn once into a bitmap, so
	// that the alpha of sp applies to the whole picture like in Flash
	function cachedPicture(tf:TextField, key:String, glow:GlowFilter):Bitmap {
		var m = Std.int(Math.ceil(glow.blurX / 2)) + 1;
		var bd = textCache.get(key);
		if (bd == null) {
			var w = Std.int(Math.ceil(tf.textWidth)) + 4 + m * 2;
			var h = Std.int(Math.ceil(tf.textHeight)) + 4 + m * 2;
			bd = new BitmapData(w, h, true, 0);
			var mat = new Matrix();
			mat.translate(m, m);
			bd.draw(tf, mat);
			bd.applyFilter(bd, bd.rect, new Point(0, 0), glow);
			textCache.set(key, bd);
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
			emitClick();
		}
		updateGame();
		Clip.runPending();
		frameCount++;
		Flash.frameEnd(this);
		#if debug
		untyped js.Browser.window.__trigo = endState();
		#end
	}

	#if debug
	// the state compared between a game and its replay (test bots)
	public function endState():Dynamic {
		var cells = [];
		if (grid != null)
			for (x in 0...GRID_SIZE)
				for (y in 0...GRID_SIZE) {
					var b = grid[x] == null ? null : grid[x][y];
					cells.push(b == null ? -1 : b.id + (b.grouped ? 10 : 0));
				}
		var arr = group == null ? [] : [for (b in group.arr) [b.x, b.y]];
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			step: Std.string(step),
			gTimer: gTimer,
			fpTimer: fpTimer,
			combo: combo,
			groups: groups,
			gblocks: gblocks == null ? 0 : gblocks.length,
			group: arr,
			lastGroup: lastGroup == null ? 0 : lastGroup.blocks.length,
			timerDelta: TIMER_DELTA,
			fpTimerMax: FP_TIMER,
			swaping: swapingBlocks,
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
	function endGame() {
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
			new GlowFilter(0xFFFFFF, 1, 4, 4, 4),
			new DropShadowFilter(1, 0, 0x0, 1.3, 1.3, 5),
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
		for (bd in textCache)
			bd.dispose();
		textCache = new Map();
		resetStatics();
		node.filters = null;
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
		FP_TIMER = 800;
		TIMER_DELTA = 5 * 40;
		me = null;
	}
}

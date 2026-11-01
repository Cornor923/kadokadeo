package alphabounce;

import common_haxe_avm1.KeyboardManager;
import common_haxe_avm1.MouseManager;
import haxe.io.UInt16Array;
import mt.bumdum.Phys;
import mt.bumdum.Sprite;
import pixi.core.Pixi.BlendModes;
import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import pixi.core.math.Matrix;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;
import pixi.filters.blur.BlurFilter;
import alphabounce.Texts;
import kado.TouchControlsConfig.TouchControlsMode;
import kado.TouchControlsConfig.TouchButtonShape;

enum Step {
	Scroll;
	Intro;
	Play;
	GameOver;
}

// Alphabounce (KadoKado, Motion-Twin): ported from the original sources (Game, Ball, Block, Pad, Option... of the
// KadoKado Alphabounce folder) and the graphics of its SWF. The game runs in the Flash pixels of the original
// (300 x 300), drawn x2. The mouse (or a finger) moves the pad, its button (or Space) launches the balls and uses the
// pad's power; the arrows move the pad too.
@:expose('GameAlphabounce')
class Game implements kado.GameInterface {
	// mobile: the finger moves the pad like the mouse without clicking, the button is the click / Space (launch, power)
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		passthroughMouseButtons: false,
		buttons: [
			{
				id: "power",
				label: "✦",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.SPACE,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	// Enter acts like Space, Q / A / D like the arrows
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	public static inline var K = 2;

	public static var DP_BG = 0;
	public static var DP_PLASMA = 2;
	public static var DP_UNDERPARTS = 3;
	public static var DP_BLOCK = 4;
	public static var DP_PAD = 5;
	public static var DP_OPTION = 6;
	public static var DP_BALL = 7;
	public static var DP_PARTS = 8;
	public static var DP_INTER = 10;

	var flDoor:Bool;

	public var flPress:Bool;
	public var flClick:Bool;
	public var flSafe:Bool;

	var step:Step;

	public var lvl:Int;
	public var block:Int;

	var blockTotal:Int;
	var accTimer:Float;
	var scroll:Float;
	var timeCoef:Null<Float>;

	public var levelTimer:Float;
	public var autoLaunchTimer:Float;

	public var grid:Array<Array<Block>>;
	public var blocks:Array<Block>;
	public var model:Array<Array<Null<Int>>>;
	public var balls:Array<Ball>;
	public var sides:Array<Mc>;
	public var options:Array<Option>;
	public var events:Array<Event>;
	public var titles:Array<Title>;

	public var pad:Pad;

	public static var me:Game;

	public var dm:Plans;
	public var bdm:Plans;
	public var halos:ASprite;
	public var root:ASprite;
	public var bg:Mc;

	var scene:ASprite;
	var mcTitle:TitleLevel;

	// clips whose timeline plays
	public var mcs:Array<Mc>;

	// BitmapData of the colours of the blocks (XMAX x YMAX)
	var bmpPaint:Array<Int>;

	var plasma:PlasmaLayer;
	var pm:Matrix;
	var shot:RenderTexture;
	var shotView:PixiSprite;

	var over:Bool;
	var frameCount:Int;
	var lastMx:Int;
	var lastMy:Int;
	var onPointerDown:Dynamic;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: UInt16Array.fromArray([KeyboardManager.LEFT, KeyboardManager.RIGHT, KeyboardManager.SPACE]),
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: UInt16Array.fromArray([MouseManager.BUTTON_LEFT]),
		});
		// like the Flash player, the game keeps the mouse while its button is held
		if (!isReplay) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			onPointerDown = function(e:Dynamic) {
				try {
					canvas.setPointerCapture(e.pointerId);
				} catch (_:Dynamic) {}
			};
			canvas.addEventListener("pointerdown", onPointerDown);
		}

		me = this;
		Sprite.clearAll();
		Cs.init();
		over = false;
		frameCount = 0;
		mcs = [];
		pm = new Matrix();
		lastMx = MouseManager.getX();
		lastMy = MouseManager.getY();
		flPress = false;
		flClick = false;

		scene = root.createEmptyMovieClip("scene", 0);
		scene._xscale = scene._yscale = 100 * K;
		scene.updateState();
		this.root = scene.createEmptyMovieClip("world", 0);
		dm = new Plans(this.root);

		// blocks: their glow (Filt.glow of the layer) is a halo under each block
		var base = dm.empty(DP_BLOCK);
		bdm = new Plans(base);
		halos = bdm.plan(0);
		bdm.plan(1);

		sides = [];
		for (i in 0...2) {
			var mc = dm.attach("side", DP_BLOCK);
			mc.stops = [1, 10];
			mc.gotoAndStop(1);
			mc._x = i * Cs.mcw;
			mc._xscale = -(i * 2 - 1) * 100;
			sides.push(mc);
		}

		// SCREENSHOT (previous level, scrolled out)
		shot = RenderTexture.create(Cs.mcw * K, Cs.mch * K);
		var mcShot = dm.empty(DP_BG);
		shotView = new PixiSprite(shot);
		shotView.scale.set(1 / K);
		mcShot.addChild(shotView);
		mcShot._x = -Cs.mcw;
		mcShot._visible = false;

		bg = dm.attach("bg", DP_BG);
		bg.stop();
		balls = [];
		options = [];
		events = [];
		titles = [];
		lvl = 0;
		pad = new Pad(dm.add(new Pad.PadSkin(), DP_PAD));

		initPlasma();
		warmShaders();
		initScroll(1);
	}

	// one frame of the Flash player
	public function update(delta:Float) {
		frameCount++;
		advanceClips();
		readInputs();

		if (pad.flStop) {
			if (timeCoef == null)
				timeCoef = 1;
			timeCoef = Math.max(timeCoef - 0.1, 0.1);
		} else {
			if (timeCoef != null) {
				timeCoef = Math.min(timeCoef + 0.1, 1);
				if (timeCoef == 1)
					timeCoef = null;
			}
		}

		if (timeCoef != null)
			Timer.tmod = timeCoef;

		switch (step) {
			case Scroll:
				updateScroll();
			case Intro:
				updateIntro();
			case Play:
				updatePlay();
			case GameOver:
				updateGameOver();
		}

		updatePlasma();
		updateTitle();

		flClick = false;
	}

	// timelines of the clips (before the code of the frame, like the Flash player)
	function advanceClips() {
		var i = 0;
		var n = mcs.length;
		while (i < n) {
			var m = mcs[i];
			if (m.dead || !onStage(m)) {
				mcs[i] = mcs[n - 1];
				mcs.pop();
				n--;
				continue;
			}
			i++;
		}
		for (m in mcs.copy())
			m.advance();
	}

	function onStage(m:Mc):Bool {
		var p:Container = m.parent;
		while (p != null) {
			if (p == scene)
				return true;
			p = p.parent;
		}
		return false;
	}

	// mouse listeners and Space of the original (a press released within the same frame, a quick tap, is released at
	// the next frame: the pad sees it pressed once)
	function readInputs() {
		var mx = MouseManager.getX(), my = MouseManager.getY();
		if (mx != lastMx || my != lastMy)
			mouseMove();
		lastMx = mx;
		lastMy = my;
		if (pendingUp) {
			pendingUp = false;
			mouseUp();
		}
		var downNow = false;
		var changes:Array<Bool> = [];
		for (c in MouseManager.getFrameButtonChanges())
			if (c.button == MouseManager.BUTTON_LEFT)
				changes.push(c.isDown);
		for (c in KeyboardManager.getFrameKeyChanges())
			if (c.keyCode == KeyboardManager.SPACE)
				changes.push(c.isDown);
		for (d in changes) {
			if (d) {
				pendingUp = false;
				downNow = true;
				mouseDown();
			} else if (downNow) {
				pendingUp = true;
			} else {
				mouseUp();
			}
		}
	}

	var pendingUp = false;

	// root._xmouse (Flash pixels)
	public function mouseX():Float {
		return Math.max(0, MouseManager.getX()) / K - root._x;
	}

	// SCROLL
	function initScroll(n:Float) {
		step = Scroll;
		scroll = n;
		pad.init();
		setBg(lvl + 1);

		// LEVEL
		initGrid();
		fillGrid();
		accTimer = 0;
		flDoor = false;

		updateScroll();
	}

	// mcBg.gotoAndStop(f): one picture per level (darkened or recoloured in the SWF)
	function setBg(f:Int) {
		bg.gotoAndStop(f > 6 ? 6 : f);
	}

	function updateScroll() {
		scroll = Math.min(scroll + 0.05 * Timer.tmod, 1);
		root._x = (1 - scroll) * Cs.mcw;

		pad.x += 3;
		pad.updatePos();

		if (scroll == 1) {
			shotView.parent.visible = false;
			initIntro();
		}
	}

	// INIT
	function initIntro() {
		step = Intro;

		mcTitle = dm.add(new TitleLevel("NIVEAU " + (lvl + 1)), DP_INTER);
		mcTitle._y = -60;
		mcTitle.timer = 30;
	}

	function updateIntro() {
		mcTitle._y = Math.min(mcTitle._y + 10, 10);

		sides[0].prevFrame();
		if (sides[0].cur == 1 && mcTitle._y == 10) {
			initPlay();
			var cx = Cs.mcw * 0.5;
			var cy = mcTitle._y + 25;
			for (i in 0...64) {
				var p = new Phys(dm.attach("light", DP_INTER));
				p.x = Seed.randVfx() * Cs.mcw;
				p.y = mcTitle._y + Seed.randVfx() * 50;
				var dx = p.x - cx;
				var dy = p.y - cy;
				var a = Math.atan2(dy, dx);
				var dist = Math.sqrt(dx * dx + dy * dy);
				var sp = dist * 0.1;
				p.vx = Math.cos(a) * sp;
				p.vy = Math.sin(a) * sp;
				p.timer = 10 + Seed.randVfx() * 10;
				p.frict = 0.9;
			}
		}
	}

	// PLAY
	function initPlay() {
		step = Play;
		var b = newBall();
		var rnd = (Seed.rand() * 2 - 1);
		b.gluePoint = rnd * 20;
		b.moveTo(pad.x, pad.y);
		b.vx = 0;
		b.vy = 1;
		b.update();
		b.colPad(rnd);

		levelTimer = 0;
		autoLaunchTimer = 0;
		flSafe = lvl == 0;
	}

	function updatePlay() {
		levelTimer += Timer.tmod;
		autoLaunchTimer += Timer.tmod;
		if (autoLaunchTimer > 200) {
			autoLaunchTimer = 0;
			for (b in balls)
				b.gluePoint = null;
		}

		// BALL ACCELERATION
		var mult = 1.0;
		if (lvl >= 5)
			mult = (lvl - 3) * 0.5;
		accTimer += mult * Timer.tmod;
		if (accTimer > Cs.TEMPO) {
			for (b in balls)
				b.setSpeed(b.speed + 0.5);
			accTimer = 0;
		}

		if (flDoor)
			checkEnd();
		if (mcTitle != null) {
			mcTitle.timer -= Timer.tmod;
			if (mcTitle.timer < 0) {
				mcTitle._y -= (11 - mcTitle._y);
				if (mcTitle._y < -60) {
					mcTitle.removeMovieClip();
					mcTitle = null;
				}
			}
		}
		Sprite.updateAll();

		// (an event killed during the loop makes it skip the next one, like the original)
		var i = 0;
		while (i < events.length) {
			events[i].update();
			i++;
		}
	}

	public function removeBlock() {
		block--;
		var c = block / blockTotal;
		if (!flDoor && c < Cs.DOOR_COEF)
			openDoor();
	}

	function openDoor() {
		var mc = sides[1];
		flDoor = true;
		mc.play();
	}

	function checkEnd() {
		if (pad.x >= Cs.mcw - (pad.ray + Cs.SIDE - 1)) {
			while (balls.length > 0)
				balls.pop().kill();
			while (options.length > 0)
				options.pop().kill();
			while (events.length > 0)
				events[0].kill();
			pad.flGo = true;
		}
	}

	public function leaveLevel() {
		lvl++;
		takeScreenshot();
		sides[0].gotoAndStop(10);
		sides[1].gotoAndStop(1);
		pad.x = pad.ray;
		pad.updatePos();

		initScroll(0);
		// everything jumped (the level scrolled back to the right, the pad to the left): no interpolation from the
		// previous frame, which showed the new level in place for a moment
		root.updateState();
	}

	// mcScreenshot.bmp.draw(root): the level left, scrolled out on the left during the scroll
	function takeScreenshot() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var view = shotView.parent;
		view.visible = false;
		var px = root.position.x, py = root.position.y;
		root.position.set(0, 0);
		renderer.render(root, {renderTexture: shot, clear: true, transform: new Matrix(K, 0, 0, K, 0, 0)});
		root.position.set(px, py);
		view.visible = true;
	}

	// GAME OVER
	public function initGameOver() {
		step = GameOver;
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			lvl: lvl,
			blocks: blocks.length
		};
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	function updateGameOver() {}

	public function addScore(n:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	// OPTIONS
	public function newOption(?t:Int, ?x:Float, ?y:Float) {
		if (x == null)
			x = pad.x;
		if (y == null)
			y = pad.y - 60;
		var opt = new Option(dm.add(new Option.OptionSkin(), DP_OPTION));
		opt.x = x;
		opt.y = y;
		opt.setType(t);
	}

	public function getOption(id:Int) {
		switch (id) {
			case 0: // A IMANT
				pad.setType(Cs.PAD_AIMANT);

			case 1: // B LINDAGE
				for (bl in blocks)
					if (bl.type < 5)
						bl.setLife(bl.life + 2);

			case 2: // C OLLE
				pad.setType(Cs.PAD_GLUE);

			case 3: // D IMINUTION
				pad.setRay(Math.max(pad.ray - 15, Pad.SIDE + 1));
				pad.powerUp();

			case 4: // E XTENSION
				pad.setRay(Math.min(pad.ray + 15, 80));
				pad.powerUp();

			case 5: // F LAMME
				for (b in balls)
					b.setType(Cs.BALL_FIRE);

			case 6: // G LACE
				for (b in balls)
					b.setType(Cs.BALL_ICE);

			case 7: // HALO
				for (b in balls)
					b.setType(Cs.BALL_HALO);

			case 8: // I NVERSION
				pad.moveFactor *= -1;

			case 9: // J AVELOT
				new alphabounce.ev.Javelot();

			case 10: // K AMIKAZE
				for (b in balls)
					b.setType(Cs.BALL_KAMIKAZE);

			case 11: // L ASER
				pad.setType(Cs.PAD_LASER);

			case 12: // M ULTI-BALL
				var list = balls.copy();
				for (b in list) {
					if (balls.length >= Cs.MAX_BALL)
						break;
					if (b.type != Cs.BALL_SHADE) {
						var ball = b.clone();
						var a = Cs.atan2(b.vy, b.vx);
						var ma = 0.15;
						ball.vx = Cs.cos(a + ma) * ball.speed;
						ball.vy = Cs.sin(a + ma) * ball.speed;
						b.vx = Cs.cos(a - ma) * b.speed;
						b.vy = Cs.sin(a - ma) * b.speed;
					}
				};

			case 13: // N ERVEUX
				pad.setType(Cs.PAD_SHAKE);

			case 14: // O UVRE
				if (!flDoor)
					openDoor();

			case 15: // P ROTECTION
				pad.setType(Cs.PAD_PROTECTION);

			case 16: // Q UASAR
				new alphabounce.ev.Quasar();

			case 17: // R LENTISSEMENT
				for (b in balls)
					b.setSpeed(Math.max(b.speed - 5, 3));

			case 18: // S AUVETAGE ACTIF
				levelTimer = 0;
				flSafe = true;

			case 19: // T EMPORALITE
				pad.setType(Cs.PAD_TIME);

			case 20: // U NIFICATION
				new alphabounce.ev.Unification();

			case 21: // V AGUE
				new alphabounce.ev.Wave();

			case 22: // W HISKY
				for (b in balls)
					b.setType(Cs.BALL_DRUNK);

			case 23: // X ENOPHOBIE
				for (b in balls)
					b.setType(Cs.BALL_STANDARD);

			case 24: // Y OYO
				for (b in balls)
					b.setType(Cs.BALL_YOYO);

			case 25: // Z ELE
				for (b in balls)
					b.setSpeed(b.speed + 5);
		}

		// TITLE
		newTitle(id, false);
	}

	// GRID
	function initGrid() {
		grid = [];
		for (x in 0...Cs.XMAX) {
			grid[x] = [];
			for (y in 0...Cs.YMAX) {
				grid[x][y] = null;
			}
		}
	}

	function fillGrid() {
		bdm.clear(0);
		bdm.clear(1);
		genPalette();

		var to = 0;
		while (true) {
			genModel();
			var bl = 0;
			for (x in 0...Cs.XMAX) {
				for (y in 0...Cs.YMAX) {
					if (mget(x, y) != null)
						bl++;
				}
			}
			if (to++ > 10 || bl > 20 + lvl * 25)
				break;
		}

		block = 0;
		blocks = [];
		for (y in 0...Cs.YMAX) {
			for (x in 0...Cs.XMAX) {
				var type = mget(x, y);
				if (type != null) {
					new Block(x, y, type);
				}
			}
		}
		blockTotal = block;
	}

	// model[x][y] (undefined out of the arrays)
	inline function mget(x:Int, y:Int):Null<Int> {
		var col = x >= 0 && x < model.length ? model[x] : null;
		return col == null || y < 0 || y >= col.length ? null : col[y];
	}

	public function getBlock(x:Int, y:Int):Block {
		if (x < 0 || x >= Cs.XMAX || y < 0 || y >= Cs.YMAX)
			return null;
		return grid[x][y];
	}

	public function hit(px:Int, py:Int, btype:Int, damage:Float) {
		var bl = getBlock(px, py);
		if (bl != null)
			bl.damage(btype, damage);
	}

	// LEVEL
	public function paint(x:Int, y:Int):Int {
		return bmpPaint[y * Cs.XMAX + x];
	}

	// colours of the blocks: 16 spots of colour (mcBrush, a disc of 100 px drawn x0.1, alpha 40, added)
	function genPalette() {
		var skin = Cs.SKIN[0];
		bmpPaint = [for (i in 0...Cs.XMAX * Cs.YMAX) skin.back];
		var ma = -2;
		for (i in 0...16) {
			var cx = ma + Seed.randomVfx(Cs.XMAX - 2 * ma);
			var cy = ma + Seed.randomVfx(Cs.YMAX - 2 * ma);
			var r = skin.br + Seed.randomVfx(skin.rr);
			var g = skin.bg + Seed.randomVfx(skin.rg);
			var b = skin.bb + Seed.randomVfx(skin.rb);
			for (y in 0...Cs.YMAX) {
				for (x in 0...Cs.XMAX) {
					var dx = x + 0.5 - cx, dy = y + 0.5 - cy;
					var dd = Math.sqrt(dx * dx + dy * dy);
					if (dd > 5)
						continue;
					// the spot fades out towards its edge (like the Flash game)
					var w = 40 / 255 * (1 - dd / 5);
					var k = y * Cs.XMAX + x;
					var c = bmpPaint[k];
					var nr = Std.int(Math.min(255, ((c >> 16) & 255) + r * w));
					var ng = Std.int(Math.min(255, ((c >> 8) & 255) + g * w));
					var nb = Std.int(Math.min(255, (c & 255) + b * w));
					bmpPaint[k] = (nr << 16) | (ng << 8) | nb;
				}
			}
		}
	}

	function genModel() {
		// PARAMS
		var flMirror = Seed.random(2) == 0;
		var flMirrorPalette = Seed.random(2) == 0 && flMirror;

		// MASSE: squares (mcShape, 100 x 100, drawn x0.05 to x0.075, turned) in a bitmap of the grid: a pixel fully
		// covered by one of them is red
		var full = [for (i in 0...Cs.XMAX * Cs.YMAX) false];
		var sc = 0.05;
		var ma = -2;
		var max = Std.int(3 + Math.pow(lvl, 2));
		for (i in 0...max) {
			var rot = Seed.rand() * 6.28;
			var scc = (sc * (1 + Seed.rand() * 0.5));
			var tx = ma + Seed.random(Cs.XMAX - 2 * ma);
			var ty = ma + Seed.random(Cs.YMAX - 2 * ma);
			var h = 50 * scc;
			var ca = Cs.cos(rot), sa = Cs.sin(rot);
			var x0 = Std.int(Math.max(0, Math.floor(tx - h * 1.5)));
			var x1 = Std.int(Math.min(Cs.XMAX - 1, Math.ceil(tx + h * 1.5)));
			var y0 = Std.int(Math.max(0, Math.floor(ty - h * 1.5)));
			var y1 = Std.int(Math.min(Cs.YMAX - 1, Math.ceil(ty + h * 1.5)));
			for (y in y0...y1 + 1) {
				for (x in x0...x1 + 1) {
					var inside = true;
					// 4 x 4 samples of the pixel (anti-aliasing of the Flash player)
					for (s in 0...16) {
						var sx = x + ((s & 3) + 0.5) / 4 - tx;
						var sy = y + ((s >> 2) + 0.5) / 4 - ty;
						var lx = sx * ca + sy * sa;
						var ly = -sx * sa + sy * ca;
						if (Math.abs(lx) > h || Math.abs(ly) > h) {
							inside = false;
							break;
						}
					}
					if (inside)
						full[y * Cs.XMAX + x] = true;
				}
			}
		}

		// FILL
		model = [];
		var ymax = Std.int(Math.min(11 + lvl, Cs.YMAX - 5));
		for (x in 0...Cs.XMAX) {
			model[x] = [];
			for (y in 0...ymax) {
				if (full[y * Cs.XMAX + x])
					model[x][y] = 0;
			}
		}

		// LINE
		for (i in 0...lvl) {
			var lim = 4;
			var y = lim + Seed.random(ymax - lim);
			for (x in 0...Cs.XMAX) {
				var m = mget(x, y);
				if (m != null && m < 5)
					model[x][y] = m + 1;
			}
		}

		// DIG
		while (lvl >= 0 && Seed.random(2) == 0) {
			var m = 3;
			var di = Seed.random(4);
			var sx = m + Seed.random(Cs.XMAX - (2 * m));
			var sy = m + Seed.random(Cs.YMAX - (2 * m));
			while (true) {
				var bl = mget(sx, sy);
				if (bl != null) {
					model[sx][sy] = null;
					var d = Cs.DIR[di];
					sx += d[0];
					sy += d[1];
					if (Seed.random(4) == 0) {
						di = Std.int(Num.sMod(di + (Seed.random(2) * 2 - 1), 4));
					}
				} else {
					break;
				}
			}
		}

		// BORDER
		if (lvl > 0) {
			for (x in 0...Cs.XMAX) {
				for (y in 0...ymax) {
					var m = mget(x, y);
					if (m != null && m < 5) {
						for (d in Cs.DIR) {
							var nx = x + d[0];
							var ny = y + d[1];
							if (nx >= 0 && nx < Cs.XMAX && ny >= 0 && ny < ymax + 1 && mget(nx, ny) == null) {
								model[x][y] = m + 1;
								break;
							}
						}
					}
				}
			}
		}

		// END MALUS
		if (lvl > 5) {
			for (i in 0...(lvl - 5)) {
				for (x in 0...Cs.XMAX) {
					for (y in 0...ymax) {
						var m = mget(x, y);
						if (m != null && m < 5)
							model[x][y] = m + 1;
					}
				}
			}
		}

		// BLOCK BALL
		while (lvl >= 1 && Seed.random(3) == 0) {
			var x = Seed.random(Cs.XMAX);
			var y = Seed.random(5);
			model[x][y] = 13;
		}

		// BONUS
		var n = 1;
		while (Seed.random(n++) == 0)
			genBonusBlock(ymax);

		// MIRROR
		if (flMirror) {
			var mx = Std.int(Cs.XMAX * 0.5);
			for (x in 0...mx) {
				var nx = Cs.XMAX - (x + 1);
				model[nx] = model[x].copy();
				if (flMirrorPalette) {
					for (y in 0...Cs.YMAX)
						bmpPaint[y * Cs.XMAX + nx] = bmpPaint[y * Cs.XMAX + x];
				}
			}
		}
	}

	function genBonusBlock(ymax:Int) {
		var max = Std.int(Math.min(2 + lvl, 4));

		var mx = 1 + Seed.random(max);
		var my = 1 + Seed.random(max);
		var sx = Seed.random(Cs.XMAX - mx);
		var sy = Seed.random(ymax - my);
		var po = 0;
		if (Seed.random(Std.int(Math.pow(mx + my + 1, 2))) == 0)
			po = 1;
		if (Seed.random(Std.int(Math.pow(mx + my + 1, 3))) == 0)
			po = 2;

		for (x in 0...mx) {
			for (y in 0...my) {
				model[sx + x][sy + y] = 10 + po;
			}
		}
	}

	// TITLES (id of an option, 26 = "SAUVETAGE !")
	public function newTitle(id:Int, flBlink:Bool) {
		var mc = dm.add(new Title(id, flBlink), DP_INTER);
		mc.bl = 100;
		mc.t = 30;
		titles.unshift(mc);
	}

	function updateTitle() {
		var i = 0;
		while (i < titles.length) {
			var mc = titles[i];
			mc.advance();
			mc.t -= Timer.tmod;
			if (i == 0 && mc.t > 0) {
				mc.bl *= 0.5;
				if (mc.bl < 0.5)
					mc.bl = 0;
			} else {
				mc.bl += 20;
				if (mc.bl > 100) {
					mc.removeMovieClip();
					titles.splice(i--, 1);
				}
			}
			mc.setBlur(mc.bl);
			i++;
		}
	}

	// LISTENERS
	function mouseDown() {
		autoLaunchTimer = 0;
		if (mcTitle != null)
			mcTitle.timer = 0;
		pad.action();
		flPress = true;
		flClick = true;
	}

	function mouseUp() {
		pad.release();
		flPress = false;
	}

	function mouseMove() {
		pad.flMouse = true;
	}

	// PLASMA: a bitmap of 90 x 90 shown x3.33 in the original, added: blurred and faded at each frame. Here at twice
	// its resolution (PR), the blur too: the same trails, without the big pixels.
	static inline var PR = 2;

	function initPlasma() {
		plasma = new PlasmaLayer(Std.int(Cs.mcw * Cs.PQ * PR), Std.int(Cs.mch * Cs.PQ * PR), 2 * PR, true);
		var mc = dm.empty(DP_PLASMA);
		plasma.view.scale.set(1 / (Cs.PQ * PR));
		mc.addChild(plasma.view);
	}

	function updatePlasma() {
		var bl = Math.max(2, Timer.tmod * 4 * Cs.PQ);
		// (alpha -2 per frame at the 40 frames per second of the SWF: -3 at the 32 of KadoKadeo, about the same per second)
		plasma.step(bl * PR, [1, 1, 1, 1], [0, 0, 0, -3], 0);
	}

	// BitmapData.draw(mc) into the plasma, with the transform and alpha of mc
	public function plasmaDraw(mc:ASprite) {
		// the state shown at the start of the coming frames: the balls are drawn between their previous and their
		// new position, the trail must not go past them
		var st = mc._prevState != null ? mc._prevState : mc._curState;
		var cos = Math.cos(st.rotation), sin = Math.sin(st.rotation);
		var q = Cs.PQ * PR;
		pm.a = cos * st.xscale * q;
		pm.b = sin * st.xscale * q;
		pm.c = -sin * st.yscale * q;
		pm.d = cos * st.yscale * q;
		pm.tx = st.x * q;
		pm.ty = st.y * q;
		plasma.draw(mc, pm, st.alpha * TRAIL_ALPHA, mc.blendMode);
	}

	// Trail of a ball (plasmaDraw(root) of the original, once per frame): a fast ball is stamped every 4 px from where
	// it was stamped last (a line, not dots), at the position shown at the start of the coming frames (the trail stays
	// behind the ball shown); a bit lighter than the original, whose trail hid the ball
	static inline var TRAIL_ALPHA = 0.6;

	public function ballTrail(b:Ball) {
		var mc = b.root;
		var st = mc._prevState != null ? mc._prevState : mc._curState;
		var x1 = st.x, y1 = st.y;
		var n = 1;
		var x0 = x1, y0 = y1;
		if (b.trailX != null) {
			var dx = x1 - b.trailX, dy = y1 - b.trailY;
			var d = Math.sqrt(dx * dx + dy * dy);
			if (d < 60) {
				x0 = b.trailX;
				y0 = b.trailY;
				n = Std.int(Math.max(1, Math.min(15, Math.ceil(d / 4))));
			}
		}
		var cos = Math.cos(st.rotation), sin = Math.sin(st.rotation);
		var q = Cs.PQ * PR;
		for (i in 1...n + 1) {
			var t = i / n;
			pm.a = cos * st.xscale * q;
			pm.b = sin * st.xscale * q;
			pm.c = -sin * st.yscale * q;
			pm.d = cos * st.yscale * q;
			pm.tx = (x0 + (x1 - x0) * t) * q;
			pm.ty = (y0 + (y1 - y0) * t) * q;
			plasma.draw(mc, pm, st.alpha * TRAIL_ALPHA, mc.blendMode);
		}
		b.trailX = x1;
		b.trailY = y1;
	}

	public function displayScore(x:Float, y:Float, sc:Int, ?col:Null<Int>, ?size:Null<Float>) {
		if (col == null)
			col = 0x222288;
		if (size == null)
			size = 1;

		var mc = dm.add(new GlyphText(Std.string(sc), "scoreGlyph", Data.SCORE_CHARS, Data.SCORE_ADV, Data.SCORE_FIELD, col), DP_PARTS);
		var psc = new Phys(mc);
		psc.x = x;
		psc.y = y;
		psc.vy = -0.5;
		psc.timer = 30;
		psc.fadeLimit = 5;
		psc.fadeType = 0;
		psc.setScale(100 * size);
	}

	// TOOLS
	public function newBall() {
		var ball = new Ball(dm.add(new Ball.BallSkin(), DP_BALL));
		return ball;
	}

	public function isFree(px:Int, py:Int) {
		if (px < 0 || px >= Cs.XMAX || py < 0)
			return false;
		return py >= Cs.YMAX || grid[px][py] == null;
	}

	public function getLowestBall() {
		var ball:Ball = null;
		for (b in balls) {
			if (ball == null || (b.flUp && b.y > ball.y)) {
				ball = b;
			}
		}
		return ball;
	}

	// The first use of a shader compiles it on the graphics card (tens of ms of freeze): the blur of the titles, the
	// mask of the options, tinted and added sprites are drawn once now, off screen.
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		s.tint = 0x4E8114;
		s.filters = [new BlurFilter()];
		holder.addChild(s);
		var add = new PixiSprite(Texture.WHITE);
		add.blendMode = BlendModes.ADD;
		holder.addChild(add);
		var masked = new PixiSprite(Texture.WHITE);
		var mask = new Graphics();
		mask.beginFill(0xFFFFFF);
		mask.drawRect(0, 0, 8, 8);
		mask.endFill();
		holder.addChild(mask);
		masked.mask = mask;
		holder.addChild(masked);
		var rt:RenderTexture = (cast RenderTexture : Dynamic).create({width: 32, height: 32});
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
		if (plasma != null) {
			plasma.destroy();
			plasma = null;
		}
		if (shot != null) {
			shot.destroy(true);
			shot = null;
		}
		Sprite.clearAll();
		mcs = [];
	}
}

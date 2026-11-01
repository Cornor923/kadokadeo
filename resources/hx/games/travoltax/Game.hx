package travoltax;

import haxe.io.UInt16Array;
import pixi.core.Pixi.BlendModes;
import pixi.filters.colormatrix.ColorMatrixFilter;
import common_haxe_avm1.KKApi;
import common_haxe_avm1.display.ASprite;
import kado.KadoKadeoManager;
import kado.Seed;
import mt.DepthManager;
import pixi.core.math.Matrix;
import pixi.core.math.shapes.Rectangle;
import pixi.core.text.Text;
import pixi.core.textures.RenderTexture;
import pixi.filters.blur.BlurFilter;
import travoltax.Common.Cs;
import travoltax.Common.Step;
import mt.bumdum.Lib;
import mt.bumdum.Sprite;
import mt.bumdum.Phys;
import mt.bumdum.Part;
import mt.bumdum.Plasma;
import kado.TouchControlsConfig.TouchControlsMode;
import kado.TouchControlsConfig.TouchButtonShape;
import common_haxe_avm1.KeyboardManager;

class LineSprite extends ASprite {
	public var bmp:RenderTexture;
	public var sleep:Float;
	public var speed:Float;
	public var ty:Int;
	public var explodeTimer:Float;
	public var special:Array<Array<Int>>;
}

class OptionSlotSprite extends ASprite {
	public var id:Int;
	public var field:Text;
	public var bg:ASprite;
}

class ContratSprite extends ASprite {
	public var field:Text;
	public var bg:ASprite;
	public var id:Int;
}

class BgSprite extends ASprite {
	public var cdm:DepthManager;
	public var odm:DepthManager;
	public var nextList:Array<Piece>;
	public var optList:Array<OptionSlotSprite>;
}

@:expose('GameTravoltax')
class Game implements kado.GameInterface {
	// mobile: move left / right at the bottom corners, turn left (V) / right (Space) above them, drop (down) in the middle,
	// the bonus (up) above it
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
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "turnleft",
				label: "↺",
				leftPx: 20,
				bottomPx: 90,
				size: 60,
				keyCode: KeyboardManager.V,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "turnright",
				label: "↻",
				rightPx: 20,
				bottomPx: 90,
				size: 60,
				keyCode: KeyboardManager.SPACE,
				shape: TouchButtonShape.SQUARE,
			},
			// centred at the bottom of the screen
			{
				id: "down",
				label: "▼",
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.DOWN,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "bonus",
				label: "▲",
				bottomPx: 90,
				size: 60,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	public static var FL_DEBUG = false;

	public static var DP_BG = 0;
	public static var DP_PLASMA = 1;
	public static var DP_LINES = 3;
	public static var DP_PIECE = 4;
	public static var DP_BOARD = 5;
	public static var DP_QUEUE = 7;
	public static var DP_PARTS = 8;
	public static var DP_FG = 10;
	public static var DP_INTER = 12;

	public var flInverse:Bool;
	public var rainbowCoef:Float;
	public var speed:Float;
	public var playTimerMax:Float;
	public var levelTimer:Float;

	public var board:RenderTexture;
	public var plasma:Plasma;
	public var grid:Array<Array<Int>>;

	var lines:Array<LineSprite>;

	public var pieceList:Array<Array<Array<Int>>>;
	public var contrats:Array<ContratSprite>;
	public var options:Array<Option>;
	public var currentOption:Option;

	var brushSquare:ASprite;
	var achievementStartFrame:Int;

	public var step:Step;
	public var piece:Piece;

	public static var me:Game;

	public var dm:DepthManager;
	public var root:ASprite;
	public var bg:BgSprite;
	public var stats:{
		_o:Array<Int>,
		_l:Array<Int>,
		_g:Array<Int>,
		_c:Array<Int>, // contracts
		_t:Int, // time (in frames) survived to 7 blocks in line 17 (index 5)
		_cc:Int, // clear grid count
	};

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayKeys = new UInt16Array(13);
		replayKeys[0] = common_haxe_avm1.KeyboardManager.LEFT;
		replayKeys[1] = common_haxe_avm1.KeyboardManager.RIGHT;
		replayKeys[2] = common_haxe_avm1.KeyboardManager.DOWN;
		replayKeys[3] = common_haxe_avm1.KeyboardManager.UP;
		replayKeys[4] = common_haxe_avm1.KeyboardManager.SPACE;
		replayKeys[5] = common_haxe_avm1.KeyboardManager.B;
		replayKeys[6] = common_haxe_avm1.KeyboardManager.V;
		replayKeys[7] = common_haxe_avm1.KeyboardManager.Q;
		replayKeys[8] = common_haxe_avm1.KeyboardManager.A;
		replayKeys[9] = common_haxe_avm1.KeyboardManager.D;
		replayKeys[10] = common_haxe_avm1.KeyboardManager.S;
		replayKeys[11] = common_haxe_avm1.KeyboardManager.Z;
		replayKeys[12] = common_haxe_avm1.KeyboardManager.W;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
		});

		me = this;
		this.root = root;
		Cs.MX = (Cs.mcw - Cs.XMAX * Cs.SIZE) * 0.5;
		Cs.MY = Cs.mch - Cs.YMAX * Cs.SIZE;
		dm = new DepthManager(root);

		speed = 0.05;
		playTimerMax = 30;
		levelTimer = 0;
		options = [];
		contrats = [];
		stats = {
			_o: [],
			_l: [],
			_g: [0, 0, 0],
			_c: [],
			_t: null,
			_cc: 0,
		};

		initBg();
		initGrid();
		initPlay();
		initPlasma();

		rainbowCoef = 0;
	}

	function initBg() {
		var mc = dm.attach("mcBg", DP_BG);
		bg = cast dm.attach("mcFg", DP_FG);
		var cadreNext = bg.createEmptyMovieClip();

		var mask = cadreNext.getGraphics();
		mask.beginFill(0xffffff);
		mask.drawRect(-KadoKadeoManager.I(60), -KadoKadeoManager.I(25), KadoKadeoManager.I(55), KadoKadeoManager.I(50));
		mask.endFill();
		cadreNext.mask = mask;

		cadreNext._x = KadoKadeoManager.I(67);
		cadreNext._y = KadoKadeoManager.I(32);
		bg.cdm = new DepthManager(cadreNext);
		var cadreOpts = bg.createEmptyMovieClip();
		bg.odm = new DepthManager(cadreOpts);
		cadreOpts._y = KadoKadeoManager.I(65);
		bg.nextList = [];
		bg.optList = [];

		// addOpt(0);
		// addOpt(12);
		// addOpt(1);
		// addOpt(13);
		// addOpt(3);
		// addOpt(10);
		// addOpt(11);
		// addOpt(14);
		// addOpt(2);
		// addOpt(6);
		// addOpt(7);
		// addOpt(8);
		// addOpt(9);

		// addOpt(6);
		// addOpt(7);
		// addOpt(5);
		// addOpt(4);
		// addOpt(4);
		// addOpt(2);
		// addOpt(3);
		// addOpt(10);
		// addOpt(15);
		// addOpt(16);
		// addContrat(4);

		// for (i in 0...Cs.CONTRAT_MAX)
		// if (Std.random(20) == 0)
		// addContrat(i);
	}

	// UPDATE
	public function update(delta:Float):Void {
		// trace(mt.Timer.tmod);

		// for( i in 0...500000 )50.2514*465.9;

		rainbowCoef += 0.01 * mt.Timer.tmod;
		levelTimer += mt.Timer.tmod;
		if (levelTimer > 500) {
			speed = speed + 0.05;
			levelTimer = 0;
			if (speed > 0.5) {
				playTimerMax *= 0.92;
			}
		}

		updatePlasma();

		switch (step) {
			case Play:
				updatePlay();
			case Fall:
				updateFall();
			case _:
		}

		updateNextPieces();
		updateOptionSlots();
		updateOptions();
		Sprite.updateAll();
	}

	function updateOptions() {
		var list = options.copy();
		for (opt in list)
			opt.update();
	}

	// PLAY
	public function initPlay() {
		if (piece == null) {
			piece = getNextPiece();
			piece.setPos(5, 2);
			Filt.glow(piece.root, 6, 2, 0xFFFFFF);
			if (!piece.isFree(piece.px, piece.py)) {
				piece.kill();
				initGameOver();
			}
		}
		step = Play;

		// check if line 18 is filled for achievement
		if (achievementStartFrame == null && grid[5].filter(function(cell) return cell != null).length >= 7) {
			achievementStartFrame = KadoKadeoManager.kkm.replay.getCurrentFrame();
		}
		if (grid[Cs.YMAX - 1].filter(function(cell) return cell != null).length == 0) {
			stats._cc += 1;
		}
	}

	function updatePlay() {}

	// FALL
	public function checkLines() {
		var sl = [];
		lines = [];
		var fall = 0;
		var scn = 0;
		for (py in 0...Cs.YMAX) {
			var y = (Cs.YMAX - (py + 1));
			var flFull = true;
			var flOk = false;
			for (x in 0...Cs.XMAX) {
				if (grid[y][x] == null) {
					flFull = false;
				} else {
					flOk = true;
				}
			}
			// BREAK LINE
			if (flFull) {
				var line = getLine(y);
				line.sleep = fall;
				line.explodeTimer = 0;
				fall++;
				scn++;
				sl.push(y);
				if (contrats[py] != null)
					validateContrat(py);
				line.special = [];
				for (x in 0...grid[y].length) {
					var n = grid[y][x];
					if (n > 0)
						line.special.push([n, x]);
				}
			} else if (flOk && fall > 0) {
				var line = getLine(y);
				// line.sleep = fall*2 + 5 + py*2;
				line.speed = KadoKadeoManager.I(5);
				line.ty = y + fall;
			} else if (!flOk) {
				fall++;
				sl.push(y);
			}
		}

		if (scn > 0) {
			for (o in options)
				o.onLine();
			stats._l.push(scn);
			KadoKadeoManager.kkm.addScore(Cs.getLineScore(scn));
		}

		for (y in sl)
			grid.splice(y, 1);
		for (y in sl)
			grid.unshift([]);

		if (lines.length > 0)
			initFall();
		else
			initPlay();
	}

	public function initFall() {
		step = Fall;
	}

	function updateFall() {
		var flFall = true;
		var i = 0;
		while (i < lines.length) {
			var mc = lines[i];
			if (mc.explodeTimer != null) {
				if (mc.sleep > 0) {
					mc.sleep -= mt.Timer.tmod;
				} else {
					mc.explodeTimer += mt.Timer.tmod;
					var c = mc.explodeTimer / 6;
					var max = 3;
					if (c < 1) {
						Col.setPercentColor(mc, c * 120, 0xFFFFFF);
					} else {
						var max = 24;
						for (a in mc.special) {
							var x = Cs.MX + (a[1] + 0.5) * Cs.SIZE;
							var y = mc._y + Cs.SIZE * 0.5;
							switch (a[0]) {
								case 1:
									launchOpt(x, y);
								case 2:
									getBonus(0, x, y);
								case 3:
									getBonus(1, x, y);
								case 4:
									getBonus(2, x, y);
							}
						}
						// CLEAN
						mc.bmp.destroy();
						mc.removeMovieClip();
						lines.splice(i--, 1);
					}

					for (i in 0...max) {
						var p = new Part(dm.attach("partPix", DP_PARTS));
						p.x = Cs.MX + Seed.randVfx() * (Cs.XMAX * Cs.SIZE);
						p.y = mc._y; // + Cs.SIZE*0.5;
						p.weight = -KadoKadeoManager.S(0.5 + Seed.randVfx());
						p.timer = 10 + Seed.randVfx();
						p.bhl = [BhVertiLine];
						p.coef = 1;
					}
				}
				flFall = false;
			} else if (flFall) {
				var lim = Cs.MY + mc.ty * Cs.SIZE;
				mc._y = Math.min(mc._y + mc.speed * mt.Timer.tmod, lim);
				if (mc._y == lim) {
					board.copyPixels(mc.bmp, new Rectangle(0, 0, mc.bmp.width, mc.bmp.height), new pixi.core.math.Point.Point(0, mc.ty * Cs.SIZE));
					mc.bmp.destroy();
					mc.removeMovieClip();
					mc = null;
					lines.splice(i--, 1);
				}
			}
			if (mc != null && mc.bmp != null && mc.bmp.baseTexture != null) {
				drawRainbowShade(mc);
			}
			i++;
		}
		if (lines.length == 0)
			initPlay();
	}

	function getBonus(id, x, y) {
		var score = Cs.SCORE_BONUS[id];
		KadoKadeoManager.kkm.addScore(score);
		stats._g[id]++;

		// FX
		var p = new Phys(Game.me.dm.empty(DP_INTER));
		p.x = x;
		p.y = y;
		p.vy = -KadoKadeoManager.I(3);
		p.frict = 0.9;
		p.timer = 30;
		var field = p.root.initTextField('field', {
			font: 'Arial',
			size: 30,
			color: 0xFFFFFF,
			align: 'center',
			stroke: ["#25A73F", "#0089C4", "#F9179F"][id],
			strokeThickness: KadoKadeoManager.I(2),
		});
		field.text = Std.string(KKApi.val(score));
	}

	// GAMEOVER
	function initGameOver() {
		step = GameOver;
		if (achievementStartFrame != null) {
			stats._t = KadoKadeoManager.kkm.replay.getCurrentFrame() - achievementStartFrame;
		} else {
			stats._t = 0;
		}

		KadoKadeoManager.kkm.gameOver(stats);
		if (piece != null) {
			piece.explode();
		}
	}

	function updateGameOver() {}

	// INTERFACE
	function getNextPiece() {
		if (pieceList == null)
			pieceList = [];
		while (pieceList.length < 10) {
			var index = Seed.random(Cs.PIECES.length);
			var a = Cs.PIECES[index];
			var matrix = a[0].copy();
			var color:Int = Col.objToCol(Col.getRainbow(index / Cs.PIECES.length));

			var infos = [matrix, a[1].copy(), [color]];

			for (x in 0...4) {
				for (y in 0...4) {
					var type = matrix[x * 4 + y];
					if (type == 1) {
						if (Seed.random(Cs.PROBA_OPTION) == 1)
							type = 2;
						if (Seed.random(Cs.PROBA_GREEN) == 0)
							type = 3;
						if (Seed.random(Cs.PROBA_BLUE) == 0)
							type = 4;
						if (Seed.random(Cs.PROBA_PINK) == 0)
							type = 5;
						matrix[x * 4 + y] = type;
					}
				}
			}

			pieceList.push(infos);
		}

		// DISPLAY NEXT
		for (next in bg.nextList)
			next.ty = -60;

		var next = new Piece(bg.cdm.empty(0), pieceList[1], true);
		next.ty = 0;
		next.y = KadoKadeoManager.I(40);
		next.x = -KadoKadeoManager.I(33);
		next.setScale(70);
		bg.nextList.push(next);

		return new Piece(dm.empty(Game.DP_PIECE), pieceList.shift());
	}

	function updateNextPieces() {
		var i = 0;
		while (i < bg.nextList.length) {
			var next = bg.nextList[i];
			var dy = next.ty - next.y;
			next.y += dy * 0.5 * mt.Timer.tmod;
			var fl = new BlurFilter();
			fl.blurX = 0;
			fl.blurY = Math.abs(dy);
			next.root.filters = [fl];

			if (Math.abs(dy) < 10 && next.ty != 0) {
				next.root.removeMovieClip();
				bg.nextList.splice(i--, 1);
			}
			i++;
		}
	}

	public function launchOpt(x, y) {
		var sp = new Particule(dm.empty(DP_INTER));
		sp.root.getGraphics()
			.beginFill(0xFFFFFF)
			.drawCircle(0, 0, KadoKadeoManager.I(3))
			.endFill();
		sp.speed = KadoKadeoManager.S(9 + Seed.rand() * 4);
		sp.a = 1.57 + (Seed.rand() * 2 - 1) * 0.2;
		sp.ca = 0.12 + Seed.rand() * 0.05;
		sp.lim = 0.25;
		sp.x = x;
		sp.y = y;

		sp.bhl = [4, 5];
	}

	public function addOpt(?id) {
		if (id == null)
			id = Cs.getRandomOptionId();
		var n = bg.optList.length;
		var mc:OptionSlotSprite = cast bg.odm.attach("mcOptSlot", 100);
		mc.play();
		mc.field = mc.initTextField('field', {
			font: 'Arial',
			size: 18,
			color: 0xFFFFFF,
		});
		mc.field.x = KadoKadeoManager.I(15);
		mc.field.y = KadoKadeoManager.I(0);
		mc.field.text = Cs.OPTION_INFOS[id].name;
		// mc.bg._visible = false;
		mc.id = id;
		// Filt.glow(cast mc.field, 2, 10, 0x375073);
		bg.optList.push(mc);

		while (bg.optList.length > 7)
			bg.optList.shift().removeMovieClip();

		updateOptPos();
	}

	public function updateOptPos() {
		var y = KadoKadeoManager.I(6);
		for (mc in bg.optList) {
			mc._y = y;
			y += KadoKadeoManager.I(13);
		}
	}

	public function useOpt() {
		if (bg.optList.length == 0)
			return;
		var mc = bg.optList.shift();
		var opt = Cs.getOption(mc.id);
		stats._o.push(mc.id);
		mc.removeMovieClip();
		updateOptPos();
	}

	function updateOptionSlots() {
		var mc = bg.optList[0];
		if (mc != null) {
			mc.field.style.fill = Col.objToCol(Col.getRainbow(rainbowCoef));
		}
	}

	// PLASMA
	function initPlasma() {
		var ww = Std.int(Cs.SIZE * Cs.XMAX);
		var hh = Std.int(Cs.SIZE * Cs.YMAX);
		var mc = dm.empty(DP_PLASMA);
		mc.blendMode = BlendModes.OVERLAY;
		mc._alpha = 120;
		var pq = 0.5;
		plasma = new Plasma(mc, ww, hh, pq);
		plasma.setPos(Cs.MX, Cs.MY);
		var plasmaCt = new ColorMatrixFilter();
		plasmaCt.matrix = [
			1, 0, 0, 0,        0,
			0, 1, 0, 0,        0,
			0, 0, 1, 0,        0,
			0, 0, 0, 1, -12 / 255,
		];
		plasma.ct = plasmaCt;
		var fl = new BlurFilter();
		fl.blurX = Std.int(4 * KadoKadeoManager.S(pq));
		fl.blurY = Std.int(4 * KadoKadeoManager.S(pq));
		plasma.filters = [cast fl];
	}

	function updatePlasma() {
		plasma.update();
	}

	public function drawRainbowShade(mc:ASprite, ?r:{r:Int, g:Int, b:Int}) {
		if (r == null)
			r = Col.getRainbow(rainbowCoef);

		var ct = new ColorMatrixFilter();
		ct.matrix = [
			0, 0, 0,   0,           r.r / 255, // R
			0, 0, 0,   0,           r.g / 255, // G
			0, 0, 0,   0,           r.b / 255, // B
			0, 0, 0, 0.5, 0, // A offset, maybe 0 ?
		];
		// 0, 0, 0, 0.5, -255 + mc.alpha * 255, // A offset, maybe 0 ?

		var pq = plasma.pq;
		plasma.drawMc(mc, -Cs.MX * pq, -Cs.MY * pq, ct);
	}

	// BOARD
	public function initGrid() {
		var ww = Std.int(Cs.XMAX * Cs.SIZE);
		var hh = Std.int(Cs.YMAX * Cs.SIZE);

		// BMP
		board = RenderTexture.create(ww, hh);
		var mc = dm.empty(DP_BOARD);
		mc._x = Cs.MX;
		mc._y = Cs.MY;
		mc.attachBitmap(board, 0);

		// BRUSH
		brushSquare = dm.attach("mcSquare", 0);
		// brushSquare._visible = false;

		// LOGIC
		grid = [];
		for (y in 0...Cs.YMAX) {
			grid[y] = [];
			if (y > 18) { // 18
				var hole = Seed.random(Cs.XMAX);
				for (x in 0...Cs.XMAX) {
					if (x != hole)
						addSquare(x, y);
				}
			}
		}
	}

	public function isFree(x, y) {
		return x >= 0 && x < Cs.XMAX && y >= 0 && y < Cs.YMAX && grid[y][x] == null;
	}

	public function addSquare(?sq:Square, x:Int, y:Int, ?type:Int, ?color:Int) {
		if (type == null)
			type = 0;
		if (color == null)
			color = Seed.randomVfx(0xFFFFFF);
		var flDestroy = false;
		if (sq == null) {
			sq = new Square(Game.me.dm.attach("mcSquare", 10), type, color);
			flDestroy = true;
		}
		sq.initSkin(brushSquare);
		Col.setPercentColor(brushSquare, 20, 0x98ABD4);
		// Col.setPercentColor(brushSquare.smc,20,sq.color);

		var m = new Matrix();
		m.translate(getX(x), getY(y));
		board.draw(brushSquare, m);
		if (this.grid[y] == null) {
			this.grid[y] = [];
			for (x in 0...Cs.XMAX) {
				this.grid[y][x] = null;
			}
		}
		grid[y][x] = sq.type;

		// if( y<5 && step!=GameOver )initGameOver();
		if (flDestroy)
			sq.kill();
	}

	public function destroySquare(x:Int, y:Int) {
		var mc = dm.attach("partScore", DP_PARTS);
		mc.removeOnFrame = 29;
		mc.play();
		mc._x = Cs.MX + (x + 0.5) * Cs.SIZE;
		mc._y = Cs.MY + (y + 0.5) * Cs.SIZE;
		mc._rotation = Seed.randVfx() * 360;

		for (n in 0...4) {
			var p = getPartSquare();
			var dx = (Seed.randVfx() * 2 - 1) * Cs.SIZE * 0.5;
			var dy = (Seed.randVfx() * 2 - 1) * Cs.SIZE * 0.5;
			var a = Math.atan2(dy, dx);
			var sp = Seed.randVfx() * KadoKadeoManager.I(3);
			p.x = Cs.MX + x * Cs.SIZE + dx;
			p.y = Cs.MY + y * Cs.SIZE + dy;
			p.vx = Math.cos(a) * sp;
			p.vy = Math.sin(a) * sp;
			p.updatePos();
		}

		removeSquare(x, y);
	}

	public function removeSquare(x:Int, y:Int) {
		grid[y][x] = null;
		board.clearRect(new Rectangle(x * Cs.SIZE, y * Cs.SIZE, Cs.SIZE, Cs.SIZE));
	}

	public function getLine(y) {
		var bmp = RenderTexture.create(Std.int(Cs.XMAX * Cs.SIZE), Cs.SIZE);
		var rect = new Rectangle(0, y * Cs.SIZE, Cs.XMAX * Cs.SIZE, Cs.SIZE);
		bmp.copyPixels(board, rect, new pixi.core.math.Point.Point(0, 0));
		board.clearRect(rect);

		//
		var mc:LineSprite = cast dm.empty(DP_LINES);
		mc.attachBitmap(bmp, 0);
		mc._x = Cs.MX;
		mc._y = Cs.MY + y * Cs.SIZE;
		mc.bmp = bmp;
		lines.push(mc);

		drawRainbowShade(mc);

		return mc;
	}

	// CONTRAT
	public function addContrat(id) {
		var col = Col.getRainbow(1 - (id / Cs.CONTRAT_MAX) * 0.6);
		var mc:ContratSprite = cast dm.empty(DP_INTER);
		var y = Cs.YMAX - (id + 1);
		mc._x = Cs.MX + Cs.XMAX * Cs.SIZE;
		mc._y = Cs.MY + y * Cs.SIZE;
		mc.id = id;
		mc.removeOnFrame = 11;
		mc.bg = mc.attachMovie("mcContrat", "bg", 0);
		mc.field = mc.initTextField('field', {
			font: 'Arial',
			size: 24,
			color: 0xFFFFFF,
			align: "center",
			stroke: "#000000",
			strokeThickness: 2,
		});
		mc.field.style.letterSpacing = 5;
		mc.field.x = KadoKadeoManager.I(35);
		mc.field.y = KadoKadeoManager.I(1);
		mc.field.text = Std.string(KKApi.val(Cs.getContratScore(id)));
		Col.setPercentColor(mc.bg, 100, Col.objToCol(col));

		// BANDE
		var o = cast col;
		o.a = 255;
		var n = Std.int(plasma.pq * Cs.SIZE);
		var inc = 0.5;
		plasma.fillRect(new Rectangle(0, Std.int((y - inc) * n), Cs.XMAX * n, Std.int(1 + inc * 2) * n), Col.objToCol(o), 125);

		// CONTOUR LETTRE
		var inc = -70;
		col.r = Std.int(Math.max(col.r + inc, 0));
		col.g = Std.int(Math.max(col.g + inc, 0));
		col.b = Std.int(Math.max(col.b + inc, 0));
		// Filt.glow(mc.field, KadoKadeoManager.I(2), 10, Col.objToCol(col));

		//
		contrats[id] = mc;
	}

	public function removeContrat(id) {
		var mc = contrats[id];
		if (mc != null) {
			mc.removeMovieClip();
		}
		contrats[id] = null;
	}

	public function validateContrat(id) {
		var mc = contrats[id];
		mc.bg.play();
		mc.field.text = "";
		KadoKadeoManager.kkm.addScore(Cs.getContratScore(id));
		contrats[id] = null;
		stats._c.push(id);

		for (i in 0...32) {
			var sp = new Part(dm.attach("partPix", DP_INTER));
			sp.x = mc._x + Seed.randVfx() * KadoKadeoManager.I(70);
			sp.y = mc._y + Seed.randVfx() * Cs.SIZE;
			sp.vx = (Seed.randVfx() * 2 - 1) * KadoKadeoManager.I(10);
			sp.timer = 10 + Seed.randVfx() * 10;
			sp.frict = 0.8;
			sp.bhl = [BhHoriLine];
		}
	}

	// FX
	public function getPartSquare() {
		var p = new Particule(Game.me.dm.attach("partSquare", Game.DP_PARTS));
		p.frict = 0.95;
		p.timer = 10 + Seed.randVfx() * 30;
		p.weight = KadoKadeoManager.S(0.05 + Seed.randVfx() * 0.05);
		p.setScale(100 + Seed.randVfx() * 50);
		p.fadeType = 0;
		p.bhl = [1];
		return p;
	}

	// TOOLS
	public function getX(x:Float) {
		return x * Cs.SIZE;
	}

	public function getY(y:Float) {
		return y * Cs.SIZE;
	}

	public function destroy():Void {}
}

// JACKPOT
// COL
// REVOIR LES LUCIOLES

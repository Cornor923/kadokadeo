package chocomouche;

import haxe.io.UInt16Array;
import pixi.core.renderers.webgl.filters.Filter;
import pixi.core.text.Text;
import common_haxe_avm1.KKApi;
import common_haxe_avm1.MouseManager;
import mt.bumdum.Sprite;
import mt.bumdum.Phys;
import mt.bumdum.Lib;

class AnonSprite15518839 extends ASprite {
	public var _timeLeft:ASprite;
	public var current:Int;
	public var max:Int;
}

class AnonSprite3854477 extends ASprite {
	public var _field:Text;
}

@:native("PIXI.filters.BevelFilter")
extern class BevelFilter extends Filter {
	public function new(options:Dynamic);
}

typedef Pos = {x:Int, y:Int}

enum Step {
	Play;
	Explode;
	NextLevel;
	FinishLevel;
	GameOver;
}

@:expose('GameChocoMouche')
class Game implements kado.GameInterface {
	public static var FL_DEBUG = true;

	public static var DP_BG = 0;
	public static var DP_SHADE = 1;
	public static var DP_BGPLAYS = 2;
	public static var DP_PLAYS = 3;
	public static var DP_SLOT = 4;
	public static var DP_INFOS = 5;
	public static var DP_ANIM = 6;
	public static var DP_FX = 7;

	public var step:Step;

	var timer:Float;

	public var life:Int;
	public var lives:List<ASprite>;
	public var level:Int;
	public var flGameOver:Bool;
	public var dm:mt.DepthManager;

	public var mcGrid:ASprite;
	public var gdm:mt.DepthManager;

	public var bg:ASprite;
	public var mcTime:AnonSprite15518839;
	public var mcWarning:ASprite;
	public var mcLevel:AnonSprite3854477;

	static public var me:Game;

	public var grid:Array<Array<Slot>>;
	public var left:Int;

	public var toUpdate:Array<ASprite> = [];
	public var stats:{
		d:Array<Array<Int>>, // discovered slots per level: -2 for timeout, -1 for fly, 0-8 for others
		c:Array<Int>, // clicked slots per level
		p:Array<Int>, // points per level
		t:Array<Int>, // time per level
	};

	var beginFrame:Int;
	var points:Int;

	public function new(root:ASprite) {
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			recordEvents: true,
		});

		dm = new mt.DepthManager(root);
		me = this;

		flGameOver = false;
		level = 0;
		left = 100;
		initLife(3);

		initBg();
		initTime();

		mcGrid = dm.empty(DP_SLOT);
		gdm = new mt.DepthManager(mcGrid);
		stats = {
			d: [],
			c: [],
			p: [],
			t: []
		};
		initGrid();
		step = Play;
	}

	function initBg() {
		var grid = dm.attach("bg", DP_BG);
		grid._x = 0;
		grid._y = 0;
		grid._alpha = 95;
	}

	public function isLocked() {
		return step != Play || flGameOver;
	}

	// the clicks, called by KadoKadeoManager before the stir of the frame (the first one of a level draws the bombs): the
	// live game polls the mouse and records them, the replay applies them at the same moment. Before the stir like the
	// Slot.onRelease of the replays recorded until 2026-10 (sprite callbacks run in MouseManager.beginFrame)
	public function applyInputEvents() {
		var replay = KadoKadeoManager.kkm.replay;
		if (replay.isPlayingReplay()) {
			for (event in replay.consumeEvents()) {
				applyReplayEvent(event);
			}
			return;
		}
		pollMouse();
	}

	// the slot under the mouse, the one pressed: the onRollOver / onRollOut / onPress / onRelease / onReleaseOutside of
	// the slots in Flash (a click: pressed and released on the same slot)
	var overSlot:Slot;
	var pressedSlot:Slot;

	function pollMouse() {
		var slot = slotAt(MouseManager.getX(), MouseManager.getY());
		if (slot != overSlot) {
			if (overSlot != null)
				overSlot.slotOut();
			overSlot = slot;
			if (slot != null)
				slot.slotOver();
		}
		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT)) {
			pressedSlot = slot;
			if (slot != null)
				slot.imPressed();
		}
		if (MouseManager.isButtonJustReleased(MouseManager.BUTTON_LEFT)) {
			var pressed = pressedSlot;
			pressedSlot = null;
			if (pressed != null) {
				if (pressed == slot)
					pressed.imClicked();
				else
					pressed.imReleased();
			}
		}
	}

	// the slot under the point of the game, as the hit test of the clips in Flash: the topmost one (the last created)
	// whose shapes hold it, its transparent square (0..SLOT_SIZE in its clip) or its picture (centered on the clip,
	// pressed: 92%). The pictures of the next slots cover the right / bottom half of a square: the picture shown wins
	function slotAt(x:Float, y:Float):Slot {
		if (grid == null)
			return null;
		var p = new pixi.core.math.Point(x, y);
		var half = Cs.SLOT_SIZE / 2;
		var gx = grid.length;
		while (gx-- > 0) {
			var column = grid[gx];
			var gy = column.length;
			while (gy-- > 0) {
				var s = column[gy];
				if (s == null || s.root == null || s.root.parent == null)
					continue;
				var l = s.root.toLocal(p);
				if (l.x >= 0 && l.x < Cs.SLOT_SIZE && l.y >= 0 && l.y < Cs.SLOT_SIZE)
					return s;
				var lp = s.slot.toLocal(p);
				if (lp.x >= -half && lp.x < half && lp.y >= -half && lp.y < half)
					return s;
			}
		}
		return null;
	}

	public function update(ts:Float) {
		updateSprites();

		switch (step) {
			case Play:
				if (flGameOver) {
					KadoKadeoManager.kkm.gameOver(stats);
					step = GameOver;
				}
				updateTime();
			case Explode:
				step = Play;

			case FinishLevel:
				timer -= 4 * mt.Timer.tmod;
				mcGrid._alpha = timer;
				if (timer <= 0) {
					mcGrid._alpha = Cs.GRID_ALPHA;
					timer = null;
					initNextLevel();
				}

			case NextLevel:
				timer -= 1.5 * mt.Timer.tmod;
				if (mcGrid._alpha < 100)
					mcGrid._alpha = 100 - timer;
				if (timer <= 0) {
					mcGrid._alpha = 100;
					timer = null;
					// prepareLevel() ;
					resetTime();
					step = Play;
					setNextLevel(false);
				}

			case GameOver:
		}
	}

	function applyReplayEvent(event:Dynamic) {
		if (event == null) {
			return;
		}

		var kind:Int = Reflect.field(event, "k");
		var x:Null<Int> = Reflect.field(event, "x");
		var y:Null<Int> = Reflect.field(event, "y");
		if (kind == null || x == null || y == null) {
			return;
		}

		switch (kind) {
			case 2:
				var slot = getSlot(x, y);
				if (slot != null) {
					slot.imClicked();
				}
			default:
		}
	}

	// on the frame being played: the replay applies it there, before the stir (applyInputEvents)
	public function recordSlotClick(pos:Pos) {
		var replay = KadoKadeoManager.kkm.replay;
		replay.recordEvent({k: 2, x: pos.x, y: pos.y}, replay.getCurrentFrame());
	}

	function updateSprites() {
		Sprite.updateAll();

		for (s in toUpdate) {
			if (s.parent != null)
				s.update();
		}
	}

	public function checkEnd():Bool {
		if (flGameOver)
			return true;
		if (life <= 0)
			flGameOver = true;

		return flGameOver;
	}

	public function checkLevel() {
		if (left > 0)
			return;

		finishLevel();
	}

	function finishLevel() {
		step = FinishLevel;

		for (x in grid) {
			for (s in x) {
				if (!s.isDiscovered() && s.isBomb())
					s.markMe();
			}
		}
		timer = 100;
	}

	function initNextLevel() {
		step = NextLevel;
		level++;
		getLevelBonus();
		timer = 100;
		stats.t.push(KadoKadeoManager.kkm.replay.getCurrentFrame() - beginFrame);
		stats.p.push(KadoKadeoManager.kkm.score - points);
		points = KadoKadeoManager.kkm.score;

		setNextLevel(true);
		prepareLevel();
	}

	// create new grid for level l
	public function prepareLevel(?from:Pos) {
		if (from == null) {
			initGrid();
		}

		var b = Cs.getLevelBombs(level);
		left = Cs.GRID_WIDTH * Cs.GRID_HEIGHT - b;
		while (b > 0) {
			var x = Seed.random(Cs.GRID_WIDTH);
			var y = Seed.random(Cs.GRID_HEIGHT);
			if (from != null && from.x == x && from.y == y)
				continue;
			var s = grid[x][y];
			if (!s.isBomb()) {
				s.placeBomb();
				b--;
			}
		}

		// resetTime() ;
		// step = Play ;
	}

	function initGrid() {
		if (grid != null) {
			for (x in grid) {
				for (s in x) {
					if (s == null)
						continue;
					s.kill();
				}
			}
		}
		overSlot = null;
		pressedSlot = null;

		grid = new Array();
		for (x in 0...Cs.GRID_WIDTH) {
			grid[x] = new Array();
			for (y in 0...Cs.GRID_HEIGHT) {
				grid[x][y] = new Slot({x: x, y: y}, false);
			}
		}
		setGridGlow();

		stats.d.push([]);
		stats.c.push(0);
		beginFrame = KadoKadeoManager.kkm.replay.getCurrentFrame();
	}

	public function setGridGlow() {
		mcGrid.filters = [];
		// Filt.glow(mcGrid, 1, 20, 0x232323);

		// var dcf = new DropShadowFilter({
		// 	color: 0x000000,
		// 	alpha: 0.15,
		// 	blur: 2,
		// 	distance: 2.5,
		// 	rotation: 45,
		// 	pixelSize: 3,
		// 	quality: 100,
		// });

		// mcGrid.filters.push(dcf);
	}

	// ### LIFE
	function initLife(l:Int) {
		life = l;
		lives = new List();
		for (i in 0...life) {
			var mc = dm.attach("life", DP_INFOS);
			mc._x = Cs.LIFE_X;
			mc._y = Cs.LIFE_Y - lives.length * (KadoKadeoManager.I(20) + KadoKadeoManager.I(1)); // => (life_width + ecart);
			Filt.glow(mc, 2, 3, 0xFFFFFF);
			lives.push(mc);
		}
	}

	function lifeLoss() {
		life--;

		var lifeMovieClip = lives.pop();
		if (lifeMovieClip != null) {
			var rf = dm.empty(DP_FX);
			rf._totalframes = 15;
			rf.getGraphics().beginFill(0xFF0000, 0.6);
			rf.getGraphics().drawRect(0, 0, 900, 900);
			rf._alpha = 60;
			rf.blendMode = OVERLAY;
			rf.removeOnFrame = rf._totalframes;
			rf.play();
			toUpdate.push(rf);

			for (i in 0...rf._totalframes) {
				rf.onFrame.set(i + 1, () -> {
					rf._alpha = 60 * (1 - (i / rf._totalframes));
				});
			}

			lifeMovieClip.removeMovieClip();
		}

		checkEnd();
	}

	public function getSlot(x:Int, y:Int) {
		if (x < 0 || y < 0 || x >= Cs.GRID_WIDTH || y >= Cs.GRID_HEIGHT)
			return null;
		return grid[x][y];
	}

	// POINTS

	public function getPoints(start:Int, end:Int, max:Int) {
		var c = (max - (end - start)) / max;
		var p = c * (Cs.POINTS + Cs.MULT_LEVEL * (Cs.INITIAL_TIME - max) / 32);

		addScore(KKApi.const(Std.int(p)));
	}

	public function getLevelBonus() {
		addScore(Cs.LEVEL_BONUS);
	}

	public function addScore(sc) { // pr ajouter au score du joueur
		KadoKadeoManager.kkm.addScore(sc);
	}

	// TIME
	function initTime() {
		mcTime = cast Game.me.dm.empty(Game.DP_INFOS);
		mcTime.getGraphics().beginFill(0);
		mcTime.getGraphics().drawRect(0, 0, KadoKadeoManager.I(79), KadoKadeoManager.I(5));
		mcTime._timeLeft = mcTime.attachMovie("timeLeft");
		mcTime._timeLeft._y = -KadoKadeoManager.I(1);
		mcTime._x = Cs.TIME_X;
		mcTime._y = Cs.TIME_Y + KadoKadeoManager.I(1);
		resetTime();
	}

	public function resetTime(?bomb:Bool) {
		var now = Date.now().getTime();
		if (bomb != null && !bomb)
			getPoints(0, mcTime.current, mcTime.max);

		mcTime.update();
		mcTime.current = 0;
		mcTime.max = Cs.getLevelTime(level);

		setWarning(false);
		checkLevel();
	}

	function updateTime() { // update TimeLine && check lifeloss
		mcTime.update();
		mcTime.current += 1;

		var c = mcTime.max - mcTime.current;
		if (c > 0) {
			mcTime._timeLeft._xscale = c / mcTime.max * 100;
			if (mcTime._timeLeft._xscale < 40)
				setWarning(true);
		} else {
			lifeLoss();
			resetTime();
			Game.me.stats.d[Game.me.stats.d.length - 1].push(-2);
		}
	}

	public function explode(from:Pos) {
		step = Explode;
		lifeLoss();
	}

	public function resetParsing() {
		for (x in grid) {
			for (s in x) {
				if (s == null)
					continue;
				s.resetParse();
			}
		}
	}

	// WARNING
	function setWarning(on:Bool) {
		if (on) {
			if (mcWarning != null)
				return;

			mcWarning = dm.empty(DP_FX);
			mcWarning.getGraphics().beginFill(0xFF2222, 0.5);
			mcWarning.getGraphics().drawRect(0, 0, Cs.mcw, Cs.mch);
			mcWarning._alpha = 0;
			mcWarning.blendMode = OVERLAY;
			mcWarning.tween = pixi.core.Pixi.tweenManager.createTween(mcWarning);
			mcWarning.tween.time = 500;
			mcWarning.tween.pingPong = true;
			mcWarning.tween.loop = true;
			mcWarning.tween.easing = pixi.core.Pixi.tween.Easing.inSine();
			mcWarning.tween.from({alpha: 0}).to({alpha: 0.6}).start();
		} else {
			if (mcWarning == null)
				return;

			mcWarning.tween.remove();
			mcWarning.removeMovieClip();
			mcWarning = null;
		}
	}

	// NEXT LEVEL MC
	function setNextLevel(on:Bool) {
		if (on) {
			if (mcLevel != null)
				return;

			mcLevel = cast dm.attach("mLevel", DP_ANIM);
			mcLevel.initTextField("_field", {
				font: "Verdana",
				align: "center",
				x: Std.int(KadoKadeoManager.I(51) + KadoKadeoManager.I(50) / 2),
				y: KadoKadeoManager.I(44),
				bold: true,
				color: 0xE5BD78,
				size: 66,
			});
			mcLevel._field.filters = [
				new BevelFilter({
					lightColor: 0xF6E8D0,
					shadowColor: 0x88402A,
					rotation: 210,
					tickness: 3
				}),
			];
			Filt.glow(mcLevel._field, 3, 3, 0x9A3D18);
			mcLevel._field.text = Std.string(level + 1);
			var s = new Phys(mcLevel);
			s.x = KadoKadeoManager.I(366);
			s.y = KadoKadeoManager.I(100);
			s.vx = -KadoKadeoManager.I(24);
			s.frict = 0.92;
			s.timer = 60;
		} else {
			if (mcLevel == null)
				return;
			mcLevel.removeMovieClip();
			mcLevel = null;
		}
	}

	public function destroy():Void {
		Game.me = null;
	}
}

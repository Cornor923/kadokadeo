package minirace;

import common_haxe_avm1.KeyboardManager;
import common_haxe_avm1.MouseManager;
import haxe.io.UInt16Array;
import js.lib.Uint16Array;
import mt.DepthManager;
import pixi.core.Pixi.BlendModes;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;
import pixi.filters.colormatrix.ColorMatrixFilter;
import pixi.mesh.NineSlicePlane;
import minirace.Cs.CheckPoint;

enum Step {
	Play;
	GameOver;
}

@:expose('GameMiniRace')
class Game implements kado.GameInterface {
	// Enter accelerates like Space (the mouse or a finger on the screen: press to accelerate, its position steers)
	public static var KEY_ALIASES = KeyboardManager.ALIASES_ENTER_SPACE;

	public static inline var DP_BG = 0;
	public static inline var DP_MAP = 1;
	public static inline var DP_INTER = 3;

	public static inline var DP_GROUND = 1;
	public static inline var DP_CAR = 2;
	public static inline var DP_PARTS = 3;
	public static inline var DP_SKY_PARTS = 4;
	public static inline var DP_SCORE = 5;

	public static inline var SC = 2;

	public var flPerfect:Bool;
	// the player's car went on the grass during this lap (the achievements, flPerfect counts the shocks too)
	public var flOffTrack:Bool;

	var blink:Null<Float>;

	var timer:Null<Float>;

	public var chronoTimer:Float;
	public var flPress:Bool;

	var lap:Int;
	var fastLimit:Int;
	var furiousLimit:Int;

	public var step:Step;
	public var checkpoints:Array<CheckPoint>;

	var sbList:Array<String>;

	public var cars:Array<Car>;
	public var sList:Array<Sprite>;

	public var map:ASprite;
	public var mdm:DepthManager;

	var mcInter:Clip;
	var chrono:ASprite;
	var chronoPpu:Float;
	var field0:Digits;
	var field1:Digits;
	var gaY:Float;
	var flagList:Array<Clip>;
	var mcShowBonus:ShowBonus;

	public var dm:DepthManager;
	public var root:ASprite;

	// _ot: the time of each lap (seconds, thousandths, bonus); for the achievements: _lp: each lap [off track, perfect],
	// _pa: the cars overtaken by pid (1 green, 2 blue, 3 pink), _x: 1 when the player's car exploded
	public var stats:{_ot:Array<Array<Int>>, _lp:Array<Array<Int>>, _pa:Array<Int>, _x:Int};

	// Bmp of the map (paint of the track and of the tyres): a render texture at 4 px per map unit
	var paintRT:RenderTexture;
	var paintBatch:Container;
	var paintCount:Int;

	// mcRace for hitTest: runs of each row of cells, index of the first run of each row
	var hitRuns:Uint16Array;
	var hitRow:Array<Int>;

	var scrolled:Bool;
	var over:Bool;
	var frameCount:Int;
	var onPointerDown:Dynamic;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: UInt16Array.fromArray([KeyboardManager.SPACE]),
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: UInt16Array.fromArray([MouseManager.BUTTON_LEFT]),
		});

		Cs.game = this;
		Clip.flushRemoved();
		// like the Flash player, the game keeps the mouse while its button is held: the race is driven with the
		// button down and the pointer near the edges, going out of the game does not release it
		if (!isReplay) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			onPointerDown = function(e:Dynamic) {
				try {
					canvas.setPointerCapture(e.pointerId);
				} catch (_:Dynamic) {}
			};
			canvas.addEventListener("pointerdown", onPointerDown);
		}
		over = false;
		scrolled = false;
		frameCount = 0;

		// the game runs in the Flash pixels of the original (300 x 300), drawn x2
		this.root = root.createEmptyMovieClip("scene", 0);
		this.root._xscale = this.root._yscale = 100 * Clip.K;
		this.root.updateState();

		sList = [];
		Cs.init(this);

		lap = 0;
		stats = {_ot: [], _lp: [], _pa: [0, 0, 0], _x: 0};
		// (undefined in the original: NaN until the first lap, the chrono shows nothing and does not count)
		chronoTimer = Math.NaN;
		flPress = false;

		dm = new DepthManager(this.root);

		// mcBg and mcPaint of the root are under the map, which always covers the screen: not drawn
		initInterface();

		initMap();
		fastLimit = 400;
		furiousLimit = 360;

		initCars();
		initPlay();

		warmShaders();
	}

	// CARS
	function initCars() {
		cars = [];
		for (i in 0...4) {
			var car = new Car(Clip.attach(mdm, "mcCar", DP_CAR));
			car.setPlayer(i);
		}
	}

	// UPDATE
	public function update(delta:Float) {
		// clips removed by their own timeline during the update of the display (taken out now: not in the middle of
		// the loop on their parent)
		Clip.flushRemoved();
		frameCount++;
		readInputs();

		switch (step) {
			case Play:
				updatePlay();
			case GameOver:
				updateGameOver();
		}

		updateInterface();
		updateSprites();
		checkCols();
		updateScroll();
		flushPaint();
	}

	function updateSprites() {
		var list = sList.copy();
		for (sp in list)
			if (!sp.dead)
				sp.update();
	}

	// MAP
	function initMap() {
		map = dm.empty(DP_MAP);
		map._xscale = SC * 100;
		map._yscale = SC * 100;
		mdm = new DepthManager(map);

		// timeline of mcMap under everything attached by the code: floor (mcBg), toys; race (the borders of the
		// track) is hidden under the floor, only used by hitTest
		var floor = map.createEmptyMovieClip("floor", -1);
		var bg = sprite("mapBg", 1 / Data.BITMAP_PX);
		floor.addChild(bg);
		for (i in 0...Data.TOYS.length) {
			var t = sprite("toy" + (i + 1), 1 / Data.MAP_PX);
			t.x = Data.TOYS[i][0];
			t.y = Data.TOYS[i][1];
			floor.addChild(t);
		}
		initHitTest();

		// Bmp at 50 %, with the paint of the track (mcPaint)
		var mc = mdm.empty(DP_GROUND);
		mc._alpha = 50;
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		paintRT = (cast RenderTexture : Dynamic).create({width: Cs.mcw * Data.MAP_PX, height: Cs.mch * Data.MAP_PX});
		var paint = sprite("mapPaint", Data.MAP_PX / Data.BITMAP_PX);
		renderer.render(paint, {renderTexture: paintRT, clear: true});
		paint.destroy();
		var bmp = new PixiSprite(paintRT);
		bmp.scale.set(1 / Data.MAP_PX, 1 / Data.MAP_PX);
		mc.addChild(bmp);
		paintBatch = new Container();
		paintCount = 0;
	}

	function sprite(anim:String, sc:Float):PixiSprite {
		var t = Tex.get(anim)[0];
		var s = new PixiSprite(t);
		s.anchor.copyFrom(t.defaultAnchor);
		s.scale.set(sc, sc);
		return s;
	}

	function updateScroll() {
		var car = cars[0];
		if (car.pid != 0)
			return;

		map._x = Cs.mm(-(Cs.mcw * SC - Cs.mcw), Cs.mcw * 0.5 - car.x * SC, 0);
		map._y = Cs.mm(-(Cs.mch * SC - Cs.mch), Cs.mch * 0.5 - car.y * SC, 0);
		if (!scrolled) {
			scrolled = true;
			map.updateState();
		}
	}

	// map.race.hitTest(x * SC + map._x, y * SC + map._y, true): the point in race, then its cell of the bitmask
	function initHitTest() {
		var b = haxe.crypto.Base64.decode(Data.HIT_RUNS);
		hitRuns = new Uint16Array(b.length >> 1);
		for (i in 0...hitRuns.length)
			hitRuns[i] = b.getUInt16(i * 2);
		hitRow = [];
		var o = 0;
		for (r in 0...Data.HIT_H) {
			hitRow.push(o);
			o += hitRuns[o] + 1;
		}
	}

	public function raceHitTest(x:Float, y:Float):Bool {
		var lx = (x - Data.RACE_TX) / Data.RACE_A;
		var ly = (y - Data.RACE_TY) / Data.RACE_D;
		var cx = Math.floor((lx - Data.HIT_X0) * Data.HIT_CELL);
		var cy = Math.floor((ly - Data.HIT_Y0) * Data.HIT_CELL);
		if (!(cx >= 0 && cy >= 0 && cx < Data.HIT_W && cy < Data.HIT_H))
			return false;
		var o = hitRow[cy];
		var inside = false;
		for (i in 0...hitRuns[o]) {
			if (hitRuns[o + 1 + i] > cx)
				break;
			inside = !inside;
		}
		return inside;
	}

	// tyre trace drawn in the Bmp (mcPneuFx: line of dist units from (x, y), angle a, alpha prc %)
	public function paintMark(x:Float, y:Float, dist:Float, a:Float, prc:Float) {
		var s:PixiSprite;
		if (paintCount < paintBatch.children.length) {
			s = cast paintBatch.children[paintCount];
			s.visible = true;
		} else {
			var t = Tex.get("pneuStrip")[0];
			s = new PixiSprite(t);
			s.anchor.copyFrom(t.defaultAnchor);
			s.tint = Data.PNEU_COLOR;
			paintBatch.addChild(s);
		}
		paintCount++;
		s.x = x * Data.MAP_PX;
		s.y = y * Data.MAP_PX;
		s.rotation = a;
		s.scale.set(dist / Data.PNEU_L, 1);
		s.alpha = prc / 100;
	}

	// the traces of this frame drawn at once
	function flushPaint() {
		if (paintCount == 0)
			return;
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		renderer.render(paintBatch, {renderTexture: paintRT, clear: false});
		for (c in paintBatch.children)
			c.visible = false;
		paintCount = 0;
	}

	// PLAY
	function initPlay() {
		timer = 0;
		step = Play;
	}

	function updatePlay() {
		chronoTimer += Timer.tmod;
		updateChrono();
	}

	public function incLap() {
		Cs.setPercentColor(root, 0, 0xFF0000);

		if (lap > 0) {
			addTime(chronoTimer);
			stats._lp.push([flOffTrack ? 1 : 0, flPerfect ? 1 : 0]);
		}
		lap++;
		flPerfect = true;
		flOffTrack = false;
		chronoTimer = 0;

		var fl = flagList.pop();
		if (fl != null)
			fl.removeMovieClip();
		for (c in cars) {
			if (c.pid > 0) {
				c.acc *= Cs.LAP_MALUS;
				c.turnLimit *= Cs.LAP_MALUS;
			}
		}

		if (lap > Cs.TURN_MAX) {
			initGameOver(0);
		}
	}

	function checkCols() {
		// (the bounds are read once: when the player's car explodes, it leaves the list during the loop and the last
		// pairs are missing, a call on them did nothing in the Flash player)
		for (i in 0...cars.length) {
			var c = cars[i];
			for (n in i + 1...cars.length) {
				var c2 = cars[n];
				if (c != null && c2 != null)
					c.checkColPhys(c2);
			}
		}
	}

	// GAME OVER
	public function initGameOver(n:Float) {
		step = GameOver;
		timer = n;
	}

	function updateGameOver() {
		if (timer != null) {
			timer -= Timer.tmod;
			if (timer < 0) {
				gameOver();
				timer = null;
			}
		}
	}

	// INTERFACE
	function initInterface() {
		mcInter = Clip.attach(dm, "mcInter", DP_INTER);
		mcInter._x = Cs.mcw;
		mcInter._y = Cs.mch;
		gaY = Data.INTER_GA[1];

		// CHRONO: its fields, the lap times and the stars of the perfect laps are drawn in its image
		chrono = mcInter.get("chrono");
		chronoPpu = Clip.K * Data.INTER_CHRONO[2] / mcInter.layerMatrix("chrono")[2];
		field0 = new Digits(Data.FIELD_SEC, chronoPpu);
		field1 = new Digits(Data.FIELD_MIL, chronoPpu);
		chrono.addChild(field1);
		chrono.addChild(field0);

		// FLAGS (attached over the timeline of mcInter)
		flagList = [];
		var ppu = mcInter.pxPerUnit();
		for (n in 0...Cs.TURN_MAX) {
			var mc = new Clip("mcFlag", ppu);
			mc._x = -(54 + n * 14) * ppu;
			mc._y = -10 * ppu;
			mcInter.addChild(mc);
			mc.updateState();
			flagList.push(mc);
		}
	}

	public function updateLife(n:Float) {
		mcInter.setOverride("bar", null, null, mcInter.layerMatrix("bar")[3] * 100 * (n / Cs.LIFE_MAX));
	}

	function updateInterface() {
		// TRIGGER
		if (flPress) {
			gaY += (-42 - gaY) * 0.1;
		} else {
			gaY = Math.max(gaY - 5, -60);
		}
		mcInter.setOverride("ga", null, null, null, null, gaY * mcInter.pxPerUnit());

		if (sbList != null && sbList.length > 0 && (mcShowBonus == null || !mcShowBonus.alive)) {
			mcShowBonus = new ShowBonus(sbList.shift());
			mcShowBonus.attachTo(dm, DP_INTER);
		}
	}

	public function showBonus(str:String) {
		if (sbList == null)
			sbList = [];
		sbList.push(str);
	}

	// CHRONO
	function updateChrono() {
		var ch = getChrono(chronoTimer);
		field1.setText(getDigit(ch.mil, 3));
		field0.setText(getDigit(ch.sec, 2));

		var lim = 25;
		if (ch.sec > lim - 1) {
			Cs.setPercentColor(root, 0, 0xFF0000);
			initGameOver(0);
		} else if (ch.sec > lim - 3) {
			if (blink == null)
				blink = 0;
			blink = (blink + 73 * Timer.tmod) % 628;
			Cs.setPercentColor(root, Math.cos(blink * 0.01) * 10, 0xFF0000);
		}
	}

	function getChrono(n:Float):{mil:Float, sec:Float} {
		if (Math.isNaN(n))
			return {mil: Math.NaN, sec: Math.NaN};
		var t = Std.int(n * 25);
		var mil = t % 1000;
		var sec = Std.int(t / 1000);
		return {mil: mil, sec: sec};
	}

	function getDigit(n:Float, max:Int):String {
		var str = Math.isNaN(n) ? "NaN" : Std.string(Std.int(n));
		while (str.length < max)
			str = "0" + str;
		return str;
	}

	function addTime(n:Float) {
		var ch = getChrono(n);
		var a = [Std.int(ch.sec), Std.int(ch.mil)];

		if (n < furiousLimit) {
			showBonus("TOUR DE FURIEUX!");
			addScore(Cs.SCORE_FURIOUS);
			a.push(1);
		} else if (n < fastLimit) {
			showBonus("TOUR RAPIDE!");
			addScore(Cs.SCORE_FAST);
			a.push(2);
		};

		stats._ot.push(a);

		// mcTime in the chrono: (83, lap * 11 - 13)
		var my = lap * 11 - 13;
		var mc = new Digits(Data.FIELD_TIME, chronoPpu);
		mc.x = 83 * chronoPpu;
		mc.y = my * chronoPpu;
		mc.setText(getDigit(ch.sec, 2) + "'" + getDigit(ch.mil, 3));
		chrono.addChild(mc);

		if (flPerfect) {
			showBonus("TOUR PARFAIT!");
			addScore(Cs.SCORE_PERFECT);

			var mcs = new Clip("mcStar", chronoPpu);
			mcs._x = 38 * chronoPpu;
			mcs._y = (my + 9.5) * chronoPpu;
			chrono.addChild(mcs);
			mcs.updateState();
		}
	}

	// TOOLS
	public function getX(x:Float):Float {
		return x * SC + map._x;
	}

	public function getY(y:Float):Float {
		return y * SC + map._y;
	}

	// root._xmouse / root._ymouse (Flash pixels)
	// (out of the game on the left or at the top: 0, like the position recorded in the replay)
	public function mouseX():Float {
		return Math.max(0, MouseManager.getX()) / Clip.K;
	}

	public function mouseY():Float {
		return Math.max(0, MouseManager.getY()) / Clip.K;
	}

	// LISTENERS: mouse button (or a finger) and Space / Enter accelerate; releasing the key stops
	function readInputs() {
		for (c in MouseManager.getFrameButtonChanges())
			if (c.button == MouseManager.BUTTON_LEFT)
				flPress = c.isDown;
		for (c in KeyboardManager.getFrameKeyChanges()) {
			if (c.keyCode != KeyboardManager.SPACE)
				continue;
			if (c.isDown)
				flPress = true;
			else if (flPress)
				flPress = false;
		}
	}

	// The first use of a filter compiles its shader on the graphics card (tens of ms of freeze): the red tint of the
	// end of a slow lap and the light streaks are drawn once now, off screen.
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		s.filters = [new ColorMatrixFilter()];
		holder.addChild(s);
		var line = new NineSlicePlane(Tex.get("partLine1")[0], 4, 0, 4, 0);
		holder.addChild(line);
		var add = new PixiSprite(Texture.WHITE);
		add.blendMode = BlendModes.ADD;
		holder.addChild(add);
		var rt:RenderTexture = (cast RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	// SCORE / END
	public function addScore(n:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	function gameOver() {
		if (over)
			return;
		over = true;
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			lap: lap,
			cars: [for (c in cars) [c.pid, c.x, c.y, c.cps]],
			stats: haxe.Json.stringify(stats)
		};
		#end
		KadoKadeoManager.kkm.gameOver(stats);
	}

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null)
				canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		if (paintRT != null) {
			paintRT.destroy(true);
			paintRT = null;
		}
		if (paintBatch != null) {
			paintBatch.destroy({children: true});
			paintBatch = null;
		}
		Clip.flushRemoved();
		Cs.game = null;
	}
}

// mcShowBonus: the message falls from the top, stays (frames 6 to 9 played 6 more times), then goes back up and the clip
// removes itself; drawn additively
class ShowBonus extends ASprite {
	public var alive(default, null):Bool;

	var msg:Clip;
	var f:Int;
	var compt:Int;

	public function new(text:String) {
		super();
		msg = new Clip("bonusMsg", 1);
		msg.gotoAndStop(Data.MSGS.indexOf(text) + 1);
		msg.blendMode = BlendModes.ADD;
		addChild(msg);
		f = 1;
		compt = 0;
		alive = true;
		show();
		msg.updateState();
	}

	public function attachTo(dm:DepthManager, plan:Int) {
		var d = dm.reserve(this, plan);
		dm.getMC().addChild(this);
		_zIndex = d;
		zsort();
		updateState();
	}

	override public function update() {
		super.update();
		if (!alive)
			return;
		f++;
		if (f == 5)
			compt = 6;
		if (f == 10 && compt-- > 0)
			f -= 4;
		if (f == 15) {
			alive = false;
			removeMovieClip();
			return;
		}
		show();
	}

	function show() {
		msg._x = Data.SHOW_BONUS_X;
		msg._y = Data.SHOW_BONUS_Y[f - 1];
	}
}

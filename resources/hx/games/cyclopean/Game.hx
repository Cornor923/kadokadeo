package cyclopean;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import cyclopean.Element.ElementMC;
import cyclopean.Level.Mat;
import cyclopean.Level.Piece;
import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import pixi.core.textures.Texture;

// mcLoader: its pieces (Data.LOADER_*: the timeline turns the quarter discs and changes the cover), the chick and
// the rune ring the code turns. The quarter disc of depth 4 is a mask on the one of depth 6 (the white wedge that
// shrinks is their intersection); it turns by quarters only: the quadrant of the same radius, a rectangle mask
// (drawn with the scissor test: no shader, sharp edges).
// The mask and the cover change when q6 crosses a quarter (the same frames in Data): they follow the rotation q6 is
// drawn with (one Flash frame late and interpolated, see MC), else the wedge flashes at each quarter
class LoaderMC extends MC {
	public var piou:MC;
	public var wh:MC;

	var q6:MC;
	var q4:Graphics;
	var cover:MC;
	// the quadrant drawn by q4 (0: 0, 1: 90, 2: 180, 3: -90 degrees)
	var quarter:Int = -1;

	public function new() {
		super();
		_totalframes = Data.LOADER_COVER.length;
		attach(new MC("loaderBase"));
		q6 = attach(new MC("loaderQuarter"));
		q4 = new Graphics();
		spr.addChild(q4);
		q6.spr.mask = q4;
		spr.addChild(new LoaderSync(this));
		cover = attach(new MC("loaderCover"));
		piou = attach(new MC("piou"));
		piou.playing = true;
		place(piou, Data.LOADER_PIOU);
		wh = attach(new MC("loaderWh"));
		place(wh, Data.LOADER_WH);
		show();
	}

	static function place(mc:MC, m:Array<Float>):Void {
		mc._xscale = Math.sqrt(m[0] * m[0] + m[1] * m[1]) * 100;
		mc._yscale = Math.sqrt(m[2] * m[2] + m[3] * m[3]) * 100;
		mc._rotation = Math.atan2(m[1], m[0]) * 180 / Math.PI;
		mc._x = m[4];
		mc._y = m[5];
	}

	override public function gotoAndStop(f:Int):Void {
		// (main() still sets the frame of the loader it has just removed: Flash ignores it)
		if (removed)
			return;
		super.gotoAndStop(f);
		show();
	}

	function show():Void {
		q6._rotation = Data.LOADER_Q6[_currentframe - 1];
	}

	// q6 drawn at `rot` degrees: in the quadrant ]q - 90, q] (Data.LOADER_Q4), with the cover of that quadrant
	// (Data.LOADER_COVER)
	public function showQuarter(rot:Float):Void {
		var k = Math.ceil(rot / 90 - 1e-6);
		k = ((k % 4) + 4) % 4;
		var cf = [0, 3, 2, 1][k];
		if (cf > 0) {
			cover.gotoAndStop(cf);
			cover.showFrame();
		} else
			cover.spr.renderable = false;
		if (k == quarter)
			return;
		quarter = k;
		// the quadrant [0, 110] x [-110, 0] (sprite 86, beyond its radius) turned by q4
		var a = [0, 90, 180, -90][k] * Math.PI / 180;
		var c = Math.round(Math.cos(a)), s = Math.round(Math.sin(a));
		var x0 = 0.0, x1 = 0.0, y0 = 0.0, y1 = 0.0;
		for (p in [[0, 0], [110, 0], [0, -110], [110, -110]]) {
			var x = c * p[0] - s * p[1];
			var y = s * p[0] + c * p[1];
			x0 = Math.min(x0, x);
			x1 = Math.max(x1, x);
			y0 = Math.min(y0, y);
			y1 = Math.max(y1, y);
		}
		q4.clear();
		q4.beginFill(0xFFFFFF);
		q4.drawRect(x0, y0, x1 - x0, y1 - y0);
		q4.endFill();
	}

	public function drawnQ6():Float {
		return q6.spr.rotation * 180 / Math.PI;
	}
}

// a child of the loader after q6: when the frame is drawn, q6 has its rotation of this frame
class LoaderSync extends ASprite {
	var loader:LoaderMC;

	public function new(loader:LoaderMC) {
		super();
		this.loader = loader;
	}

	override public function updateGraphics(a:Float) {
		super.updateGraphics(a);
		loader.showQuarter(loader.drawnQ6());
	}
}

// mcInter: the time gauge on the right. Its "bar" (a 12 x 292 rectangle scaled by the code) is the mask of the gauge
// (it shows the gauge up to the time left; its own _alpha changes nothing): a rectangle mask in the clip of the bar
// (it follows the scale shown; drawn with the scissor test, no shader); barUp follows its top
class InterMC extends MC {
	public var bar:MC;
	public var barUp:MC;
	public var dec:Float = 0;
	public var glow:InterGlow;

	public function new() {
		super();
		bar = attach(new MC());
		place(bar, Data.INTER_BAR);
		var mask = new Graphics();
		mask.beginFill(0xFFFFFF);
		mask.drawRect(0, -Data.INTER_BAR_H, Data.INTER_BAR_W, Data.INTER_BAR_H);
		mask.endFill();
		bar.spr.addChild(mask);
		attach(new MC("interFrame")).spr.mask = mask;
		place(attach(new MC("interCap")), Data.INTER_CAP);
		barUp = attach(new MC("interCap"));
		place(barUp, Data.INTER_BARUP);
	}

	static function place(mc:MC, m:Array<Float>):Void {
		mc._xscale = m[0] * 100;
		mc._yscale = m[3] * 100;
		mc._x = m[4];
		mc._y = m[5];
	}

	// bar._height
	public function barHeight():Float {
		return MC.twips(Data.INTER_BAR_H * Math.abs(bar._yscale) / 100);
	}

	// mcInter.filters = [GlowFilter] + Cs.setPercentColor(mcInter, inc * 4, 0xFFFFFF); off with inc = null
	public function setGlow(inc:Null<Float>):Void {
		if (inc == null) {
			spr.filters = null;
			return;
		}
		if (glow == null)
			glow = new InterGlow();
		glow.blur = inc;
		glow.setPercent(inc * 4);
		if (spr.filters == null)
			spr.filters = [glow];
	}
}

// partFlamb: its mcLightFlip (depth 1, playing on its own) under the dot of the frame the code chooses
class FlambMC extends MC {
	var dot:MC;

	public function new() {
		super();
		_totalframes = 3;
		var l = attach(new MC("lightflip"));
		l.playing = true;
		var m = Data.FLAMB_LIGHT;
		l._xscale = m[0] * 100;
		l._yscale = m[3] * 100;
		dot = attach(new MC("flamb"));
	}

	override public function gotoAndStop(f:Int):Void {
		super.gotoAndStop(f);
		dot.gotoAndStop(f);
	}
}

// mcPiou in the minimap (13 frames looping: the last 3 empty)
class MiniPiouMC extends MC {
	public function new() {
		super("miniPiou");
		_totalframes = 13;
		playing = true;
	}
}

// the minimap (Game.initMiniMap): the level at 10 %, white at 50 %, turning with the scroller, under the 80 x 80
// square of mcMask
class MiniMap extends MC {
	public var map:MC;
	public var smc:MC;
	public var mask:Graphics;

	public function new(tex:Texture, side:Float) {
		super();
		map = attach(new MC());
		map._x = side * 0.5;
		map._y = side * 0.5;
		map._alpha = 50;
		// minimap.map.smc: the level bitmap at _xscale 10 (a picture of the level at 2 px per Flash pixel of the
		// minimap: _xscale 100 here, res 2)
		smc = map.attach(new MC(null, Game.K));
		smc.spr.texture = tex;
		// mcMask (a 100 x 100 square) at side %: a rectangle mask, drawn with the scissor test (no shader)
		mask = new Graphics();
		mask.beginFill(0xFFFFFF);
		mask.drawRect(0, 0, side, side);
		mask.endFill();
		spr.addChild(mask);
		map.spr.mask = mask;
		var piou = attach(new MiniPiouMC());
		piou._x = side * 0.5;
		piou._y = side * 0.5;
	}
}

@:expose('GameCyclopean')
class Game implements kado.GameInterface {
	public static inline var K = 2;

	static inline var DP_BASE = 0;
	static inline var DP_BG = 4;
	public static inline var DP_DECOR = 5;
	public static inline var DP_ELEMENT = 6;
	public static inline var DP_PIOU = 7;
	public static inline var DP_PART = 8;

	static inline var TOLERANCE = 60;

	// Flash played Cyclopean at 40 frames/s (the rate of the SWF) with mt.Timer.wantedFPS = 32: tmod = 0.8, one main()
	// per Flash frame (see update)
	public static inline var FRAME_RATE = 40;
	public static var tmod:Float = 32 / FRAME_RATE;

	// like PiouPiou: a touch on the left half of the screen turns the cave left, on the right half right
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left_zone",
				label: "",
				leftPx: -450,
				size: 600,
				keyCode: KeyboardManager.LEFT,
				invisible: true,
			},
			{
				id: "right_zone",
				label: "",
				rightPx: -450,
				size: 600,
				keyCode: KeyboardManager.RIGHT,
				invisible: true,
			},
		],
	};

	// Q / D (A / D) turn like the arrows
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	public static var me:Game;

	var step:Int;
	var genStep:Int;

	public var generator:Array<Int>;
	public var flCenterActive:Bool;

	// never set before the end (initStep(9)): NaN like Flash's undefined
	var timer:Float = Math.NaN;

	public var gameTimer:Float;

	var scoreTimer:Float;

	var angle:Float;
	var va:Float;

	public var gcos:Float;
	public var gsin:Float;

	public var root:MC;
	public var dm:Plans;

	var gdm:Plans;

	public var sList:Array<Sprite>;
	public var bList:Array<Bille>;
	public var eList:Array<Element>;

	var outList:Array<{x:Float, y:Float, rot:Float}>;
	var flDone:Bool = false;

	public var ball:Ball;

	var map:MC;
	var minimap:MiniMap;
	var bg:MC;
	var bgx:Float;
	var bgy:Float;
	var bgsc:MC;
	var scroller:MC;
	var mcInter:InterMC;
	var pentacle:MC;
	var loader:LoaderMC;

	public var level:Level;

	var textures:Array<Texture> = [];

	// Flash frames of the game played (scrollMap: the first one places the scene at once)
	var frameStep1:Int = 0;
	var isReplay:Bool;
	var over:Bool = false;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;

	#if debug
	// test harness: what the game went through (window.__over)
	public var stats:Dynamic;
	var levelHash:Int = 0;
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(2);
		keys[0] = KeyboardManager.LEFT;
		keys[1] = KeyboardManager.RIGHT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		me = this;
		MC.clearAll();
		#if debug
		stats = {elements: [0, 0, 0, 0, 0], billes: 0, maxGen: 0};
		#end

		// the original's 300x300 pixels, drawn x2
		root = new MC(null, 1 / K);
		root.posK = K;
		mc.addChild(root.spr);

		Cs.game = this;
		gdm = new Plans(root);
		// the stage of the SWF: white (the white covers of mcLoader hide the pentacle not drawn yet)
		var stage = gdm.empty(0);
		stage.spr.texture = Texture.WHITE;
		stage._xscale = stage._yscale = Cs.mcw / Texture.WHITE.width * 100;
		scroller = gdm.empty(2);

		map = scroller.attach(new MC());
		dm = new Plans(map);
		sList = new Array();
		eList = new Array();

		angle = 0;
		va = 0;
		gcos = 0;
		gsin = 0;
		generator = new Array();
		scoreTimer = 0;

		flCenterActive = false;

		initStep(0);
		MC.displayAll(1);
		warmShaders();
		Level.readTiles();
	}

	function initBackground():Void {
		var ts = 128;
		var fs = (Math.ceil(Cs.mcw / ts) + 2) * ts;
		var tex = Level.bgTexture(fs);
		textures.push(tex);

		bg = gdm.empty(1);
		// bg.sc: the clip "bg" (an orange 300 x 300 square, always under the opaque bitmap: not drawn) and the bitmap
		bgsc = bg.attach(new MC(null, 1));
		bgsc.spr.texture = tex;
		bgx = 0;
		bgy = 0;
		bg._x = Cs.mcw * 0.5;
		bg._y = Cs.mcw * 0.5;
	}

	function initStep(s:Int):Void {
		step = s;

		switch (step) {
			case 0: //
				genStep = 0;
				level = new Level();
				outList = [{x: Cs.LEVEL_SIDE * 0.5, y: Cs.LEVEL_SIDE * 0.5, rot: 0}];
				//
				loader = gdm.add(new LoaderMC(), 10);
				loader._x = Cs.mcw * 0.5;
				loader._y = Cs.mch * 0.5;

			case 1: //
				bList = new Array();
				ball = genBall(Cs.LEVEL_SIDE * 0.5, Cs.LEVEL_SIDE * 0.5);
				gameTimer = Cs.TIME_MAX;

				// INTER
				mcInter = gdm.add(new InterMC(), 3);
				mcInter.bar._alpha = 50;
				mcInter._x = Cs.mcw;
				mcInter.dec = 0;

				// EXPLO (particles: visual random)
				var max = 48;
				for (i in 0...max) {
					var p = newPart("mcLightFlip");
					var a = (i / max) * 6.28;
					var ca = Math.cos(a);
					var sa = Math.sin(a);
					var sp = 1 + Seed.randVfx() * 2;
					var ray = 100;

					p.x = Cs.LEVEL_SIDE * 0.5 + ca * ray;
					p.y = Cs.LEVEL_SIDE * 0.5 + sa * ray;
					p.vx = ca * sp;
					p.vy = sa * sp;
					p.timer = 10 + Seed.randVfx() * 10;
					if (Seed.randomVfx(3) == 0)
						p.timer += Seed.randVfx() * 100;
					p.fadeType = 0;
					p.weight = 0.1 + Seed.randVfx() * 0.3;
					p.bouncer = new Bouncer(p);
					p.setScale(100 + Seed.randVfx() * 100);
				}

			case 9: // ENDGAME
		}
	}

	function genBall(x:Float, y:Float):Ball {
		var b = new Ball();
		b.bouncer.setPos(x, y);
		return b;
	}

	public function genBille(x:Float, y:Float):Bille {
		var b = new Bille();
		b.bouncer.setPos(x, y);
		#if debug
		stats.billes++;
		#end
		return b;
	}

	function finalizeLevel():Void {
		// BACKGROUND
		initBackground();
		// BONUS
		for (p in outList) {
			var e = new Element(p.x, p.y, Cs.SPAWN[Seed.random(Cs.SPAWN.length)]);
		}
		// TEXTURE
		var tex = level.texture();
		textures.push(tex);
		var lv = dm.empty(DP_DECOR);
		lv.spr.texture = tex;

		initMiniMap();

		#if debug
		var h = 0x811C9DC5;
		for (i in 0...level.alpha.length)
			h = untyped Math.imul(h ^ level.alpha[i], 0x01000193);
		levelHash = h;
		#end
	}

	// ---------------------------------------------------------------- port: KadoKadeo
	public function update(delta:Float):Void {
		// 5 Flash frames every 4 steps (see FRAME_RATE)
		tmod = 32 / FRAME_RATE;
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			MC.frameStart();
			main();
			frameCount++;
		}
		MC.displayAll(frameAcc / 4);
	}

	public function addScore(n:Int):Void {
		if (over)
			return;
		KadoKadeoManager.kkm.addScore(n);
	}

	function gameOver():Void {
		if (over)
			return;
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			bx: ball.x,
			by: ball.y,
			vx: ball.vx,
			vy: ball.vy,
			angle: angle,
			gen: generator.length,
			elements: eList.length,
			billes: bList.length,
			level: levelHash,
			stats: haxe.Json.stringify(stats)
		};
		#end
		// (stats: never set by the original)
		KadoKadeoManager.kkm.gameOver({});
		over = true;
	}

	//
	function main():Void {
		timer -= tmod;
		switch (step) {
			case 0: //
				genLevel();
				genStep++;
				if (genStep >= Cs.LEVEL_SIZE) {
					finalizeLevel();
					loader.removeMovieClip();
					initStep(1);
				}
				loader.piou._rotation += 15 * tmod;
				loader.wh._rotation -= tmod;
				loader.gotoAndStop(Std.int(genStep / Cs.LEVEL_SIZE * 100) + 1);

			case 1:
				var ty = (gameTimer / Cs.TIME_MAX) * 100;
				mcInter.bar._yscale = mcInter.bar._yscale * 0.7 + ty * 0.3;
				mcInter.barUp._y = 295 - mcInter.barHeight();

				#if debug
				stats.maxGen = Std.int(Math.max(stats.maxGen, generator.length));
				#end
				scoreTimer -= tmod;
				while (scoreTimer < 0) {
					scoreTimer += Cs.SCORE_LAP;
					for (i in 0...generator.length)
						addScore(KKApi.val(Cs.SCORE_BASE));
				}

				// CENTER CHECK
				var dist = ball.getDist({x: Cs.LEVEL_SIDE * 0.5, y: Cs.LEVEL_SIDE * 0.5});
				var lim = Cs.mcw;
				if ((flCenterActive && dist >= lim) || (!flCenterActive && dist < lim)) {
					switchCenter();
				}

				// SPRITES
				var list = sList.copy();
				for (s in list) {
					s.update();
				}
				// MOVE MAP
				scrollMap();

				// CHECK END
				gameTimer -= tmod;
				var m = -20;
				if (ball.x < m || ball.x > Cs.LEVEL_SIDE - m || ball.y < m || ball.y > Cs.LEVEL_SIDE - m) {
					gameTimer = Math.min(gameTimer, 20);
				}

				if (gameTimer < 0) {
					var burst = gdm.attach("burst", 10);
					burst._totalframes = 72;
					burst.removeAt = 72;
					burst._x = Cs.mcw - 6;
					burst._y = Cs.mch - 6;
					mcInter.removeMovieClip();
					timer = 8;
					initStep(9);
				}

				if (gameTimer < 400) {
					mcInter.dec = (mcInter.dec + 23 * tmod) % 628;
					var inc = Math.abs(Math.cos(mcInter.dec / 100) * 10);
					mcInter.setGlow(inc);
				} else {
					mcInter.setGlow(null);
				}

			case 9:
				if (timer < 0) {
					gameOver();
					va = 0;
					initStep(10);
				}

			case 10:
				va += 0.4 * tmod;
				scroller._rotation += va * tmod;
				ball.root._rotation = -scroller._rotation;
		}

		// PENTACLE TOURNE
		if (flCenterActive) {
			pentacle._rotation += (0.6 + generator.length * 0.2) * tmod;
		}
	}

	//
	function scrollMap():Void {
		var acc = 0.07;
		if (KeyboardManager.isDown(KeyboardManager.LEFT)) {
			va -= acc * tmod;
		}
		if (KeyboardManager.isDown(KeyboardManager.RIGHT)) {
			va += acc * tmod;
		}
		va *= Cs.pow(0.6, tmod);
		angle = Cs.hMod(angle + va * tmod, Math.PI);

		var a = -angle + 1.57;
		gcos = Cs.cos(a);
		gsin = Cs.sin(a);

		var dx = -ball.root._x - map._x;
		var dy = -ball.root._y - map._y;

		map._x += dx;
		map._y += dy;
		scroller._x = Cs.mcw * 0.5;
		scroller._y = Cs.mch * 0.5;
		scroller._rotation = angle / (Math.PI / 180);
		if (minimap != null) {
			updateMinimap();
		}

		// BG
		var c = 0.1;
		var nx = bgx + dx * c;
		var ny = bgy + dy * c;
		bgx = Cs.sMod(nx, 128);
		bgy = Cs.sMod(ny, 128);
		// (the wrap moves the picture by 128 px, which looks the same: not a move to interpolate)
		var wx = bgx - nx;
		var wy = bgy - ny;
		bgsc._x = bgx - (Cs.mcw * 0.5 + 256);
		bgsc._y = bgy - (Cs.mch * 0.5 + 256);
		if (wx != 0 || wy != 0)
			bgsc.shiftShown(wx, wy);
		bg._rotation = scroller._rotation;

		if (frameStep1 == 0) {
			// first frame of the game: the scene jumps from the origin to the ball (not a move to interpolate)
			map.teleport();
			scroller.teleport();
			bgsc.teleport();
			bg.teleport();
		}
		frameStep1++;
	}

	//
	public function newPart(link:String):Part {
		var mc = switch (link) {
			case "mcLightFlip": new MC("lightflip");
			case "partSpark":
				var s = new MC("spark");
				// frame 9: empty, obj.kill()
				s._totalframes = 9;
				s.killAt = 9;
				s;
			case "partFlamb": new FlambMC();
			default: new MC("impact");
		}
		mc.playing = mc._totalframes > 1;
		var p = new Part(dm.add(mc, DP_PART));
		return p;
	}

	// CENTER
	function switchCenter():Void {
		flCenterActive = !flCenterActive;
		if (flCenterActive) {
			pentacle = dm.attach("pentacle", DP_DECOR);
			pentacle._alpha = 50;
			pentacle._x = Cs.LEVEL_SIDE * 0.5;
			pentacle._y = Cs.LEVEL_SIDE * 0.5;

			// the balls turning in the pentacle: visual random
			for (i in 0...generator.length) {
				var a = Seed.randVfx() * 6.28;
				var ray = 10 + Seed.randVfx() * 80;
				var b = genBille(pentacle._x + Math.cos(a) * ray, pentacle._y + Math.sin(a) * ray);
				b.initGeneratorMode();
				b.bTimer = null;
				b.bouncer = null;
				b.setColor(generator[i]);
			}
		} else {
			pentacle.removeMovieClip();
			var i = 0;
			while (i < bList.length) {
				var b = bList[i];
				if (b.step == 2) {
					b.kill();
					i--;
				}
				i++;
			}
		}
	}

	// MINIMAP
	function initMiniMap():Void {
		var m = 4;
		var side = 80;

		var tex = level.miniTexture();
		textures.push(tex);
		minimap = gdm.add(new MiniMap(tex, side), 5);
		minimap._x = m;
		minimap._y = Cs.mch - (side + m);
		// (Cs.setPercentColor(minimap.map, 100, 0xFFFFFF): the picture is white)
	}

	function updateMinimap():Void {
		var sc = 0.1;
		minimap.map._rotation = scroller._rotation;
		minimap.smc._x = map._x * sc;
		minimap.smc._y = map._y * sc;
	}

	// LEVEL
	public function isFree(x:Float, y:Float):Bool {
		return level.getAlpha(x, y) <= TOLERANCE;
	}

	function genLevel():Void {
		var index = Seed.random(outList.length);
		var p = outList[index];
		var list = p != null ? tryBranche(p.x, p.y, p.rot) : tryBranche(Math.NaN, Math.NaN, Math.NaN);
		if (list != null) {
			for (n in list) {
				outList.push(n);
			}
			outList.splice(index, 1);
		}
	}

	function tryBranche(x:Float, y:Float, rot:Float):Array<{x:Float, y:Float, rot:Float}> {
		var mc = getRandomBase(x, y, rot);
		var m = matrix(mc.x, mc.y, mc.rot * Math.PI / 180);
		var list = new Array();
		for (mcp in mc.list) {
			// (globalToLocal(map): the map is at the origin while the level is made)
			var p1 = Level.localToGlobal(m, mcp.x, mcp.y);
			if (isFree(p1.x, p1.y)) {
				return null;
			}
			list.push({x: p1.x, y: p1.y, rot: Cs.hMod(mc.rot + mcp.rot, 180)});
		}

		//
		var b = Level.getBounds(mc.piece, m);
		for (i in 0...1500) {
			var px = Std.int(b.xMin + Seed.rand() * (b.xMax - b.xMin));
			var py = Std.int(b.yMin + Seed.rand() * (b.yMax - b.yMin));
			// (the same tests as the original, the cheapest first)
			if (isFree(px, py) && Level.hitTest(mc.piece, m, px, py)) {
				if (Cs.getDist({x: px, y: py}, {x: x, y: y}) > 40) {
					return null;
				}
			}
		}

		// Cs.drawMC: the matrix is rotated by _rotation * 0.0174 (not PI / 180)
		level.erase(mc.piece, matrix(mc.x, mc.y, mc.rot * 0.0174));
		return list;
	}

	function matrix(x:Float, y:Float, a:Float):Mat {
		var c = Cs.cos(a);
		var s = Cs.sin(a);
		return {a: c, b: s, c: -s, d: c, tx: x, ty: y};
	}

	// the piece attached (mcFirst, then a random frame of mcBase), its anchor `index` on (x, y) and turned so that
	// both anchors face each other; the clip itself is not drawn (removed in the same frame)
	function getRandomBase(x:Float, y:Float, rot:Float):{piece:Piece, x:Float, y:Float, rot:Float, list:Array<Level.Anchor>} {
		var pieces = flDone ? Level.bases : [Level.first];
		var frame = Seed.random(pieces.length) + 1;
		var piece = pieces[frame - 1];
		var list = piece.anchors.copy();

		var index = Seed.random(list.length);
		if (flDone != true)
			index = 0;
		// (frame 9 of mcBase has no $a0: an empty list, p undefined and NaN below)
		var p = list[index];
		var px = p != null ? p.x : Math.NaN;
		var py = p != null ? p.y : Math.NaN;
		var prot = p != null ? p.rot : Math.NaN;
		var ba = Cs.atan2(py, px);

		rot -= (180 + prot);

		var a = Cs.hMod(ba + rot * 0.0174, 3.14);
		var dist = Math.sqrt(px * px + py * py);
		// Flash ignores NaN in _x / _y / _rotation: the clip stays where attach put it (0, 0, 0)
		var mx = x - Cs.cos(a) * dist;
		var my = y - Cs.sin(a) * dist;
		var r = {
			piece: piece,
			x: Math.isNaN(mx) ? 0 : MC.twips(mx),
			y: Math.isNaN(my) ? 0 : MC.twips(my),
			rot: Math.isNaN(rot) ? 0 : Cs.normRot(rot),
			list: list
		};

		list.remove(p);
		flDone = true;

		return r;
	}

	#if debug
	// test harness (ccheck.mjs): the clips of a page of pages.json drawn by the runtime, over everything
	public function debugShow(items:Array<Dynamic>, bgColor:Int):Void {
		var stage:Dynamic = untyped KadoKadeoManager.kkm.stage;
		var box = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		var dr = new MC(null, 1 / K);
		dr.posK = K;
		box.addChild(dr.spr);
		for (it in items) {
			var mc:MC = switch (it.k) {
				case "loader":
					var l = new LoaderMC();
					l.piou.gotoAndStop(1);
					l.gotoAndStop(it.f);
					l;
				case "elem":
					// the nested clips on the frame of the page (lightflip 1, the blobs, the egg)
					var e = new ElementMC(it.id, it.sid != null ? it.sid : 0);
					for (c in e.children) {
						if (Std.isOfType(c, MC) && c.playing)
							c.gotoAndStop(it.f != null ? it.f : 1);
						for (b in c.children)
							b.gotoAndStop(it.blob != null ? it.blob : 2);
					}
					e;
				case "flamb":
					var f = new FlambMC();
					f.gotoAndStop(it.f);
					f.children[0].gotoAndStop(1);
					f;
				case "inter":
					var i = new InterMC();
					i.bar._yscale = it.ys;
					i.barUp._y = 295 - i.barHeight();
					i;
				default:
					var a = new MC(it.a);
					a.gotoAndStop(it.f);
					a;
			}
			dr.attach(mc);
			mc._x = it.x;
			mc._y = it.y;
			mc._xscale = mc._yscale = it.s != null ? it.s : 100;
			mc._rotation = it.r != null ? it.r : 0;
			if (it.a50 == true)
				mc._alpha = 50;
		}
		MC.displayAll(1);
		stage.addChild(box);
		box.updateGraphics(1);
	}
	#end

	// ---------------------------------------------------------------- port: shaders
	// the glow of the time bar (its first use would compile a shader during the game)
	function warmShaders():Void {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new pixi.core.sprites.Sprite(Texture.WHITE);
		var g = new InterGlow();
		g.blur = 4;
		s.filters = [g];
		holder.addChild(s);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function destroy():Void {
		MC.clearAll();
		for (t in textures)
			t.destroy(true);
		textures = [];
		if (Cs.game == this)
			Cs.game = null;
		if (me == this)
			me = null;
	}
}

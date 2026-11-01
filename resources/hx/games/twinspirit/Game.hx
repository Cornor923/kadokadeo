package twinspirit;

import common_haxe_avm1.KeyboardManager;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import pixi.core.Pixi.BlendModes;
import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import pixi.core.math.Matrix;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;
import pixi.filters.blur.BlurFilter;
import pixi.filters.colormatrix.ColorMatrixFilter;

enum Step {
	Play;
	Bomb;
	Transfert;
	TestScroll;
}

typedef Victim = {p:Phys, ray:Float};
typedef Fayot = {_k:Array<Int>, _m:Array<Int>};

// mcStase: the picture of the game frozen when a hero dies, uncovered by a growing circle
class Stase extends ASprite {
	public var rt:RenderTexture;
	public var circle:Graphics;
	public var light:Mc;
	public var ray:Float;
}

class Line extends Mc {
	public var c:Float;
}

// Twin Spirit (KadoKado, Motion-Twin): ported from the original sources (Game, Hero, Bad, Robot, Stykades, Scroller...
// of the KadoKado TwinSpirit folder) and the graphics of its SWF. The game runs in the Flash pixels of the original
// (300 x 300), drawn x2. Arrows (or ZQSD / WASD) move the ship, Space / Enter / Control fire.
@:expose('GameTwinSpirit')
class Game implements kado.GameInterface {
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.JOYSTICK,
		joystick: {
			x: 0.18,
			y: 0.8,
			radius: 84,
			deadZone: 0.18,
			dynamicCenter: true,
		},
		buttons: [
			{
				id: "fire",
				label: "☄️",
				rightPx: 14,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.SPACE,
			}
		],
	};

	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	public static inline var K = 2;

	public static var FL_TEST = false;

	public static var DP_FRONT_FX = 20;
	public static var DP_FRONT = 18;
	public static var DP_INTER = 17;
	public static var DP_FX = 14;
	public static var DP_SHOTS = 12;
	public static var DP_BADS = 11;
	public static var DP_SCORE = 10;
	public static var DP_HERO = 9;
	public static var DP_UNDER_FX = 6;
	public static var DP_BG = 0;

	public var flTwinMode:Bool;

	var sstep:Int;
	var coef:Float;

	public var robertId:Null<Int>;
	public var shotId:Null<Int>;

	var posMax:Float;
	var sid:Int;

	public var bonus:Int;
	public var step:Step;

	public var generator:Stykades;
	public var scroller:Scroller;
	public var fayot:Fayot;

	public var bads:Array<Bad>;
	public var shots:Array<Phys>;
	public var parts:Array<Part>;
	public var heros:Array<Hero>;
	public var sprites:Array<Sprite>;
	public var bgrid:Array<Array<Array<Bad>>>;
	public var sgrid:Array<Array<Array<BadShot>>>;

	public static var me:Game;

	public var dm:Plans;
	public var root:ASprite;

	var scene:ASprite;

	public var bomb:Bomb;
	public var mcStase:Stase;
	public var swap:{mc:Mc, sx:Float, sy:Float, tx:Float, ty:Float};
	public var htrg:Hero;
	public var speedLines:Array<Line>;
	public var victims:Array<Victim>;

	// clips whose timeline plays (Mc)
	public var mcs:Array<Mc>;

	var star:StarMc;
	var over:Bool;
	var frameCount:Int;
	var greyRoot:ColorMatrixFilter;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: UInt16Array.fromArray([
				KeyboardManager.LEFT, KeyboardManager.RIGHT, KeyboardManager.UP, KeyboardManager.DOWN, KeyboardManager.SPACE,
				KeyboardManager.ENTER, KeyboardManager.CONTROL
			]),
			recordInputs: true,
			recordEvents: false,
		});
		me = this;
		mt.bumdum.Sprite.clearAll();
		Clip.flushRemoved();
		Cs.init();
		over = false;
		frameCount = 0;
		mcs = [];

		scene = root.createEmptyMovieClip("scene", 0);
		scene._xscale = scene._yscale = 100 * K;
		scene.updateState();
		this.root = scene.createEmptyMovieClip("world", 0);
		dm = new Plans(this.root);

		flTwinMode = false;

		heros = [];
		sprites = [];
		shots = [];
		bads = [];
		parts = [];
		initGrid();
		initInter();

		fayot = {_k: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], _m: []};

		// SID
		sid = Seed.random(100000);

		// SMOKE LAYER (blurred)
		var mc = dm.plan(DP_UNDER_FX);
		var bl = new BlurFilter();
		bl.blur = 4;
		mc.filters = [bl];

		// SCROLLER (the clouds of the original were drawn in bitmaps during the first frames: all at once here)
		scroller = new Scroller();

		warmShaders();
		initPlay();
	}

	function initGrid() {
		bgrid = [];
		for (x in 0...Cs.XMAX) {
			bgrid[x] = [];
			for (y in 0...Cs.YMAX)
				bgrid[x][y] = [];
		}
		sgrid = [];
		for (x in 0...Cs.XMAX) {
			sgrid[x] = [];
			for (y in 0...Cs.YMAX)
				sgrid[x][y] = [];
		}
	}

	// cells of the grids (outside: a new empty list, like undefined in Flash)
	public function badCell(px:Int, py:Int):Array<Bad> {
		if (px < 0 || px >= Cs.XMAX || py < 0 || py >= Cs.YMAX)
			return [];
		return bgrid[px][py];
	}

	public function shotCell(px:Int, py:Int):Array<BadShot> {
		if (px < 0 || px >= Cs.XMAX || py < 0 || py >= Cs.YMAX)
			return [];
		return sgrid[px][py];
	}

	// one frame of the Flash player
	public function update(delta:Float) {
		frameCount++;
		Clip.flushRemoved();
		advanceClips();

		playAll();
		var list = mt.bumdum.Sprite.spriteList.copy();
		for (sp in list)
			sp.update();
	}

	// timelines of the Mc (before the code of the frame, like the Flash player)
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
		if (star != null)
			star.advance();
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

	public function playAll() {
		scroller.update();
		switch (step) {
			case Play:
				updatePlay();
			case Bomb:
				updateBomb();
			default:
		}
	}

	// PLAY
	public function initPlay() {
		step = Play;
		setBonus(0);
		generator = new Stykades(sid);

		var hid = 0;
		if (heros.length > 0)
			hid = 1 - heros[0].id;
		new Hero(hid);

		for (h in heros)
			h.birth();
	}

	public function updatePlay() {
		scroller.inc(1);
		generator.incDanger(1);
		var list = sprites.copy();
		for (s in list) {
			if (step != Play)
				return;
			s.update();
		}
	}

	// BOMB
	public function initBomb(hero:Hero, bomb:Bomb) {
		this.bomb = bomb;
		htrg = hero;
		step = Bomb;
		posMax = scroller.pos;
		coef = 0;
		sstep = 0;
		generator.danger = 0;

		for (p in parts)
			p.root._visible = false;
		var x = hero.x;
		var y = hero.y;

		// picture of the game without the enemies and their shots, grey, uncovered by a circle around the hero
		mcStase = dm.add(new Stase(), DP_FRONT);
		mcStase.rt = RenderTexture.create(Cs.mcw * K, Cs.mch * K);
		for (b in bads)
			b.root._visible = false;
		for (b in shots)
			b.root._visible = false;
		snapshot(mcStase.rt);
		for (b in bads)
			b.root._visible = true;
		for (b in shots)
			b.root._visible = true;

		var view = new PixiSprite(mcStase.rt);
		view.scale.set(1 / K);
		mcStase.addChild(view);
		mcStase.circle = new Graphics();
		mcStase.addChild(mcStase.circle);
		view.mask = mcStase.circle;
		var dx = Math.max(Math.abs(x), Math.abs(Cs.mcw - x));
		var dy = Math.max(Math.abs(y), Math.abs(Cs.mch - y));
		mcStase.ray = Math.sqrt(dx * dx + dy * dy);
		setStaseMask(x, y, 0);

		mcStase.light = dm.add(new Mc("reverseLight", false), DP_FRONT);
		mcStase.light._x = x;
		mcStase.light._y = y;
		mcStase.light._xscale = mcStase.light._yscale = 0;
		mcStase.light.blendMode = BlendModes.ADD;

		fige(mcStase, 1);

		// DESTROY
		victims = [];
		for (b in bads)
			b.addToVictims();
		for (s in shots)
			s.addToVictims();
		victims.sort(function(a:Victim, b:Victim) {
			if (a.ray < b.ray)
				return -1;
			return 1;
		});
	}

	var staseX:Float;
	var staseY:Float;

	// mcRound (a disc of 100) at the hero, scale sc: radius sc / 2
	function setStaseMask(x:Float, y:Float, sc:Float) {
		staseX = x;
		staseY = y;
		var g = mcStase.circle;
		g.clear();
		if (sc <= 0)
			return;
		g.beginFill(0xFFFFFF);
		g.drawCircle(x - mcStase._x, y - mcStase._y, sc * 0.5);
		g.endFill();
	}

	public function updateBomb() {
		switch (sstep) {
			case 0: // FADE OUT
				coef = Math.min(coef + 0.05, 1);
				var sc = coef * (mcStase.ray * 2);
				setStaseMask(staseX, staseY, sc);
				mcStase.light._xscale = mcStase.light._yscale = sc;

				while (victims.length > 0 && victims[0].ray < sc) {
					victims.shift().p.warp();
				}

				if (coef == 1) {
					mcStase.light.removeMovieClip();
					mcStase.rt.destroy(true);
					mcStase.removeMovieClip();
					mcStase = null;
					fige(root, 1);
					coef = 0;
					while (bads.length > 0)
						bads[0].warp();
					while (shots.length > 0)
						shots[0].warp();
					while (parts.length > 0)
						parts[0].kill();
					for (sp in mt.bumdum.Sprite.spriteList.copy())
						sp.kill();

					switch (bomb) {
						case Transfert:
							var other = htrg.getTwin();
							var mc = dm.add(new Mc("swap", false), DP_FX);
							mc._x = htrg.x;
							mc._y = htrg.y;
							swap = {
								mc: mc,
								sx: htrg.x,
								sy: htrg.y,
								tx: other.x,
								ty: other.y
							};
							sstep = 11;
							coef = 0;

						case Reverse:
							speedLines = [];
							for (i in 0...50) {
								var mc = dm.add(new Line("line", false), DP_FX);
								mc._x = Seed.randVfx() * Cs.mcw;
								mc._y = Seed.randVfx() * Cs.mch;
								mc.c = 0.1 + Seed.randVfx() * 0.5;
								mc._yscale = 0;
								mc._alpha = 40 + mc.c * 100;
								speedLines.push(mc);
							}
							sstep = 1;

						case Standard:
							sstep = 3;
					}
				}
			case 1:
				coef = Math.min(coef + 0.05, 1);
				if (coef == 1)
					sstep++;

			case 2: // REVERSE
				var parc = posMax - scroller.startPos;
				var sc = Num.mm(0.002, 10 / parc, 0.01);

				coef = Math.max(coef - sc, 0);
				var c = (1 - Math.cos(coef * 3.14)) * 0.5;

				scroller.setPos(scroller.startPos + c * parc);
				var vy = scroller.speed * Scroller.HIGHSPEED;

				for (mc in speedLines) {
					mc._y += vy * mc.c;
					mc._yscale = -vy * mc.c;
					if (mc._y + mc._yscale < 0) {
						mc._x = Seed.randVfx() * Cs.mcw;
						mc._y = Cs.mch;
						mc.updateState();
					}
				}

				if (coef == 0) {
					while (speedLines.length > 0)
						speedLines.pop().removeMovieClip();
					scroller.setPos(scroller.startPos);
					sstep = 3;
				}

			case 3: // FADE IN
				coef = Math.min(coef + 0.1, 1);
				fige(root, 1 - coef);
				if (coef == 1) {
					root.filters = null;
					switch (bomb) {
						case Transfert:
							step = Play;
						case Standard:
							step = Play;
						case Reverse:
							initPlay();
							flTwinMode = true;
					}
				}

			case 11: // TRANSFERT
				coef = Math.min(coef + 0.05, 1);
				var cc = (1 - Math.cos(coef * 3.14)) * 0.5;
				var ox = swap.mc._x;
				var oy = swap.mc._y;
				swap.mc._x = swap.sx * (1 - cc) + swap.tx * cc;
				swap.mc._y = swap.sy * (1 - cc) + swap.ty * cc - 80 * Math.sin(coef * 3.14);

				var dx = swap.mc._x - ox;
				var dy = swap.mc._y - oy;
				var mc = dm.attach("queue", Game.DP_FX);
				mc.removeAfter = true;
				mc._x = ox;
				mc._y = oy;
				mc._xscale = Math.sqrt(dx * dx + dy * dy);
				mc._rotation = Math.atan2(dy, dx) / 0.0174;
				mc.updateState();
				if (coef == 1) {
					swap.mc.removeMovieClip();
					coef = 0;
					sstep = 3;
					var mc = dm.attach("warp", Game.DP_FX);
					mc.removeAfter = true;
					mc._x = swap.tx;
					mc._y = swap.ty;
					mc._xscale = mc._yscale = 300;
				}
		}
	}

	// picture of the game (mcStase.bmp.draw(root))
	function snapshot(rt:RenderTexture) {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var px = root.position.x, py = root.position.y;
		root.position.set(0, 0);
		renderer.render(root, {renderTexture: rt, clear: true, transform: new Matrix(K, 0, 0, K, 0, 0)});
		root.position.set(px, py);
	}

	// GAMEOVER
	public function initGameOver() {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			twin: flTwinMode
		};
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	public function addScore(n:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	// INTERFACES (mcInter: the star with the bonus, at the bottom left; the level field is hidden)
	public function initInter() {
		star = dm.add(new StarMc(), DP_INTER);
		star._x = Data.STAR_POS[0];
		star._y = Cs.mch + Data.STAR_POS[1];
		star._xscale = Data.STAR_POS[2] * 100;
		star._yscale = Data.STAR_POS[3] * 100;
	}

	public function setBonus(n:Int) {
		bonus = n;
		star.setText(Std.string(n));
		if (n > 0)
			star.gotoAndPlay(2);
	}

	public function incBonus(n:Int) {
		setBonus(bonus + n);
	}

	public function setLevel(n:Int) {}

	// FX
	public function genScore(x:Float, y:Float, n:Int, col:Int) {
		var p = new ScorePart(n, col);
		p.x = x;
		p.y = y;
		p.vy = -3;
		p.timer = 15;
		p.weight = 0.5;
		p.fadeLimit = 5;
		p.setScale(70 + Math.pow(n, 0.5));
		p.updatePos();
		p.root.updateState();
	}

	// Filt.grey(mc, c, 30): towards a grey (0.25 r + 0.15 g + 0.6 b + 30)
	public function fige(mc:ASprite, c:Float) {
		var m0 = [1.0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
		var r = 0.25, g = 0.15, b = 0.6, o = 30 / 255;
		var m1 = [r, g, b, 0, o, r, g, b, 0, o, r, g, b, 0, o, 0, 0, 0, 1, 0];
		var m = [for (i in 0...20) m0[i] * (1 - c) + m1[i] * c];
		var f:ColorMatrixFilter = mc == root ? greyRoot : null;
		if (f == null) {
			f = new ColorMatrixFilter();
			if (mc == root)
				greyRoot = f;
		}
		f.matrix = m;
		mc.filters = [f];
	}

	// TOOLS
	public function getMainHero():{x:Float, y:Float} {
		var h = heros[0];
		if (h == null)
			return {x: Cs.mcw * 0.5, y: Cs.mch - 5.0};
		return {x: h.x, y: h.y};
	}

	public function isPlaying() {
		return step == Play;
	}

	// joystick of the touch screens: the arrows
	public function pollTouchControls():Void {
		var joystick = KadoKadeoManager.kkm.getTouchJoystickState();
		if (joystick == null)
			return;
		var axisX = joystick.active ? joystick.dirX : 0;
		var axisY = joystick.active ? joystick.dirY : 0;
		setKey(KeyboardManager.LEFT, axisX < 0);
		setKey(KeyboardManager.RIGHT, axisX > 0);
		setKey(KeyboardManager.UP, axisY < 0);
		setKey(KeyboardManager.DOWN, axisY > 0);
	}

	inline function setKey(keyCode:Int, down:Bool):Void {
		if (down)
			KeyboardManager.setKeyDown(keyCode);
		else
			KeyboardManager.setKeyUp(keyCode);
	}

	// The first use of a shader compiles it on the graphics card (tens of ms of freeze): the filters of the game are
	// drawn once now, off screen.
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		s.filters = [new BlurFilter()];
		holder.addChild(s);
		var s2 = new PixiSprite(Texture.WHITE);
		s2.filters = [new ColorMatrixFilter()];
		holder.addChild(s2);
		var s3 = new PixiSprite(Texture.WHITE);
		Filt.glow(s3, 8, 2, 0xFF0000, false, 0.2);
		holder.addChild(s3);
		var add = new PixiSprite(Texture.WHITE);
		add.blendMode = BlendModes.ADD;
		add.tint = 0x808080;
		holder.addChild(add);
		var masked = new PixiSprite(Texture.WHITE);
		var mask = new Graphics();
		mask.beginFill(0xFFFFFF);
		mask.drawCircle(4, 4, 4);
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
		if (mcStase != null && mcStase.rt != null)
			mcStase.rt.destroy(true);
		mt.bumdum.Sprite.clearAll();
		Clip.flushRemoved();
		mcs = [];
	}
}

// digits of the Impact font of the SWF, centred in a Flash field ([left, width, top, xscale, yscale])
class Digits extends ASprite {
	var field:Array<Float>;
	var glowCol:Null<Int>;
	var text:String;

	public function new(field:Array<Float>, ?glowCol:Null<Int>) {
		super();
		this.field = field;
		this.glowCol = glowCol;
		text = "";
	}

	public function setText(s:String) {
		if (s == text)
			return;
		text = s;
		removeChildren();
		var sx = field[3], sy = field[4];
		var width = 0.0;
		for (i in 0...s.length)
			width += Data.DIGIT_ADV[s.charCodeAt(i) - 48];
		var pen = field[0] + (field[1] - width * sx) / 2;
		var base = field[2] + Data.DIGIT_ASC * sy;
		for (pass in 0...(glowCol != null ? 2 : 1)) {
			var pp = pen;
			for (i in 0...s.length) {
				var d = s.charCodeAt(i) - 48;
				if (d < 0 || d > 9)
					continue;
				var g = new Mc(glowCol != null && pass == 0 ? "digitGlow" : "digit", false);
				g.gotoAndStop(d + 1);
				if (glowCol != null && pass == 0)
					g.tint = glowCol;
				g._x = pp;
				g._y = base;
				g._xscale = sx * 100;
				g._yscale = sy * 100;
				addChild(g);
				pp += Data.DIGIT_ADV[d] * sx;
			}
		}
	}
}

// partScore: the number grows (frames 1-5 of its field) then stays
class ScorePart extends Part {
	var smc:Digits;
	var f:Int;

	public function new(n:Int, col:Int) {
		super(Game.me.dm.empty(Game.DP_FX));
		smc = new Digits(Data.FIELD_SCORE, col);
		smc.setText(Std.string(n));
		root.addChild(smc);
		f = 0;
		show();
	}

	function show() {
		var m = Data.PSCORE[f];
		smc._x = m[0];
		smc._y = m[1];
		smc._xscale = m[2] * 100;
		smc._yscale = m[3] * 100;
	}

	override public function update() {
		if (f < 4) {
			f++;
			show();
		}
		super.update();
	}
}

// mcInter.star: still on frame 1, plays frames 2-12 when the bonus grows (the star and its number swell)
class StarMc extends ASprite {
	var pic:Mc;
	var field:ASprite;
	var digits:Digits;
	var f:Int;
	var playing:Bool;

	public function new() {
		super();
		pic = new Mc("star", false);
		addChild(pic);
		field = new ASprite();
		addChild(field);
		digits = new Digits(Data.FIELD_STAR, 0x990000);
		field.addChild(digits);
		f = 1;
		playing = false;
		show();
	}

	public function setText(s:String) {
		digits.setText(s);
	}

	override public function gotoAndPlay(fr:Dynamic) {
		f = Std.int(fr);
		playing = true;
		show();
	}

	public function advance() {
		if (!playing)
			return;
		f++;
		if (f > 12) {
			f = 1;
			playing = false;
		}
		show();
	}

	function show() {
		var a = Data.STAR[f - 1], b = Data.STAR_SMC[f - 1];
		pic._x = a[0];
		pic._y = a[1];
		pic._xscale = a[2] * 100;
		pic._yscale = a[3] * 100;
		pic._rotation = a[4];
		field._x = b[0];
		field._y = b[1];
		field._xscale = b[2] * 100;
		field._yscale = b[3] * 100;
		field._rotation = b[4];
	}
}

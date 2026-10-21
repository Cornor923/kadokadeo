package crepuscud;

import haxe.io.Bytes;
import js.html.IFrameElement;
import mt.bumdum.Sprite;
import mt.bumdum.Phys;
import mt.bumdum.Part;
import mt.bumdum.Lib;
import mt.bumdum.Plasma;
import pixi.core.math.Matrix;
import pixi.core.Pixi.BlendModes;
import pixi.core.math.shapes.Rectangle;
import pixi.filters.colormatrix.ColorMatrixFilter;
import pixi.core.text.Text;
import common_haxe_avm1.KKApi;
import common_haxe_avm1.PixelHelper;
import common_haxe_avm1.MouseManager;
import haxe.io.UInt16Array;

enum Step {
	Play;
	GameOver;
}

class McField extends ASprite {
	public var field:Text;
}

class HeroSprite extends ASprite {
	public var gun:ASprite;
}

typedef GROUP = {id:Int};

@:expose('GameCrepuscud')
class Game implements kado.GameInterface {
	public static var GH = KadoKadeoManager.S(20);
	public static var RGH = KadoKadeoManager.S(14);
	public static var GY = 0;
	public static var RGY = 0;
	public static var DX = KadoKadeoManager.S(22);

	public static var DP_BG = 0;
	public static var DP_PLASMA = 1;
	public static var DP_ONDE = 2;
	public static var DP_MISSILE = 3;
	public static var DP_PARTS = 6;
	public static var DP_GROUND = 7;
	public static var DP_INTER = 8;
	public static var DP_SCORE = 9;

	public var flGameOver:Bool;

	public var expl:Int;
	public var fade:Float;

	public var dif:Float;
	public var angle:Float;
	public var totalSpeed:Float;
	public var replenish:Float;

	public var cmun:Int;
	public var munitions:Array<ASprite>;
	public var muniCount:Float;
	public var brushQueueMissile:ASprite;

	public var hero:HeroSprite;
	public var heroBase:HeroSprite;
	public var missiles:Array<Missile>;
	public var patriots:Array<Patriot>;
	public var holes:Array<Float>;

	public var mcExplode:ASprite;

	public var bmpGround:RenderTexture;

	// The ground of the gameplay, GH rows of Cs.mcw pixels (1: ground), computed by the CPU like bmpGround is drawn (the
	// strip, the elements, the holes): the pixels of the picture, drawn by the GPU, differ from a machine to another at
	// the edges (and the replay verifier of the server draws without GPU), so a replay read them differently
	var ground:Bytes;
	var groundCpu:Bool;

	// replay event at frame 0: the game uses the ground of the CPU
	static inline var EV_GROUND_CPU = 1;

	// mcGroundElement (frames 1-5): its pixels of alpha >= 128, a rectangle of its 113 x 13 picture (anchor 0.5, 0.947)
	static var ELEMENT_FRAMES = [0, 0, 1, 1, 2];
	static var ELEMENT_SHAPES:Array<{x:Int, y:Int, rows:Array<String>}> = [
		{
			x: 38,
			y: 0,
			rows: [
				"..............########...............",
				"...........##############............",
				".........##################..........",
				"........####################.........",
				"......########################.......",
				".....##########################......",
				".....###########################.....",
				"....############################.....",
				"...##############################....",
				"...###############################...",
				"..################################...",
				"..################################...",
				"..################################...",
			]
		},
		{
			x: 22,
			y: 0,
			rows: [
				"............................############............................",
				"......................########################......................",
				"...................##############################...................",
				"................####################################................",
				"..............########################################..............",
				"............############################################............",
				"..........################################################..........",
				"........####################################################........",
				".......######################################################.......",
				".....#########################################################......",
				"....############################################################....",
				"...##############################################################...",
				"...##############################################################...",
			]
		},
		{
			x: 0,
			y: 3,
			rows: [
				".................................................................................................................",
				".................................................................................................................",
				"..........................................############################...........................................",
				"..............................####################################################...............................",
				"......................####################################################################.......................",
				"................################################################################################.................",
				"...........##########################################################################################............",
				".......##################################################################################################........",
				"...##########################################################################################################....",
				".................................................................................................................",
			]
		},
	];
	static inline var ELEMENT_ANCHOR_X = 56.5;
	static inline var ELEMENT_ANCHOR_Y = 12.315784;
	// mcOnde: a disc of 100 pixels of radius (200 x 200, anchor 0.5)
	static inline var HOLE_RAY = 100;

	public var step:Step;
	public var plasma:Plasma;
	public var dm:mt.DepthManager;
	public var edm:mt.DepthManager;
	public var root:ASprite;
	public var bg:ASprite;

	public var playerTargetX:Int;
	public var playerTargetY:Int;

	public static var me:Game;

	var isClickRegistered:Bool = false;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayMouseButtons = new UInt16Array(1);
		replayMouseButtons[0] = MouseManager.BUTTON_LEFT;
		var replay = KadoKadeoManager.kkm.replay;
		replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			// (only EV_GROUND_CPU)
			recordEvents: true,
			recordMousePosition: true,
			recordedMouseButtons: replayMouseButtons,
		});
		// the ground computed by the CPU (see ground): the replays recorded before it (2026-10) read the pixels of the
		// picture, like their live game
		if (replay.isPlayingReplay()) {
			groundCpu = Lambda.exists(replay.getReplayEvents(), (e) -> e.event != null && e.event.k == EV_GROUND_CPU);
		} else {
			groundCpu = true;
			replay.recordEvent({k: EV_GROUND_CPU}, 0);
		}

		this.root = root;
		me = this;
		dm = new mt.DepthManager(root);

		initBg();

		GY = Std.int(Cs.mch - GH);
		RGY = Std.int(Cs.mch - RGH);

		flGameOver = false;
		dif = 1;
		totalSpeed = 0;
		replenish = 0;
		expl = 0;

		missiles = [];
		patriots = [];
		munitions = [];
		muniCount = 0;
		cmun = 0;
		incMunition(12);

		initPlasma();
		initDecor();

		initPlay();
	}

	function initBg() {
		bg = dm.empty(DP_BG);
		var bmp = RenderTexture.create(Cs.mcw, Cs.mch);
		bg.attachBitmap(bmp, 0);

		// FOND
		var mc = dm.attach("mcBg", 0);
		bmp.draw(mc, new Matrix());
		mc.removeMovieClip();

		// STARS
		var mc = dm.attach("mcStar", 0);
		for (i in 0...100) {
			var m = new Matrix();
			var py = Math.pow(Seed.randVfx(), 3) * 100 - 5;
			var sc = 0.2 + Seed.randVfx() * 0.8;
			m.scale(sc, sc);
			m.translate(Seed.randVfx() * Cs.mcw, py);

			mc.blendMode = BlendModes.ADD;
			bmp.draw(mc, m);
			mc.blendMode = BlendModes.NORMAL;
		}
	}

	function initDecor() {
		// BRUSHES
		brushQueueMissile = dm.attach("queueMissile", DP_PLASMA);
		brushQueueMissile._visible = false;

		// GROUND
		bmpGround = RenderTexture.create(Cs.mcw, GH);
		var mc = dm.empty(DP_GROUND);
		var gdm = new mt.DepthManager(mc);
		mc._y = GY;
		mc.attachBitmap(bmpGround, 0);
		Filt.glow(mc, 4, 2, 0xCC6600, true);
		Filt.glow(mc, 2, 2, 0xCC6600); // TODO filt.glow à bannir et à mettre sur l'image directement

		bmpGround.fillRect(new Rectangle(0, GH - RGH, Cs.mcw, RGH), 0x000000);
		ground = Bytes.alloc(Std.int(Cs.mcw) * Std.int(GH));
		for (y in Std.int(GH - RGH)...Std.int(GH))
			ground.fill(y * Std.int(Cs.mcw), Std.int(Cs.mcw), 1);

		// ELEMENTS
		var mc = dm.attach("mcGroundElement", 0);
		var ma = KadoKadeoManager.I(40);
		for (i in 0...24) {
			var sc = 0.5 + Seed.randVfx() * 0.5;
			var m = new Matrix();
			m.scale(sc, sc);
			var tx = ma + Seed.randomVfx(Cs.mcw - ma);
			m.translate(tx, GH - RGH);
			var frame = Seed.randomVfx(mc._totalframes) + 1;
			mc.gotoAndStop(frame);
			bmpGround.draw(mc, m);
			groundElement(frame, sc, tx, GH - RGH);
		}
		mc.removeMovieClip();

		// HERO BASE
		heroBase = cast gdm.attach("mcBaseCanon", 10);
		heroBase._y = GH - RGH;
		heroBase._x = DX;

		// HERO
		hero = cast gdm.attach("mcCanon", 10);
		hero._y = GH - RGH;
		hero._x = DX;

		// EXPLODE
		mcExplode = dm.empty(DP_ONDE);
		edm = new mt.DepthManager(mcExplode);
		mcExplode._alpha = 25;
	}

	// UPDATE
	public function update(delta:Float) {
		mt.Timer.tmod /= 2; // GAME WAS BUILT WITH 2 CALLS TO mt.Timer.update
		updateMouseInput();

		switch (step) {
			case Play:
				updatePlay();
			case GameOver:
				updateGameOver();
			case _:
		}

		plasma.drawMc(mcExplode);
		fade += mt.Timer.tmod;
		if (fade > 1) {
			var n = Math.floor(fade);
			var plasmaCt = new ColorMatrixFilter();
			plasmaCt.matrix = [
				1, 0, 0, 0,           0,
				0, 1, 0, 0,           0,
				0, 0, 1, 0,           0,
				0, 0, 0, 1, -n * 2 / 255,
			];
			plasma.ct = plasmaCt;
			fade -= n;
		}

		plasma.update();

		Sprite.updateAll();

		if (cmun != munitions.length)
			KKApi.flagCheater();
	}

	// PLAY
	function initPlay() {
		step = Play;
	}

	function updatePlay() {
		moveHero();

		dif += 0.005 * mt.Timer.tmod;

		replenish += mt.Timer.tmod;
		if (replenish > Cs.REPLENISH_CYCLE) {
			replenish -= Cs.REPLENISH_CYCLE;
			incMunition(1);
		}

		//
		if (!flGameOver && (totalSpeed / KadoKadeoManager.I(1)) < dif * 1.5 + Missile.BOOST * 8) {
			new Missile();
		}

		// GAMEOVER
		if (flGameOver) {
			var p = new Fly(dm.attach("mcFly", DP_GROUND));
			p.x = holes[Seed.random(holes.length)] + (Seed.randVfx() * 2 - 1) * 2;
			p.y = Cs.mch + 5;
		}
	}

	function moveHero() {
		var dx = MouseManager.getX() - DX;
		var dy = MouseManager.getY() - RGY;
		angle = Num.mm(-1.57, Math.atan2(dy, dx), -0.05);
		hero._rotation = angle / 0.0174;
	}

	// GAMEOVER
	function initGameOver() {
		if (flGameOver)
			return;

		holes = [];
		while (patriots.length > 0)
			patriots[0].kill();
		flGameOver = true;
		KadoKadeoManager.kkm.gameOver({});
	}

	function updateGameOver() {}

	//
	function launchMissile() {
		if (flGameOver)
			return;
		if (muniCount == 0) {
			return;
		}

		moveHero();

		incMunition(-1);
		var p = new Patriot();
	}

	// PLASMA
	function initPlasma() {
		plasma = new Plasma(dm.empty(DP_PLASMA), Cs.mcw, Cs.mch, 0.5);
		var plasmaCt = new ColorMatrixFilter();
		plasmaCt.matrix = [
			1, 0, 0, 0,       0,
			0, 1, 0, 0,       0,
			0, 0, 1, 0,       0,
			0, 0, 0, 1, -2 / 255,
		];
		plasma.ct = plasmaCt;
		plasma.root.blendMode = BlendModes.ADD;
		fade = 0;
		plasma.root.blendMode = BlendModes.NORMAL;
	}

	// TOOLS
	public function addScore(x, y, sc, cid) {
		KadoKadeoManager.kkm.addScore(sc);

		var score = KKApi.val(sc);

		var p = new Phys(dm.empty(DP_SCORE));
		p.x = x;
		p.y = y;
		p.timer = 12;
		p.fadeLimit = 5;
		p.fadeType = 4;

		var mc:McField = cast p.root;
		mc.field = mc.initTextField("field", {
			color: 0x000000,
			align: "center",
			font: "Pricedown",
			size: 45,
			stroke: "#FFFFFF",
			strokeThickness: 4,
		});
		mc.field.text = Std.string(score);
		if (cid != null) {
			var co = Col.colToObj(Missile.COLOR[cid]);
			var inc = -100;
			co.r = Std.int(Math.max(0, co.r + inc));
			co.g = Std.int(Math.max(0, co.g + inc));
			co.b = Std.int(Math.max(0, co.b + inc));

			mc.field.style.fill = Col.objToCol(co);
		}
	}

	public function incMunition(inc) {
		cmun = Std.int(Num.mm(0, cmun + inc, Cs.MISSILE_MAX));
		var goal = Num.mm(0, munitions.length + inc, Cs.MISSILE_MAX);
		muniCount = goal;
		while (goal < munitions.length)
			munitions.pop().removeMovieClip();
		while (goal > munitions.length) {
			var mc = Game.me.dm.attach("mcMunition", DP_INTER);
			mc._x = KadoKadeoManager.I(4);
			mc._y = KadoKadeoManager.S(283) - munitions.length * KadoKadeoManager.I(5);
			munitions.push(mc);
		}
	}

	public function makeHole(x:Float, y:Float, sc:Float) {
		var mc = dm.attach("mcOnde", 0);
		mc.play();
		var m = new Matrix();
		m.scale(sc, sc);
		m.translate(Std.int(x), Std.int(y - GY));
		mc.blendMode = untyped BlendModes.ERASE;
		bmpGround.draw(mc, m);
		mc.removeMovieClip();
		groundHole(Std.int(x), Std.int(y - GY), HOLE_RAY * sc);
		if (y + sc * 50 > Cs.mch + 1) {
			initGameOver();
			holes.push(x);
		}
	}

	public function getGroundHeight(x:Int) {
		if (groundCpu) {
			var w = Std.int(Cs.mcw);
			// (outside: the first row, like the pixels read out of the picture)
			if (x < 0 || x >= w)
				return GY;
			for (y in 0...Std.int(GH)) {
				if (ground.get(y * w + x) != 0)
					return GY + y;
			}
			return Cs.mch;
		}
		var pixels = PixelHelper.extract(bmpGround);
		for (y in 0...Std.int(GH)) {
			if (pixels.getPixelAlpha(x, y) != 0)
				return GY + y;
		}
		return Cs.mch;
	}

	// an element drawn at (tx, ty) scaled by sc: the pixels whose middle falls on a pixel of its picture
	function groundElement(frame:Int, sc:Float, tx:Float, ty:Float) {
		var shape = ELEMENT_SHAPES[ELEMENT_FRAMES[frame - 1]];
		var w = Std.int(Cs.mcw), h = Std.int(GH);
		var sw = shape.rows[0].length, sh = shape.rows.length;
		var x0 = Std.int(Math.max(0, Math.floor(tx + (shape.x - ELEMENT_ANCHOR_X) * sc)));
		var x1 = Std.int(Math.min(w, Math.ceil(tx + (shape.x + sw - ELEMENT_ANCHOR_X) * sc)));
		var y0 = Std.int(Math.max(0, Math.floor(ty + (shape.y - ELEMENT_ANCHOR_Y) * sc)));
		var y1 = Std.int(Math.min(h, Math.ceil(ty + (shape.y + sh - ELEMENT_ANCHOR_Y) * sc)));
		for (py in y0...y1) {
			var v = Math.floor((py + 0.5 - ty) / sc + ELEMENT_ANCHOR_Y) - shape.y;
			if (v < 0 || v >= sh)
				continue;
			var row = shape.rows[Std.int(v)];
			for (px in x0...x1) {
				var u = Math.floor((px + 0.5 - tx) / sc + ELEMENT_ANCHOR_X) - shape.x;
				if (u >= 0 && u < sw && row.charCodeAt(Std.int(u)) == "#".code)
					ground.set(py * w + px, 1);
			}
		}
	}

	// mcOnde drawn with ERASE at (cx, cy): the pixels whose middle is in its disc
	function groundHole(cx:Int, cy:Int, ray:Float) {
		var w = Std.int(Cs.mcw), h = Std.int(GH);
		var r2 = ray * ray;
		var x0 = Std.int(Math.max(0, Math.floor(cx - ray))), x1 = Std.int(Math.min(w, Math.ceil(cx + ray) + 1));
		var y0 = Std.int(Math.max(0, Math.floor(cy - ray))), y1 = Std.int(Math.min(h, Math.ceil(cy + ray) + 1));
		for (py in y0...y1) {
			var dy = py + 0.5 - cy;
			for (px in x0...x1) {
				var dx = px + 0.5 - cx;
				if (dx * dx + dy * dy < r2)
					ground.set(py * w + px, 0);
			}
		}
	}

	public function destroy():Void {}

	function updateMouseInput():Void {
		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT)) {
			launchMissile();
		}
	}
}

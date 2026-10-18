package mel;

import haxe.io.UInt16Array;
import common_haxe_avm1.display.ASprite;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import pixi.core.graphics.Graphics;
import mel.Lib;
import mel.Gfx;
import mel.Char;
import mel.Ui;

/**
 * Mel (Arkadeo, Motion Twin 2012), the league mode: Mel climbs the city as high as she can, the pulpz (the swarm)
 * rising under her. Game.hx of the original (a flash.display.Sprite: the root of the game, gs here), then the parts of
 * the port.
 *
 * The game area of Arkadeo: 600 x 460 pixels, drawn at 1 canvas pixel per Flash pixel, the bar of KadoKadeo under it
 * (the canvas of an Arkadeo game is 600 x 500).
 */
@:expose('GameMel')
class Game implements kado.GameInterface {
	// left / right run, the jump button jumps (double jump in the air), down charges a jump on the ground, kicks an
	// enemy in the air, leaves a wall, cancels a double jump; G (✋) switches the Mag Grips off / on (not in the original)
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left",
				label: "◀",
				leftPx: 14,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.LEFT,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 112,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.RIGHT,
			},
			{
				id: "down",
				label: "▼",
				rightPx: 112,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.DOWN,
			},
			{
				id: "jump",
				label: "▲",
				rightPx: 14,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.SPACE,
			},
			{
				// over the jump: the Mag Grips off / on (key G)
				id: "grip",
				label: "✋",
				rightPx: 24,
				bottomPx: 112,
				size: 64,
				keyCode: KeyboardManager.G,
			}
		],
	};

	// ZQSD / WASD like the arrows (up jumps)
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	// Mel ran at 40 Flash frames per second (the rate of its SWF)
	public static inline var FLASH_FPS = 40;

	public var view:View;
	public var level:Level;
	public var char:Char;

	public static var me:Game;

	public var tweenie:Tweenie;
	public var fxMan:Manager;
	public var ui:Ui;

	public var time:{ufr:Int};

	public var score:Int = 0;
	public var fixScore:Int = 0;

	public var rd:Rand;

	public static function showScore()
		return isLeague();

	public static function isLevelup()
		return false;

	// KadoKadeo plays the league mode of Arkadeo (an endless climb, a score)
	public static function isLeague()
		return true;

	// (AKApi.getLevel() - 1: the league is not a level)
	public static function getLevel()
		return 0;

	public static var conf:{?deadLine:Bool, ?deadLineSpeed:Float, ?spawnBonuses:Bool};

	public function getRandom():Rand {
		return new Rand(getSeed() ^ Game.getFrame());
	}

	// ---------------------------------------------------------------- the port
	// the Sprite of the original Game (its children: the planes, the view, the interface...)
	public var gs:Sprite;

	var root:ASprite;
	var isReplay:Bool;
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	var over:Bool = false;
	var keyPrev:Map<Int, Bool> = new Map();
	var keyNow:Map<Int, Bool> = new Map();
	var seed:Int;

	public var pause:Bool = false;

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(7);
		keys[0] = KeyboardManager.LEFT;
		keys[1] = KeyboardManager.RIGHT;
		keys[2] = KeyboardManager.UP;
		keys[3] = KeyboardManager.DOWN;
		keys[4] = KeyboardManager.SPACE;
		keys[5] = KeyboardManager.CONTROL;
		keys[6] = KeyboardManager.G;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		root = mc;
		OverlayBlend.register(KadoKadeoManager.kkm.renderer);
		// the seed of the game (AKApi.getSeed): every random of the original derives from it
		seed = Seed.random(0x3FFFFFFF);
		Flash.reset();
		Tex.init("/mel/");
		Clip.init(Art.clips);
		TextField.init(() -> Art.meta().fonts);
		FTimer.clear();
		Fx.DEFAULT_MANAGER = null;
		Level.SKIP_VIEW_SYNC = false;
		Level.cry = -1;
		Level.cfx = -1;

		gs = new Sprite();
		root.addChild(gs.node);
		// the game area of Arkadeo (600 x 460): what goes out of it is not drawn (under the bar of KadoKadeo)
		var mask = new Graphics();
		mask.beginFill(0xFFFFFF);
		mask.drawRect(0, 0, Lib.w(), Lib.h());
		mask.endFill();
		root.addChild(mask);
		gs.node.mask = mask;

		me = this;
		rd = new Rand(I32.of(0xdeadbeef + getSeed()));

		fxMan = new Manager();

		Nmy.create();
		time = {ufr: 0};

		conf = {deadLine: Game.isLeague(), spawnBonuses: false};
		conf.spawnBonuses = true;

		tweenie = new Tweenie(40);

		addChild(view = new View());
		level = new Level();
		level.init();
		view.addChild(level.getRoot());

		ui = new Ui();

		warmShaders();
		Flash.display(gs, 1);
	}

	public function hasDeadLine() {
		if (Level.NO_DEADLINE)
			return false;
		return conf != null && conf.deadLine == true;
	}

	// one frame of the original (Game.update on ENTER_FRAME)
	function origUpdate() {
		time.ufr++;
		if (level.gameOverCalled)
			return;

		rd.initSeed(I32.of(getFrame() + getSeed() * 1337.0) ^ 0xdeadbeef, 2);

		// (the port: key G, the Mag Grips off / on)
		if (!pause && isKeyToggled(KeyboardManager.G))
			char.toggleGrip();

		if (!pause)
			level.update();

		tweenie.update();
		fxMan.update();
		FTimer.update();
		if (level.gameOverCalled)
			return;

		var nscore = fixScore + Std.int(char.getAbsCy() * 20);
		if (nscore > score) {
			addScore(nscore - score);

			var v = Math.abs(I32.of((Game.getLevel() * 48683843.0 + Game.getSeed() * 1.0 * score) % 500));
			if (Game.isLeague())
				if (v == 1)
					new SMS(Data.getSmsVar());
			score = nscore;
		}

		ui.update();
		view.update();
	}

	public static function getFrame():Int {
		return me.frameCount;
	}

	public static function getSeed():Int {
		return me.seed;
	}

	public static function isKeyDown(k:Int):Bool {
		return me.keyNow.exists(k);
	}

	// pressed on this frame (down now, up on the previous Flash frame)
	public static function isKeyToggled(k:Int):Bool {
		return me.keyNow.exists(k) && !me.keyPrev.exists(k);
	}

	public static function isLowQuality()
		return false;

	// ---------------------------------------------------------------- the Sprite of the original Game
	public function addChild(o:DisplayObject):DisplayObject
		return gs.addChild(o);

	public function setChildIndex(o:DisplayObject, i:Int)
		gs.setChildIndex(o, i);

	public var numChildren(get, never):Int;

	inline function get_numChildren()
		return gs.numChildren;

	public var filters(get, set):Array<BitmapFilter>;

	inline function get_filters()
		return gs.filters;

	inline function set_filters(f:Array<BitmapFilter>) {
		gs.filters = f;
		return f;
	}

	public function isReplayGame()
		return isReplay;

	// ---------------------------------------------------------------- KadoKadeo step: 5 Flash frames every 4 steps
	public function update(delta:Float) {
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame();
		}
		Flash.display(gs, frameAcc / 4);
	}

	// one Flash frame: the playheads advance, then the game (enterFrame), then the frame scripts of the timelines
	function flashFrame() {
		keyNow = new Map();
		for (k in [KeyboardManager.LEFT, KeyboardManager.RIGHT, KeyboardManager.UP, KeyboardManager.DOWN, KeyboardManager.SPACE,
			KeyboardManager.CONTROL, KeyboardManager.G])
			if (KeyboardManager.isDown(k))
				keyNow.set(k, true);
		Flash.frameStart(gs);
		MovieClip.tickAll();
		origUpdate();
		Clip.runPending();
		keyPrev = keyNow;
		frameCount++;
		#if debug
		untyped js.Browser.window.__mel = endState();
		#end
	}

	#if debug
	// the state compared between a game and its replay (test bots)
	function endState():Dynamic {
		return {
			frame: frameCount,
			score: score,
			cx: char.cx,
			cy: char.cy,
			rx: char.rx,
			ry: char.ry,
			pv: char.pv,
			state: Std.string(char.state),
			powers: char.powers.toInt(),
			life: level.life,
			over: over,
			nmy: [for (l in level.nmyLists()) l.length],
			fix: fixScore,
		};
	}
	#end

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
			new GlowFilter(0, 1, 3, 3, 2),
			new BlurFilter(4, 4),
			new ColorMatrixFilter([0.3, 0.59, 0.11, 0, 0, 0.3, 0.59, 0.11, 0, 0, 0.3, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0])
		];
		for (f in fl) {
			var d = new Shape();
			d.graphics.beginFill(0xFFFFFF);
			d.graphics.drawRect(0, 0, 8, 8);
			d.graphics.endFill();
			d.filters = [f];
			holder.addChild(d.node);
		}
		var ov = new pixi.core.sprites.Sprite(pixi.core.textures.Texture.WHITE);
		ov.filters = [new OverlayBlend()];
		holder.addChild(ov);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function destroy():Void {
		over = true;
		Flash.reset();
		FTimer.clear();
		if (level != null && level.plan4Tex != null)
			level.plan4Tex.destroy(true);
		me = null;
	}

	// trigonometry and powers that move the game, rounded (their last bits may differ between browsers)
	public static inline function q(v:Float):Float {
		return Math.round(v * 1e9) / 1e9;
	}
}

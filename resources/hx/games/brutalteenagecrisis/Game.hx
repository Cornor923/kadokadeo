package brutalteenagecrisis;

import haxe.io.UInt16Array;
import common_haxe_avm1.display.ASprite;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import mt.deepnight.Particle;
import mt.deepnight.slb.AnimManager;
import mt.deepnight.slb.BSprite;

// Brutal Teenage Crisis (Arkadeo, Motion Twin, 600 x 460 at 30 frames/s), its League. The code is the Arkadeo HTML5
// port of the original Haxe sources: the logic of the original on the AS3 display list of the lib (arkadeo, over the
// ASprite of the site) and the SpriteLib mt.deepnight.slb. This class replaces its Boot and the
// original Game: KadoKadeo creates it, steps it and records its replay (the arrows and space, polled by the hero every
// frame); the game gives its score and its end to KadoKadeo (addScore, onGameOver).
//
// What the Arkadeo HTML5 port added to the original and is kept here (Boot.hx there): the hero's fall speed is capped
// and the hero stays under a ceiling (the Fly's charge threw it out of the map), a hero thrown under the map is put
// back on the ground, and the super power gives a higher jump while up is held. They ran once per displayed picture
// there: here once per frame of the game, right after it.
@:expose('GameBrutalTeenageCrisis')
class Game implements kado.GameInterface {
	// arrows on the left, jump / go down on the right, the phase (space) above the jump; clear of the score bar
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left",
				label: "◀",
				leftPx: 8,
				bottomPx: 48,
				size: 50,
				keyCode: KeyboardManager.LEFT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 66,
				bottomPx: 48,
				size: 50,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "down",
				label: "▼",
				rightPx: 66,
				bottomPx: 48,
				size: 50,
				keyCode: KeyboardManager.DOWN,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "jump",
				label: "▲",
				rightPx: 8,
				bottomPx: 48,
				size: 50,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "phase",
				label: "✦",
				rightPx: 8,
				bottomPx: 106,
				size: 50,
				keyCode: KeyboardManager.SPACE,
				shape: TouchButtonShape.CIRCLE,
			},
		],
	};

	// ZQSD / WASD move like the arrows
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	// the game runs at 30 frames/s and KadoKadeo steps it 32 times a second: 15 frames every 16 steps
	static inline var FPS = 30;
	static inline var STEPS_PER_SECOND = 32;

	// (Arkadeo HTML5 port, Boot.hx) extra jump speed per frame while up is held during the jump extension, with the
	// super power; the fall speed cap (cells / frame) and the ceiling of the hero (cy)
	static inline var SUPER_JUMP_BOOST = 0.07;
	static inline var HERO_MAX_FALL = 0.45;
	static inline var CEILING_CY = -6;

	public static var ME:Game;

	// the sprite sheets of the game (brutalteenagecrisis-N.json), loaded by KadoKadeo before the game is created
	public var sheets(default, null):Array<Dynamic>;
	var root:Sprite;
	var mode:Mode;
	var isReplay:Bool;
	var frameAcc:Int;
	var frameCount:Int;
	var over:Bool;
	var score:Int;
	var prevJumpExtend:Bool;

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		ME = this;

		var keys = new UInt16Array(5);
		keys[0] = KeyboardManager.LEFT;
		keys[1] = KeyboardManager.RIGHT;
		keys[2] = KeyboardManager.UP;
		keys[3] = KeyboardManager.DOWN;
		keys[4] = KeyboardManager.SPACE;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});

		resetStatics();
		frameAcc = FPS;
		frameCount = 0;
		over = false;
		score = 0;
		prevJumpExtend = false;

		sheets = findSheets();
		// pixel art: drawn without smoothing, like the Arkadeo HTML5 port (PIXI.SCALE_MODES.NEAREST)
		for (s in sheets)
			s.baseTexture.scaleMode = 0;

		root = new Sprite();
		mc.addChild(root.node);
		mode = new brutalteenagecrisis.mode.League(this);
		warmShaders();
		Flash.display(root, 1);
	}

	public function addChild(o:DisplayObject) {
		root.addChild(o);
	}

	// ---------------------------------------------------------------- KadoKadeo step: 15 frames of the game every 16 steps
	// Shown 30/32 of a frame behind the last frame of the game (always between the last two frames: the moves are even,
	// see arkadeo.Flash), ASprite interpolating between two steps
	public function update(delta:Float) {
		frameAcc += FPS;
		while (frameAcc >= STEPS_PER_SECOND) {
			frameAcc -= STEPS_PER_SECOND;
			Flash.frameStart(root);
			gameFrame();
			Flash.frameEnd(root);
		}
		Flash.display(root, (frameAcc + STEPS_PER_SECOND - FPS) / STEPS_PER_SECOND);
	}

	// one frame of the game: the update of the original Game, then the hero guards of the Arkadeo HTML5 port
	function gameFrame() {
		mt.deepnight.Mode.updateAll(true);
		frameCount++;
		superPowerJumpBoost();
		clampHero();
		syncHeroAttachAlpha();
	}

	// nothing more after the end
	public function addScore(n:Int) {
		if (over)
			return;
		score += n;
		KadoKadeoManager.kkm.addScore(n);
	}

	// the end (lost: the League has no win) and its stats go to KadoKadeo once (Mode.gameOver)
	public function onGameOver(win:Bool) {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({diff: mode.diff});
	}

	public function destroy():Void {
		mode.destroy();
		for (s in BSprite.ALL.copy())
			s.dispose();
		resetStatics();
		if (root.node.parent != null)
			root.node.parent.removeChild(root.node);
		root.node.destroy({children: true});
		mode = null;
		ME = null;
	}

	// statics of the game: one page plays several games and replays
	static function resetStatics() {
		// the display of the game: positions of the HTML5 port (no twips), pixel art (whole pixels), the glow of the
		// HTML5 port, the blur of PIXI; the first move of a new object and a move of more than 2 cells (a respawn, the dash
		// of the Fly) are jumps
		Flash.reset();
		Flash.useTwips = false;
		Flash.snapFirstMove = true;
		Flash.teleport = 64;
		Flash.roundMoving = true;
		GlowFilter.style = SAMPLED;
		BlurFilter.scale = 1;
		BlurFilter.forceQuality = null;
		Const.UID = 0;
		Const.PHASE_CD = Const.seconds(15);
		Const.PHASE_DURATION = Const.seconds(2.5);
		Entity.ALL = [];
		Entity.TOKILL = [];
		brutalteenagecrisis.en.Mob.ALL = [];
		brutalteenagecrisis.en.mob.Walker.ALL = [];
		brutalteenagecrisis.en.mob.Big.COUNT = 0;
		BSprite.ALL = [];
		Particle.ALL = [];
		@:privateAccess {
			mt.deepnight.Mode.ALL = [];
			mt.deepnight.Mode.KILL_LIST = [];
		}
		@:privateAccess AnimManager.UNSYNC = new Map();
		Mode.ME = null;
		Fx.ME = null;
	}

	// the sheets of this game in the loader of KadoKadeo (the frame names of another game cannot collide)
	static function findSheets():Array<Dynamic> {
		var sheets = [];
		var res = untyped PIXI.Loader.shared.resources;
		for (k in Reflect.fields(res)) {
			var r = Reflect.field(res, k);
			var url:String = r.url != null ? r.url : k;
			if (r.spritesheet != null && url.indexOf("/brutalteenagecrisis") >= 0)
				sheets.push(r.spritesheet);
		}
		return sheets;
	}

	// the first use of a filter compiles its shader (a frozen frame of 10 to 80 ms): each filter of the game is drawn
	// once here (GlowFilter: one shader by distance and quality; BlurFilter; ColorMatrixFilter of the Simple mob)
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var flts:Array<BitmapFilter> = [for (d in [2, 4, 6, 8, 16]) new GlowFilter(0xFFFFFF, 1, d, d, 1)];
		flts.push(new GlowFilter(0xFFFFFF, 0.9, 16, 16, 1, 2));
		flts.push(new BlurFilter(16, 16));
		flts.push(mt.deepnight.Color.getColorizeMatrixFilter(0x64979B, 0.5, 0.5));
		var filters = [for (f in flts) f.toPixi()];
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		for (f in filters) {
			var holder = new pixi.core.display.Container();
			var s = new pixi.core.sprites.Sprite(pixi.core.textures.Texture.WHITE);
			s.x = s.y = 12;
			s.width = s.height = 8;
			s.filters = [f];
			holder.addChild(s);
			renderer.render(holder, {renderTexture: rt, clear: true});
			holder.destroy({children: true});
		}
		rt.destroy(true);
	}

	// ---------------------------------------------------------------- hero guards (Arkadeo HTML5 port, Boot.hx)

	// the super power's jump: extra speed while up is held during the jump extension, but not on the take-off frame (a
	// short jump keeps its height, only a held jump gets higher)
	function superPowerJumpBoost() {
		var hero = mode.hero;
		if (hero == null || hero.killed || hero.hasLeft) {
			prevJumpExtend = false;
			return;
		}
		var je = hero.cd.has("jumpExtend");
		if (hero.hasSuperPower() && je && prevJumpExtend && KeyboardManager.isDown(KeyboardManager.UP) && hero.dy < 0)
			hero.dy -= SUPER_JUMP_BOOST;
		prevJumpExtend = je;
	}

	// the Fly's charge throws the hero down at ~2 cells / frame (the original has no terminal speed) and its pushes could
	// throw it out of the map: fall speed capped, a ceiling, and a hero under the map put back on the ground
	function clampHero() {
		var hero = mode.hero;
		if (hero == null || mode.level == null || hero.hasLeft || hero.killed)
			return;

		if (hero.dy > HERO_MAX_FALL)
			hero.dy = HERO_MAX_FALL;

		if (hero.cy < CEILING_CY) {
			hero.cy = CEILING_CY;
			hero.yr = 0.5;
			if (hero.dy < 0)
				hero.dy = 0;
		}

		if (hero.cy >= Const.LHEI) {
			var pt = mode.level.getRandomSpot(0);
			if (pt == null)
				pt = mode.level.getRandomSpot();
			if (pt == null)
				return;
			hero.setPos(pt.cx, pt.cy);
			hero.dx = 0;
			hero.dy = 0;
			hero.stable = false;
		}
	}

	// the hair, the ball and the chain are separate sprites: they take the alpha of the hero's body (phase)
	function syncHeroAttachAlpha() {
		var hero = mode.hero;
		if (hero == null || hero.sprite == null)
			return;
		var a:Float = hero.sprite.alpha;
		var hair = @:privateAccess hero.hair;
		if (hair != null)
			hair.alpha = a;
		var ball = @:privateAccess hero.ball;
		if (ball != null) {
			if (ball.sprite != null)
				ball.sprite.alpha = a;
			var chain = @:privateAccess ball.chain;
			if (chain != null)
				for (c in chain)
					c.alpha = a;
		}
	}

	#if debug
	// state compared between a game and its replay (test harness)
	public function debugState():Dynamic {
		var h = mode.hero;
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			ascore: score, // the score the game gave
			diff: mode.diff,
			skill: Math.round(mode.skill * 1e6) / 1e6,
			credits: h.credits,
			hx: h.cx + ":" + Math.round(h.xr * 1e6),
			hy: h.cy + ":" + Math.round(h.yr * 1e6),
			mobs: brutalteenagecrisis.en.Mob.ALL.length,
			entities: Entity.ALL.length,
			uid: Const.UID,
		};
	}

	// what the test bots read to play (harness): the hero, the mobs and the items, in cells
	public function botState():Dynamic {
		var h = mode.hero;
		return {
			frame: frameCount,
			over: over,
			cx: h.cx + h.xr,
			cy: h.cy + h.yr,
			stable: h.stable,
			stun: h.cd.has("stun"),
			phasing: h.isPhasing(),
			phaseReady: !h.cd.has("phaseLock"),
			power: h.hasSuperPower(),
			credits: h.credits,
			diff: mode.diff,
			mobs: [
				for (m in brutalteenagecrisis.en.Mob.ALL)
					if (!m.killed) {cx: m.cx + m.xr, cy: m.cy + m.yr, climbing: m.climbing, type: Std.string(m.type)}
			],
			items: [
				for (e in Entity.ALL)
					if (!e.killed && Std.isOfType(e, brutalteenagecrisis.en.Item)) {cx: e.cx + e.xr, cy: e.cy + e.yr}
			],
		};
	}
	#end
}

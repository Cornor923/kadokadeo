package greenwitch;

import haxe.io.UInt16Array;
import common_haxe_avm1.display.ASprite;

// Green Witch (Arkadeo, Motion Twin, 600 x 460 at 30 frames/s), its League: a dungeon to hold as long as possible, the
// witch shoots by herself and summons turrets, the princes give points, the monsters come back stronger and stronger. The
// code is the original (Haxe 2, AS3) on the AS3 display list of the lib (arkadeo), as the Arkadeo HTML5 port of it plays
// it; this class is the Game of the original (the buffer of the scene, the mode) and the game KadoKadeo creates, steps and
// records (the left button and the mouse) instead of the Arkadeo loader (AKApi).
//
// What changes from the original, and why:
//  - the LvUP campaign (mode.Progression, the 20 levels of levelInfos.xml, the experience of the witch, its tutorial)
//    and the in-game prizes of Arkadeo (en.it.KPoint) are not ported;
//  - the inputs: the MOUSE_DOWN / MOUSE_UP listeners of the buffer (the AKApi events 0, 1 and the mouse in the scroller)
//    are the left button polled at each step of KadoKadeo, its changes played at the start of the next frame of the
//    game like the AKApi events; the mouse is recorded: the summoning gauge and the glow of what is under the mouse
//    (the original: only in a live game) are the same in a replay;
//  - the random: the seed of the game (AKApi.getSeed) is drawn from the seed of KadoKadeo, the generators of the original
//    (mt.Rand: the game's, the level's, each entity's) are kept on it; what only changes the look (the effects, the frames
//    of the dungeon walls) on the random of the effects (Seed.*Vfx);
//  - no low quality (AKApi.getPerf, isLowQuality): the effects are those of a fast machine (getPerf 0.85, the value of the
//    Arkadeo HTML5 port), they never depend on the machine;
//  - the plans of the dungeons are read from Data.hx (levels.png in the original), the attach points of the staff in the
//    frames of the witch too (Data.HERO_ATTACH): nothing is read from a picture;
//  - the particles of the effects registered one after the other with the same filters share one filter pass (Fx.register,
//    in the order of the original): a fight draws about 4 times fewer passes;
//  - kept from the Arkadeo HTML5 port (comments "(Arkadeo HTML5 port)" in the code): the fix of the princes (their
//    square freed when picked up, no crash when the dungeon is full), the Unlocker locking one door until it dies, the
//    repair of the broken doors only, the HUD blinks, the pops of the points drawn without being flattened, the glow of the
//    spawn effects shared by all their particles, the aiming sight of the Bomber drawn, the halos in ADD and the smoke in
//    MULTIPLY (no OVERLAY), no light under the dispensers, the z-sort at every frame, the sounds (the original Arkadeo
//    build had none: -D disableSfx).
@:expose('GameGreenWitch')
class Game extends Sprite implements kado.GameInterface {
	public static var ME:Game;

	// the left button (the AKApi events of the original); a finger on a touch screen is the mouse
	public static var KEY_ALIASES:Array<Dynamic> = [];

	// AKApi.getPerf of the Arkadeo HTML5 port: the effects of a fast machine (perf >= 0.8)
	public static inline var PERF = 0.85;

	// the game runs at 30 frames/s and KadoKadeo steps it 32 times a second: 15 frames every 16 steps
	public static inline var FPS = 30;
	static inline var STEPS_PER_SECOND = 32;

	public var buffer:Buffer;

	// ---------------------------------------------------------------- KadoKadeo
	public var isReplay(default, null):Bool;
	public var seed(default, null):Int;
	public var frameCount(default, null):Int;
	public var over(default, null):Bool;

	var frameAcc:Int;
	var gameRoot:ASprite;
	var gameMask:pixi.core.graphics.Graphics;
	var onPointerDown:Dynamic->Void;
	// the events of the AKApi queue (0: pressed, 1: released, 2 + x, 2 + y: the mouse in the scroller when released)
	var events:Array<Int>;
	var mouseWas:Bool;

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
		frameAcc = FPS;
		frameCount = 0;
		over = false;
		events = [];
		mouseWas = false;

		// pixel art: the sheet drawn without smoothing, like the buffer of the original shown x2
		for (s in findSheets())
			s.baseTexture.scaleMode = 0;
		Tex.init("/greenwitch");
		TextField.init(Data.fonts);
		// (the OVERLAY draws of Level.draw: the edges of the walls, the cracks, the texture of their thickness)
		OverlayBlend.register(KadoKadeoManager.kkm.renderer);
		GameSounds.init("greenwitch", S.BANK._names);

		gameRoot = mc;
		mc.addChild(node);
		// the game area of Arkadeo (600 x 460): what goes out of it is not drawn (under the bar of KadoKadeo)
		gameMask = new pixi.core.graphics.Graphics();
		gameMask.beginFill(0xFFFFFF);
		gameMask.drawRect(0, 0, Const.WID, Const.HEI);
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

		ME = this;
		// (AKApi.getSeed: a seed of KadoKadeo)
		seed = Seed.random(0x3FFFFFFF);

		buffer = new Buffer(Math.ceil(Const.WID / Const.UPSCALE), Math.ceil(Const.HEI / Const.UPSCALE), Const.UPSCALE, false, 0x0);
		addChild(buffer.render);

		new greenwitch.mode.League();

		warmShaders();
		Flash.display(this, 1);
	}

	// the update of the original Game (one frame at 30 frames/s)
	public function updateGame(render:Bool) {
		Mode.updateAll(render);
		if (render)
			buffer.update();
	}

	// ---------------------------------------------------------------- AKApi
	public inline function emitEvent(e:Int) {
		events.push(e);
	}

	public inline function getEvent():Null<Int> {
		return events.length > 0 ? events.shift() : null;
	}

	public function addScore(v:Int) {
		if (over)
			return;
		KadoKadeoManager.kkm.addScore(v);
	}

	public function gameOver(win:Bool) {
		if (over)
			return;
		over = true;
		// (the hand over a dispenser does not stay on the end screen)
		if (greenwitch.mode.Play.ME != null)
			greenwitch.mode.Play.ME.setHandCursor(false);
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	// the mouse in the game area (canvas pixels, the replay records it: >= 0)
	public static inline function mouseX():Float return Math.max(0, MouseManager.getX());

	public static inline function mouseY():Float return Math.max(0, MouseManager.getY());

	// the trigonometry that moves the game, rounded to 1/65536 (the last bits of Math.cos / Math.sin / Math.atan2 may differ
	// between browsers): the same game in every replay
	public static inline function q(v:Float):Float return Math.round(v * 65536) / 65536;

	public static inline function cos(a:Float):Float return q(Math.cos(a));

	public static inline function sin(a:Float):Float return q(Math.sin(a));

	public static inline function atan2(y:Float, x:Float):Float return q(Math.atan2(y, x));

	// the button of the original: MOUSE_DOWN / MOUSE_UP of the buffer, over the game area (a release out of it is not one, like
	// Flash: the mouse was not over the buffer)
	function pollInputs() {
		var mouse = MouseManager.isButtonDown(MouseManager.BUTTON_LEFT);
		var x = MouseManager.getX(), y = MouseManager.getY();
		var inside = x >= 0 && x < Const.WID && y >= 0 && y < Const.HEI;
		var play = greenwitch.mode.Play.ME;
		if (play != null) {
			if (mouse && !mouseWas && inside)
				play.onMouseDown();
			if (!mouse && mouseWas && inside)
				play.onMouseUp();
		}
		mouseWas = mouse;
	}

	// ---------------------------------------------------------------- KadoKadeo step: 15 frames of the game every 16 steps
	// Shown 30/32 of a frame behind the last frame of the game (see arkadeo.Flash), ASprite interpolating between two steps
	public function update(delta:Float) {
		GameSounds.step();
		pollInputs();
		frameAcc += FPS;
		while (frameAcc >= STEPS_PER_SECOND) {
			frameAcc -= STEPS_PER_SECOND;
			Flash.frameStart(this);
			updateGame(true);
			frameCount++;
			Flash.frameEnd(this);
		}
		Flash.display(this, (frameAcc + STEPS_PER_SECOND - FPS) / STEPS_PER_SECOND);
	}

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null) {
				canvas.removeEventListener("pointerdown", onPointerDown);
				if (canvas.style != null)
					canvas.style.cursor = "";
			}
			onPointerDown = null;
		}
		GameSounds.stopMusic();
		Particle.clearAll();
		resetStatics();
		node.mask = null;
		if (gameMask.parent != null)
			gameMask.parent.removeChild(gameMask);
		gameMask.destroy();
		if (node.parent != null)
			node.parent.removeChild(node);
		node.destroy({children: true});
		ME = null;
	}

	// statics of the game: one page plays several games and replays
	static function resetStatics() {
		// the display: the positions of the original at whole pixels (pixel art drawn x2), the RenderTextures of its bitmaps
		// without smoothing, the glows of the Arkadeo HTML5 port (the shader of pixi-filters)
		Flash.reset();
		Flash.useTwips = false;
		Flash.roundMoving = true;
		BitmapData.gpuScaleMode = 0;
		GlowFilter.style = SAMPLED;
		// (the cracks of the floor: Level.draw thresholds a perlin noise)
		BitmapData.perlinFractal = true;
		mt.deepnight.Sfx.reset();
		Particle.ALL = [];
		BSprite.ALL = new List();
		Mode.reset();
		Entity.reset();
		greenwitch.en.Door.reset();
		greenwitch.en.Dispenser.ALL = [];
		greenwitch.en.Exit.ALL = [];
		greenwitch.en.Prop.ALL = [];
		greenwitch.en.it.Civilian.ALL = [];
		greenwitch.en.it.Civilian.TOTAL = 0;
		Fx.reset();
		greenwitch.mode.Play.ME = null;
		ME = null;
	}

	// the sheets of this game in the loader of KadoKadeo (the frame names of another game cannot collide)
	static function findSheets():Array<Dynamic> {
		var sheets = [];
		var res = untyped PIXI.Loader.shared.resources;
		for (k in Reflect.fields(res)) {
			var r = Reflect.field(res, k);
			var url:String = r.url != null ? r.url : k;
			if (r.spritesheet != null && url.indexOf("/greenwitch") >= 0)
				sheets.push(r.spritesheet);
		}
		return sheets;
	}

	// the first use of a filter compiles its shader (a frozen frame of 10 to 80 ms): each filter of the game is drawn once
	// here (the glows of pixi-filters at their distances, the blurs, the drop shadows, the colour matrices); the sheet is
	// uploaded to the GPU now too, not at the first picture of the game
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var flts:Array<BitmapFilter> = [];
		for (d in [2, 4, 8, 10])
			flts.push(new GlowFilter(0xFFFFFF, 1, d, d, 2));
		flts.push(new GlowFilter(0xFFFFFF, 1, 4, 4, 2, 1, true));
		flts.push(new BlurFilter(4, 4));
		flts.push(new BlurFilter(16, 16));
		flts.push(new BlurFilter(32, 32, 2));
		flts.push(new DropShadowFilter(2, 90, 0x0, 1, 0, 0));
		flts.push(new ColorMatrixFilter());
		var filters:Array<Dynamic> = [];
		for (f in flts) {
			var p = f.toPixi();
			if (p != null)
				filters.push(p);
		}
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
		for (s in findSheets())
			renderer.texture.bind(s.baseTexture);
	}

	#if debug
	// (test modes of the harness) the mode of the game
	public function testPlay():greenwitch.mode.Play {
		return greenwitch.mode.Play.ME;
	}

	// (test mode of the harness) a monster near the witch, at a free square chosen by the frame of the game: through a
	// Spawner (its effects), or at once (instant)
	public function testSpawn(kind:String, ?instant:Bool = false) {
		var p = greenwitch.mode.Play.ME;
		if (p == null || p.hero == null || p.currentLevel == null)
			return;
		var cls:Class<greenwitch.en.Mob> = switch (kind) {
			case "bleuarg": greenwitch.en.mob.Bleuarg;
			case "unlocker": greenwitch.en.mob.Unlocker;
			case "firecannon": greenwitch.en.mob.FireCannon;
			case "kamikaze": greenwitch.en.mob.Kamikaze;
			case "bomber": greenwitch.en.mob.Bomber;
			case "ghost": greenwitch.en.mob.Ghost;
			case "horde": greenwitch.en.mob.Horde;
			case "bat": greenwitch.en.mob.Bat;
			case "rabbit": greenwitch.en.mob.Rabbit;
			case "skeleton": greenwitch.en.mob.Skeleton;
			default: null;
		}
		if (cls == null)
			return;
		var k = frameCount;
		for (i in 0...40) {
			// (2 to 7 squares away, the 4 quarters around the witch in turn)
			var dx = 2 + (k + i * 7) % 6, dy = 2 + (k * 3 + i * 5) % 6;
			var q = (k + i) % 4;
			var cx = p.hero.cx + (q % 2 == 0 ? dx : -dx);
			var cy = p.hero.cy + (q < 2 ? dy : -dy);
			if (!p.currentLevel.getCollision(cx, cy)) {
				if (instant) {
					var m:greenwitch.en.Mob = Type.createInstance(cls, [cx, cy]);
					m.updateScreenCoords();
				} else
					new greenwitch.en.Spawner(cls, cx, cy);
				return;
			}
		}
	}

	// (test mode of the harness) every monster hit to death
	public function testKillAll() {
		var p = greenwitch.mode.Play.ME;
		if (p != null)
			for (m in p.mobs.copy())
				m.hit(99999);
	}

	// (test bots) what the bot sees, in canvas pixels
	@:privateAccess
	public function botState():Dynamic {
		var p = greenwitch.mode.Play.ME;
		if (p == null || p.hero == null)
			return null;
		var sx = @:privateAccess p.scroller.x, sy = @:privateAccess p.scroller.y;
		inline function cx(x:Float) return Math.round((x + sx) * Const.UPSCALE);
		inline function cy(y:Float) return Math.round((y + sy) * Const.UPSCALE);
		var near = 9999.0;
		for (m in p.mobs)
			near = Math.min(near, m.distance(p.hero));
		return {
			over: over || @:privateAccess p.gameEnded,
			dead: p.hero.dead,
			frame: frameCount,
			hx: cx(p.hero.xx),
			hy: cy(p.hero.yy),
			ammo: p.hero.ammo,
			turrets: p.hero.turrets,
			weapon: Type.enumIndex(p.hero.weaponType),
			mobs: p.mobs.length,
			near: Math.round(near),
			moving: p.hero.isMoving(),
			disp: [for (d in greenwitch.en.Dispenser.ALL) {x: cx(d.xx), y: cy(d.yy) - 30, w: @:privateAccess Type.enumIndex(d.effect) == 1}],
			civ: [for (c in greenwitch.en.it.Civilian.ALL) {x: cx(c.xx), y: cy(c.yy)}],
			gold: [for (e in Entity.ALL) if (Std.isOfType(e, greenwitch.en.it.Gold)) {x: cx(e.xx), y: cy(e.yy)}],
		};
	}

	// state compared between a game and its replay (test harness)
	public function debugState():Dynamic {
		var p = greenwitch.mode.Play.ME;
		var h = 0;
		for (e in Entity.ALL)
			h = (h * 31 + Math.round(e.xx * 100) * 7 + Math.round(e.yy * 100)) | 0;
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			time: p != null ? p.time : -1,
			entities: Entity.ALL.length,
			mobs: p != null ? p.mobs.length : -1,
			life: p != null && p.hero != null ? p.hero.life : -1,
			ammo: p != null && p.hero != null ? p.hero.ammo : -1,
			turrets: p != null && p.hero != null ? p.hero.turrets : -1,
			difficulty: p != null ? Math.round(p.difficulty * 1000) / 1000 : -1,
			pos: h,
		};
	}
	#end
}

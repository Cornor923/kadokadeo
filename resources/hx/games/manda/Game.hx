package manda;

import common_haxe_avm1.KeyboardManager;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;
import kado.TouchControlsConfig.TouchButtonShape;

// Manda (KadoKado, Motion-Twin): ported from the original sources (Manager, Game, Level, Snake... of the manda folder)
// and the graphics of its SWF. The game runs in the Flash pixels of the original (300 x 300), drawn x2.
@:expose('GameManda')
class Game implements kado.GameInterface {
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
				leftPx: 90,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "up",
				label: "▲",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	// ZQSD / WASD turn and speed up like the arrows
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	public static inline var K = 2;

	public var root:ASprite;
	public var dmanager:Plans;
	public var interf:Plans;
	public var snake:Snake;
	public var level:Level;
	public var game_over_flag:Bool;
	public var fcounter:Int;
	public var fbarre:Float;
	public var jackpot:Jackpot;
	public var nfruits:Int;
	public var fcloche:Null<Void->Void>;

	// Manager.updates: called after the game every frame
	public var updates:Array<Void->Void>;
	// clips "fruit" / "bonus" whose timelines play
	public var mcs:Array<ItemMc>;

	var over:Bool;
	var frameCount:Int;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: UInt16Array.fromArray([KeyboardManager.LEFT, KeyboardManager.RIGHT, KeyboardManager.UP]),
			recordInputs: true,
			recordEvents: false,
		});
		Bonus.CISEAUX_COUNT = 1;
		Bonus.POTION_BLEUES = 0;
		over = false;
		frameCount = 0;
		updates = [];
		mcs = [];

		this.root = root.createEmptyMovieClip("scene", 0);
		this.root._xscale = this.root._yscale = 100 * K;
		this.root.updateState();

		// bg, game layer (masked by bgMask in the original: the bands of bgTop cover it outside the mask), interface
		this.root.createEmptyMovieClip("bg", 0).addChild(new Pic("bg"));
		dmanager = new Plans(this.root.createEmptyMovieClip("game", 1));
		var top = this.root.createEmptyMovieClip("bgTop", 2);
		for (i in 0...4) {
			var p = new Pic("bgTop");
			p.show(i + 1);
			top.addChild(p);
		}
		interf = new Plans(this.root.createEmptyMovieClip("interf", 3));

		level = new Level(this);
		jackpot = new Jackpot(this);
		snake = new Snake(this, dmanager, {x: 0, y: 0});
		snake.ang = Math.PI / 4;
		fcounter = 0;
		fbarre = 0;
		nfruits = 0;
		game_over_flag = false;

		warmShaders();
	}

	// one frame of the Flash player
	public function update(delta:Float) {
		frameCount++;
		snake.gfx.beginStep();
		// timelines of the clips (their playheads move before the scripts of the frame)
		for (m in mcs.copy())
			m.advance();
		snake.advanceTimeline();
		main();
		// (a function removing itself makes the loop skip the next one, like the original)
		var i = 0;
		while (i < updates.length) {
			updates[i]();
			i++;
		}
	}

	function main() {
		fcounter++;
		if (game_over_flag) {
			gameOverMain();
			return;
		}
		gameMain();
	}

	public function eatFruit(f:Fruit):Bool {
		if (f.isMoving())
			return false;

		var pts = f.points();
		new PopScore(this, f.mc._x, f.mc._y, pts, dmanager.empty(Cs.PLAN_POPSCORE));
		jackpot.addFruit(f.id);
		if (f.add_queue)
			snake.addQueue();
		f.destroy();
		nfruits++;
		addScore(pts);
		fbarre += Cs.FBARRE_FRUIT_EAT;
		if (fbarre > Cs.FBARRE_MAX)
			fbarre = Cs.FBARRE_MAX;
		return true;
	}

	inline function isDown(k:Int):Bool {
		return KeyboardManager.isDown(k);
	}

	function gameMain() {
		var tmod = Timer.tmod;
		if (isDown(KeyboardManager.LEFT))
			snake.ang -= snake.delta_ang * Cs.qt(Math.pow(snake.speed / Cs.SNAKE_DEFAULT_SPEED, 0.5)) * tmod;
		if (isDown(KeyboardManager.RIGHT))
			snake.ang += snake.delta_ang * Cs.qt(Math.pow(snake.speed / Cs.SNAKE_DEFAULT_SPEED, 0.5)) * tmod;

		snake.base_speed *= Cs.qt(Math.pow(Cs.FRICTION, tmod));
		if (isDown(KeyboardManager.UP))
			snake.base_speed = Cs.SNAKE_FAST_SPEED_COEF;
		if (snake.base_speed < 1)
			snake.base_speed = 1;

		if (fcloche != null)
			fcloche();
		var hit = snake.move(Cs.LEVEL_BOUNDS);
		if (hit)
			game_over_flag = true;

		snake.speed += Cs.SNAKE_SPEED_INCREMENT * tmod;
		level.main();
		jackpot.main();
		snake.draw();
	}

	function gameOverMain() {
		if (snake.len >= 0) {
			var timer = 4;
			if (snake.len > 10)
				timer = 3;
			if (snake.len > 50)
				timer = 2;
			if (snake.len > 100)
				timer = 1;
			if (fcounter % Std.int(Math.max(1, Std.int(timer / Timer.tmod))) == 0)
				snake.explode(snake.getColor());
			snake.draw();
		} else {
			snake.tete._visible = false;
			saveScore();
		}
		level.main();
	}

	// SCORE / END
	public function getScore():Int {
		return KadoKadeoManager.kkm.score.get();
	}

	public function addScore(n:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	function saveScore() {
		if (over)
			return;
		over = true;
		var stats = {f: nfruits, j2: jackpot.count2, j3: jackpot.count3};
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: getScore(),
			x: snake.x,
			y: snake.y,
			speed: snake.speed,
			stats: haxe.Json.stringify(stats)
		};
		#end
		KadoKadeoManager.kkm.gameOver(stats);
	}

	// The first use of a shader compiles it on the graphics card (tens of ms of freeze): the body of the snake (meshes
	// in a render texture) and the tinted sprites are drawn once now, off screen.
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var disc = SnakeGfx.Strokes.discTexture();
		var st = new SnakeGfx.Strokes(disc);
		st.build([0, 0, 5, 5, 10, 0, 6], 0x009900);
		holder.addChild(st.mesh);
		var s = new PixiSprite(Texture.WHITE);
		s.tint = 0x4E8114;
		holder.addChild(s);
		var rt:RenderTexture = (cast RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy();
		st.dispose();
		s.destroy();
		disc.destroy(true);
		rt.destroy(true);
	}

	public function destroy():Void {
		snake.gfx.dispose();
	}
}

package aquasplash;

import aquasplash.MC.Plans;
import aquasplash.Slime.SlimeMC;
import haxe.io.UInt16Array;
import pixi.core.Pixi.BlendModes;
import pixi.core.display.Container;
import pixi.core.textures.Texture;
import pixi.filters.alpha.AlphaFilter;

typedef Pos = {x:Int, y:Int}

enum Step {
	Play;
	Spout;
	Bombing;
	Explode;
	NextLevel;
	GameOver;
}

// timeLine: its frame (shape 11) and _timeLeft (shape 9, scaled by the code)
class TimeLine extends MC {
	public var _timeLeft:MC;
	public var start:Float;

	public function new() {
		super();
		attach(new MC("timeBg"));
		_timeLeft = attach(new MC("timeLeft"));
	}
}

// score: shape 66, the _field ("x" + chain), shape 69 over it. The field has filters: Flash applies its alpha to
// the field composed with them (MC.alphaFilter)
class ScoreMC extends MC {
	public var _field:TextField;
	public var timer:Null<Float>;

	public function new() {
		super();
		attach(new MC("scoreBack"));
		_field = cast attach(new TextField(Data.TEXT_SCORE));
		_field.alphaFilter = new AlphaFilter(1);
		_field.spr.filters = [_field.alphaFilter];
		attach(new MC("scoreFront"));
	}
}

// play (sprite 75): frame 1 a play spent, 2 a play left, 3 a play just won: sprite 74 plays its 31 frames (a flash
// of colours) and stops, from its first frame each time the icon goes to frame 3 (anim play: 1, 2, then 74's frames)
class PlayMC extends MC {
	var frame:Int = 1;
	var sub:Int = 1;

	public function new() {
		super("play");
	}

	override public function gotoAndStop(f:Int):Void {
		playing = false;
		if (f == frame)
			return;
		frame = f;
		sub = 1;
		_currentframe = f < 3 ? f : 3;
	}

	override function advance():Void {
		if (removed || frame != 3 || sub >= 31)
			return;
		sub++;
		_currentframe = 2 + sub;
	}
}

@:expose('GameAquaSplash')
class Game implements kado.GameInterface {
	// texture pixels per Flash pixel: the original's 300 x 300 pixels drawn x2
	public static inline var K = 2;
	// Flash played Aqua Splash at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32: tmod = 0.8
	public static inline var FRAME_RATE = 40;

	public static inline var DP_BG = 0;
	public static inline var DP_BGPLAYS = 1;
	public static inline var DP_DROP = 3;
	public static inline var DP_SLIME = 4;
	public static inline var DP_ANIM = 5;
	public static inline var DP_PLAYS = 6;
	public static inline var DP_SCORING = 7;

	public static inline var DP_PARTS = 8;
	public static inline var DP_POINTS = 9;

	public static var MAX_PLAYS = 20;

	public var step:Step;

	var timer:Null<Float>;

	public var mcTime:TimeLine;

	var lockSlime:Bool;

	public var level:Int;
	public var plays:Int;
	public var mcPlays:Array<PlayMC>;
	public var mcScore:ScoreMC;
	public var explosion:Int;

	public var flGameOver:Bool;
	public var dm:Plans;
	public var root:MC;
	public var sdm:Plans;
	public var slimeMc:MC;
	public var mcBomb:MC;

	public var bg:MC;
	public var mcLevel:NextLevel;

	public static var me:Game;

	public var slimes:Array<Slime>;
	public var allSlimes:Array<Slime>;
	public var toReduce:Array<Slime>;
	public var drops:Array<Drop>;

	// ---------------------------------------------------------------- port
	var isReplay:Bool;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	var over:Bool = false;
	// mouse (Flash buttons): the slime under the pointer, the slime pressed, whether the pointer is still over it
	var hovered:SlimeMC;
	var pressed:Bool = false;
	var pressTarget:SlimeMC;
	var onPointerDown:Dynamic;

	#if debug
	// test harness: what the game went through (window.__over)
	public var stats:Dynamic;
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: UInt16Array.fromArray([MouseManager.BUTTON_LEFT]),
		});
		// statics of the original (the SWF was loaded again for every game)
		MC.clearAll();
		Sprite.spriteList = [];
		Cs.INIT_PLAYS = 11;
		#if debug
		// test harness (modes/aquasplash.js): another board than the one of the debug seed (map=<n>), more plays to
		// reach the late levels (plays=<n>), the same in a game and in its replay
		if (untyped js.Browser.window.__aquaMap != null)
			Seed.init(untyped js.Browser.window.__aquaMap);
		if (untyped js.Browser.window.__aquaPlays != null)
			Cs.INIT_PLAYS = untyped js.Browser.window.__aquaPlays;
		stats = {chains: 0, maxChain: 0, bombs: 0, bonus: 0, reduce: 0, levels: 0, zombies: 0};
		#end
		// like the Flash player, a slime pressed keeps the mouse while the button is held (its release outside the
		// game is still seen)
		if (!isReplay) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			onPointerDown = function(e:Dynamic) {
				try {
					canvas.setPointerCapture(e.pointerId);
				} catch (_:Dynamic) {}
			};
			canvas.addEventListener("pointerdown", onPointerDown);
		}

		root = new MC(null, 1 / K);
		root.posK = K;
		mc.addChild(root.spr);
		me = this;
		dm = new Plans(root);

		slimeMc = dm.empty(DP_SLIME);
		sdm = new Plans(slimeMc);

		flGameOver = false;

		lockSlime = false;
		level = 0;
		explosion = 0;

		slimes = [];
		allSlimes = [];
		drops = [];

		initBg();
		initPlays();
		initScore();
		prepareLevel();
		initTime();

		step = Play;

		MC.displayAll(1);
		warmShaders();
	}

	// flash.Lib.getTimer(): the time of the Flash frame being played, 25 ms per frame (40 frames/s)
	function getTimer():Float {
		return frameCount * 1000 / FRAME_RATE;
	}

	function initTime() {
		mcTime = dm.add(new TimeLine(), DP_SLIME);
		mcTime.start = getTimer();
		mcTime._rotation = -90;
		mcTime._alpha = 80;
		mcTime._x = 5;
		mcTime._y = 230;
	}

	function initBg() {
		// mcBg: the bitmap of the board, at its native resolution
		bg = dm.add(new MC("bg", 1), DP_BG);
		bg._x = 0;
		bg._y = 0;
	}

	function initPlays() {
		var i = 0;
		plays = Cs.INIT_PLAYS;
		mcPlays = [];
		var h = false;

		var p = {x: 12.8, y: 13};

		var pm = dm.empty(DP_PLAYS);
		pm._x = Cs.PLAYS_X;
		pm._y = Cs.PLAYS_Y;
		var pdm = new Plans(pm);

		while (i < Cs.MAX_PLAYS) {
			var mc = pdm.add(new PlayMC(), if (h) 1 else 2);
			mc.gotoAndStop(if (i < plays) 2 else 1);

			mc._x = i * p.x;
			mc._y = (if (h) 0 else p.y);
			mcPlays.push(mc);

			i++;
			h = !h;
		}

		// pm.cacheAsBitmap = true ;
	}

	function initScore() {
		mcScore = dm.add(new ScoreMC(), DP_SCORING);
		mcScore._x = 268;
		mcScore._y = 265;
		mcScore._field.setText("");
	}

	public function isLocked() {
		return lockSlime || flGameOver;
	}

	public function lock() {
		lockSlime = true;
	}

	public function unlock() {
		lockSlime = false;
	}

	public function resetExplosion() {
		explosion = 0;
		mcScore.timer = Cs.ALPHA_SCORE;
	}

	// UPDATE
	public function update(delta:Float) {
		// Flash played Aqua Splash at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32: tmod = 0.8, one
		// update() per Flash frame. KadoKadeo steps 32 times per second: 5 Flash frames every 4 steps. The mouse
		// events of the step come between two Flash frames, like Flash's
		mt.Timer.tmod = 32 / FRAME_RATE;
		updateMouse();
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame();
		}
		MC.displayAll(frameAcc / 4);
	}

	function flashFrame() {
		MC.frameStart();
		frameCount++;
		main();
	}

	// update() of the original: one Flash frame
	function main() {
		// (cheatDetected / KKApi.flagCheater: the PArray anti-cheat of the original)
		updateSprites();
		updateScore();

		switch (step) {
			case Play:
				updateTime();

				if (flGameOver) {
					gameOver();
					step = GameOver;
				}

			case Spout:
				if (!noMoreDrops())
					return;

				if (checkNextLevel()) {
					initNextLevel();
					return;
				}

				checkEnd();
				setPlay();

			case Bombing:
				if (mcBomb == null || mcBomb._currentframe >= 20) {
					if (toReduce != null) {
						step = Explode;
						return;
					} else {
						if (checkNextLevel()) {
							initNextLevel();
							return;
						}

						checkEnd();
						setPlay();
					}
				}

			case Explode:
				// for (s in toReduce): the length is read at each turn, a slime removed lets the next one wait
				// until the next frame
				var i = 0;
				while (i < toReduce.length) {
					var s = toReduce[i];
					i++;
					if (s.ungrowing())
						toReduce.remove(s);
				}

				if (toReduce.length > 0)
					return;

				if (checkNextLevel()) {
					initNextLevel();
					return;
				}

				checkEnd();
				setPlay();

			case NextLevel:
				timer -= 5 * mt.Timer.tmod;
				if (!mcLevel.hasBurn() && timer < 0) {
					timer = null;
					prepareLevel();
					setNextLevel(false);
					setPlay();
				} else
					mcLevel.setText(Std.string(level + 1));

			case GameOver:
		}
	}

	function updateTime() { // update TimeLine && check gameover
		var now = getTimer();
		var c = Cs.PLAY_TIME - (now - mcTime.start);

		if (c > 0)
			mcTime._timeLeft._xscale = c / Cs.PLAY_TIME * 100;
		else
			forceReduce();

		// TIME PARTS (pictures only: visual random)
		var nb = 1 + Seed.randomVfx(4);
		var drop = {
			x: Data.TIME_LEFT_H * mcTime._timeLeft._yscale / 100,
			y: 230 - Data.TIME_LEFT_W * mcTime._timeLeft._xscale / 100 + 1
		};
		for (i in 0...nb) {
			// Col.setColor(mc, 0xFF9900) baked in the picture
			var mc = dm.attach("part1", DP_PARTS);
			mc._xscale = 40 + Seed.randVfx() * 10;
			mc._yscale = 40;
			mc.setAdd();

			var s = new Phys(mc);
			s.x = 6 + i * (drop.x / nb);
			s.y = drop.y;
			s.weight = -0.2;
			s.alpha = 90;
			s.vx = Seed.randVfx() * 1;
			s.vy = Seed.randVfx() * -4;
			s.fadeType = 5; // alpha
			s.timer = 5;
		}
	}

	public function resetTime() {
		mcTime.start = getTimer();
		mcTime._timeLeft._xscale = 100;
	}

	function forceReduce() {
		resetTime();

		var slime = null;
		var count = 30;
		while (slime == null && count > 0) {
			count--;
			slime = slimes[Seed.random(slimes.length)];

			if (slime != null && slime.grow == 1)
				slime = null;
		}

		if (slime == null) // not found
			return;

		#if debug
		stats.reduce++;
		#end
		slime.growTo(slime.grow - 1);
	}

	function updateScore() {
		if (mcScore.timer == null)
			return;
		mcScore.timer -= 5 * mt.Timer.tmod;
		if (mcScore.timer <= 0) {
			mcScore._field.setText("");
			mcScore._field._alpha = Cs.ALPHA_SCORE;
		} else {
			mcScore._field._alpha = mcScore.timer;
		}
	}

	public function setPlay() {
		resetExplosion();
		if (toReduce != null)
			toReduce = null;

		if (checkNextLevel()) {
			initNextLevel();
			return;
		}

		step = Play;
		resetTime();

		if (checkEnd())
			setGameOver();

		unlock();
	}

	public function noMoreDrops():Bool {
		return drops == null || drops.length == 0;
	}

	public function initSploutch(from:Slime) {
		if (step == Spout || from == null || !from.bigEnough())
			return;

		step = Spout;
		from.explode();
	}

	public function checkNextLevel() {
		if (slimes == null || slimes.length == 0)
			return true;
		for (s in slimes) {
			if (!s.bonus)
				return false;
		}
		return true;
	}

	public function initNextLevel() {
		step = NextLevel;
		level++;
		#if debug
		stats.levels++;
		#end

		Game.me.addScore(Cs.BONUS_LEVEL);

		mcScore._field.setText("");
		mcScore._field._alpha = Cs.ALPHA_SCORE;

		upPlay();
		timer = 100;

		setNextLevel(true);
	}

	public function downPlay() {
		var mc = mcPlays[plays - 1];
		if (mc != null)
			mc.gotoAndStop(1);
		plays--;
	}

	public function upPlay(?p:Pos) {
		if (plays >= Cs.MAX_PLAYS)
			return;
		plays++;

		var mc = mcPlays[plays - 1];
		if (mc != null) {
			mc.gotoAndStop(3);
			launchLights(mc);
		}
	}

	public function initBombing(p:Pos) {
		step = Bombing;
		#if debug
		stats.bombs++;
		#end

		mcBomb = dm.add(new Flame(), DP_PARTS);
		var pos = Cs.getPos(p, true);
		mcBomb._x = pos.x;
		mcBomb._y = pos.y;
	}

	public function getBonus(p:Pos) {
		#if debug
		stats.bonus++;
		#end
		powerUp(p, true);
		for (i in 0...Cs.BONUS_PLAYS) {
			upPlay();
		}
	}

	public function incExplode(p:Pos) {
		explosion++;
		#if debug
		stats.chains++;
		if (explosion > stats.maxChain)
			stats.maxChain = explosion;
		#end

		mcScore.timer = null;
		mcScore._field._alpha = Cs.ALPHA_SCORE;
		mcScore._field.setText("x" + explosion);

		if (Lambda.exists(Cs.WIN_PLAYS, function(x) {
			return x == Game.me.explosion;
		})) {
			upPlay(p);
			powerUp(p, false);
		}
	}

	public function powerUp(p:Pos, bonus:Bool) {
		// mc.smc.gotoAndStop(if (bonus) 2 else 1): one picture set per smc frame
		var mc = dm.attach(if (bonus) "powerup2" else "powerup1", DP_POINTS);
		mc.removeAt = 25;
		var pos = Cs.getPos(p, true);
		mc._x = pos.x;
		mc._y = pos.y;
	}

	public function checkEnd():Bool {
		if (flGameOver)
			return true;
		return plays <= 0;
	}

	public function setGameOver() {
		flGameOver = true;
	}

	// create new board for level l
	function prepareLevel() {
		// for (s in allSlimes) s.kill(): kill removes the slime from allSlimes, the loop skips the next one. Every
		// other slime of the last board is never killed: its clip stays (frame 5: invisible, still a button) under the
		// new board
		var i = 0;
		while (i < allSlimes.length) {
			var s = allSlimes[i];
			i++;
			s.kill();
		}
		#if debug
		stats.zombies += allSlimes.length;
		#end
		allSlimes = [];
		slimes = [];
		for (x in 0...Cs.BOARD_WIDTH) {
			for (y in 0...Cs.BOARD_HEIGHT) {
				var grow = Slime.getRandomGrow(level);

				var s = new Slime({x: x, y: y});

				if (level == 0 && grow == 0)
					grow = Seed.random(2) + 1;

				s.growTo(grow);
				allSlimes.push(s);

				if (grow != 0) {
					if (Seed.random(18) == 0) {
						if (Seed.random(10) == 0)
							s.addBonus();
					}
					slimes.push(s);
				}
			}
		}
	}

	public function addScore(sc:Int) {
		if (over)
			return;
		KadoKadeoManager.kkm.addScore(sc);
	}

	function updateSprites() {
		var list = Sprite.spriteList.copy();
		for (sp in list)
			sp.update();
	}

	// NEXT LEVEL MC
	function setNextLevel(on:Bool) {
		if (on) {
			if (mcLevel != null)
				mcLevel.removeMovieClip();
			mcLevel = dm.add(new NextLevel(), DP_ANIM);
			mcLevel.setText(Std.string(level + 1));
		} else {
			if (mcLevel == null)
				return;
			mcLevel.removeMovieClip();
			mcLevel = null;
		}
	}

	// ### PARTS (pictures only: visual random)
	public function launchLights(mc:MC) {
		// PARTS LIGHT
		var max = 8;
		var cr = 2;
		for (i in 0...max) {
			var a = (i + Seed.randVfx()) / max * 6.28;
			var ca = Math.cos(a);
			var sa = Math.sin(a);
			var sp = 0.5 + Seed.randVfx() * 10;
			var p = new Phys(Game.me.dm.attach("partLight", Game.DP_PARTS));
			var sc = 40 + Seed.randomVfx(60);
			p.root._xscale = sc;
			p.root._yscale = sc;

			p.root.setAdd();
			p.x = Cs.PLAYS_X + mc._x + ca * sp * cr;
			p.y = Cs.PLAYS_Y + mc._y + sa * sp * cr;
			p.vx = ca * sp + 0.4;
			p.vy = sa * sp + 0.4;
			p.frict = 0.8;
			p.fadeType = 5;
			p.timer = 10 + Seed.randVfx() * 15;
		}
	}

	// ---------------------------------------------------------------- port: game over
	function gameOver() {
		if (over)
			return;
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		var board = [for (s in allSlimes) s.bonus ? "b" : Std.string(s.grow)].join("");
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			level: level,
			plays: plays,
			board: board,
			stats: haxe.Json.stringify(stats)
		};
		#end
		KadoKadeoManager.kkm.gameOver({});
		over = true;
	}

	// ---------------------------------------------------------------- port: mouse
	// The slimes are Flash buttons (onRollOver, onRollOut, onRelease; no onDragOver / onDragOut / onReleaseOutside).
	// The pointer is polled once per step (the replay records it): the button under it is the topmost slime clip of
	// the slime plane whose shapes cover it (the zombies of the boards before included, see prepareLevel).
	function updateMouse() {
		var mx = Math.max(0, MouseManager.getX());
		var my = Math.max(0, MouseManager.getY());
		var under = slimeAt((mx + 0.5) / K, (my + 0.5) / K);
		// a button removed under the pointer: Flash sends it nothing more
		if (hovered != null && hovered.removed)
			hovered = null;
		if (!pressed && under != hovered) {
			if (hovered != null)
				hovered.slime.rollOut();
			hovered = under;
			if (hovered != null)
				hovered.slime.rollOver();
		}
		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT)) {
			pressed = true;
			pressTarget = hovered;
		}
		if (MouseManager.isButtonJustReleased(MouseManager.BUTTON_LEFT)) {
			var target = pressTarget;
			pressed = false;
			pressTarget = null;
			if (target != null && !target.removed && under == target) {
				// onRelease (the pointer is still over it: it stays the button under the mouse)
				target.slime.touch();
			} else {
				// released elsewhere (onReleaseOutside): the button pressed got onDragOut when the pointer left it,
				// no onRollOut; the button under the pointer gets its onRollOver at the next step
				hovered = null;
			}
		}
	}

	function slimeAt(fx:Float, fy:Float):SlimeMC {
		var plane = sdm.get(3);
		var i = plane.children.length - 1;
		while (i >= 0) {
			var c = plane.children[i];
			if (Std.isOfType(c, SlimeMC)) {
				var s:SlimeMC = cast c;
				if (!s.removed && s.hitTest(fx, fy))
					return s;
			}
			i--;
		}
		return null;
	}

	// ---------------------------------------------------------------- port: tools
	// The first use of a filter or a blend mode compiles its shader (tens of ms of freeze): the AlphaFilter of the
	// score and of the level plate and the "add" sprites are drawn once now, off screen
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new pixi.core.sprites.Sprite(Texture.WHITE);
		s.filters = [new AlphaFilter(0.5)];
		holder.addChild(s);
		var a = new pixi.core.sprites.Sprite(Texture.WHITE);
		a.blendMode = BlendModes.ADD;
		holder.addChild(a);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	#if debug
	// test harness (examples/aquasplash/pnext.mjs): n Flash frames played by hand, shown as they are (no lagged display)
	public function debugFrames(n:Int):Void {
		for (i in 0...n)
			flashFrame();
		MC.displayAll(1);
	}
	#end

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null)
				canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		MC.clearAll();
		Sprite.spriteList = [];
	}
}

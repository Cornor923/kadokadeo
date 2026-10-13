package logico;

import haxe.io.UInt16Array;
import logico.MC.Plans;
import pixi.core.display.Container;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;
import pixi.filters.alpha.AlphaFilter;

enum Step {
	Play;
	Move;
	Combo(a:Array<Ball>, nlist:Array<Ball>);
	Fill;
	GameOver;
}

typedef GROUP = {id:Int};

@:expose('GameLogicO')
class Game implements kado.GameInterface {
	// texture pixels per Flash pixel: the original's 300 x 300 pixels drawn x2
	public static inline var K = 2;
	// Flash played Logico at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32: tmod = 0.8 (halved by update)
	public static inline var FRAME_RATE = 40;

	public static var FL_DEBUG = true;
	public static var MODE = 0;

	public static inline var DP_BG = 0;
	public static inline var DP_SHADE = 1;
	public static inline var DP_PLASMA = 3;
	public static inline var DP_LINE = 4;
	public static inline var DP_BALLS = 5;
	public static inline var DP_PARTS = 7;
	public static inline var DP_POOL = 10;
	public static inline var DP_INTER = 11;

	public var flForceDeath:Bool = false;

	// (mt.flash.Volatile: the anti-cheat of the original, plain variables)
	public var mult:Int;
	public var colorMax:Int;
	public var toFill:Int;
	public var pool:Int;
	public var ghost:Null<Int>;
	public var tcoef:Float;
	public var cycle:Float;
	public var dif:Float;
	public var lck:Float;
	public var rcoef:Null<Float>;
	public var nextTimer:Float;
	public var circleDecal:Float;
	public var toScore:KKConst;

	public var balls:Array<Ball>;
	public var bcount:Int;
	public var selection:Array<Ball>;
	public var miniballs:Array<MC>;
	public var mcLine:MC;
	public var mcMult:MC;
	public var mcScore:ScoreMC;
	public var plasma:Plasma;

	public var step:Step;
	public var dm:Plans;
	public var sdm:Plans;
	public var root:MC;
	public var bg:MC;
	public var stats:{a:Array<Array<Int>>, lck:Int};

	static public var me:Game;

	// ---------------------------------------------------------------- port
	static inline var EV_SELECT = 0;

	var isReplay:Bool;
	var buttons:Buttons;
	// replay: the balls pressed in the step (their index in the ring), played in its first Flash frame
	var replaySelects:Array<Int> = [];
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	var over:Bool = false;
	var onPointerDown:Dynamic;
	var flushListener:Dynamic;
	var handCursor:Bool = false;
	var shadeFilter:AlphaFilter;

	#if debug
	// test harness: what the game went through (window.__over)
	public var dstats:Dynamic;
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			// the press on a ball is the only input of the game: recorded as an event (the hovers are only glows)
			recordEvents: true,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		// statics of the original (the SWF was loaded again for every game)
		MC.clearAll();
		Sprite.spriteList = [];
		MODE = 0;
		mt.Timer.tmod = 32 / FRAME_RATE;
		#if debug
		dstats = {
			combos: 0,
			balls: 0,
			selects: 0,
			fills: 0,
			maxMult: 0
		};
		#end
		// like the Flash player, a pressed button keeps the mouse until it is released (KadoKadeo releases the buttons
		// when the pointer leaves the canvas)
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
		bg = dm.attach("bg", DP_BG);
		// (bg.cacheAsBitmap = true)

		var mcShade = dm.empty(DP_SHADE);
		sdm = new Plans(mcShade);
		// mcShade.blendMode = "layer", mcShade._alpha = 50: the shadows drawn together, then at 50 %
		shadeFilter = new AlphaFilter(0.5);
		mcShade.spr.filters = [shadeFilter];

		circleDecal = 0;
		pool = 0;
		colorMax = 3;
		dif = 0;
		cycle = 50;
		nextTimer = 2000;
		lck = Num.q(Math.pow(Seed.rand(), 0.5));

		stats = {a: [], lck: Std.int(lck * 100)};

		miniballs = [];

		buttons = new Buttons(dm, [DP_BALLS]);

		initBalls();
		initPlay();
		// (initKeyListener: debug keys doing nothing)
		initPlasma();

		// the plasma is drawn on the GPU just before the screen is: after the steps of the frame (NORMAL priority),
		// before the render of the page (LOW)
		flushListener = function(_) if (plasma != null)
			plasma.flush();
		var ticker:Dynamic = KadoKadeoManager.kkm.ticker;
		ticker.add(flushListener, null, -10);

		MC.displayAll(1);
		warmShaders();
	}

	function initPlasma() {
		plasma = new Plasma(dm.empty(20), Cs.mcw, Cs.mch);
		// BlurFilter 4 x 4, ColorTransform(1, 1, 1, 1, 0, 0, 0, -15), root.blendMode = "add": see Plasma
	}

	// ---------------------------------------------------------------- KadoKadeo
	public function update(delta:Float) {
		// Flash played Logico at 40 frames/s with Timer.wantedFPS = 32: tmod = 0.8, one update() per Flash frame.
		// KadoKadeo steps 32 times per second: 5 Flash frames every 4 steps. The mouse events of the step come
		// between two Flash frames, like Flash's (in a replay: the presses recorded on the step)
		var changes = [];
		if (isReplay) {
			for (e in KadoKadeoManager.kkm.replay.consumeEvents())
				if (e != null && e.k == EV_SELECT)
					replaySelects.push((e.x << 3) | e.y);
		} else {
			for (c in MouseManager.getFrameButtonChanges())
				if (c.button == MouseManager.BUTTON_LEFT)
					changes.push(c.isDown);
		}
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame(changes);
			changes = [];
		}
		MC.displayAll(frameAcc / 4);
		plasma.show(frameAcc / 4);
		setHandCursor(!over && buttons.handCursor());
	}

	// one Flash frame: playheads advance, the mouse events of the buttons, then the original update()
	function flashFrame(changes:Array<Bool>) {
		frameCount++;
		mt.Timer.tmod = 32 / FRAME_RATE;
		MC.frameStart();
		if (isReplay)
			playSelects();
		else
			buttons.frame(Math.max(0, MouseManager.getX()) / K, Math.max(0, MouseManager.getY()) / K, changes);
		main();
		plasma.frameEnd();
	}

	// UPDATE (update() of the original)
	function main() {
		mt.Timer.tmod /= 2; // GAME WAS BUILT WITH 2 CALLS TO mt.Timer.update

		// (KKApi.loader.buttons: read and unused)

		if (flForceDeath)
			step = GameOver;

		// (step is null once KKApi.gameOver was called: no case)
		if (step != null)
			switch (step) {
				case Fill:
					updateFill();
				case Play:
					updatePlay();
					updateDif();
				case Move:
					updateDif();
				case Combo(list, nlist):
					updateCombo(list, nlist);
				case GameOver:
					updateGameOver();
			}

		plasma.update();
		updateBalls();
		updateSprites();

		// (bcount != balls.length: KKApi.flagCheater)
	}

	function updateSprites() {
		var list = Sprite.spriteList.copy();
		for (sp in list)
			sp.update();
	}

	// BALLS
	function initBalls() {
		balls = [];
		bcount = 0;
		for (i in 0...16)
			newBall();
	}

	function newBall() {
		var ball = new Ball();
		ball.x = Cs.mcw * 0.5;
		ball.y = Cs.mch * 0.5;
		ball.flMove = true;

		var id = Seed.random(getBallsLength() + 1);
		var prev:Ball = null;
		var next:Ball = null;

		if (Seed.rand() > lck) {
			var to = 0;
			while (getBallsLength() > 4) {
				id = Seed.random(getBallsLength() + 1);
				prev = getBall(id, -1);
				next = getBall(id, 0);
				if (prev.col != next.col) {
					break;
				}
				if (to++ > 100) {
					// (trace "yahoo!")
					break;
				}
			}
		}

		// COL
		if (getBallsLength() >= 3) {
			if (prev == null) {
				next = getBall(id, -1);
				prev = getBall(id, 0);
			}

			var cols = [];
			for (n in 0...colorMax)
				cols.push(n);
			if (prev.group > 2)
				cols.remove(prev.col);
			if (next.group > 2)
				cols.remove(next.col);
			if (prev.col == next.col && prev.group + next.group > 2)
				cols.remove(next.col);
			ball.setSkin(cols[Seed.random(cols.length)]);
		} else {
			ball.setSkin(Seed.random(colorMax));
		}

		// INSERT_BALL
		Game.me.balls.insert(id, ball);
		bcount++;
		#if debug
		dstats.balls++;
		#end

		// START POS
		var a = id / getBallsLength() * 6.28;
		ball.x += Num.q(Math.cos(a)) * 200;
		ball.y += Num.q(Math.sin(a)) * 200;

		//
		if (getBallsLength() >= 4)
			buildGroups();
	}

	function updateBalls() {
		var max = getBallsLength();
		var circ = max * 2 * Cs.BRAY;
		var ray = circ / 6.28;

		for (i in 0...max) {
			var ball = balls[i];

			var a = 6.28 * (i + circleDecal) / max;
			ball.tx = Cs.mcw * 0.5 + Num.q(Math.cos(a)) * ray;
			ball.ty = Cs.mch * 0.5 + Num.q(Math.sin(a)) * ray;
		}

		// (a rainbow colour of bg.smc above a radius of 20, commented out in the original: rcoef stays null, the else
		// branch does nothing)
	}

	// SELECTION
	public function select(ball:Ball) {
		ballOut();

		var id:Int = getBallId(ball);
		var max = getBallsLength();
		var id2 = (id + Math.ceil(max * 0.5)) % max;
		ball.flMove = true;

		switch (MODE) {
			case 0:
				balls.splice(id, 1);
				if (id2 > id)
					id2--;
				// INSERT_BALL
				balls.insert(id2, ball);
			case 1:
				var ball2 = balls[id2];
				balls[id] = ball2;
				balls[id2] = ball;
				ball2.flMove = true;
		}

		//
		step = Move;
		for (b in balls)
			b.deactivate();

		//
		circleDecal = id2 / max;
		incPool(1);
		#if debug
		dstats.selects++;
		#end
	}

	public function ballOver(ball:Ball) {
		selection = [ball];

		switch (MODE) {
			case 0:
			case 1:
				var max = getBallsLength();
				var id2 = (getBallId(ball) + Std.int(max * 0.5)) % max;
				var ball2 = balls[id2];
				selection.push(ball2);
		}

		for (b in selection) {
			dm.over(b.root);
			// Filt.glow(b.root, 8, 2, 0xFFFFFF, true), Filt.glow(b.root, 2, 4, 0xFFFFFF): baked in the pictures
			b.setGlowOver(true);
		}

		ghost = getBallId(ball);
	}

	public function ballOut() {
		ghost = null;
		// (mcLine.removeMovieClip(): mcLine is never created)
		mcLine = null;

		// (a for over an undefined selection in AVM1 does nothing)
		if (selection != null)
			for (b in selection) {
				// b.root.filters = []
				b.setGlowOver(false);
			}
	}

	// COMBO
	public function buildGroups() {
		for (b in balls)
			b.group = 1;
		if (getBallsLength() <= 1)
			return;

		var i = 0;
		var col:Null<Int> = null;
		var a = [];
		var to = 0;
		while (true) {
			var id = i % getBallsLength();
			var ball = balls[id];
			if (ball.col != col) {
				a = [ball];
				col = ball.col;
				if (i != id)
					break;
			} else {
				for (b in a) {
					if (b == ball)
						break;
					b.group++;
				}
				a.push(ball);
				ball.group = a[0].group;
			}
			i++;

			if (to++ > 200) {
				// HAPPEN
				return;
			}
		}
	}

	public function checkCombo() {
		if (getBallsLength() < 4) {
			initTurn();
			return;
		}

		buildGroups();

		var list = [];
		for (b in balls) {
			if (b.group >= Cs.COMBO_LIMIT)
				list.push(b);
		}

		if (list.length > 0) {
			nextTimer = cycle;
			step = Combo(list, []);
			tcoef = 0;
			toScore = KKApi.cmult(KKApi.const(list.length), Cs.SCORE_BALL);
			toScore = KKApi.cadd(toScore, KKApi.cmult(KKApi.const(list.length - Cs.COMBO_LIMIT), Cs.SCORE_BALL_SUP));
			toScore = KKApi.cmult(toScore, KKApi.const(mult));
			// stats.a.push( [list.length,mult] ); //OVERFLOW
			mult++;
			#if debug
			dstats.combos++;
			if (mult - 1 > dstats.maxMult)
				dstats.maxMult = mult - 1;
			#end
		} else {
			mult = 1;
			initTurn();
		}
	}

	public function updateCombo(list:Array<Ball>, nlist:Array<Ball>) {
		tcoef = Math.min(tcoef + 0.2 * mt.Timer.tmod, 1);
		if (tcoef < 1) {
			// the step of tcoef (0.2 * tmod each Flash frame): the picture of the ball at it
			var k = Std.int(Math.round(tcoef / (0.2 * mt.Timer.tmod)));
			k = k < 1 ? 1 : k > Data.COMBO_STEPS ? Data.COMBO_STEPS : k;
			for (ball in list) {
				// Col.setPercentColor(ball.root, tcoef * 100, 0xFFFFFF), ball.root.filters = [],
				// Filt.glow(ball.root, c * 30, c, 0xFFFFFF) with c = tcoef^2: baked in the pictures
				ball.setCombo(k);

				plasma.drawMc(ball.root, ball.col);
				// (mcRay particles: commented out in the original)
			}
		} else {
			for (ball in list) {
				// REMOVE_BALL
				balls.remove(ball);
				ball.explode();
				bcount--;
			}

			addScore(toScore);
			displayScore();
			checkCombo();
		}
	}

	// TURN
	public function initTurn() {
		var ballMin = colorMax * 4 - 1;
		if (getBallsLength() < ballMin || pool >= Cs.POOL_LIMIT) {
			emptyPool();
			var dif = ballMin - (getBallsLength() + toFill);
			if (dif > 0)
				toFill += dif;
		} else {
			initPlay();
		}
	}

	public function updateFill() {
		tcoef += 0.5 * mt.Timer.tmod;
		while (tcoef >= 1) {
			tcoef--;
			newBall();
			toFill--;
			// (miniballs.pop().removeMovieClip(): the pool is never drawn, miniballs stays empty)
			miniballs.pop();

			var circ = getBallsLength() * 2 * Cs.BRAY;
			var ray = circ / 6.28;
			if (ray > 132) {
				initGameOver();
			} else if (toFill == 0) {
				initPlay();
			}
		}
	}

	// PLAY
	function initPlay() {
		mult = 1;
		for (b in balls)
			b.activate();
		step = Play;
	}

	function updatePlay() {
		if (nextTimer <= 0) {
			incPool(1);
			if (pool >= Cs.POOL_LIMIT)
				emptyPool();
			nextTimer += cycle;
		};
	}

	function incPool(inc:Int) {
		// (one mcMiniBall per ball of the pool: commented out in the original)
		pool += inc;
	}

	function emptyPool() {
		tcoef = 0;
		step = Fill;
		toFill = pool;
		pool = 0;
		#if debug
		dstats.fills++;
		#end
	}

	// GAMEOVER
	function initGameOver() {
		step = GameOver;
		for (b in balls)
			b.frozen = true;
		flForceDeath = true;
	}

	function updateGameOver() {
		if (getBallsLength() > 0) {
			balls.pop().explode();
			bcount--;
		} else {
			gameOver();
			step = null;
		}
	}

	// DIFFICULTE
	function updateDif() {
		nextTimer -= mt.Timer.tmod;
		dif += mt.Timer.tmod;
		cycle -= mt.Timer.tmod * 0.013;

		if (dif * 0.05 > Num.q(Math.pow(colorMax, 3)) && colorMax < 7) {
			colorMax++;
		}
	}

	// FX
	// (displayMult: never called by the original)

	function displayScore() {
		// (mcScore._visible: undefined, false, once mcScore is removed)
		if (mcScore != null && !mcScore.removed && mcScore._visible)
			mcScore.removeMovieClip();
		mcScore = dm.add(new ScoreMC(), DP_INTER);
		mcScore._x = Cs.mcw;
		mcScore._y = Cs.mch;
		var str = "+" + KKApi.val(toScore) / (mult - 1);
		if (mult > 2)
			str += " x" + (mult - 1);
		mcScore.setText(str);
		var p = new Part(mcScore);
		p.timer = 16;
		p.fadeLimit = 4;
	}

	//
	function getBall(id:Int, inc:Int):Ball {
		return balls[Std.int(Num.sMod(id + inc, getBallsLength()))];
	}

	function getBallId(ball:Ball):Null<Int> {
		var id = 0;
		for (b in balls) {
			if (b == ball)
				return id;
			id++;
		}
		return null;
	}

	function getBallsLength() {
		return balls.length;
	}

	// ---------------------------------------------------------------- port: score, game over
	function addScore(n:KKConst) {
		if (over)
			return;
		KadoKadeoManager.kkm.addScore(KKApi.val(n));
	}

	function gameOver() {
		if (over)
			return;
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			colorMax: colorMax,
			dif: dif,
			cycle: cycle,
			pool: pool,
			lck: stats.lck,
			stats: haxe.Json.stringify(dstats)
		};
		#end
		// KKApi.gameOver(stats)
		KadoKadeoManager.kkm.gameOver(stats);
		over = true;
		setHandCursor(false);
	}

	// ---------------------------------------------------------------- port: mouse
	// onPress of a ball (live): recorded on the step being played, the replay presses it at the same moment
	public function press(ball:Ball) {
		var id = getBallId(ball);
		if (id == null)
			return;
		// the index in the ring (less than 27 balls: the game is over above 26) packed in one byte
		KadoKadeoManager.kkm.replay.recordEvent({k: EV_SELECT, x: id >> 3, y: id & 7}, KadoKadeoManager.kkm.replay.getCurrentFrame());
		select(ball);
	}

	// replay: the presses of the step, where the live game took them. Not in Play only: the balls keep their handlers
	// when the timer empties the pool (emptyPool does not deactivate them, like the original), a press during the Fill
	// (or the GameOver that follows it) selects a ball and stops the fill
	function playSelects() {
		for (id in replaySelects) {
			var ball = balls[id];
			if (ball != null && ball.root.onPress != null)
				select(ball);
		}
		replaySelects = [];
	}

	// root.useHandCursor of the ball under the mouse (live games only: the cursor of the page)
	function setHandCursor(on:Bool) {
		if (isReplay || on == handCursor)
			return;
		handCursor = on;
		var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
		if (canvas != null)
			canvas.style.cursor = on ? "pointer" : "";
	}

	// ---------------------------------------------------------------- port: display
	// The first use of a filter compiles its shader (tens of ms of freeze): the AlphaFilter (shadows, score fade) is
	// drawn once now, off screen (the plasma compiles its own)
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		s.filters = [new AlphaFilter(0.5)];
		holder.addChild(s);
		var rt:Dynamic = (cast RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			if (canvas != null)
				canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		setHandCursor(false);
		if (flushListener != null) {
			var ticker:Dynamic = KadoKadeoManager.kkm.ticker;
			ticker.remove(flushListener);
			flushListener = null;
		}
		if (plasma != null)
			plasma.destroy();
		plasma = null;
		MC.clearAll();
		Sprite.spriteList = [];
		if (me == this)
			me = null;
	}
}

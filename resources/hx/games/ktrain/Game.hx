package ktrain;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import ktrain.MC.Holder;
import ktrain.MC.FilterSpec;

// Game.hx of the original (Haxe for Flash 8), line by line, as compiled in the released game.swf; the port's own parts
// are at the end

@:expose('GameKTrain')
class Game implements kado.GameInterface {
	// in the locomotive: up / down change the speed, left / right send the driver out; outside, the arrows walk;
	// space brakes
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
				bottomPx: 90,
				size: 60,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "down",
				label: "▼",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.DOWN,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "brake",
				label: "■",
				rightPx: 20,
				bottomPx: 160,
				size: 60,
				keyCode: KeyboardManager.SPACE,
			},
		],
	};

	// ZQSD / WASD move like the arrows, Enter brakes like space
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	// Flash played K-Train at 40 frames/s (the rate of the SWF and of the KadoKado loader) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	public var dm:DepthManager;
	public var root:ASprite;
	public var gameOver:Bool;
	public var coal:Float;
	public var me:Float;
	public var opp:Float;
	public var oppCycles:Float;

	public static var game:Game = null;
	public static var signalSent = false;
	public static var startBoom = 0;

	public var scroll:Float;

	var cycles:Int;
	var anim:Array<Anim>;

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
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
		MC.clearAll();
		Clip.reset();
		Bmp.reset();
		resetStatics();
		// mt.Timer before its first update (Manager.init creates the game before the first Manager.main)
		Timer.tmod = 1;
		Clip.deferring = true;
		Game.me_ = this;
		// the original's 300x300 pixels, drawn x2
		stage = mc.createEmptyMovieClip("scene", 0);
		stage._xscale = stage._yscale = 100 * Clip.K;
		stage.updateState();
		stage.addChild(new Bmp.Flusher());

		anim = [];
		game = this;
		me = 0;
		opp = 0;
		coal = 0;
		oppCycles = 0;
		coal += (KKApi.val(Const.NEXT_STATION) + Const.LOCO_H * 3) * KKApi.val(Const.STATION_COAL);
		gameOver = false;
		cycles = 0;
		root = stage;
		dm = new DepthManager(new Holder(stage));
		scroll = 1;

		Man.init(this);
		SceneManager.init(this);
		RailManager.init(this);
		Loco.init(this);
		Station.init(this);
		ObjectManager.init(this);
		Gem.init(this);
		Levier.init(this);
		// initKeyListener: the key presses are taken by update (onKeyDown)

		Clip.deferring = false;
		Clip.runLater();
		Bmp.flushAll();
		MC.displayAll(1);
		// Flash shows the first picture after the first frame (Manager.init, then Manager.main)
		stage.visible = false;
		warmShaders();
	}

	public function origUpdate() {
		var tmod = Timer.tmod;
		scroll = tmod * Const.SPEED;

		updateCoal();
		updateOpp(tmod);

		if (Sprite.spriteList.length > 0) {
			var l = Sprite.spriteList.copy();
			for (s in l) {
				s.update();
			}
		}

		if (anim.length > 0) {
			// (the length is read at each turn: after a removal the next animation waits for the next frame)
			var i = 0;
			while (i < anim.length) {
				var a = anim[i++];
				if (a.play()) {
					a.onEnd();
					a.clean();
					anim.remove(a);
				}
			}
			return;
		}

		if (gameOver && !signalSent) {
			sendGameOver();
			signalSent = true;
		}

		if (Loco.lockSpeed)
			scroll *= 4;

		// SCROLL
		updateSpeed(tmod);
		Scroller.scroll(scroll);
		SceneManager.update(scroll);
		RailManager.scroll(scroll);
		Station.scroll(scroll);

		// MAN
		updateManMove();

		// NON-GRAPHICAL
		SceneManager.clean();
		ObjectManager.update(scroll);
		Station.update(scroll);
		RailManager.update(scroll);
		RailManager.clean();
		Scroller.clean();
		Gem.update(scroll);
		updateGameplay();
		Loco.update(scroll);
	}

	function updateCoal() {
		coal -= scroll;

		if (coal <= 0 && !gameOver) {
			if (Const.SPEED <= 0) {
				gameOver = true;
				return;
			}
			Const.NEXT_SPEED = 0;
			Const.STEP_SPEED = 0;
			updateSpeedoMeter();
			Levier.noMoreCoal();
		}

		Levier.updateCoal();
	}

	public function addCoal() {
		if (gameOver)
			return;

		var a = new CoalAnim(this);
		var me = this;
		a.onEnd = function() {
			me.coal += (KKApi.val(Const.NEXT_STATION) + Const.LOCO_H * 3) * KKApi.val(Const.STATION_COAL);
		}
		anim.push(a);
	}

	// pieces of the locomotive pushed by the train behind (only pictures: visual random)
	public function boom() {
		if (startBoom-- <= 0)
			return;

		for (i in 0...3) {
			var m = game.dm.attach("mcDebris", Const.DP_RAIL);
			m._rotation = Const.randomVfx(360);
			m._y = Loco.mcBad._y - Const.LOCO_H;
			m._x = Const.CENTER_X + (if (Const.randomVfx(2) != 0) 20 else -20);
			m.gotoAndStop(Const.randomVfx(m._totalframes - 1) + 1);
			var p = new Phys(m);
			p.timer = 15;
			p.vy = 3 * Timer.tmod;
			p.vr = Const.randomVfx(2) * Timer.tmod;
			p.weight = -(m._width / 20);
			p.vx = if (Const.randomVfx(2) != 0) Const.randomVfx(10) * Timer.tmod else -Const.randomVfx(10);
			p.fadeType = 3;
		}
	}

	function updateOpp(tmod:Float) {
		me += tmod * Const.SPEED;
		opp += tmod * KKApi.val(Const.OPP_SPEED);
		Levier.updateOpp();
	}

	public function updateGameplay() {
		cycles += Std.int(scroll);
		oppCycles += scroll;

		if (gameOver)
			return;
		if (cycles > Const.FRAME_RATE) {
			addScore(KKApi.const(Std.int(KKApi.val(Const.BASE_SCORE) * Const.SPEED * 0.90)));
			cycles = 0;
		}

		if (oppCycles > KKApi.val(Const.OPP_CYCLE)) {
			Const.OPP_SPEED = KKApi.const(KKApi.val(Const.OPP_SPEED) + 1);
			oppCycles = 0;
		}
	}

	public function incSpeed() {
		if (Const.NEXT_SPEED < Const.MAX_SPEED) {
			Const.NEXT_SPEED = Math.pow(++Const.STEP_SPEED, 2);
		}
	}

	// (compiled form of the tests)
	public function updateSpeed(tmod:Float) {
		if (Const.SPEED <= 0 && Const.STEP_SPEED <= 0) {
			Const.SPEED = 0.0;
			return;
		}

		var mv = Const.SPEED_DIFF * tmod;

		if (Const.SPEED != Const.NEXT_SPEED) {
			if (Const.NEXT_SPEED <= Const.SPEED) {
				if (Const.NEXT_SPEED >= Const.SPEED) {
					Const.SPEED = Const.SPEED >= 0 ? Std.int(Const.SPEED) : 0;
				} else if (Const.SPEED <= Const.SPEED_DIFF) {
					Const.SPEED = 0.0;
				} else {
					Const.SPEED -= mv;
				}
			} else {
				Const.SPEED += mv;
			}
		}

		Levier.updateCounter();
	}

	public function updateManMove() {
		var kd = false;

		if (KeyboardManager.isDown(KeyboardManager.LEFT) && !Man.outside) {
			if (Man.left())
				kd = true;
		}

		if (KeyboardManager.isDown(KeyboardManager.RIGHT) && !Man.outside) {
			if (Man.right())
				kd = true;
		}

		if (KeyboardManager.isDown(KeyboardManager.UP)
			|| KeyboardManager.isDown(KeyboardManager.DOWN)
			|| KeyboardManager.isDown(KeyboardManager.LEFT)
			|| KeyboardManager.isDown(KeyboardManager.RIGHT)) {
			kd = true;
			Man.go();
		}

		if (Man.inLoco() && kd && !game.gameOver) {
			kd = false;
			#if debug
			stats.boards++;
			#end
			Man.init(this);
			Loco.move = false;
			Levier.show();
			if (Const.SPEED <= 0) {
				Const.NEXT_SPEED = 1;
				Const.STEP_SPEED = 1;
			}
			unlockScroll();
		}

		Man.update();
	}

	public function unlockScroll() {
		Scroller.lock = false;
		Scroller.showObjects();
		ObjectManager.lock = false;
		SceneManager.lock = false;
		RailManager.lock = false;
		Station.lock = false;
	}

	public function stopScroll() {
		Levier.hide();
		Scroller.lock = true;
		Scroller.hideObjects();
		ObjectManager.lock = true;
		SceneManager.lock = true;
		RailManager.lock = true;
		Loco.move = true;
		Station.lock = true;
		Man.show();
	}

	// Key.getCode(): the key just pressed
	public function changeSpeed(code:Int) {
		switch (code) {
			case KeyboardManager.UP:
				incSpeed();

			case KeyboardManager.DOWN:
				if (Const.SPEED <= 0)
					return;
				if (Const.STEP_SPEED <= 0)
					return;
				Const.NEXT_SPEED = Math.max(0, Math.pow(--Const.STEP_SPEED, 2));
		}

		updateSpeedoMeter();
	}

	public function updateSpeedoMeter() {
		Levier.update(Const.STEP_SPEED);
	}

	// Key.addListener({onKeyDown: ...}): every key pressed
	public function onKeyDown(code:Int) {
		if (coal <= 0)
			return;

		if (!Man.outside) {
			changeSpeed(code);
			return;
		}
	}

	// ---------------------------------------------------------------- port
	public static var me_:Game;

	var isReplay:Bool;
	var stage:ASprite;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	// the score of KKApi, nothing after the game over
	var score:Int = 0;

	#if debug
	// test harness: events of the game (coverage)
	public var stats = {
		gems: 0,
		piouz: 0,
		piouzCrash: 0,
		stations: 0,
		tunnels: 0,
		crash: 0,
		exits: 0,
		boards: 0,
		brakes: 0,
	};
	#end

	// (the statics of the original: the SWF was loaded again for every game)
	function resetStatics() {
		Const.reset();
		Man.reset();
		Loco.reset();
		Levier.reset();
		ObjectManager.reset();
		RailManager.reset();
		SceneManager.reset();
		Scroller.reset();
		Station.reset();
		Gem.reset();
		Sprite.spriteList = [];
		CoalAnim.reset();
		game = null;
		signalSent = false;
		startBoom = 0;
	}

	public function stageRoot():ASprite {
		return stage;
	}

	// KKApi.addScore
	public function addScore(c:KKConst) {
		if (signalSent)
			return;
		var n = KKApi.val(c);
		score += n;
		if (n != 0)
			KadoKadeoManager.kkm.addScore(n);
	}

	// KKApi.gameOver({})
	function sendGameOver() {
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	// ---------------------------------------------------------------- KadoKadeo step: 5 Flash frames every 4 steps
	public function update(delta:Float) {
		// Key.addListener: the keys pressed since the last frame, before it (the replay records them, even a press and its
		// release in the same step)
		var pressed = [];
		for (c in KeyboardManager.getFrameKeyChanges())
			if (c.isDown)
				pressed.push(c.keyCode);
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame(pressed);
			pressed = [];
		}
		MC.displayAll(frameAcc / 4);
	}

	// one Flash frame: the key events, the timelines advance, then Manager.main (tmod ~0.8: Timer settles on 32 / 40),
	// then the frame scripts the code triggered
	function flashFrame(pressed:Array<Int>) {
		Timer.tmod = 32 / FLASH_FPS;
		Clip.deferring = true;
		for (k in pressed)
			onKeyDown(k);
		Clip.deferring = false;
		MC.frameStart();
		Clip.deferring = true;
		origUpdate();
		Clip.deferring = false;
		Clip.runLater();
		frameCount++;
		stage.visible = true;
		#if debug
		untyped js.Browser.window.__state = debugState();
		#end
	}

	// the filters compile their shaders now, not at the first gem
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		if (renderer == null)
			return;
		var holder = new pixi.core.display.Container();
		for (f in ([
			new FlashBlur([4], [0]),
			new FlashBlur([4, 6], [0, 0]),
			new FlashColorMatrix([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0])
		] : Array<Dynamic>)) {
			var s = new pixi.core.sprites.Sprite(pixi.core.textures.Texture.WHITE);
			s.filters = [f];
			holder.addChild(s);
		}
		var m = new pixi.core.sprites.Sprite(pixi.core.textures.Texture.WHITE);
		m.blendMode = pixi.core.Pixi.BlendModes.MULTIPLY;
		holder.addChild(m);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	#if debug
	// state compared between a game and its replay (test harness)
	public function debugState():Dynamic {
		var man = Man.debugMan();
		var l = Scroller.debugLists();
		var os:Array<MC> = l.objects;
		var gs:Array<MC> = l.gems;
		var osum = 0.0;
		if (os != null)
			for (o in os)
				osum += o._x * 7 + o._y;
		var gsum = 0.0;
		var ng = 0;
		if (gs != null)
			for (g in gs)
				if (!g.removed) {
					gsum += g._x * 7 + g._y;
					ng++;
				}
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: score,
			speed: Math.round(Const.SPEED * 1e6) / 1e6,
			step: Const.STEP_SPEED,
			coal: Math.round(coal * 1000) / 1000,
			opp: Math.round(opp * 1000) / 1000,
			me: Math.round(this.me * 1000) / 1000,
			locoY: Loco.mc._y,
			manX: man == null ? null : man._x,
			manY: man == null ? null : man._y,
			outside: Man.outside,
			station: Math.round(Station.nextStation * 1000) / 1000,
			objects: os == null ? 0 : os.length,
			osum: Math.round(osum * 1000) / 1000,
			gems: ng,
			gsum: Math.round(gsum * 1000) / 1000,
			over: gameOver,
			stats: haxe.Json.stringify(stats),
		};
	}
	#end

	#if debug
	// test harness (modes/ktrain.js): every gem a piouz; the speed of the train behind
	public var testPiouz:Bool = false;

	public function debugOpp(n:Int) {
		Const.OPP_SPEED = KKApi.const(n);
	}

	// test harness: clips drawn by the runtime on a page ([name, frame, x, y, scale, {nested instance: frame}, blend]), to
	// compare with the SWF (ref.py)
	public function debugShow(list:Array<Array<Dynamic>>, bgColor:Int) {
		var st:Dynamic = untyped KadoKadeoManager.kkm.stage;
		var box = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		for (o in list) {
			var c = new Clip(o[0], 2);
			c.gotoAndStop(o[1]);
			if (o.length > 5)
				for (k in Reflect.fields(o[5])) {
					var sub = c.getClip(k);
					if (sub != null)
						sub.gotoAndStop(Reflect.field(o[5], k));
				}
			Clip.runLater();
			if (o.length > 6 && o[6] == "multiply")
				c.setBlend(pixi.core.Pixi.BlendModes.MULTIPLY);
			c._x = o[2];
			c._y = o[3];
			c._xscale = c._yscale = o[4] * 100;
			box.addChild(c);
		}
		box.updateState();
		box.updateGraphics(1);
		st.addChild(box);
	}

	// test harness: what the bot reads
	public function debugBot():Dynamic {
		var man = Man.debugMan();
		var l = Scroller.debugLists();
		var gs:Array<MC> = l.gems;
		var gems = [];
		if (gs != null)
			for (g in gs)
				if (g.gem)
					gems.push([g._x, g._y, g.piouz ? 1 : 0]);
		return {
			frame: frameCount,
			over: gameOver,
			speed: Const.SPEED,
			step: Const.STEP_SPEED,
			next: Const.NEXT_SPEED,
			coal: coal,
			gap: opp - me,
			station: Station.nextStation,
			stationY: Station.station == null ? null : Station.station._y,
			locoY: Loco.mc._y,
			lock: Loco.lockSpeed,
			anim: anim.length,
			out: Man.outside,
			mx: man == null ? null : man._x,
			my: man == null ? null : man._y,
			gems: gems,
		};
	}
	#end

	public function destroy():Void {
		game = null;
		me_ = null;
		MC.clearAll();
		Clip.reset();
		Bmp.reset();
	}
}

interface Anim {
	public var onEnd:Void->Void;
	public function play():Bool;
	public function clean():Void;
}

// the driver carries the coal from the station to the locomotive (the game waits for it)
class CoalAnim implements Anim {
	public var onEnd:Void->Void;

	var game:Game;
	var mc:MC;
	var s:MC;
	var steps:Float;
	var armCycles:Float;
	var leftArm:Int;
	var left:Bool;
	var d:Array<Float>;

	static var Y = 1.0;
	static var X = 1.0;
	static var SPEED = 3.0;
	static var MAX = 32;
	static var ARMS_CYCLE = 5;

	public static function reset() {
		Y = 1.0;
		X = 1.0;
	}

	public function new(game:Game) {
		left = true;
		leftArm = 1;
		armCycles = ARMS_CYCLE;
		steps = 0.0;
		this.game = game;
		s = game.dm.attach("ombre_pilote", Const.DP_MAN);
		s.setBlend("multiply");
		mc = game.dm.attach("mcPilote", Const.DP_MAN);
		var st = Station.station;
		var y = st._y - (st._y - (Loco.mc._y - Const.LOCO_H)) / 2;
		mc._y = y;
		s._y = y;
		var x = st._x - st._width / 2;
		mc._x = x;
		s._x = x;
		mc.gotoAndStop(10);
		// (sin and cos the other way round: only the walk of the picture, a fixed number of frames)
		var r = Math.atan2(mc._y - (Loco.mc._y + Const.LOCO_H / 2), mc._x - Loco.mc._x);
		X = Math.sin(r);
		Y = Math.cos(r);
		d = [
			1.56, 0, 0, 0, -90.16, 0, 1.56, 0, 0, -90.16, 0, 0, 1.56, 0, -90.16, 0, 0, 0, 1, 0
		];
		#if debug
		game.stats.stations++;
		#end
	}

	public function play():Bool {
		mc.setFilters([ColorMatrix(d)]);
		if (armCycles-- <= 0) {
			if (left)
				mc.gotoAndStop(10 + leftArm);
			else
				mc.gotoAndStop(4 + leftArm);

			if (++leftArm > 2) {
				leftArm = 0;
			}
			armCycles = ARMS_CYCLE;
		}

		if (steps < MAX / 2) {
			var v = mc._x + X * SPEED;
			mc._x = v;
			s._x = v;
			v = mc._y + Y * SPEED;
			mc._y = v;
			s._y = v;
		} else {
			left = false;
			var v = mc._x - X * SPEED;
			mc._x = v;
			s._x = v;
			v = mc._y - Y * SPEED;
			mc._y = v;
			s._y = v;
		}

		if (steps++ > MAX) {
			return true;
		}
		return false;
	}

	public function clean() {
		s.removeMovieClip();
		s = null;
		mc.removeMovieClip();
		mc = null;
	}
}

package quadrikolor;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import quadrikolor.MC.Plans;

// Game.mt of the original (MTypes, taupebille.swf), line by line; the port's own parts are at the end
@:expose('GameQuadriKolor')
class Game implements kado.GameInterface {
	// the mouse aims and clicks; on a touch screen a finger only aims (it drags the aim, a touch during the choice of
	// the power goes back to the choice of the direction) and the button acts: it chooses the direction, then the power
	// (see touchMode). The button gives FIRE_KEY, at the bottom middle of the canvas, half on the bar of KadoKadeo (the
	// corners of the table are holes; the offsets are CSS pixels of the canvas, whatever its size on the screen)
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "fire",
				label: "▶",
				bottomPx: 4,
				size: 64,
				keyCode: FIRE_KEY,
				shape: TouchButtonShape.CIRCLE,
			},
		],
	};

	// the key of the touch button (recorded by the replay; only read in touch mode TOUCH_BUTTON)
	static inline var FIRE_KEY = KeyboardManager.ENTER;

	// Flash played Quadrikolor at 40 frames/s (the rate of the SWF and of the KadoKado loader) with Timer.wantedFPS = 32
	public static inline var FLASH_FPS = 40;

	// replay events: the player uses a touch screen (from that frame on, touchMode). EV_TOUCH_LIFT: the replays recorded
	// before the button (a finger acted when it was lifted); EV_TOUCH_BUTTON: the ones recorded since
	static inline var EV_TOUCH_LIFT = 1;
	static inline var EV_TOUCH_BUTTON = 2;
	static inline var TOUCH_NONE = 0;
	static inline var TOUCH_LIFT = 1;
	static inline var TOUCH_BUTTON = 2;

	public static inline var CHOOSE_WAY = 0;
	public static inline var CHOOSE_SPEED = 1;
	public static inline var IGNITION = 2;
	public static inline var SIMULATE = 3;
	public static inline var GAMEOVER = 5;
	public static inline var FICHE = 6;

	var bar:MC;
	var lines:Lines;
	var cases:Array<MC>;

	public var dmanager:Plans;

	var physics:Physics;
	var ship:Ball;
	var fiche:MC;
	var result:Array<Int>;
	var balls:Array<Ball>;
	var aspire:Array<Ball>;

	public var state:Int;

	var carbu:Int;
	var timer:Float;

	var angle:Float;
	var speed:Float;
	var speed_time:Float;
	var start_time:Float;

	var stats:{r:Array<Array<Int>>, b:Array<Int>};

	// port
	var isReplay:Bool;
	var root:ASprite;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	// the score of KKApi, nothing after the game over
	var score:Int = 0;
	var over:Bool = false;
	// drawLines / clearLines of this Flash frame and of the one before (the display is one Flash frame late)
	var linesOn:Bool = false;
	var prevLinesOn:Bool = false;
	// the score lines of the sheet (removed with it)
	var slots:Array<MC> = [];
	// the text pictures of the fields written by the code (fieldMulti of the bar, pts / mult of a score line)
	var multiTxt:pixi.core.sprites.Sprite;
	// touch screen: TOUCH_LIFT, a finger acts when it is lifted, not when it touches (it has to drag the aim first);
	// TOUCH_BUTTON, a finger only aims and the touch button acts
	var touchMode:Int = TOUCH_NONE;
	var touchPending:Bool = false;
	var onPointerDown:Dynamic;
	var onAnyPointerDown:Dynamic;
	#if debug
	// test harness: hash of the balls at every Flash frame (a replay must give the same)
	var ghash:Int = 0;
	var shots:Int = 0;
	#end

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(2);
		keys[0] = KeyboardManager.SPACE;
		keys[1] = FIRE_KEY;
		var buttons = new UInt16Array(1);
		buttons[0] = MouseManager.BUTTON_LEFT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: true,
			recordMousePosition: true,
			recordedMouseButtons: buttons,
		});
		MC.clearAll();
		Clip.reset();
		Timer.tmod = 32 / FLASH_FPS;
		Timer.deltaT = 1 / FLASH_FPS;
		if (!isReplay) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			// like the Flash player, a pressed button keeps the mouse until it is released (KadoKadeo releases the
			// buttons when the pointer leaves the canvas)
			onPointerDown = function(e:Dynamic) {
				try {
					canvas.setPointerCapture(e.pointerId);
				} catch (_:Dynamic) {}
			};
			canvas.addEventListener("pointerdown", onPointerDown);
			// (on the window: with the touch controls, the fingers land on their overlay)
			onAnyPointerDown = function(e:Dynamic) {
				if (e.pointerType == "touch" && touchMode == TOUCH_NONE && !touchPending) {
					touchPending = true;
					KadoKadeoManager.kkm.replay.recordEvent({k: EV_TOUCH_BUTTON});
				}
			};
			js.Browser.window.addEventListener("pointerdown", onAnyPointerDown, true);
		}
		Clip.deferring = true;
		// the original's 300x300 pixels, drawn x2
		root = mc.createEmptyMovieClip("scene", 0);
		root._xscale = root._yscale = 100 * Clip.K;
		root.updateState();

		stats = {r: [], b: []};

		start_time = 1;
		balls = new Array();
		aspire = new Array();
		physics = new Physics(cast balls, Const.FRICTION, {
			xmin: 0,
			ymin: Const.MIN_Y,
			xmax: 300,
			ymax: 300,
			coef: Const.BOUNDS_COEF
		});
		dmanager = new Plans(root);
		// lines = dmanager.empty(Const.PLAN_LINE)
		lines = new Lines();
		lines.bounds = physics.bounds;
		dmanager.get(Const.PLAN_LINE).addChild(lines);
		carbu = Const.INIT_CARBU;
		initLevel();
		initBarre();
		updateCarbu();
		physics.start();
		state = CHOOSE_WAY;

		Clip.deferring = false;
		Clip.runLater();
		MC.displayAll(1);
		lines.ship = ship;
	}

	function randomPos(pos:Array<{x:Int, y:Int}>):{x:Int, y:Int} {
		while (true) {
			var x = 30 + Seed.random(240);
			var y = Const.MIN_Y + 30 + Seed.random(240 - Const.MIN_Y);
			var i = 0;
			while (i < pos.length) {
				var p = pos[i];
				var dx = p.x - x;
				var dy = p.y - y;
				var d = Math.sqrt(dx * dx + dy * dy);
				if (d < Const.INIT_MIN_DIST)
					break;
				i++;
			}
			if (i == pos.length)
				return {x: x, y: y};
		}
	}

	function gameOver() {
		sendGameOver();
		state = GAMEOVER;
	}

	function initBarre() {
		cases = new Array();
		bar = dmanager.attach("bar", Const.PLAN_INTERF);
		for (i in 0...Const.MAX_CARBU) {
			var s = dmanager.attach("square", Const.PLAN_INTERF);
			s._x = 79 + i * 10;
			s._y = 3;
			cases.push(s);
		}
		var t = Tex.get("txtMulti");
		multiTxt = new pixi.core.sprites.Sprite(t[0]);
		multiTxt.anchor.copyFrom(t[0].defaultAnchor);
		bar.clip.addChild(multiTxt);
	}

	function updateCarbu() {
		bar.gotoAndStop("carburant");
		for (i in 0...Const.MAX_CARBU) {
			var s = cases[i];
			if (carbu * 2 > i)
				s.gotoAndStop("1");
			else
				s.gotoAndStop("2");
			var ss = s.sub("s");
			if (ss != null)
				ss.gotoAndStop("1");
		}
		// bar.fieldMulti.text = "x " + carbu
		setText(multiTxt, "txtMulti", carbu + 1);
	}

	function updateSpeed() {
		bar.gotoAndStop("puissance");
		// (fieldMulti is not on this frame)
		multiTxt.visible = false;
		var sp = (speed - Const.MIN_SPEED) * Const.MAX_CARBU / (Const.MAX_SPEED - Const.MIN_SPEED);
		for (i in 0...Const.MAX_CARBU) {
			var s = cases[i];
			var f = Std.string(Math.round(i * 22 / Const.MAX_CARBU));
			var ss = s.sub("s");
			if (sp > i) {
				s.gotoAndStop("1");
				if (ss != null)
					ss.gotoAndStop(f);
			} else {
				s.gotoAndStop("2");
				if (ss != null)
					ss.gotoAndStop(f);
			}
		}
	}

	function initLevel() {
		dmanager.attach("bg", 0);
		// (bg.onPress = callback(this, onClick); KKApi.registerButton(bg): the presses on the game, read in flashFrame)
		var t = dmanager.attach("trou", 0);
		var ts = 70;
		t._y = Const.MIN_Y;
		t._xscale = ts;
		t._yscale = ts;
		t = dmanager.attach("trou", 0);
		t._xscale = -ts;
		t._yscale = ts;
		t._x = 300;
		t._y = Const.MIN_Y;
		t = dmanager.attach("trou", 0);
		t._xscale = ts;
		t._yscale = -ts;
		t._y = 300;
		t = dmanager.attach("trou", 0);
		t._xscale = -ts;
		t._yscale = -ts;
		t._x = 300;
		t._y = 300;

		var pos = new Array();
		for (i in 0...Const.NBALLS + 1)
			pos.push(randomPos(pos));
		for (i in 0...Const.NBALLS + 1)
			balls.push(new Ball(this, i, pos[i].x, pos[i].y));
		ship = balls[0];
	}

	function clearLines() {
		// (the lineseg marks and the strokes: see Lines)
		linesOn = false;
	}

	function drawLines() {
		// (clearLines, then the path from the ship at ship.mc._rotation: drawn by Lines from what is shown)
		linesOn = true;
	}

	function onClick() {
		if (start_time >= 0)
			return;
		switch (state) {
			case CHOOSE_WAY:
				clearLines();
				state = CHOOSE_SPEED;
				speed_time = 0;
			case CHOOSE_SPEED:
				state = IGNITION;
				timer = 6;
				// GFX
				var mc = dmanager.attach("spark", Const.PLAN_LINE);
				mc._x = ship.x;
				mc._y = ship.y;
				mc._rotation = ship.mc._rotation;
			case FICHE:
				speed_time = -1;
			case _:
		}
	}

	// port: a finger put on the table (TOUCH_BUTTON) aims again during the choice of the power (like Space) and closes
	// the sheet (like a click); the touch button does the rest
	function onTap() {
		if (start_time >= 0)
			return;
		switch (state) {
			case CHOOSE_SPEED:
				updateCarbu();
				state = CHOOSE_WAY;
			case FICHE:
				onClick();
			case _:
		}
	}

	function endFiche() {
		// (fiche.removeMovieClip(): its score lines with it; nothing when no sheet was shown)
		for (s in slots)
			s.removeMovieClip();
		slots = [];
		if (fiche != null)
			fiche.removeMovieClip();
		carbu--;
		updateCarbu();
		if (carbu == 0 || ship.mc.removed || balls.length == 1)
			gameOver();
		else {
			state = CHOOSE_WAY;
		}
	}

	function attachSlot(p:Int, max:Int):MC {
		var s = fiche.attachMC("scoreSlot");
		slots.push(s);
		s._y = p * 18;
		var bord = s.sub("bord");
		if (bord != null)
			bord.gotoAndStop((max == 1) ? 1 : ((p == 0) ? 2 : ((p == max - 1) ? 3 : 4)));
		return s;
	}

	function initFiche() {
		stats.r.push(result);
		stats.b.push(ship.bande);
		if (result.length == 0) {
			endFiche();
			return;
		}
		state = FICHE;
		fiche = dmanager.empty(Const.PLAN_INTERF);
		fiche._x = 5;
		fiche._y = Const.MIN_Y + 5;
		var p = 0;
		var pts = KKApi.const(0);
		var mult = carbu;

		var max = result.length;
		if (max >= 2)
			max++;
		if (ship.bande > 0)
			max++;
		var perfect = (balls.length == 1 && !ship.mc.removed) || (balls.length == 0);
		if (perfect)
			max++;
		for (i in 0...result.length) {
			var id = result[i];
			var s = attachSlot(p++, max);
			s.gotoAndStop("1");
			// s.pts.text = KKApi.val(Const.POINTS[id]); s.mult.text = "x " + carbu
			addText(s, "txtPts", id + 1);
			addText(s, "txtMult", carbu);
			// s.b.stop(); Ball.initColor(s.b, id): the ball of the line in its colour
			var b = s.sub("b");
			if (b != null) {
				b.stop();
				b.setDef("slotball" + id);
			}
			pts = KKApi.cadd(pts, Const.POINTS[id]);
		}
		if (result.length > 1) {
			var s = attachSlot(p++, max);
			var m = Std.int(Math.min(result.length, 5));
			mult += m;
			s.gotoAndStop(Std.string(m));
		}
		if (ship.bande > 0) {
			var s = attachSlot(p++, max);
			var m = Std.int(Math.min(ship.bande, 3));
			mult += m + 1;
			s.gotoAndStop(Std.string(5 + m));
		}
		pts = KKApi.cmult(pts, KKApi.const(mult));
		if (perfect) {
			var s = attachSlot(p++, max);
			pts = KKApi.cadd(pts, Const.C5000);
			s.gotoAndStop("9");
		}
		addScore(KKApi.val(pts));
		speed = -1;
		speed_time = 0;
		fiche._alpha = 0;
	}

	function main() {
		start_time -= Timer.deltaT;
		physics.update(Timer.tmod);
		var sim_flag = false;
		var i = 0;
		while (i < balls.length) {
			var b = balls[i];
			if (b.update(Timer.tmod))
				sim_flag = true;
			if (state == SIMULATE && b.hole()) {
				balls.splice(i--, 1);
				aspire.push(b);
				physics.stop();
				physics.start();
			}
			i++;
		}

		i = 0;
		while (i < aspire.length) {
			var b = aspire[i];
			if (!b.update(Timer.tmod)) {
				if (b != ship)
					result.push(b.id);
				b.destroy();
				aspire.splice(i--, 1);
			} else
				sim_flag = true;
			i++;
		}

		switch (state) {
			case CHOOSE_WAY:
				angle = Const.q(Math.atan2(ymouse() - ship.y, xmouse() - ship.x));
				var tr = angle - ship.mc._rotation / 180 * Math.PI;
				while (tr > Math.PI)
					tr -= 2 * Math.PI;
				while (tr < -Math.PI)
					tr += 2 * Math.PI;
				ship.mc._rotation += (tr * 180 / Math.PI) * Math.pow(0.4, Timer.tmod);
				drawLines();
			case CHOOSE_SPEED:
				if (KeyboardManager.isDown(KeyboardManager.SPACE)) {
					updateCarbu();
					state = CHOOSE_WAY;
				} else {
					speed_time += Timer.tmod / 10;
					speed = Const.q((1 - Math.abs(Math.sin(speed_time))) * (Const.MAX_SPEED - Const.MIN_SPEED) + Const.MIN_SPEED);
					updateSpeed();
				}
			case IGNITION:
				timer -= Timer.tmod;
				if (timer < 0) {
					state = SIMULATE;
					var r = ship.mc.sub("reacteur");
					if (r != null)
						r.play();
					for (i in 0...balls.length)
						balls[i].colflag = false;
					ship.bande = 0;
					ship.bandeLast = false;
					result = new Array();
					physics.stop();
					ship.dx = Const.q(Math.cos(angle) * speed);
					ship.dy = Const.q(Math.sin(angle) * speed);
					physics.start();
					#if debug
					shots++;
					#end
				}
			case SIMULATE:
				speed = physics.speed(ship);
				updateSpeed();
				ship.colflag = true;
				if (!sim_flag)
					initFiche();
			case FICHE:
				if (speed_time == 0) {
					speed += Timer.tmod / 10;
					if (speed >= 0) {
						speed = 0;
						speed_time = 1.5;
					}
				} else if (speed_time > 0) {
					speed_time -= Timer.deltaT;
					if (speed_time == 0)
						speed_time = -1;
				}
				if (speed_time < 0) {
					speed += Timer.tmod / 10;
					if (speed >= 1)
						endFiche();
				}
				// (the sheet was removed by endFiche: nothing written to it)
				if (fiche != null)
					fiche._alpha = (1 - Math.abs(speed)) * 100;
			case GAMEOVER:
		}
	}

	// ---------------------------------------------------------------- port
	// Std.xmouse() / Std.ymouse(): the mouse in the 300 x 300 pixels of the game (the replay records it)
	function xmouse():Float {
		return Math.max(0, MouseManager.getX()) / Clip.K;
	}

	function ymouse():Float {
		return Math.max(0, MouseManager.getY()) / Clip.K;
	}

	// a picture of the text of a field (frame f of its anim), in the space of the clip that holds the field
	function addText(s:MC, anim:String, f:Int) {
		var t = Tex.get(anim);
		var sp = new pixi.core.sprites.Sprite(t[0]);
		sp.anchor.copyFrom(t[0].defaultAnchor);
		s.clip.addChild(sp);
		setText(sp, anim, f);
	}

	function setText(sp:pixi.core.sprites.Sprite, anim:String, f:Int) {
		var t = Tex.get(anim);
		sp.texture = f >= 1 && f <= t.length ? t[f - 1] : pixi.core.textures.Texture.EMPTY;
		sp.visible = true;
	}

	// ---------------------------------------------------------------- KadoKadeo step: 5 Flash frames every 4 steps
	public function update(delta:Float) {
		for (e in KadoKadeoManager.kkm.replay.consumeEvents())
			if (e != null && e.k == EV_TOUCH_LIFT)
				touchMode = TOUCH_LIFT;
			else if (e != null && e.k == EV_TOUCH_BUTTON)
				touchMode = TOUCH_BUTTON;
		// (live: the event recorded when the finger touched is in this frame of the replay)
		if (touchPending) {
			touchPending = false;
			touchMode = TOUCH_BUTTON;
		}
		// presses: clicks (the mouse, the touch button); taps: fingers put on the table (TOUCH_BUTTON)
		var presses = 0;
		var taps = 0;
		for (c in MouseManager.getFrameButtonChanges())
			if (c.button == MouseManager.BUTTON_LEFT && inGame()) {
				if (touchMode == TOUCH_BUTTON) {
					if (c.isDown)
						taps++;
				} else if (c.isDown == (touchMode == TOUCH_NONE))
					presses++;
			}
		if (touchMode == TOUCH_BUTTON)
			for (c in KeyboardManager.getFrameKeyChanges())
				if (c.keyCode == FIRE_KEY && c.isDown)
					presses++;
		frameAcc += 5;
		var first = true;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame(first ? presses : 0, first ? taps : 0);
			first = false;
		}
		MC.displayAll(frameAcc / 4);
		// the aiming line as shown (one Flash frame late, like the clips)
		lines.shown = prevLinesOn;
		lines.carbu = carbu;
	}

	// the pointer is on the game (bg covers its 300 x 300 pixels; below: the bar of KadoKadeo)
	function inGame():Bool {
		var x = MouseManager.getX() / Clip.K;
		var y = MouseManager.getY() / Clip.K;
		return x >= 0 && x < 300 && y >= 0 && y < 300;
	}

	// one Flash frame: the timelines advance, the presses on bg (bg.onPress) then Manager.main (Timer settles on tmod
	// 32 / 40, deltaT 1 / 40), then the frame scripts the code triggered
	function flashFrame(presses:Int, taps:Int) {
		Timer.tmod = 32 / FLASH_FPS;
		Timer.deltaT = 1 / FLASH_FPS;
		prevLinesOn = linesOn;
		MC.frameStart();
		Clip.deferring = true;
		for (i in 0...taps)
			onTap();
		for (i in 0...presses)
			onClick();
		main();
		Clip.deferring = false;
		Clip.runLater();
		frameCount++;
		#if debug
		var hsh = ghash;
		for (b in balls)
			hsh = (hsh * 31 + Std.int(b.x * 1000) * 7 + Std.int(b.y * 1000)) | 0;
		hsh = (hsh * 31 + state * 17 + aspire.length) | 0;
		ghash = hsh;
		untyped js.Browser.window.__state = debugState();
		#end
	}

	// KKApi.addScore: nothing after the game over
	function addScore(n:Int) {
		if (over)
			return;
		score += n;
		KadoKadeoManager.kkm.addScore(n);
	}

	// KKApi.gameOver(stats)
	function sendGameOver() {
		if (over)
			return;
		over = true;
		#if debug
		untyped js.Browser.window.__over = debugState();
		#end
		var s:Dynamic = {};
		Reflect.setField(s, "$r", stats.r);
		Reflect.setField(s, "$b", stats.b);
		KadoKadeoManager.kkm.gameOver(s);
	}

	#if debug
	// state compared between a game and its replay (test harness)
	function debugState():Dynamic {
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			gscore: score,
			state: state,
			carbu: carbu,
			shots: shots,
			balls: [
				for (b in balls) (b.ship ? "s" : "" + b.id) + "@" + Math.round(b.x * 100) / 100 + "," + Math.round(b.y * 100) / 100
			].join(" "),
			stats: haxe.Json.stringify(stats),
			ghash: ghash,
			touch: touchMode != TOUCH_NONE,
			over: over,
		};
	}

	// test harness: clips drawn by the runtime on a page ([name, frame, x, y, scale, {nested instance: frame}]), to
	// compare with the SWF
	public function debugShow(list:Array<Array<Dynamic>>, bgColor:Int) {
		var stage:Dynamic = untyped KadoKadeoManager.kkm.stage;
		var box = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		for (o in list) {
			var c = new Clip(o[0], 2);
			for (pass in 0...2) {
				if (pass == 1)
					c.gotoAndStop(o[1]);
				if (o.length > 5)
					for (k in Reflect.fields(o[5])) {
						var sub = c;
						for (n in k.split("."))
							sub = sub != null ? sub.getClip(n) : null;
						if (sub != null)
							sub.gotoAndStop(Reflect.field(o[5], k));
					}
			}
			Clip.runLater();
			c._x = o[2];
			c._y = o[3];
			c._xscale = c._yscale = o[4] * 100;
			box.addChild(c);
		}
		box.updateState();
		box.updateGraphics(1);
		stage.addChild(box);
	}
	#end

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		if (onAnyPointerDown != null) {
			js.Browser.window.removeEventListener("pointerdown", onAnyPointerDown, true);
			onAnyPointerDown = null;
		}
		MC.clearAll();
		Clip.reset();
	}
}

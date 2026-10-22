package hypercube;

import haxe.io.UInt16Array;
import hypercube.Gfx;
import hypercube.MC.Plans;
import hypercube.Piece.Cub;
import kado.TouchControlsConfig;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;

typedef Form = {x:Int, y:Int, list:Array<Cub>};

@:expose('GameHypercube')
class Game implements kado.GameInterface {
	// the original's 300 x 300 pixels, drawn x2
	public static inline var K = 2;
	// Hypercube ran in the KadoKado loader at 40 frames/s (Timer.wantedFPS = 32: tmod = 0.8)
	public static inline var FRAME_RATE = 40;

	// touch screens: a finger is the mouse; SPACE turns the piece in hand, CONTROL (held) swaps it with the form under it
	public static var TOUCH_CONTROLS:TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "turn",
				label: "⟳",
				leftPx: 10,
				bottomPx: 10,
				size: 64,
				keyCode: KeyboardManager.SPACE,
				shape: TouchButtonShape.CIRCLE,
			},
			{
				id: "swap",
				label: "⇄",
				rightPx: 10,
				bottomPx: 10,
				size: 64,
				keyCode: KeyboardManager.CONTROL,
				shape: TouchButtonShape.CIRCLE,
			}
		],
	};

	public static inline var DP_BG = 1;
	public static inline var DP_SCORE = 2;
	public static inline var DP_GROUND = 3;

	public static inline var DP_PIECES = 5;
	public static inline var DP_PARTS = 6;
	public static inline var DP_HAND = 8;
	public static inline var SIZE = 15;

	public static var DIR = [{x: 1, y: 0}, {x: 0, y: 1}, {x: -1, y: 0}, {x: 0, y: -1}];

	// GFX
	public static inline var VANISH_SPEED = 8;

	// replay: the actions of the mouse, one Int each (kind | x << 1 | y << 11, x / y: the mouse in canvas pixels
	// 0..1023), not the mouse itself (a game can last for hours). The keys (SPACE, CONTROL) stay recorded as inputs.
	// a press that took a piece / a form back or pressed the end button: replayed on the button under the mouse
	public static inline var EV_PRESS = 0;
	// a press with a piece in hand (handDown)
	public static inline var EV_DROP = 1;
	// replay: the hand goes from an event to the next one in MOVE_BASE steps + 1 per MOVE_SPEED Flash pixels (eased),
	// then waits there
	static inline var MOVE_BASE = 4;
	static inline var MOVE_SPEED = 16;

	var flPress:Bool = false;
	var flTurnRelease:Bool;
	var flGameOver:Bool;

	var pieceTimer:Float;
	var pieceBoost:Float;
	var shake:Null<Float>;
	var blink:Null<Float>;
	var mainTimer:Float;
	var flashHorloge:Null<Float>;
	var life:Int;

	var grid:Array<Array<Cube>>;

	var dm:Plans;

	var bg:Bg;
	var ground:MC;
	var hand:Piece;

	var formList:Array<Form>;
	var pieceList:Array<Piece>;
	var destroyList:Array<{t:Float, x:Int, y:Int}>;
	var pList:Array<Part>;
	var timeLightList:Array<Part>;
	var flashLightList:Array<{mc:Cube, prc:Float}>;

	var root:MC;
	var butEndGame:EndButton;

	var stats:{_p:Int, _c:Array<{_s:Int, _m:Int, _t:Int}>};

	// KadoKadeo
	var isReplay:Bool;
	var buttons:Buttons;
	// mouse in canvas pixels (0..1023: what the replay events hold), and in the root's coordinates
	// (Manager.root_mc._xmouse / _ymouse)
	var mouseX:Int = 0;
	var mouseY:Int = 0;
	var xmouse:Float = 0;
	var ymouse:Float = 0;
	// replay: the mouse events of the replay (frame, position in Flash pixels), the one at or before the frame played
	var path:Array<{f:Int, x:Float, y:Float}>;
	var pathIdx:Int = 0;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;
	var overSent:Bool = false;
	var handCursor:Bool = false;
	var onPointerDown:Dynamic;

	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(2);
		keys[0] = KeyboardManager.SPACE;
		keys[1] = KeyboardManager.CONTROL;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: true,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		if (isReplay)
			initPath();
		// one page plays several games and replays: the clips of the previous one go
		MC.clearAll();
		mt.Timer.tmod = 32 / FRAME_RATE;
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
		buttons = new Buttons(root);
		if (!isReplay)
			readMouse();

		// original: new(mc)
		dm = new Plans(root);
		bg = dm.add(new Bg(), DP_BG);
		ground = dm.empty(DP_GROUND);

		grid = new Array();
		for (x in 0...20) {
			grid[x] = new Array();
			for (y in 0...20) {
				grid[x][y] = null;
			}
		}
		formList = new Array();
		pieceList = new Array();
		destroyList = new Array();
		pList = new Array();
		timeLightList = new Array();
		flashLightList = new Array();
		//
		flGameOver = false;
		flTurnRelease = false;
		pieceTimer = 0;
		pieceBoost = 30;
		mainTimer = Cs.TIMER_MAX;

		//
		stats = {
			_p: 0,
			_c: []
		};

		initMouse();
		MC.displayAll(1);
	}

	// Mouse.addListener({onMouseDown: flPress = true, onMouseUp: flPress = false}): called by Buttons before onPress
	function initMouse() {
		buttons.onMouseDown = function() flPress = true;
		buttons.onMouseUp = function() flPress = false;
	}

	// ---------------------------------------------------------------- KadoKadeo
	public function update(delta:Float) {
		// Flash played Hypercube at 40 frames/s with Timer.wantedFPS = 32: tmod = 0.8, one main() per Flash frame.
		// KadoKadeo steps 32 times per second: 5 Flash frames every 4 steps
		mt.Timer.tmod = 32 / FRAME_RATE;
		frameAcc += 5;
		var first = true;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame(first);
			first = false;
		}
		MC.displayAll(frameAcc / 4);
		setHandCursor(buttons.over != null);
	}

	// one Flash frame: the mouse events (between two frames), the playheads, then Manager.main
	function flashFrame(first:Bool) {
		frameCount++;
		MC.snapshotAll();
		if (isReplay) {
			replayMouse(first);
		} else {
			readMouse();
			var changes = [];
			if (first)
				for (c in MouseManager.getFrameButtonChanges())
					if (c.button == MouseManager.BUTTON_LEFT)
						changes.push(c.isDown);
			buttons.frame(xmouse, ymouse, changes);
		}
		MC.advanceAll();
		main();
		#if debug
		if (testHook != null)
			testHook();
		#end
	}

	function readMouse() {
		setMouse(MouseManager.getX(), MouseManager.getY());
	}

	function setMouse(x:Int, y:Int) {
		mouseX = x < 0 ? 0 : x > 1023 ? 1023 : x;
		mouseY = y < 0 ? 0 : y > 1023 ? 1023 : y;
		xmouse = mouseX / K;
		ymouse = mouseY / K;
	}

	// ---------------------------------------------------------------- replay
	// the actions of the mouse are recorded for the frame (step) being played: the replay gives them back on the same
	// frame, before the game's update (they all happen in its first Flash frame: the presses are dispatched there)
	function recordMouseEvent(kind:Int) {
		if (!isReplay) {
			var replay = KadoKadeoManager.kkm.replay;
			replay.recordEvent(kind | (mouseX << 1) | (mouseY << 11), replay.getCurrentFrame());
		}
	}

	function initPath() {
		path = [];
		for (e in KadoKadeoManager.kkm.replay.getReplayEvents()) {
			var v = Std.int(e.event);
			path.push({f: e.frame, x: ((v >> 1) & 1023) / K, y: ((v >> 11) & 1023) / K});
		}
	}

	// the mouse of a replay: the actions of the frame where the player did them; in between, the hand of the player
	// goes from an action to the next one (only the position of the actions counts)
	function replayMouse(first:Bool) {
		var replay = KadoKadeoManager.kkm.replay;
		// (the second Flash frame of a step: half a step later)
		var t = replay.getCurrentFrame() + (first ? 0 : 0.5);
		while (pathIdx + 1 < path.length && path[pathIdx + 1].f <= t)
			pathIdx++;
		while (pathIdx > 0 && path[pathIdx].f > t)
			pathIdx--;
		if (path.length > 0) {
			var a = path[pathIdx];
			if (t <= a.f || pathIdx + 1 >= path.length) {
				xmouse = a.x;
				ymouse = a.y;
			} else {
				var b = path[pathIdx + 1];
				var dx = b.x - a.x;
				var dy = b.y - a.y;
				var u = Math.min(1, (t - a.f) / Math.min(b.f - a.f, MOVE_BASE + Math.sqrt(dx * dx + dy * dy) / MOVE_SPEED));
				u = u * u * (3 - 2 * u);
				xmouse = a.x + dx * u;
				ymouse = a.y + dy * u;
			}
		}
		if (!first)
			return;
		for (e in replay.consumeEvents()) {
			var v = Std.int(e);
			setMouse((v >> 1) & 1023, (v >> 11) & 1023);
			switch (v & 1) {
				case EV_PRESS:
					buttons.pressAt(xmouse, ymouse);
				case EV_DROP:
					// main() puts the hand down
					flPress = true;
			}
		}
	}

	// ---------------------------------------------------------------- original
	function main() {
		if (hand != null) {
			hand.root._x = xmouse;
			hand.root._y = ymouse;
			if (shake != null) {
				shake *= 0.7;
				// (the shaken position is the one handDown reads: gameplay random)
				hand.root._x += Seed.rand() * shake;
				hand.root._y += Seed.rand() * shake;
				if (shake < 0.5)
					shake = null;
			}
			if (flPress)
				handDown();
			if (KeyboardManager.isDown(KeyboardManager.SPACE)) {
				if (flTurnRelease) {
					turnHand();
				}
				flTurnRelease = false;
			} else {
				flTurnRelease = true;
			}
		}
		if (!flGameOver) {
			mainTimer -= mt.Timer.tmod;
			var c = mainTimer / Cs.TIMER_MAX;
			var frame = Std.int(166 - c * 165);
			bg.ha.gotoAndStop(frame);

			if (c < 0.15) {
				if (blink == null)
					blink = 0;
				blink = (blink + 67) % 628;
				Cs.setPercentColor(bg.ha, (Math.cos(blink / 100) + 1) * 30, 0xFF0000);
			}

			if (c < 0)
				gameOver();
		}

		var i = 0;
		while (i < flashLightList.length) {
			var o = flashLightList[i];
			var prc = o.prc;
			o.prc *= 0.9;
			if (o.prc < 1) {
				flashLightList.splice(i--, 1);
				prc = 0;
			}
			// (a cube removed meanwhile: Flash ignores the new Color)
			if (!o.mc.removed)
				Cs.setPercentColor(o.mc, prc, 0xFFFFFF);
			i++;
		}

		updatePieces();
		updateDestroy();
		updateParts();
		updateTimeLight();
	}

	function updatePieces() {
		pieceTimer -= pieceBoost * mt.Timer.tmod;
		if (pieceTimer < 0 && !flGameOver) {
			pieceTimer += Cs.PIECE_INTERVAL;
			createPiece();
		}

		var i = 0;
		while (i < pieceList.length) {
			var p = pieceList[i];
			p.root._x -= pieceBoost * mt.Timer.tmod;
			if (p.root._x < -40) {
				p.kill();
				pieceList.splice(i--, 1);
			}
			i++;
		}

		bg.ray._x -= pieceBoost * mt.Timer.tmod;
		while (bg.ray._x < -20)
			bg.ray._x += 20;

		//
		var d = (Cs.PIECE_SPEED / (pieceList.length + 1)) - pieceBoost;
		pieceBoost += d * 0.1 * mt.Timer.tmod;

		//
		if (flGameOver && pieceList.length == 0) {
			if (butEndGame == null) {
				butEndGame = cast dm.get(4).attach(new EndButton());
				butEndGame._alpha = 0;
				// Cs.makeButton(butEndGame.smc); KKApi.registerButton(butEndGame.smc)
				butEndGame.smc.onPress = endGame;
			} else {
				if (butEndGame._alpha < 100)
					butEndGame._alpha += 1;
			}
			if (bg.ray._visible) {
				bg.ray._alpha -= 0.01;
			}
		}
	}

	function updateDestroy() {
		var i = 0;
		while (i < destroyList.length) {
			var o = destroyList[i];
			o.t -= mt.Timer.tmod;
			if (o.t <= VANISH_SPEED) {
				// (null: the cube was taken back while vanishing, see takeCub; Flash reads undefined from it)
				var mc = gridGet(o.x, o.y);
				if (mc != null) {
					mc._xscale = o.t * (100 / VANISH_SPEED);
					mc._yscale = mc._xscale;
				}

				if (o.t <= VANISH_SPEED * 0.5) {
					for (n in 0...1) {
						// (particles: visual random)
						var p = newPart("partLight");
						if (mc != null) {
							p._x = mc._x;
							p._y = mc._y;
						}
						var a = Seed.randVfx() * 6.28;
						var sp = 0.2 + Seed.randVfx() * 2.5;
						p.vx = Math.cos(a) * sp;
						p.vy = Math.sin(a) * sp;
						p.t = 10 + Seed.randVfx() * 10;
						p.scale = 50 + Seed.randVfx() * 100;
						p._xscale = p.scale;
						p._yscale = p.scale;
						p.ft = 0;
					}
				}
				if (o.t <= 0) {
					if (mc != null && mc._currentframe > 3 && !flGameOver) {
						// the light of a special cube flies to the time ring (it gives time when it gets there: gameplay)
						var p = newPart("partLight");
						p._x = mc._x;
						p._y = mc._y;

						var dx = p._x - Data.HORLOGE_X;
						var dy = p._y - Data.HORLOGE_Y;

						var a = Cs.q(Math.atan2(dy, dx)); // Math.random()*6.28
						var sp = 4 + Seed.rand() * 10;
						p.vx = Cs.q(Math.cos(a) * sp);
						p.vy = Cs.q(Math.sin(a) * sp);
						p.scale = 200;
						p._xscale = p.scale;
						p._yscale = p.scale;
						p.flQueue = true;
						p.frict = 0.9;
						timeLightList.push(p);
					}

					if (mc != null)
						mc.removeMovieClip();
					destroyList.splice(i--, 1);
					gridSet(o.x, o.y, null);
				}
			}
			i++;
		}
	}

	function updateTimeLight() {
		for (i in 0...timeLightList.length) {
			var p = timeLightList[i];
			// (removed: Flash reads undefined from it, NaN: nothing happens)
			if (p.removed)
				continue;

			var dx = Data.HORLOGE_X - p._x;
			var dy = Data.HORLOGE_Y - p._y;

			var lim = 1.5;
			var coef = 0.1;
			p.vx += Math.min(Math.max(-lim, dx * coef), lim);
			p.vy += Math.min(Math.max(-lim, dy * coef), lim);

			if (Math.abs(dx) + Math.abs(dy) < 20 && !flGameOver) {
				p.t = 0;
				for (n in 0...10) {
					// (particles: visual random)
					var pp = newPart("partLight");
					var a = Seed.randVfx() * 6.28;
					var ray = 6;
					var sp = 2 + Seed.randVfx() * 5;
					pp._x = p._x + Math.cos(a) * ray;
					pp._y = p._y + Math.sin(a) * ray;
					pp.vx = Math.cos(a) * sp;
					pp.vy = Math.sin(a) * sp;
					pp.t = 10 + Seed.randVfx() * 10;
					pp.frict = 0.92;
				}
				mainTimer = Math.min(mainTimer + 400, Cs.TIMER_MAX);
				#if debug
				cov.timeBonus++;
				#end
				flashHorloge = 80;
			}
			if (flGameOver && p.t == null)
				p.t = 10;
		}

		if (flashHorloge != null) {
			bg.horloge._alpha = 20 + flashHorloge;
			flashHorloge *= 0.6;
			if (flashHorloge < 1) {
				flashHorloge = null;
				bg.horloge._alpha = 20;
			}
		}
	}

	// MOVE
	function createPiece() {
		stats._p++;
		var pl = getPieceShape();
		var list = new Array<Cub>();
		var col = Seed.random(3);

		for (i in 0...pl.length) {
			var pos = pl[i];
			var o:Cub = {
				x: pos[0],
				y: pos[1],
				n: col,
				s: null,
				mc: null
			};
			if (Seed.random(30) == 0)
				o.n += 3;
			list.push(o);
		}
		var p = new Piece(dm.empty(DP_PIECES), list);
		p.build(true);
		p.root._x = Cs.mcw + 50;
		p.root._y = SIZE * 2.5;
		p.root.onPress = takePiece.bind(p);
		// KKApi.registerButton(p.root)
		pieceList.push(p);
	}

	function getPieceShape():Array<Array<Int>> {
		var mg = new Array<Array<Bool>>();
		for (x in 0...Cs.SHAPE_VOLUME) {
			mg[x] = new Array();
			for (y in 0...Cs.SHAPE_VOLUME) {
				mg[x][y] = false;
			}
		}
		var size = Seed.random(Cs.SHAPE_SIZE);
		var px = 0;
		var py = 0;
		mg[px][py] = true;
		while (size > 0) {
			var d = DIR[Seed.random(DIR.length)];
			var nx = px + d.x;
			var ny = py + d.y;
			// (out of the 4 x 4 square: undefined in Flash, not == false)
			if (nx >= 0 && nx < Cs.SHAPE_VOLUME && ny >= 0 && ny < Cs.SHAPE_VOLUME && mg[nx][ny] == false) {
				mg[nx][ny] = true;
				size--;
				px = nx;
				py = ny;
			}
		}

		var pl = new Array();
		for (x in 0...Cs.SHAPE_VOLUME) {
			for (y in 0...Cs.SHAPE_VOLUME) {
				if (mg[x][y])
					pl.push([x, y]);
			}
		}
		return pl;
	}

	function takePiece(p:Piece) {
		if (hand != null)
			return;
		recordMouseEvent(EV_PRESS);
		#if debug
		cov.take++;
		#end
		flPress = false;
		createHand(p.list);
		p.kill();
		pieceList.remove(p);
	}

	// onPress of a placed cube (takeCub is also called by the swap: recorded as the drop)
	function pressCub(form:Form) {
		if (hand == null)
			recordMouseEvent(EV_PRESS);
		takeCub(form);
	}

	function takeCub(form:Form) {
		if (hand != null)
			return;
		#if debug
		cov.takeBack++;
		#end
		flPress = false;
		destroyCubs(form);
		createHand(form.list);
	}

	function createHand(list:Array<Cub>) {
		hand = new Piece(dm.empty(DP_HAND), list);
		hand.build(false);
		hand.root._x = xmouse;
		hand.root._y = ymouse;
		hand.game = this;
		life = 5;
	}

	function handDown() {
		flPress = false;
		recordMouseEvent(EV_DROP);

		var x = Math.floor((hand.root._x / SIZE) - hand.dx);
		var y = Math.floor((hand.root._y / SIZE) - hand.dy);

		if (formFit(x, y, hand.list)) {
			put(x, y);
		} else {
			if (KeyboardManager.isDown(KeyboardManager.CONTROL)) {
				var form = checkSwap(x, y, hand.list);
				if (form != null) {
					#if debug
					cov.swap++;
					#end
					var list = hand.list;
					emptyHand();
					takeCub(form);
					// EMULE put(x,y)
					var info:Form = {x: x, y: y, list: list};
					for (i in 0...list.length) {
						var o = list[i];
						o.mc = newCube(o.x + x, o.y + y, o.n, o.s);
						o.mc.onPress = pressCub.bind(info);
						o.mc.form = info;
					}
					formList.push(info);
					checkCombo();
				}
			} else {
				for (i in 0...4) {
					var d = DIR[i];
					var nx = x + d.x;
					var ny = y + d.y;
					if (formFit(nx, ny, hand.list)) {
						put(nx, ny);
						break;
					}
				}
				#if debug
				cov.miss++;
				#end
				shake = 10;
				life--;
				if (life == 0) {
					#if debug
					cov.burst++;
					#end
					// (hand is null when a neighbour square took the piece: Flash calls nothing)
					if (hand != null)
						hand.burst();
					emptyHand();
				}
			}
		}
	}

	function put(x:Int, y:Int) {
		#if debug
		cov.put++;
		#end
		// PART
		var mc = dm.add(new Round(), DP_SCORE);
		mc._x = Math.round(hand.root._x / SIZE) * SIZE; // x*SIZE
		mc._y = Math.round(hand.root._y / SIZE) * SIZE; // y*SIZE
		mc._alpha = 50;
		//

		var info:Form = {x: x, y: y, list: hand.list};
		for (i in 0...hand.list.length) {
			var o = hand.list[i];
			o.mc = newCube(o.x + x, o.y + y, o.n, o.s);
			o.mc.onPress = pressCub.bind(info);
			// KKApi.registerButton(o.mc)
			o.mc.form = info;
		}
		formList.push(info);
		emptyHand();
		checkCombo();
	}

	function emptyHand() {
		if (hand != null)
			hand.kill();
		hand = null;
	}

	function newCube(x:Int, y:Int, n:Int, s:Null<Int>):Cube {
		var d = x * 100 + y;
		var mc:Cube = cast ground.attachAt(new Cube(), d);
		mc._x = (x + 0.5) * SIZE;
		mc._y = (y + 0.5) * SIZE;
		gridSet(x, y, mc);
		mc.gotoAndStop(n + 1);
		mc.setSub(s);

		flashLightList.push({mc: mc, prc: 100});

		return mc;
	}

	function formFit(x:Int, y:Int, list:Array<Cub>):Bool {
		for (i in 0...list.length) {
			var o = list[i];
			var tx = x + o.x;
			var ty = y + o.y;
			var m = 1;
			if (ty < 5 + m || ty > 19 - m || tx < m || tx > 19 - m || grid[tx][ty] != null) {
				return false;
			}
		}
		return true;
	}

	function checkSwap(x:Int, y:Int, list:Array<Cub>):Form {
		var form:Form = null;
		for (i in 0...list.length) {
			var o = list[i];
			var tx = x + o.x;
			var ty = y + o.y;

			var g = gridGet(tx, ty);
			if (g != null) {
				var f = g.form;
				if (form == null) {
					form = f;
				} else {
					if (form != f)
						return null;
				}
			}
		}
		return form;
	}

	function turnHand() {
		#if debug
		cov.turn++;
		#end
		// (hand is null when handDown put it down on this frame, SPACE held: Flash calls nothing)
		if (hand == null)
			return;
		hand.destroy();
		var mx = 9999;
		var my = 9999;
		for (i in 0...hand.list.length) {
			var cub = hand.list[i];
			var x = cub.x;
			var y = cub.y;
			cub.x = -y;
			cub.y = x;
			mx = Std.int(Math.min(cub.x, mx));
			my = Std.int(Math.min(cub.y, my));
		}

		for (i in 0...hand.list.length) {
			var cub = hand.list[i];
			cub.x -= mx;
			cub.y -= my;
		}

		hand.sortList();
		hand.build(false);
	}

	// DESTROY
	function destroyCubs(form:Form) {
		for (i in 0...form.list.length) {
			var o = form.list[i];
			o.mc.removeMovieClip();
			gridSet(form.x + o.x, form.y + o.y, null);
		}
		formList.remove(form);
	}

	function destroySquare(info:{x:Int, y:Int, max:Int}) {
		var id = Seed.random(5);
		for (x in info.x...info.x + info.max) {
			for (y in info.y...info.y + info.max) {
				var o = {
					x: x,
					y: y,
					t: getVanishTime(id, x - info.x, y - info.y, info.max)
				};
				destroyList.push(o);
			}
		}
	}

	function getVanishTime(id:Int, x:Int, y:Int, max:Int):Float {
		switch (id) {
			case 0: // ROND
				var dx = (max - 1) * 0.5 - x;
				var dy = (max - 1) * 0.5 - y;
				return VANISH_SPEED + Math.sqrt(dx * dx + dy * dy) * 5;

			case 1: // DIAGONAL
				return VANISH_SPEED + (x + y) * 3;
			case 2: // HORLOGE
				var cx = (max - 1) * 0.5;
				var cy = (max - 1) * 0.5;
				return VANISH_SPEED + (Cs.q(Math.atan2(cy - y, cx - x)) + 1) * 5;
			case 3: // CHAINE 1
				return VANISH_SPEED + x * max + y;
			case 4: // CHAINE 2
				return VANISH_SPEED + y * max + x;
		}
		return 12;
	}

	// CHECK
	function checkCombo() {
		var dl = new Array<Form>();
		var di = null;
		for (i in 0...formList.length) {
			var info = formList[i];
			var sx = info.x + info.list[0].x;
			var sy = info.y + info.list[0].y;
			for (n in Cs.COMBO_MIN...15) {
				var test = checkSquare(sx, sy, n);
				if (test != null && test.length > dl.length) {
					dl = test;
					di = {x: sx, y: sy, max: n};
				}
			}
		}

		if (dl.length > 0) {
			var color = [0, 0, 0];
			for (i in 0...dl.length) {
				var f = dl[i];
				var col = f.list[0].n;
				if (col > 2)
					col -= 3;
				color[col]++;
				formList.remove(f);
			}
			destroySquare(di);
			// SCORE
			var multi = 1;
			for (i in 0...color.length)
				if (color[i] == 0)
					multi++;
			var score = Math.round(Cs.q(Math.pow(di.max, 2.5)) * 0.1) * KKApi.val(Cs.C100);
			addScore(score * multi);
			#if debug
			cov.combo++;
			cov.maxSquare = Std.int(Math.max(cov.maxSquare, di.max));
			if (multi == 2)
				cov.bicolor++;
			if (multi == 3)
				cov.monocolor++;
			#end
			//
			var p:ScoreSquare = cast dm.add(new ScoreSquare(), DP_SCORE);
			p._x = di.x * SIZE;
			p._y = di.y * SIZE;
			p.vx = 0;
			p.vy = 0;
			p.setBgScale(di.max * SIZE);
			p.score = score * multi;
			p.sf._x = di.max * SIZE * 0.5;
			p.sf._y = di.max * SIZE * 0.5;
			p.sf._xscale = Math.min(di.max * 20, 100);
			p.sf._yscale = p.sf._xscale;
			p.t = 100;
			pList.push(p);
			// STATS
			stats._c.push({_s: score, _m: multi, _t: Math.round((mainTimer / Cs.TIMER_MAX) * 100)});

			// INTERFACE
			if (multi > 1) {
				var sc:ScorePanel = cast dm.add(new ScorePanel(), DP_HAND);
				sc._x = Cs.mcw;
				sc._y = Cs.mch;
				sc.score.gotoAndStop(multi - 1);
			}
		}
	}

	function checkSquare(sx:Int, sy:Int, max:Int):Array<Form> {
		for (x in sx...sx + max) {
			for (y in sy...sy + max) {
				if (gridGet(x, y) == null)
					return null;
			}
		}
		var fl = new Array();
		for (i in 0...formList.length) {
			var o = formList[i];
			var flOut:Null<Bool> = null;
			for (n in 0...o.list.length) {
				var p = o.list[n];
				var px = o.x + p.x;
				var py = o.y + p.y;
				if (px >= sx && px < sx + max && py >= sy && py < sy + max) {
					if (flOut == true)
						return null;
					flOut = false;
				} else {
					if (flOut == false)
						return null;
					flOut = true;
				}
			}
			if (flOut != true) {
				fl.push(o);
			}
		}
		return fl;
	}

	// the grid of the original: 20 Flash arrays. Out of them (x < 0 or x > 19) Flash read undefined and wrote nothing;
	// in a column, an index out of 0..19 is read / written like an AVM1 array (JS arrays do the same): only the swap
	// (CONTROL) can put cubes there
	inline function gridGet(x:Int, y:Int):Cube {
		return x >= 0 && x < 20 ? grid[x][y] : null;
	}

	inline function gridSet(x:Int, y:Int, v:Cube):Void {
		if (x >= 0 && x < 20)
			grid[x][y] = v;
	}

	//
	function endGame() {
		recordMouseEvent(EV_PRESS);
		gameOverSend();
		butEndGame.removeMovieClip();
	}

	// PARTS
	function updateParts() {
		var i = 0;
		while (i < pList.length) {
			var p = pList[i];
			if (p.weight != null) {
				p.vy += p.weight * mt.Timer.tmod;
			}
			if (p.frict != null) {
				p.vx *= p.frict;
				p.vy *= p.frict;
			}

			var ox = p._x;
			var oy = p._y;

			p._x += p.vx * mt.Timer.tmod;
			p._y += p.vy * mt.Timer.tmod;

			if (p.flQueue) {
				var dx = ox - p._x;
				var dy = oy - p._y;
				var a = Math.atan2(dy, dx);
				var d = Math.sqrt(dx * dx + dy * dy);
				var q = newPart("partQueue");
				q._x = p._x;
				q._y = p._y;
				q._rotation = a / 0.0174;
				q._xscale = d;
			}

			if (p.t != null) {
				p.t -= mt.Timer.tmod;
				if (p.t < 0) {
					p.removeMovieClip();
					pList.splice(i--, 1);
				} else if (p.t < 10) {
					// (compiled as `if (p.ft !== 0)`: ft undefined fades the alpha)
					if (p.ft != 0) {
						p._alpha = p.t * 10;
					} else {
						p._xscale = p.scale * (p.t / 10);
						p._yscale = p._xscale;
					}
				}
			}
			i++;
		}
	}

	public function newPart(link:String):Part {
		// (partLight: pictures at 4 px per Flash pixel, the particles are scaled up to 200 %)
		var p:Part = link == "partQueue" ? new Queue() : new Part("partLight", 2 * K);
		dm.add(p, DP_PARTS);
		p.vx = 0;
		p.vy = 0;
		p.frict = 0.95;
		p.scale = 100;
		pList.push(p);
		return p;
	}

	//
	function gameOver() {
		// KKApi.gameOver(stats)
		flGameOver = true;
	}

	// ---------------------------------------------------------------- KadoKadeo
	// KKApi.addScore: nothing after the game over is sent
	function addScore(n:Int) {
		if (!overSent)
			KadoKadeoManager.kkm.addScore(n);
	}

	// KKApi.gameOver({}) (the end button)
	function gameOverSend() {
		if (overSent)
			return;
		overSent = true;
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		untyped js.Browser.window.__over = debugState();
		#end
		KadoKadeoManager.kkm.gameOver({});
	}

	// map.useHandCursor (live games only: the cursor of the page)
	function setHandCursor(on:Bool) {
		if (isReplay || on == handCursor)
			return;
		handCursor = on;
		var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
		if (canvas != null)
			canvas.style.cursor = on ? "pointer" : "";
	}

	#if debug
	// test harness: called after each Flash frame (test modes)
	public var testHook:Void->Void;
	// what the game went through (coverage of the bots, compared between a game and its replay)
	public var cov = {
		take: 0,
		takeBack: 0,
		put: 0,
		swap: 0,
		turn: 0,
		miss: 0,
		burst: 0,
		combo: 0,
		maxSquare: 0,
		bicolor: 0,
		monocolor: 0,
		timeBonus: 0
	};

	// the comparison page (modes/hypercube.js test=show, examples/hypercube/ref.py draws it from the SWF): every cube
	// picture (6 frames x 16 subs), a whitened cube, the time ring reddened, a score square, mcScore at its top,
	// the end button (over), partRound, particles. The game is not updated afterwards
	public function debugShow():Void {
		for (n in 0...6)
			for (s in 1...17)
				newCube(s, 6 + 2 * n, n, s);
		var w = newCube(17, 6, 3, 5);
		for (o in flashLightList)
			Cs.setPercentColor(o.mc, o.mc == w ? 50 : 0, 0xFFFFFF);
		flashLightList = [];
		bg.ha.gotoAndStop(100);
		Cs.setPercentColor(bg.ha, 30, 0xFF0000);
		var p:ScoreSquare = cast dm.add(new ScoreSquare(), DP_SCORE);
		p._x = 17 * SIZE;
		p._y = 12 * SIZE;
		p.setBgScale(3 * SIZE);
		p.score = 9120;
		p.sf._x = p.sf._y = 3 * SIZE * 0.5;
		p.sf._xscale = p.sf._yscale = 60;
		var sc:ScorePanel = cast dm.add(new ScorePanel(), DP_HAND);
		sc._x = Cs.mcw;
		sc._y = Cs.mch;
		sc.gotoAndStop(11);
		sc.score._y = Data.SCORE_Y[10];
		sc.score.gotoAndStop(2);
		var e:EndButton = cast dm.get(4).attach(new EndButton());
		e.gotoAndStop(11);
		e.script(11);
		e.smc.gotoAndStop(2);
		var r = dm.add(new Round(), DP_SCORE);
		r._x = 285;
		r._y = 255;
		r._alpha = 50;
		r.gotoAndStop(6);
		var l = newPart("partLight");
		l._x = 270;
		l._y = 105;
		l._xscale = l._yscale = 150;
		var q = newPart("partQueue");
		q._x = 255;
		q._y = 120;
		q._rotation = 30;
		q._xscale = 40;
		MC.snapshotAll();
		MC.displayAll(1);
	}

	public function debugState():Dynamic {
		var g = "";
		for (x in 0...20)
			for (y in 0...20) {
				var c = grid[x][y];
				g += c == null ? "." : Std.string(c._currentframe);
			}
		return {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			timer: mainTimer,
			pieces: stats._p,
			combos: stats._c.length,
			forms: formList.length,
			boost: pieceBoost,
			cov: haxe.Json.stringify(cov),
			grid: g
		};
	}
	#end

	public function destroy():Void {
		if (onPointerDown != null) {
			var canvas:Dynamic = KadoKadeoManager.kkm.canvas;
			canvas.removeEventListener("pointerdown", onPointerDown);
			onPointerDown = null;
		}
		setHandCursor(false);
		MC.clearAll();
	}
}

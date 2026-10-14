package tubulo;

import common_haxe_avm1.kac.ProtectedInt;
import pixi.filters.colormatrix.ColorMatrixFilter;
import pixi.core.math.shapes.Circle;
import common_haxe_avm1.MouseManager;
import haxe.io.UInt16Array;
import pixi.core.text.Text;
import common_haxe_avm1.pixi.DropShadowFilter;
import kado.Seed;
import pixi.core.graphics.Graphics;
import mt.bumdum.Sprite;
import mt.bumdum.Lib;

enum Step {
	Play;
	Move(sens:Int);
	Anim(sens:Int);
	GameOver;
}

class ReplaySprite extends ASprite {
	public var but:Graphics;
	public var image:ASprite;
	public var point:pixi.core.math.Point;
}

class BgSprite extends ASprite {
	public var chrono:Graphics;
	public var field:Text;
	public var replay:ReplaySprite;
}

class TubeSprite extends ASprite {
	public var overAnim:ASprite;
	public var but:Circle;
	public var id:Int;
	public var oldId:Int;
	public var gridx:Int;
	public var gridy:Int;
	public var coef:Null<Float>;
}

@:expose('GameTubulo')
class Game implements kado.GameInterface {
	public static var DP_BG = 0;
	public static var DP_TUBES = 3;

	var lastMove:Float;
	var moveCoef:Float;
	var chrono:Float;
	var inMove:Int;
	var lvl:ProtectedInt;
	var score:Int;

	var par:Int;
	var moveNum:Int;

	var stats:{
		_t:Array<Array<Int>>,
		_e:Array<Int>,
		_r:Array<Int>,
		_l:Array<Array<Int>>,
		_cl:Array<Float>
	};

	public var grid:Array<Array<TubeSprite>>;
	public var tubes:Array<TubeSprite>;
	public var moves:Array<TubeSprite>;

	var step:Step;
	var isReplayMode:Bool;
	var allowClick:Bool;
	var currentHover = null;

	public var dm:mt.DepthManager;
	public var root:ASprite;
	public var bg:BgSprite;
	public var me:Game;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		isReplayMode = isReplay;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			recordEvents: true,
			recordMousePosition: false,
			recordedMouseButtons: UInt16Array.fromArray([MouseManager.BUTTON_LEFT]),
		});
		Cs.init();
		this.root = root;
		me = this;
		dm = new mt.DepthManager(root);

		bg = cast dm.attach("mcBg", DP_BG);
		bg.chrono = bg.getGraphics();
		bg.chrono.x = Cs.I(51);
		bg.chrono.y = Cs.I(262);
		bg.chrono.rotation = -Math.PI / 4;

		bg.field = bg.initTextField("field", {
			font: "Alien Encounters Solid",
			align: "right",
			size: 50,
			color: 0xFFFFFF,
			strokeThickness: 9,
			stroke: "0x5A8929"
		});
		bg.field.x = Cs.S(300);

		stats = {
			_t: [[]],
			_e: [],
			_r: [],
			_l: [],
			_cl: [],
		}

		//
		lvl = new ProtectedInt(0);
		KadoKadeoManager.kkm.addScore(Cs.SCORE_START);

		initGrid();
		genLevel();
		// initPlay();
		initAnim(-1);

		initChrono();
	}

	function initGrid() {
		grid = [];
		tubes = [];
		for (x in 0...Cs.SIDE) {
			grid[x] = [];
			for (y in 0...Cs.SIDE) {
				var mc:TubeSprite = cast dm.attach("mcTube", DP_TUBES);
				mc._x = Cs.getX(x, y);
				mc._y = Cs.getY(x, y);
				mc.overAnim = mc.attachMovie("over");
				mc.overAnim.loop = true;
				mc.overAnim.play();
				mc.overAnim._visible = false;
				var f = new ColorMatrixFilter();
				f.matrix = [
					1, 0, 0, 0, 1,
					0, 1, 0, 0, 1,
					0, 0, 1, 0, 1,
					0, 0, 0, 1, 0
				];
				mc.overAnim.filters = [f];

				mc.but = new Circle(Cs.I(0), Cs.I(-19), Cs.I(14));
				// mc.getGraphics().beginFill(0xFF0000, 0.5).drawCircle(mc.but.x, mc.but.y, mc.but.radius);

				mc.id = 0;
				mc.oldId = mc.id;
				grid[x][y] = mc;
				mc.gridx = x;
				mc.gridy = y;
				mc.gotoAndStop(getTubeFrame(mc.id, 11));
				tubes.push(mc);
			}
		}

		hideInterface();
	}

	public function applyReplayEvents() {
		for (event in KadoKadeoManager.kkm.replay.consumeEvents()) {
			if (event.k == 0) {
				if (currentHover != null)
					rOutTube(currentHover[0], currentHover[1]);
				rOverTube(event.x, event.y);
				currentHover = [event.x, event.y];
			}
			if (event.k == 2) {
				clickTube(event.x, event.y);
			}
			if (event.k == 3) {
				resetLevel();
			}
		}
	}

	function updateMouseEvents() {
		if (allowClick && !isReplayMode) {
			var hover:TubeSprite = null;
			var i = tubes.length - 1;
			while (i >= 0) {
				var tube = tubes[i];
				if (tube.but.contains(MouseManager.getX() - tube._x, MouseManager.getY() - tube._y)) {
					hover = tube;
					break;
				}
				i--;
			}

			if (hover == null) {
				if (currentHover != null) {
					rOutTube(currentHover[0], currentHover[1]);
					// KadoKadeoManager.kkm.replay.recordEvent({k: 1, x: currentHover[0], y: currentHover[1]});
					currentHover = null;
				}
			} else if (MouseManager.isButtonJustReleased(MouseManager.BUTTON_LEFT)) {
				clickTube(hover.gridx, hover.gridy);
			} else if (currentHover == null || currentHover[0] != hover.gridx || currentHover[1] != hover.gridy) {
				if (currentHover != null)
					rOutTube(currentHover[0], currentHover[1]);
				rOverTube(hover.gridx, hover.gridy);
				KadoKadeoManager.kkm.replay.recordEvent({k: 0, x: hover.gridx, y: hover.gridy}, KadoKadeoManager.kkm.replay.getCurrentFrame());
				currentHover = [hover.gridx, hover.gridy];
			}

			bg.replay.point.x = MouseManager.getX() - bg.replay.but.x;
			bg.replay.point.y = MouseManager.getY() - bg.replay.but.y;
			if (bg.replay.but.containsPoint(bg.replay.point)) {
				bg.replay.image.gotoAndStop(2);
				if (MouseManager.isButtonDown(MouseManager.BUTTON_LEFT)) {
					bg.replay.image.gotoAndStop(3);
				}
				if (MouseManager.isButtonJustReleased(MouseManager.BUTTON_LEFT)) {
					bg.replay.image.gotoAndStop(1);
					resetLevel();
					KadoKadeoManager.kkm.replay.recordEvent({k: 3}, KadoKadeoManager.kkm.replay.getCurrentFrame());
				}
			} else {
				bg.replay.image.gotoAndStop(1);
			}
		} else {
			bg.replay.image.gotoAndStop(1);
		}
	}

	// UPDATE
	public function update(delta:Float) {
		applyReplayEvents();
		updateMouseEvents();

		switch (step) {
			case Play:
				updateChrono();
			case Move(sens):
				moveCoef = Math.min(moveCoef + Cs.TUBE_SPEED * mt.Timer.tmod, 1);
				var frame = 10 * moveCoef;
				if (sens == -1)
					frame = 10 * (1 - moveCoef);

				var flSwap = false;

				if (moveCoef == 1) {
					if (sens == 1) {
						step = Move(-1);
						flSwap = true;
						moveCoef = 0;
					} else {
						checkEnd();
					}
				}

				for (mc in moves) {
					var displayId = sens == 1 && !flSwap ? mc.oldId : mc.id;
					mc.gotoAndStop(getTubeFrame(displayId, Std.int(frame + 1)));
					if (flSwap)
						mc.oldId = mc.id;
				}

				updateChrono();
			case Anim(sens):
				moveCoef = Math.min(moveCoef + Cs.TUBE_SPEED * mt.Timer.tmod, 1);

				for (mc in tubes) {
					if (mc.coef != null) {
						var coef = Math.min(mc.coef + Cs.TUBE_SPEED * mt.Timer.tmod, 1);
						mc.coef = coef;
						if (coef > 0) {
							var frame = 10 * coef;
							if (sens == -1)
								frame = 10 * (1 - coef);
							mc.gotoAndStop(getTubeFrame(mc.id, Std.int(frame + 1)));
							if (coef == 1) {
								// mc.smc.gotoAndStop(mc.id + 1);
								inMove--;
								mc.coef = null;
							}
						}
					}
				}
				if (inMove == 0) {
					if (sens == 1) {
						genLevel();
						initAnim(-1);
					} else {
						moveNum = 0;
						initPlay();
					}
				}

				updateChrono();
			case GameOver:
		}

		Sprite.updateAll();
	}

	function initChrono() {
		chrono = 0;

		bg.chrono.filters = [
			new DropShadowFilter({
				blur: 4,
				rotation: 90,
				distance: Cs.S(2),
				color: 0x25892B,
			})
		];

		bg.replay = cast bg.attachMovie("reloadBase");
		bg.replay._x = Cs.S(250);
		bg.replay._y = Cs.S(260);
		bg.replay.but = bg.replay.getGraphics().beginFill(0x000000, 0.001).drawCircle(Cs.S(2), Cs.S(4), Cs.S(36));
		bg.replay.image = bg.replay.attachMovie("reload");

		bg.replay.but.scale.x = 0.98;
		bg.replay.but.scale.y = 0.76;
		bg.replay.but.skew.x = -0.92;
		bg.replay.but.skew.y = 0.45;

		bg.replay.point = new pixi.core.math.Point(0, 0);
	}

	function updateChrono() {
		// static var scaleX = 0.98;
		// static var scaleY = 0.76;
		// static var skewX = -0.92;
		// static var skewY = 0.45;
		// static var scaleX = 1.02;
		// static var scaleY = 0.66;
		// static var skewX = -1.47;
		// static var skewY = 1.09;

		chrono += mt.Timer.tmod;

		var angle = (1 - chrono / Cs.CHRONO_MAX) * Math.PI * 2;
		bg.chrono.clear();
		bg.chrono.beginFill(0x25892B);
		bg.chrono.moveTo(0, 0);
		bg.chrono.arc(0, 0, Cs.I(36), -Math.PI / 3, angle - Math.PI / 3, false);
		bg.chrono.lineTo(0, 0);

		// if (KeyboardManager.isDown(KeyboardManager.A)) {
		// 	scaleX -= 0.01;
		// }
		// if (KeyboardManager.isDown(KeyboardManager.Z)) {
		// 	scaleX += 0.01;
		// }
		// if (KeyboardManager.isDown(KeyboardManager.Q)) {
		// 	scaleY -= 0.01;
		// }
		// if (KeyboardManager.isDown(KeyboardManager.S)) {
		// 	scaleY += 0.01;
		// }
		// if (KeyboardManager.isDown(KeyboardManager.E)) {
		// 	skewX -= 0.01;
		// }
		// if (KeyboardManager.isDown(KeyboardManager.R)) {
		// 	skewX += 0.01;
		// }
		// if (KeyboardManager.isDown(KeyboardManager.D)) {
		// 	skewY -= 0.01;
		// }
		// if (KeyboardManager.isDown(KeyboardManager.F)) {
		// 	skewY += 0.01;
		// }

		bg.chrono.scale.x = 1.02;
		bg.chrono.scale.y = 0.66;
		bg.chrono.skew.x = -1.47;
		bg.chrono.skew.y = 1.09;
		// trace("scaleX: " + scaleX + ", scaleY: " + scaleY + ", skewX: " + skewX + ", skewY: " + skewY);

		if (chrono >= Cs.CHRONO_MAX) {
			hideInterface();
			step = GameOver;
			KadoKadeoManager.kkm.gameOver(stats);
		}
	}

	function clickTube(x, y) {
		KadoKadeoManager.kkm.replay.recordEvent({k: 2, x: x, y: y}, KadoKadeoManager.kkm.replay.getCurrentFrame());
		moveNum++;

		var now = Date.now().getTime();
		var dif = Std.int(now - lastMove);
		stats._t[stats._t.length - 1].push(dif);
		lastMove = now;

		moves = [];
		var list = Cs.DIR.copy();
		list.push([0, 0]);
		for (d in list) {
			if (grid[x + d[0]] != null && grid[x + d[0]][y + d[1]] != null) {
				var mc = grid[x + d[0]][y + d[1]];
				mc.oldId = mc.id;
				mc.id = (mc.id + 1) % Cs.COL_MAX;
				KadoKadeoManager.kkm.addScore(Cs.SCORE_TUBE[mc.id]);
				moves.push(mc);
			}
			rOutTube(x, y);
		}
		hideInterface();
		step = Move(1);
		moveCoef = 0;
	}

	function checkEnd() {
		var bid = null;
		for (mc in tubes) {
			if (bid == null)
				bid = mc.id;
			if (mc.id != bid) {
				initPlay();
				return;
			}
		}

		stats._e.push(moveNum - par);
		stats._t.push([]);
		lvl += 1;
		KadoKadeoManager.kkm.addScore(Cs.SCORE_LEVEL);
		initAnim(1);
		chrono = Math.max(chrono - Cs.CHRONO_BONUS, 0);
		stats._cl.push(chrono);
	}

	function initPlay() {
		step = Play;
		lastMove = Date.now().getTime();
		showInterface();
	}

	//
	function rOverTube(x, y) {
		var list = Cs.DIR.copy();
		list.push([0, 0]);
		for (d in list) {
			if (grid[x + d[0]] != null && grid[x + d[0]][y + d[1]] != null) {
				var mc = grid[x + d[0]][y + d[1]];
				mc.overAnim._visible = true;
				mc.overAnim.gotoAndPlay(1);
			}
		}
	}

	function rOutTube(x, y) {
		var list = Cs.DIR.copy();
		list.push([0, 0]);
		for (d in list) {
			if (grid[x + d[0]] != null && grid[x + d[0]][y + d[1]] != null) {
				var mc = grid[x + d[0]][y + d[1]];
				mc.overAnim._visible = false;
				mc.overAnim.stop();
			}
		}
	}

	function initAnim(sens) {
		var aid = Seed.random(5);
		var sx = Seed.random(2) == 0;
		var sy = Seed.random(2) == 0;
		for (mc in tubes)
			setAnim(mc, aid, sx, sy);
		step = Anim(sens);
		inMove = tubes.length;
		hideInterface();
	}

	function setAnim(mc:TubeSprite, aid, sx:Bool, sy:Bool) {
		var x:Float = mc.gridx;
		var y:Float = mc.gridy;
		if (sx)
			x = Cs.SIDE - x;
		if (sy)
			y = Cs.SIDE - y;

		var dx = x - Cs.SIDE * 0.5;
		var dy = y - Cs.SIDE * 0.5;
		var dist = Math.sqrt(dx * dx + dy * dy);
		var a = Num.sMod(Math.atan2(dy, dx), 6.28);

		switch (aid) {
			case 0:
				mc.coef = -(x + y) * 0.3;
			case 1:
				mc.coef = -(x + y * 0.3) * 0.5;
			case 2:
				mc.coef = -dist * 0.4;
			case 3:
				mc.coef = -a * 0.5;
			case 4:
				mc.coef = -(a * 0.2 + dist * 0.2);
		}
	}

	function genLevel() {
		// DISPLAY
		bg.field.text = "niveau " + (lvl + 1);

		// GAIN
		score = KadoKadeoManager.kkm.score;

		// CLEAN
		var baseColor = 0;
		for (mc in tubes) {
			mc.id = baseColor;
			mc.oldId = mc.id;
		}

		var max = Std.int(1 + Math.pow(lvl, 1.5));
		var mir = [[false, false]];

		var proba = lvl + 2;
		if (Seed.random(proba) == 0)
			mir.push([true, false]);
		else if (Seed.random(proba) == 0)
			mir.push([false, true]);
		else if (Seed.random(proba) == 0)
			mir.push([true, true]);

		par = 0;
		while (max > 0) {
			var x = Seed.random(Cs.SIDE);
			var y = Seed.random(Cs.SIDE);
			for (dm in mir) {
				var list = Cs.DIR.copy();
				list.push([0, 0]);
				for (d in list) {
					var nx = x + d[0];
					var ny = y + d[1];

					if (dm[0])
						nx = Cs.SIDE - (nx + 1);
					if (dm[1])
						ny = Cs.SIDE - (ny + 1);

					if (grid[nx] != null && grid[nx][ny] != null) {
						var mc = grid[nx][ny];
						mc.id = (mc.id + Cs.COL_MAX - 1) % Cs.COL_MAX;
						mc.oldId = mc.id;
					}
				}
				max--;
				par++;
			}
		}

		var cols = [0, 0, 0];
		for (mc in tubes) {
			// mc.smc.gotoAndStop(mc.id + 1); // OLD
			mc.gotoAndStop(getTubeFrame(mc.id, getTubeLocalFrame(mc))); // NEW
			cols[mc.id]++;
		}
		stats._l.push(cols);
	}

	inline function getTubeFrame(id:Int, frame:Int) {
		return id * 11 + frame;
	}

	inline function getTubeLocalFrame(mc:TubeSprite) {
		return ((mc._currentframe - 1) % 11) + 1;
	}

	function resetLevel() {
		if (step != Play)
			return;
		stats._r.push(lvl);
		setScore(score);
		chrono = Math.min(chrono + 100, Cs.CHRONO_MAX);
		initAnim(1);
		stats._l.splice(lvl, 1);
	}

	function setScore(value:Int) {
		KadoKadeoManager.kkm.addScore(value - KadoKadeoManager.kkm.score);
	}

	// INTERFACE
	function showInterface() {
		allowClick = true;
	}

	function hideInterface() {
		allowClick = false;
	}

	public function destroy() {}
}

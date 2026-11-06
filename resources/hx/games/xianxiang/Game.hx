package xianxiang;

import haxe.io.UInt16Array;
import mt.Timer;
import mt.DepthManager;
import common_haxe_avm1.MouseManager;
import pixi.filters.colormatrix.ColorMatrixFilter;
import xianxiang.Level.CellPos;

typedef MatchNumber = {mc:ASprite, sub:ASprite, frame:Int, t:Float};

@:expose('GameXianXiang')
class Game implements kado.GameInterface {
	public var dmanager:DepthManager;

	var level:Level;
	var bg_mc:ASprite;
	var mlist:Array<MatchNumber>;

	var current:Card;
	var colorTime:Float;
	var breaks:Array<Card>;

	var path:Array<ASprite>;
	var pathColor:ColorMatrixFilter;

	var hoverCell:CellPos;
	var bgPressed:Bool;
	var finished:Bool;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayMouseButtons = new UInt16Array(1);
		replayMouseButtons[0] = MouseManager.BUTTON_LEFT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: new UInt16Array(0),
			recordInputs: false,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: replayMouseButtons,
		});

		colorTime = 0;
		dmanager = new DepthManager(root);
		bg_mc = dmanager.attach("bg", Const.PLAN_BG);
		level = new Level(this);
		mlist = new Array();
		breaks = new Array();
		path = new Array();
		bgPressed = false;
		finished = false;

		// Color.setRGB(0xFF0000) on the path parts blocked by a card
		pathColor = new ColorMatrixFilter();
		pathColor.matrix = [
			0, 0, 0, 0, 1,
			0, 0, 0, 0, 0,
			0, 0, 0, 0, 0,
			0, 0, 0, 1, 0
		];
	}

	public function spawn(c:Card, v:Int) {
		var m = dmanager.empty(Const.PLAN_MATCH);
		m._x = c.mc._x + Const.MATCH_X;
		m._y = c.mc._y + Const.MATCH_Y;
		var sub = m.attachMovie("match", "sub", 1);
		sub.gotoAndStop(v + 1);
		var n = {
			mc: m,
			sub: sub,
			frame: 0,
			t: 1.0
		};
		showMatchFrame(n);
		mlist.push(n);
	}

	function showMatchFrame(m:MatchNumber) {
		m.sub._xscale = Const.MATCH_SCALE[m.frame] * 100;
		m.sub._yscale = Const.MATCH_SCALE[m.frame] * 100;
		m.sub._alpha = Const.MATCH_ALPHA[m.frame] * 100;
	}

	public function update(delta:Float) {
		if (!finished)
			updateMouse();

		var i = 0;
		while (i < mlist.length) {
			var m = mlist[i];
			if (m.frame < Const.MATCH_SCALE.length - 1) {
				m.frame++;
				showMatchFrame(m);
			}
			m.t -= Timer.deltaT;
			if (m.t < 0) {
				m.mc._alpha -= Timer.tmod * 8;
				if (m.mc._alpha <= 0) {
					mlist.splice(i--, 1);
					m.mc.removeMovieClip();
				}
			}
			i++;
		}

		colorTime += Timer.tmod / 5;
		var c = Std.int((Math.sin(colorTime) + 1) * 25);
		if (current != null)
			current.setColorOffset(c);

		var i = 0;
		while (i < breaks.length) {
			var b = breaks[i];
			b.mc._alpha -= 30 * Timer.tmod;
			if (b.mc._alpha <= 0) {
				breaks.splice(i--, 1);
				b.destroy();
			}
			i++;
		}
	}

	// card.onPress / bg.onRelease / bg.onMouseMove, polled so that replays are deterministic
	function updateMouse() {
		var mx = MouseManager.getX();
		var my = MouseManager.getY();

		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT)) {
			var c = level.getCardAt(mx, my);
			bgPressed = (c == null);
			if (c != null)
				cardSelect(c);
		}

		if (MouseManager.isButtonJustReleased(MouseManager.BUTTON_LEFT)) {
			if (bgPressed && level.getCardAt(mx, my) == null)
				release();
			bgPressed = false;
		}

		if (!finished)
			mouseMove();
	}

	function explosion(x:Float, y:Float) {
		var fx = dmanager.attach("explosion", Const.PLAN_FX);
		fx._x = x + Const.CARD_WIDTH / 2;
		fx._y = y + Const.CARD_HEIGHT / 2;
		var scale = Seed.randomVfx(40) + 80;
		fx._xscale = scale * (Seed.randomVfx(2) * 2 - 1);
		fx._yscale = scale;
		fx.removeOnFrame = Const.EXPLOSION_END_FRAME;
		fx.play();
	}

	function cardSelect(c:Card) {
		if (current == null) {
			current = c;
			colorTime = 0;
		} else {
			if (level.breakCards(c, current)) {
				explosion(c.mc._x, c.mc._y);
				explosion(current.mc._x, current.mc._y);
				c.desactivate();
				current.desactivate();
				breaks.push(c);
				breaks.push(current);
				if (!level.canBreak())
					gameOver();
			}
			current.resetColor();
			current = null;
		}
		mouseMove(true);
	}

	function release() {
		if (current != null) {
			current.resetColor();
			current = null;
			clearPath();
			mouseMove(true);
		}
	}

	function gameOver() {
		finished = true;
		KadoKadeoManager.kkm.gameOver({c: level.combis, p: level.perfectColors, n: level.perfectNeighbours});
	}

	function mouseMove(?force:Bool = false) {
		var cell = getMouseCell();
		if (!force && sameCell(cell, hoverCell))
			return;
		hoverCell = cell;
		activePath(cell);
	}

	function getMouseCell():CellPos {
		var xm = MouseManager.getX() - Const.BASE_X;
		var ym = MouseManager.getY() - Const.BASE_Y;
		if (xm < 0 || ym < 0)
			return null;
		var x = Std.int(xm / Const.CARD_WIDTH);
		var y = Std.int(ym / Const.CARD_HEIGHT);
		if (x >= Const.LVL_WIDTH || y >= Const.LVL_HEIGHT)
			return null;
		return {x: x, y: y};
	}

	function sameCell(a:CellPos, b:CellPos) {
		if (a == null || b == null)
			return a == b;
		return a.x == b.x && a.y == b.y;
	}

	function activePath(target:CellPos) {
		clearPath();
		if (current == null || target == null || (target.x == current.x && target.y == current.y))
			return;

		var npath1 = level.pathLength(current, target);
		var npath2 = level.pathLength(target, current);
		if (npath1 < npath2)
			tracePath(current, target);
		else
			tracePath(target, current);
	}

	function attachPath(x:Int, y:Int, t:Int) {
		var s = (level.tbl[x][y] == null) || t >= 3;
		var p = dmanager.attach("link", Const.PLAN_PATH);
		p.gotoAndStop(t + 1);
		p._x = Const.BASE_X + (x + 0.5) * Const.CARD_WIDTH;
		p._y = Const.BASE_Y + (y + 0.5) * Const.CARD_HEIGHT;
		if (!s)
			p.filters = [pathColor];
		path.push(p);
		return p;
	}

	function tracePath(c1:CellPos, c2:CellPos) {
		var x, y;
		var p;
		y = c1.y;

		if (c1.x == c2.x) {
			p = attachPath(c1.x, c1.y, 3);
			if (c1.y > c2.y)
				p._yscale = -100;
		} else {
			p = attachPath(c1.x, c1.y, 4);
			if (c1.x > c2.x)
				p._xscale = -100;
		}

		if (c1.x < c2.x) {
			x = c1.x + 1;
			while (x < c2.x) {
				attachPath(x, y, 0);
				x++;
			}
		} else if (c1.x == c2.x)
			x = c1.x;
		else {
			x = c1.x - 1;
			while (x > c2.x) {
				attachPath(x, y, 0);
				x--;
			}
		}

		if (c1.x != c2.x && c1.y != c2.y) {
			p = attachPath(x, y, 2);
			if (c1.y > c2.y)
				p._yscale = -100;
			if (c1.x < c2.x)
				p._xscale = -100;
		}

		if (c1.y < c2.y) {
			y = c1.y + 1;
			while (y < c2.y) {
				attachPath(x, y, 1);
				y++;
			}
		} else {
			y = c1.y - 1;
			while (y > c2.y) {
				attachPath(x, y, 1);
				y--;
			}
		}

		if (c1.y == c2.y) {
			p = attachPath(c2.x, c2.y, 4);
			if (c1.x < c2.x)
				p._xscale = -100;
		} else {
			p = attachPath(c2.x, c2.y, 3);
			if (c1.y < c2.y)
				p._yscale = -100;
		}
	}

	function clearPath() {
		for (p in path) {
			p.removeMovieClip();
		}
		path = new Array();
	}

	public function destroy():Void {
		dmanager.destroy();
	}
}

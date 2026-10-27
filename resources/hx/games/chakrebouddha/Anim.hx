package chakrebouddha;

import chakrebouddha.Common;
import chakrebouddha.Gfx;
import chakrebouddha.MC.FilterDef;

interface Anim {
	public var onEnd:Void->Void;
	public function play():Bool;
	public function clean():Void;
}

interface Guest {
	public function updateCoord(x:Float, y:Float):Void;
}

// (class ChakraGlow of the original: never created, not ported)

// the loop of PointsAnim / BonusAnim / BonusPointsAnim.play over Sprite.spriteList (not a copy: a Phys that dies makes
// the next one wait for the next frame). Every sprite of the game is updated once more per frame for each of these
// anims alive: the rocks fall and the neons fade faster while points are shown (kept)
function updateSprites() {
	var l = Sprite.spriteList;
	var i = 0;
	while (i < l.length) {
		var p = l[i];
		i++;
		p.update();
	}
}

// ct.rgb = color then the multipliers 0.3 (Transform.colorTransform also sets the alpha back to 100)
function lotusColor(mc:MC, color:Int) {
	mc.cx = [0.3, 0.3, 0.3, (color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF];
	mc._alpha = 100;
}

class PointsAnim implements Anim {
	public var onEnd:Void->Void;

	var mc:MC;
	var mcPoints:Points;
	var glow:FilterDef;
	var phys:Phys;

	public function new(game:Game, chakra:Chakra, points:Int) {
		mc = game.dm.add(new Lotus(), Const.DP_CHAKRAS);
		mc._x = chakra.mc._x;
		mc._y = chakra.mc._y;
		mc._xscale = mc._yscale = 5;
		mc._alpha = 0;
		mc._rotation = 1;

		// (after _alpha = 0: the lotus starts opaque)
		lotusColor(mc, chakra.color);

		mcPoints = game.dm.add(new Points(), Const.DP_CHAKRAS);
		if (!chakra.missed) {
			mcPoints._xscale = mcPoints._yscale = mc._xscale;
			var sp = Std.string(points);
			mcPoints.text.text = sp;
			switch (sp.length) {
				case 2:
					mcPoints._x = mc._x + 2;
				case 3:
					mcPoints._x = mc._x + 2.5;
				case 4:
					mcPoints._x = mc._x;
			}
			mcPoints._y = mc._y;
		} else {
			mcPoints._visible = false;
		}

		glow = Glow(32, 1, chakra.color, 1);
		phys = new Phys(mc);
		phys.fadeType = 4;
		phys.timer = 40;

		var p = new Phys(mcPoints);
		p.fadeType = 4;
		p.timer = 40;
	}

	public function play() {
		var tmod = mt.Timer.tmod;
		phys.root._rotation -= 5;

		mc.filters = [glow];
		phys.root._alpha += 10;
		phys.root._xscale += 7;
		mcPoints._xscale = phys.root._xscale;
		phys.root._yscale = phys.root._xscale;
		mcPoints._yscale = phys.root._yscale;

		updateSprites();

		if (phys.timer <= 0 || phys == null) {
			return true;
		}
		return false;
	}

	public function clean() {
		mc.removeMovieClip();
		mc = null;
	}
}

class EnergyAnim implements Anim {
	public var onEnd:Void->Void;

	var mc:MC;
	var steps:Int;
	var max:Int;
	// the move of the whole anim, in twips (1/20 px)
	var total:Int;
	var minus:Bool;

	// The original moved points / max per step, but play moves the bar max + 2 times: every gain and loss was shown
	// 10 % too big, and the bar drifted away from the energy over a game (half full at the end of a long one). Now
	// points over the max + 2 steps, in whole twips (_y keeps whole twips: points / 22 would lose its rest at every
	// step). The end of the anim (its onEnd) is unchanged: mc._y never reaches 0 (the energy stops at 0, the bar at -91)
	public function new(mc:MC, points:Int, minus = true) {
		this.mc = mc;
		steps = 0;
		max = 20;
		total = points * 20;
		this.minus = minus;
	}

	public function play() {
		if (mc._y >= 0)
			return true;

		var t = Std.int(total * (steps + 1) / (max + 2)) - Std.int(total * steps / (max + 2));
		moveBy(mc, minus ? t : -t);

		if (steps++ > max) {
			return true;
		}

		return false;
	}

	// mc._y += twips / 20, exactly: MC.twips truncates towards 0, a sum a hair short of a whole twip would lose it
	public static function moveBy(mc:MC, twips:Int) {
		var k = Math.round(mc._y * 20) + twips;
		mc._y = (k + (k < 0 ? -0.5 : 0.5)) / 20;
	}

	public function clean() {}
}

class BonusAnim implements Anim {
	public var onEnd:Void->Void;

	var mc:MC;
	var mcPoints:Points;
	var phys:Phys;

	public function new(game:Game, points:Int) {
		mc = game.dm.add(new Lotus(), Const.DP_CHAKRAS);
		mc._x = 150;
		mc._y = 150;
		mc._xscale = mc._yscale = 5;
		mc._alpha = 0;
		mc._rotation = 1;

		// (a colour for the eye only: the visual random)
		lotusColor(mc, Const.COLORS[Seed.randomVfx(Const.COLORS.length)]);

		mcPoints = game.dm.add(new Points(true), Const.DP_CHAKRAS);
		mcPoints._xscale = mcPoints._yscale = mc._xscale;
		var sp = Std.string(points);
		mcPoints.text.text = sp;
		mcPoints._x = mc._x;
		mcPoints._y = mc._y;

		phys = new Phys(mc);
		phys.timer = 40;
		phys.vsc = 1.14;
		var p = new Phys(mcPoints);
		p.timer = 40;
		p.vsc = 1.14;
	}

	public function play() {
		phys.root._rotation -= 5;

		phys.root._alpha += 2;

		updateSprites();

		if (phys.timer <= 0 || phys == null) {
			return true;
		}
		return false;
	}

	public function clean() {
		mc.removeMovieClip();
		mc = null;
	}
}

class BonusPointsAnim implements Anim {
	public var onEnd:Void->Void;

	var mc:MC;
	var mcBonus:MC;
	var mcPoints:Points;
	var glow:FilterDef;
	var phys:Phys;

	public function new(game:Game, chakra:Chakra, points:Int) {
		mc = game.dm.add(new Lotus(), Const.DP_CHAKRAS);
		mc._x = chakra.mc._x;
		mc._y = chakra.mc._y;
		mc._xscale = mc._yscale = 5;
		mc._alpha = 0;
		mc._rotation = 1;

		mcBonus = game.dm.add(new Bonus(), Const.DP_CHAKRAS);
		mcBonus._x = mc._x;
		mcBonus._y = mc._y - 5;
		mcBonus._xscale = mcBonus._yscale = mc._xscale;

		lotusColor(mc, chakra.color);

		mcPoints = game.dm.add(new Points(), Const.DP_CHAKRAS);
		if (!chakra.missed) {
			mcPoints._xscale = mcPoints._yscale = mc._xscale;
			var sp = Std.string(points);
			mcPoints.text.text = sp;
			switch (sp.length) {
				case 2:
					mcPoints._x = mc._x + 2;
				case 3:
					mcPoints._x = mc._x + 2.5;
				case 4:
					mcPoints._x = mc._x;
			}
			mcPoints._y = mc._y + 10;
		} else {
			mcPoints._visible = false;
		}

		glow = Glow(32, 1, chakra.color, 1);
		phys = new Phys(mc);
		phys.fadeType = 4;
		phys.timer = 40;

		var p = new Phys(mcPoints);
		p.fadeType = 4;
		p.timer = 40;

		var b = new Phys(mcBonus);
		b.fadeType = 4;
		b.timer = 40;
		b.vy = -1;
	}

	public function play() {
		var tmod = mt.Timer.tmod;
		phys.root._rotation -= 5 * tmod;

		mc.filters = [glow];
		phys.root._alpha += 10 * tmod;
		phys.root._xscale += 7 * tmod;
		mcPoints._xscale = phys.root._xscale;
		mcBonus._xscale = mcPoints._xscale;
		phys.root._yscale = phys.root._xscale;
		mcPoints._yscale = phys.root._yscale;
		mcBonus._yscale = mcPoints._yscale;

		updateSprites();

		if (phys.timer <= 0 || phys == null) {
			return true;
		}
		return false;
	}

	public function clean() {
		mc.removeMovieClip();
		mc = null;
	}
}

enum TransitionParam {
	In;
	Out;
	InOut;
}

enum Transition {
	Linear;
	Quad; // Quadratic
	Cubic; // Cubicular
	Quart; // Quartetic
	Quint; // Quintetic
	Pow(pa:Float);
	Expo;
	Circ;
	Sine;
	Back(pa:Float);
	Bounce;
	Elastic(pa:Float);
}

class TransitionFunctions {
	static function transitionParam(p:TransitionParam, f:Float->Float):Float->Float {
		return switch (p) {
			case In: f;
			case Out: function(pos:Float) {
					return 1 - f(1 - pos);
				}
			case InOut: function(pos:Float) {
					return if (pos <= 0.5) f(2 * pos) / 2 else (2 - f(2 * (1 - pos)) / 2);
				}
		}
	}

	public static function get(t:Transition) {
		return switch (t) {
			case Linear: linear;
			case Quad: transitionParam(Out, quad);
			case Cubic: transitionParam(Out, cubic);
			case Quart: transitionParam(Out, quart);
			case Quint: transitionParam(Out, quint);
			case Pow(pa): transitionParam(Out, pow.bind(pa));
			case Expo: transitionParam(Out, expo);
			case Circ: transitionParam(Out, circ);
			case Sine: transitionParam(Out, sine);
			case Back(pa): transitionParam(Out, back.bind(pa));
			case Bounce: transitionParam(Out, bounce);
			case Elastic(pa): transitionParam(Out, elastic.bind(pa));
		}
	}

	public static function linear(p:Float) {
		return p;
	}

	public static function pow(x:Float = 6.0, p:Float) {
		return Math.pow(p, x);
	}

	public static function expo(p:Float) {
		return Math.pow(2, 8 * (p - 1));
	}

	public static function circ(p:Float) {
		return 1 - Math.sin(Math.acos(p));
	}

	public static function sine(p:Float) {
		return 1 - Math.sin((1 - p) * Math.PI / 2);
	}

	public static function back(pa:Float = 1.618, p:Float) {
		return Math.pow(p, 2) * ((pa + 1) * p - pa);
	}

	public static function bounce(p:Float):Float {
		var value:Float = Math.NaN;
		var a = 0.0;
		var b = 1.0;
		while (true) {
			if (p >= (7 - 4 * a) / 11) {
				value = -Math.pow((11 - 6 * a - 11 * p) / 4, 2) + b * b;
				break;
			}
			a += b;
			b /= 2;
		}
		return value;
	}

	public static function elastic(pa:Float = 1.0, p:Float) {
		return Math.pow(2, 10 * --p) * Math.cos(20 * p * Math.PI * pa / 3);
	}

	public static function quad(p:Float) {
		return Math.pow(p, 2);
	}

	public static function cubic(p:Float) {
		return Math.pow(p, 3);
	}

	public static function quart(p:Float) {
		return Math.pow(p, 4);
	}

	public static function quint(p:Float) {
		return Math.pow(p, 5);
	}
}

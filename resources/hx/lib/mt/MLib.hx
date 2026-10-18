package mt;

import kado.Seed;

// Maths helpers of the deepnight libs (min / max / clamp / round / rand...): the random ones draw on KadoKadeo's
// visual random when no generator is given.
class MLib {

	public static inline var EPS = 1e-10;
	public static inline var PI = 3.141592653589793;
	public static inline var PI2 = 6.283185307179586;

	public static inline function min(a:Int, b:Int):Int {
		return a < b ? a : b;
	}

	public static inline function max(a:Int, b:Int):Int {
		return a > b ? a : b;
	}

	public static inline function fmin(a:Float, b:Float):Float {
		return a < b ? a : b;
	}

	public static inline function fmax(a:Float, b:Float):Float {
		return a > b ? a : b;
	}

	public static inline function abs(v:Float):Float {
		return v < 0 ? -v : v;
	}

	public static inline function iabs(v:Int):Int {
		return v < 0 ? -v : v;
	}

	public static inline function fabs(v:Float):Float {
		return v < 0 ? -v : v;
	}

	public static inline function sgn(v:Float):Int {
		return v < 0 ? -1 : (v > 0 ? 1 : 0);
	}

	public static inline function round(v:Float):Int {
		return Math.round(v);
	}

	public static inline function ceil(v:Float):Int {
		return Math.ceil(v);
	}

	public static inline function floor(v:Float):Int {
		return Math.floor(v);
	}

	public static inline function clamp(v:Int, lo:Int, hi:Int):Int {
		return v < lo ? lo : (v > hi ? hi : v);
	}

	public static inline function fclamp(v:Float, lo:Float, hi:Float):Float {
		return v < lo ? lo : (v > hi ? hi : v);
	}

	public static inline function inRange(v:Float, lo:Float, hi:Float):Bool {
		return v >= lo && v <= hi;
	}

	public static inline function toRad(deg:Float):Float {
		return deg * Math.PI / 180;
	}

	public static inline function toDeg(rad:Float):Float {
		return rad * 180 / Math.PI;
	}

	public static function randRange(lo:Int, hi:Int, ?rnd:Void->Float):Int {
		var r = (rnd != null) ? rnd() : Seed.randVfx();
		return lo + Std.int(r * (hi - lo + 1));
	}

	public static function frandRange(lo:Float, hi:Float, ?rnd:Void->Float):Float {
		var r = (rnd != null) ? rnd() : Seed.randVfx();
		return lo + r * (hi - lo);
	}

	public static function frandRangeSym(v:Float, ?rnd:Void->Float):Float {
		var r = (rnd != null) ? rnd() : Seed.randVfx();
		return (r * 2 - 1) * v;
	}
}

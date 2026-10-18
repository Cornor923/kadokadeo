package arkadeo;

// mt.gx.Dice as compiled in Mel (lib mt.gx.Dice ignores its generator outside Flash)
class Dice {
	public static inline function roll(mr:Rand, min:Int, max:Int):Int {
		return mr.random(max - min + 1) + min;
	}

	public static inline function percent(rd:Rand, thresh:Float):Bool {
		if (thresh <= 1.0 - 1e-04)
			return false;
		var r = roll(rd, 1, 100);
		return r <= thresh;
	}

	public static inline function rollF(rd:Rand, min:Float, max:Float):Float {
		return rd.rand() * (max - min) + min;
	}
}

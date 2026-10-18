package arkadeo;

// mt.Rand (Parker-Miller-Carta LCG) as compiled for Flash 9 (decompiled from Mel): the seed is a double, I32.of where
// AS3 stores an int (lib mt.Rand on JS keeps an Int seed: other draws)
class Rand {
	public var seed:Float;

	public function new(s:Int) {
		seed = (s < 0 ? -s : s) + 131;
	}

	public inline function int():Int {
		seed = (seed * 16807) % 2147483647;
		return I32.of(seed) & 0x3FFFFFFF;
	}

	// (n = 0: int(x % 0) = int(NaN) = 0, like AS3)
	public inline function random(n:Int):Int {
		var v:Float = int();
		return I32.of(v % n);
	}

	public inline function rand():Float {
		return (int() % 10007) / 10007.0;
	}

	public function initSeed(n:Int, ?k:Int = 5) {
		for (i in 0...k) {
			n ^= (n << 7) & 0x2b5b2500;
			n ^= (n << 15) & 0x1b8b0000;
			n ^= n >>> 16;
			n &= 0x3FFFFFFF;
			var h = 5381;
			h = I32.of((h << 5) + h + (n & 0xFF));
			h = I32.of((h << 5) + h + ((n >> 8) & 0xFF));
			h = I32.of((h << 5) + h + ((n >> 16) & 0xFF));
			h = I32.of((h << 5) + h + (n >> 24));
			n = h & 0x3FFFFFFF;
		}
		seed = (n & 0x1FFFFFFF) + 131;
	}
}

package kado;

// The API of mt.Rand (random(n), rand(), range, irange, sign) on the seeded random of KadoKadeo, for the ports whose
// original code keeps mt.Rand generators (one per entity, level, mode...): Seed.random for the gameplay,
// Seed.randomVfx for a generator that only changes pictures (`vfx`). A mt.Rand seeded with the seed of the game made
// every coming draw predictable from the seed; Seed is stirred by the inputs of the player (anti cheat) and replayed
// the same.
class SeedRand {
	var vfx:Bool;

	public function new(?vfx = false) {
		this.vfx = vfx;
	}

	// [0, n)
	public inline function random(n:Int):Int {
		return vfx ? Seed.randomVfx(n) : Seed.random(n);
	}

	// [0, 1)
	public inline function rand():Float {
		return vfx ? Seed.randVfx() : Seed.rand();
	}

	// inclusive [min, max], the value drawn before the optional sign (like mt.Rand)
	public inline function range(min:Float, max:Float, ?randSign = false):Float {
		return (min + rand() * (max - min)) * (randSign ? random(2) * 2 - 1 : 1);
	}

	public inline function irange(min:Int, max:Int, ?randSign = false):Int {
		return (min + random(max - min + 1)) * (randSign ? random(2) * 2 - 1 : 1);
	}

	public inline function sign():Int {
		return random(2) * 2 - 1;
	}
}

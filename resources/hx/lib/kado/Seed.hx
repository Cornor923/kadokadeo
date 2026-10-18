package kado;

class Seed {
	static var gameplayRng:mt.Rand;
	static var vfxRng:mt.Rand;
	// the gameplay draws depend on the frame and the inputs of the player (see stir)
	static var stirEnabled:Bool = false;

	public static function init(seedHash:Int):Void {
		gameplayRng = new mt.Rand(seedHash);
		// not the gameplay sequence: the effects must not show it
		vfxRng = new mt.Rand((seedHash ^ 0x2545F491) & 0x3FFFFFFF);
	}

	// off for the daily game: every player gets the same pieces
	public static function setStirEnabled(enabled:Bool):Void {
		stirEnabled = enabled;
	}

	// ANTI CHEAT: called at the start of each frame of the game (KadoKadeoManager.updatePhysics) with the number of the
	// frame and the inputs the player changed on it (identical in the replay): a piece depends on the frame it is drawn
	// on, so the coming pieces can't be listed from the seed. 32 bit operations only: the same in every browser.
	public static function stir(frame:Int, inputs:Int):Void {
		if (!stirEnabled) {
			return;
		}
		ensureInit();
		var n = gameplayRng.getSeed() ^ mix(frame + 0x6A09E667) ^ mix(inputs);
		gameplayRng.initSeed(n);
	}

	static inline function mix(x:Int):Int {
		x ^= x << 13;
		x ^= x >>> 17;
		x ^= x << 5;
		return x;
	}

	static inline function ensureInit():Void {
		if (gameplayRng == null || vfxRng == null) {
			init(0);
		}
	}

	public static inline function rand():Float {
		return randGameplay();
	}

	public static inline function random(max:Int):Int {
		return randomGameplay(max);
	}

	public static inline function randGameplay():Float {
		ensureInit();
		return gameplayRng.rand();
	}

	public static inline function randomGameplay(max:Int):Int {
		if (max <= 0)
			return 0;
		ensureInit();
		return gameplayRng.random(max);
	}

	// the helpers of mt.Rand on the gameplay random (an original that kept mt.Rand generators): inclusive [min, max],
	// the value drawn before the optional sign
	public static inline function range(min:Float, max:Float, ?randSign = false):Float {
		return (min + rand() * (max - min)) * (randSign ? random(2) * 2 - 1 : 1);
	}

	public static inline function irange(min:Int, max:Int, ?randSign = false):Int {
		return (min + random(max - min + 1)) * (randSign ? random(2) * 2 - 1 : 1);
	}

	public static inline function sign():Int {
		return random(2) * 2 - 1;
	}

	// the same on the random of the effects
	public static inline function rangeVfx(min:Float, max:Float, ?randSign = false):Float {
		return (min + randVfx() * (max - min)) * (randSign ? randomVfx(2) * 2 - 1 : 1);
	}

	public static inline function irangeVfx(min:Int, max:Int, ?randSign = false):Int {
		return (min + randomVfx(max - min + 1)) * (randSign ? randomVfx(2) * 2 - 1 : 1);
	}

	public static inline function signVfx():Int {
		return randomVfx(2) * 2 - 1;
	}

	public static inline function randVfx():Float {
		ensureInit();
		return vfxRng.rand();
	}

	public static inline function randomVfx(max:Int):Int {
		if (max <= 0)
			return 0;
		ensureInit();
		return vfxRng.random(max);
	}
}

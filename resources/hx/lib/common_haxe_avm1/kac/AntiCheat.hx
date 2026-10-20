package common_haxe_avm1.kac;

// Mask of what the client detected during a game, sent with the run (`ac`): the server marks the run as cheated for the
// "hard" bits, and puts it in the queue of the suspicious runs for the "soft" ones (App\Settings\AntiCheatSettings,
// App\Enums\AntiCheatBit). See Integrity for the detections of a script of the page.
class AntiCheat {
	public static inline var PROTECTED_INT_CORRUPTED:Int = 0x1;
	// hard: a function of the game (prototype or static) was replaced, or an object of the game given another prototype
	public static inline var CODE_PATCHED:Int = 0x2;
	// hard: an object of the game has its own function in place of a method (the game, the manager, the replay...)
	public static inline var INSTANCE_SHADOWED:Int = 0x4;
	// soft: a display object added to the stage by a script of the page (not by the game)
	public static inline var FOREIGN_DISPLAY_OBJECT:Int = 0x10;
	// soft: a method of PIXI was replaced (PIXI is global: a way to reach the game)
	public static inline var PIXI_PATCHED:Int = 0x20;
	// soft: a function of the browser used by the game was replaced (extensions do it too)
	public static inline var NATIVE_PATCHED:Int = 0x40;
	// soft: inputs made by a script (isTrusted false: dispatchEvent) were sent to the game
	public static inline var UNTRUSTED_INPUT:Int = 0x80;
	// soft: a fake event (a Proxy...) reached the listeners of the game
	public static inline var FORGED_EVENT:Int = 0x100;
	// soft: a check could not be done (an error, no stack trace)
	public static inline var CHECK_FAILED:Int = 0x200;

	static var mask:Int = 0;
	static var seed:Int = 0x6D2B79F5;
	static var counter:Int = 0;

	public static function reset():Void {
		mask = 0;
	}

	public static function flag(code:Int):Void {
		mask |= code;
	}

	public static inline function getMask():Int {
		return mask;
	}

	public static function getPayload():Dynamic {
		return mask;
	}

	public static function nextKey():Int {
		counter++;
		seed ^= seed << 13;
		seed ^= seed >>> 17;
		seed ^= seed << 5;
		return mix(seed, counter, 0x45D9F3B);
	}

	public static inline function mix(a:Int, b:Int, c:Int):Int {
		var h = a;
		h ^= b + 0x9E3779B9 + (h << 6) + (h >>> 2);
		h ^= c + 0x85EBCA6B + (h << 6) + (h >>> 2);
		return h;
	}
}

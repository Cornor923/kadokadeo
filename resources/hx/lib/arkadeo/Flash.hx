package arkadeo;

/**
 * arkadeo: the part of the Flash Player 11 display list (AS3) the Arkadeo games (Mel, Brutal Teenage Crisis) use, over
 * PIXI, built on common_haxe_avm1.display.ASprite: every DisplayObject has an ASprite node, interpolated between two
 * steps of KadoKadeo like every sprite of the site (gameRoot.update / updateGraphics). The depths of a root are planes of
 * mt.DepthManager (DepthManager). Also the helpers of their mt libs that need the AS3 numbers (Rand, I32, Dice, Pick).
 *
 * The game sets the Flash properties (x, y in twips like Flash, scaleX, scaleY, rotation in degrees, alpha, visible); the
 * children keep the Flash order (index 0 at the bottom).
 *
 * Display: a game runs at the rate of its SWF (Mel 40 frames/s, Brutal Teenage Crisis 30) and KadoKadeo steps 32 times
 * per second, a step plays 0, 1 or 2 Flash frames. Every object shows its state one Flash frame ago, interpolated towards
 * the last one by the fraction of a Flash frame the steps are behind (display(root, frac)): the game moves by exactly the
 * same amount every step, and ASprite interpolates between two steps. An object put on the display list (or moved to
 * another parent) is shown where it is, without interpolation (snap). Each game loop:
 *   for each Flash frame: Flash.frameStart(root); <the frame of the game>; [Flash.frameEnd(root)]
 *   then Flash.display(root, <fraction>)
 */
class Flash {
	// x / y of the display objects truncated to twips (1/20 px) like Flash (the code of an Arkadeo SWF); off for a game
	// whose positions never went through a SWF (Brutal Teenage Crisis: the HTML5 port of its original)
	public static var useTwips = true;

	// Flash.frameEnd: the first move of an object put on the display list is a jump (made at (0, 0), placed by its first
	// update), and so is a move longer than `teleport` pixels (a respawn, a dash)
	public static var snapFirstMove = false;
	public static var teleport = Math.POSITIVE_INFINITY;

	// what moves is drawn at whole pixels (a game made of pixel art pictures)
	public static var roundMoving = false;

	// the settings of a game, set in its constructor after reset(), and the statics of the timelines
	public static function reset() {
		useTwips = true;
		snapFirstMove = false;
		teleport = Math.POSITIVE_INFINITY;
		roundMoving = false;
		BlurFilter.scale = 0.5;
		BlurFilter.forceQuality = 2;
		GlowFilter.style = FLASH;
		FlashGlow.maxStageScale = 1;
		BitmapData.gpuScaleMode = 1;
		MovieClip.all = [];
		Clip.reset();
	}

	// state of the previous Flash frame of every object of the display list
	public static function frameStart(root:DisplayObject) {
		root.keepPrev();
	}

	// after a Flash frame of the game: the snaps of snapFirstMove / teleport
	public static function frameEnd(root:DisplayObject) {
		root.checkJumps();
	}

	public static function display(root:DisplayObject, frac:Float) {
		root.show(frac);
	}

	// twips (1/20 px): the x / y of a Flash display object (truncated)
	public static inline function twips(v:Float):Float {
		return useTwips ? Std.int(v * 20) / 20 : v;
	}

	// Flash rotation in degrees, in ]-180, 180]
	public static function normRot(v:Float):Float {
		v = v % 360;
		if (v > 180)
			v -= 360;
		else if (v <= -180)
			v += 360;
		return v;
	}
}

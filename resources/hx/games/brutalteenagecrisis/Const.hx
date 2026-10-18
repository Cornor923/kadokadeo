package brutalteenagecrisis;

class Const {
	public static var WID = 600;
	public static var HEI = 460;

	public static var LWID = 23;
	public static var LHEI = 17;
	public static var GRID = 26;

	public static var GRAVITY = 0.07;
	public static var AUTODIFF = 30;
	public static var FRICTION = 0.85;
	// (the statics are initialised in order: FPS, below, is still undefined here and the original got NaN, so a phase
	// never ended; Game sets them again once FPS is set, as the Arkadeo HTML5 port did)
	public static var PHASE_CD = seconds(15);
	public static var PHASE_DURATION = seconds(2.5);

	public static var UID = 0;

	static var uniq_ = 0;
	public static var DP_BG = uniq_++;
	public static var DP_BG_FX = uniq_++;
	public static var DP_ENTITY = uniq_++;
	public static var DP_MOB = uniq_++;
	public static var DP_PHASE = uniq_++;
	public static var DP_FX = uniq_++;
	public static var DP_ITEM = uniq_++;
	public static var DP_HERO = uniq_++;
	public static var DP_INTERF = uniq_++;

	public static var FPS = 30;
	public static inline function seconds(sec:Float) return mt.MLib.round(FPS*sec);

	// cos / sin / atan2 can differ in the last bits between browsers: their results are rounded to 1/65536 (an exact
	// binary fraction) where they enter the state of the game, so that a replay plays the same everywhere
	public static inline function q(v:Float):Float return Math.round(v * 65536) / 65536;
}

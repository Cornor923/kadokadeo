package kado;

// Math.sin, Math.cos, Math.atan2, Math.pow, Math.acos, Math.exp and Math.log of the games are computed in plain
// JavaScript once on (resources/js/games/builds/exact-math.mjs, put in the bundles by build-games.mjs): the same
// result on every browser and processor, those of the browsers differ in the last bit and a replay diverges from its
// game. Set by ReplayManager: on for a live game, and for the replays recorded with it (version 5). A build without
// it (test harness) keeps the functions of the browser.
class ExactMath {
	public static function setEnabled(enabled:Bool):Void {
		js.Syntax.code("typeof __kadoMath != 'undefined' && __kadoMath.setExact({0})", enabled);
	}
}

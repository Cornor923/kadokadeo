package trigo;

// The texts of the game (Text of the original: mt.data.Texts on texts.<lang>.xml), the French ones (texts.fr.xml) the League
// shows. The texts of the LvUP (the orders, the tutorial) and of the Arkadeo prizes are not ported.
class Text {
	public static var combo = "Combo +1";

	public static function unicombo(o:{_c:Int}):String {
		return "UniCombo +" + o._c;
	}

	public static function rainbowcombo(o:{_c:Int}):String {
		return "RainbowCombo +" + o._c;
	}
}

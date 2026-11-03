package fafi360;

// The texts of the game (Lang = @:build(mt.data.Texts.build("texts.fr.xml")) in the original): the French texts of the
// archive (Data.TEXTS, generated from texts.fr.xml); a text with ::variables:: is a function of an object of _variables,
// like the class the macro built
class Lang {
	public static var LostBall(get, never):String;
	public static var ScoreGoal(get, never):String;
	public static var ConcedeGoal(get, never):String;
	public static var ConcedeGoalYourself(get, never):String;
	public static var TimeOut(get, never):String;
	public static var StatScore(get, never):String;
	public static var StatPass(get, never):String;
	public static var StatControl(get, never):String;

	static inline function get_LostBall() return Data.TEXTS["LostBall"];
	static inline function get_ScoreGoal() return Data.TEXTS["ScoreGoal"];
	static inline function get_ConcedeGoal() return Data.TEXTS["ConcedeGoal"];
	static inline function get_ConcedeGoalYourself() return Data.TEXTS["ConcedeGoalYourself"];
	static inline function get_TimeOut() return Data.TEXTS["TimeOut"];
	static inline function get_StatScore() return Data.TEXTS["StatScore"];
	static inline function get_StatPass() return Data.TEXTS["StatPass"];
	static inline function get_StatControl() return Data.TEXTS["StatControl"];

	public static function Score(args:{_player:Int, _opponent:Int}) return format("Score", args);

	public static function Pass(args:{_n:Int}) return format("Pass", args);

	public static function Passes(args:{_n:Int}) return format("Passes", args);

	public static function PickTime(args:{_n:Int}) return format("PickTime", args);

	// ::name:: replaced by the field _name of args (mt.data.Texts)
	static function format(id:String, args:Dynamic):String {
		var s = Data.TEXTS[id];
		for (f in Reflect.fields(args))
			s = StringTools.replace(s, "::" + f.substr(1) + "::", Std.string(Reflect.field(args, f)));
		return s;
	}
}

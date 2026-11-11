package greenwitch;

// The texts of the game (Lang = @:build(mt.data.Texts.build("texts.fr.xml")) in the original): the French texts of the
// archive (Data.TEXTS, generated from texts.fr.xml); a text with ::variables:: is a function of an object of _variables,
// like the class the macro built
class Lang {
	public static var ALL(get, never):Map<String, String>;

	static inline function get_ALL() return Data.TEXTS;

	public static var LowTurret(get, never):String;
	public static var OutOfAmmo(get, never):String;
	public static var AmmoDepleted(get, never):String;
	public static var TurretDepleted(get, never):String;
	public static var OutOfTurret(get, never):String;
	public static var AllCiviliansProgress(get, never):String;
	public static var RemainingCivilian(get, never):String;
	public static var Map(get, never):String;
	public static var SlowedDown(get, never):String;
	public static var DoorUnlocked(get, never):String;
	public static var DoorsRepaired(get, never):String;
	public static var TurretReloaded(get, never):String;
	public static var WeaponReloaded(get, never):String;

	static inline function get_LowTurret() return Data.TEXTS["LowTurret"];
	static inline function get_OutOfAmmo() return Data.TEXTS["OutOfAmmo"];
	static inline function get_AmmoDepleted() return Data.TEXTS["AmmoDepleted"];
	static inline function get_TurretDepleted() return Data.TEXTS["TurretDepleted"];
	static inline function get_OutOfTurret() return Data.TEXTS["OutOfTurret"];
	static inline function get_AllCiviliansProgress() return Data.TEXTS["AllCiviliansProgress"];
	static inline function get_RemainingCivilian() return Data.TEXTS["RemainingCivilian"];
	static inline function get_Map() return Data.TEXTS["Map"];
	static inline function get_SlowedDown() return Data.TEXTS["SlowedDown"];
	static inline function get_DoorUnlocked() return Data.TEXTS["DoorUnlocked"];
	static inline function get_DoorsRepaired() return Data.TEXTS["DoorsRepaired"];
	static inline function get_TurretReloaded() return Data.TEXTS["TurretReloaded"];
	static inline function get_WeaponReloaded() return Data.TEXTS["WeaponReloaded"];

	public static function LowAmmo(args:{_n:Int}) return format("LowAmmo", args);

	public static function AllCiviliansLeague(args:{_n:Int}) return format("AllCiviliansLeague", args);

	public static function NeedCivilians(args:{_n:Int}) return format("NeedCivilians", args);

	public static function RemainingCivilians(args:{_n:Int}) return format("RemainingCivilians", args);

	public static function LevelUp(args:{_n:Int}) return format("LevelUp", args);

	// ::n:: replaced by the field _n of args
	static function format(id:String, args:Dynamic):String {
		var s = Data.TEXTS[id];
		for (f in Reflect.fields(args))
			s = s.split("::" + f.substr(1) + "::").join(Std.string(Reflect.field(args, f)));
		return s;
	}
}

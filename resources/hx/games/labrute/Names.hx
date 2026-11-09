package labrute;

// the names of the brutes met in the arena (gameplay random: the same in the replay)
class Names {
	static var START = [
		"Gro", "Bra", "Kra", "Zor", "Mou", "Pif", "Ta", "Bou", "Gna", "Ra", "Fé", "Lu", "Tor", "Va", "Bri", "Ka", "Do", "Mi", "Zé", "Ro",
		"Bal", "Gor", "Tri", "Pou", "Gru", "Sko", "Dra", "Bob", "Kou", "Rin"
	];
	static var MIDDLE = ["", "", "", "ba", "ka", "lo", "mi", "ra", "to", "zu", "gno", "pi", "dou"];
	static var END = [
		"ff", "x", "k", "to", "ra", "dor", "nus", "bob", "mox", "rak", "lix", "nard", "zo", "ton", "gor", "us", "ette", "uche", "ok",
		"ax", "in", "ouille"
	];

	public static function random():String {
		return Rng.item(START) + Rng.item(MIDDLE) + Rng.item(END);
	}
}

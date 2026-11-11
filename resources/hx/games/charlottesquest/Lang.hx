package charlottesquest;

// the texts of texts.fr.xml (the original: a class built by mt.deepnight.TextXmlBuilder from it)
class Lang {
	public static inline function get(id:String):String {
		return Data.TEXTS.get(id);
	}
}

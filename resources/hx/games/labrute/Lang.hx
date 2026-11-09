package labrute;

import labrute.lang.*;

// The languages of the game: French, the texts of the code, and the others (lang/<Lang>.hx: the texts of the screens,
// by their French text; lang/<Lang>Data.hx: the texts of the data, by kind and key, made by build_lang.mjs). The key L
// goes to the next one, kept by the browser of the player. Only the pictures and the texts change: never the game.
// A text missing in a language: its English one (FALLBACK), else the French one.
// Another language: its two files, a line in PACKS, its flag (Ui.flag), its pictures of the skin `<name>-<lang>`.
class Lang {
	public static var LANGS:Array<String> = ["fr", "en", "de", "es", "it", "pt", "ru", "ko"];
	static var PACKS:Map<String, {texts:Map<String, String>, data:Map<String, Map<String, String>>}> = [
		"en" => {texts: En.TEXTS, data: EnData.DATA},
		"de" => {texts: De.TEXTS, data: DeData.DATA},
		"es" => {texts: Es.TEXTS, data: EsData.DATA},
		"it" => {texts: It.TEXTS, data: ItData.DATA},
		"pt" => {texts: Pt.TEXTS, data: PtData.DATA},
		"ru" => {texts: Ru.TEXTS, data: RuData.DATA},
		"ko" => {texts: Ko.TEXTS, data: KoData.DATA}
	];
	public static inline var FALLBACK = "en";
	static inline var STORAGE = "labrute-lang";

	public static var current(default, null):String = "fr";
	// one more at each change (the screens made again)
	public static var epoch(default, null):Int = 0;
	static var loaded = false;

	// the language kept by the browser (once)
	public static function load():Void {
		if (loaded)
			return;
		loaded = true;
		try {
			var saved = js.Browser.window.localStorage.getItem(STORAGE);
			if (saved != null && LANGS.indexOf(saved) >= 0)
				current = saved;
		} catch (e:Dynamic) {}
	}

	public static function next():Void {
		current = LANGS[(LANGS.indexOf(current) + 1) % LANGS.length];
		epoch++;
		try {
			js.Browser.window.localStorage.setItem(STORAGE, current);
		} catch (e:Dynamic) {}
	}

	// a text of the screens, by its French text
	public static function t(fr:String):String {
		if (current == LANGS[0])
			return fr;
		for (lang in [current, FALLBACK]) {
			var pack = PACKS.get(lang);
			var s = pack != null ? pack.texts.get(fr) : null;
			if (s != null)
				return s;
		}
		return fr;
	}

	// the same with its values: {0}, {1}... in the text
	public static function f(fr:String, values:Array<Dynamic>):String {
		var s = t(fr);
		for (i in 0...values.length)
			s = StringTools.replace(s, "{" + i + "}", Std.string(values[i]));
		return s;
	}

	// a text of the data (kind: weapon, skill, desc, effect, pet, stat, type, detail, league, label), its French one
	// without a translation
	public static function data(kind:String, key:String, fr:String):String {
		if (current == LANGS[0])
			return fr;
		for (lang in [current, FALLBACK]) {
			var pack = PACKS.get(lang);
			var map = pack != null ? pack.data.get(kind) : null;
			var s = map != null ? map.get(key) : null;
			if (s != null)
				return s;
		}
		return fr;
	}
}

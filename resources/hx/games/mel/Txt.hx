package mel;

import common_haxe_avm1.display.ASprite;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;
import mel.Fl;

typedef FontDef = {
	a:String,
	size:Float,
	chars:String,
	adv:Array<Float>,
	ascent:Float,
	descent:Float,
	leading:Float
}

/**
 * flash.text.TextField with an embedded font: the glyphs of the font of game.swf drawn as pictures (with the filters
 * of the original field baked in, Art.meta().fonts), laid out like Flash: 2 px gutter, first baseline at 2 + ascent,
 * advances of the font, lines of ascent + descent + leading. A character the font does not have is not drawn.
 * Fonts: score (galaxy 10, white: the bonus texts), big (galaxy 50: "SAUTE !"), sms (trana 24), tip (galaxy 8),
 * height (Transponder AOE 18: the height signs).
 */
class Txt extends DO {
	static var fonts:Map<String, {def:FontDef, idx:Map<String, Int>, tex:Array<Texture>}> = new Map();

	var font:{def:FontDef, idx:Map<String, Int>, tex:Array<Texture>};
	var str:String = "";
	var lines:Array<String> = [];

	// field width (alignment), "left" | "right" | "center"
	public var fieldWidth:Float = 100;
	public var align:String = "left";
	public var text(get, set):String;
	public var textWidth(default, null):Float = 0;
	public var textHeight(default, null):Float = 0;

	public function new(fontName:String) {
		super(new ASprite());
		font = getFont(fontName);
	}

	static function getFont(n:String) {
		var f = fonts.get(n);
		if (f == null) {
			var d:FontDef = Reflect.field(Art.meta().fonts, n);
			var idx = new Map();
			for (i in 0...d.chars.length)
				idx.set(d.chars.charAt(i), i);
			f = {def: d, idx: idx, tex: Tex.get(d.a)};
			fonts.set(n, f);
		}
		return f;
	}

	inline function get_text()
		return str;

	function set_text(s:String) {
		str = s == null ? "" : s;
		layout();
		return s;
	}

	public function setWidth(w:Float) {
		fieldWidth = w;
		layout();
	}

	public function setAlign(a:String) {
		align = a;
		layout();
	}

	function lineWidth(l:String):Float {
		var w = 0.0;
		for (i in 0...l.length) {
			var j = font.idx.get(l.charAt(i));
			if (j != null)
				w += font.def.adv[j];
		}
		return w;
	}

	function layout() {
		node.removeChildren();
		var d = font.def;
		lines = str.split("\r\n").join("\n").split("\r").join("\n").split("\n");
		textWidth = 0;
		for (l in lines)
			textWidth = Math.max(textWidth, lineWidth(l));
		var lh = d.ascent + d.descent + d.leading;
		textHeight = lines.length * lh - d.leading;
		var y = 2 + d.ascent;
		for (l in lines) {
			var w = lineWidth(l);
			var x = 2.0;
			if (align == "right")
				x = fieldWidth - 2 - w;
			else if (align == "center")
				x = (fieldWidth - w) * 0.5;
			for (i in 0...l.length) {
				var j = font.idx.get(l.charAt(i));
				if (j == null)
					continue;
				var s = new PixiSprite(font.tex[j]);
				s.anchor.copyFrom(font.tex[j].defaultAnchor);
				s.x = x;
				s.y = y;
				node.addChild(s);
				x += d.adv[j];
			}
			y += lh;
		}
	}
}

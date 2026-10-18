package arkadeo;

import common_haxe_avm1.display.ASprite;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.Texture;

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
 * flash.text.TextField, drawn in one of two ways:
 * - new TextField(): a PIXI.Text in a web font (the embedded font of the original is not drawn: "sans-serif"), set by
 *   defaultTextFormat; width / height are the box (they do not scale the glyphs), textWidth / textHeight its text;
 * - new TextField(<font name>), an embedded font: the glyphs of the font of game.swf drawn as pictures (with the filters
 * of the original field baked in), laid out like Flash: 2 px gutter, first baseline at 2 + ascent,
 * advances of the font, lines of ascent + descent + leading. A character the font does not have is not drawn.
 * The fonts of the game: TextField.init(() -> {<name>: FontDef}) (Mel: Art.meta().fonts, measured in its SWF).
 */
class TextField extends DisplayObject {
	static var fontSource:Void->Dynamic = null;
	static var fonts:Map<String, {def:FontDef, idx:Map<String, Int>, tex:Array<Texture>}> = new Map();

	var font:{def:FontDef, idx:Map<String, Int>, tex:Array<Texture>};
	var str:String = "";
	var lines:Array<String> = [];

	// field width (alignment), "left" | "right" | "center"
	public var fieldWidth:Float = 100;
	public var align:String = "left";
	public var text(get, set):String;
	public var textWidth(get, never):Float;
	public var textHeight(get, never):Float;

	var tw:Float = 0;
	var th:Float = 0;

	// the PIXI.Text (no embedded font) and its box
	var pixiText:pixi.core.text.Text = null;

	public var defaultTextFormat(default, set):TextFormat = null;
	public var embedFonts:Bool = false;
	public var multiline:Bool = false;
	public var wordWrap:Bool = false;
	public var selectable:Bool = true;
	public var autoSize:String = "none";

	public static function init(source:Void->Dynamic) {
		fontSource = source;
		fonts = new Map();
	}

	public function new(?fontName:String) {
		super(new Node());
		if (fontName != null) {
			font = getFont(fontName);
		} else {
			pixiText = new pixi.core.text.Text("");
			node.addChild(pixiText);
		}
	}

	static function getFont(n:String) {
		var f = fonts.get(n);
		if (f == null) {
			var d:FontDef = Reflect.field(fontSource(), n);
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
		if (pixiText != null)
			pixiText.text = str;
		else
			layout();
		return s;
	}

	public var htmlText(get, set):String;

	inline function get_htmlText()
		return str;

	// (the tags are removed)
	function set_htmlText(v:String) {
		text = ~/<[^>]*>/g.replace(v, "");
		return v;
	}

	public function appendText(s:String) {
		text = str + s;
	}

	function set_defaultTextFormat(f:TextFormat):TextFormat {
		defaultTextFormat = f;
		if (pixiText != null) {
			var st:Dynamic = pixiText.style;
			if (f.size != null)
				st.fontSize = f.size;
			if (f.color != null)
				st.fill = f.color;
			if (f.font != null)
				st.fontFamily = "sans-serif";
			if (f.bold == true)
				st.fontWeight = "bold";
			if (f.align != null)
				st.align = f.align;
		}
		return f;
	}

	function get_textWidth():Float {
		return pixiText != null ? (untyped pixiText.getLocalBounds().width : Float) : tw;
	}

	function get_textHeight():Float {
		return pixiText != null ? (untyped pixiText.getLocalBounds().height : Float) : th;
	}

	override public function contentRect():Rectangle {
		return new Rectangle(0, 0, textWidth, textHeight);
	}

	// the box (Flash: the glyphs keep their size)
	var boxW:Float = 100;
	var boxH:Float = 100;

	override function set_width(v:Float):Float {
		boxW = v;
		return v;
	}

	override function set_height(v:Float):Float {
		boxH = v;
		return v;
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
		tw = 0;
		for (l in lines)
			tw = Math.max(tw, lineWidth(l));
		var lh = d.ascent + d.descent + d.leading;
		th = lines.length * lh - d.leading;
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

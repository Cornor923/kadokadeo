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
	leading:Float,
	// a glow of the original fields drawn once into pictures (the anim `o`, one per glyph, laid under every glyph):
	// GlowFilter(glow.color, glow.alpha, glow.blurX, glow.blurY, glow.strength) given as the only filter of a field
	?o:String,
	?glow:{color:Int, alpha:Float, blurX:Float, blurY:Float, strength:Float}
}

/**
 * flash.text.TextField, drawn in one of two ways:
 * - new TextField(): a PIXI.Text in a web font (the embedded font of the original is not drawn: "sans-serif"), set by
 *   defaultTextFormat; width / height are the box (they do not scale the glyphs), textWidth / textHeight its text;
 * - new TextField(<font name>), an embedded font: the glyphs of the font of game.swf drawn as pictures (with the filters
 * of the original field baked in), laid out like Flash: 2 px gutter, first baseline at 2 + ascent,
 * advances of the font, lines of ascent + descent + leading. A character the font does not have is not drawn.
 * The fonts of the game: TextField.init(() -> {<name>: FontDef}) (Mel: Art.meta().fonts, measured in its SWF).
 * A font may bring the pictures of a glow of its fields (FontDef.o / glow: Green Witch's black outline of every text):
 * that glow set as the filters of a field is drawn by them under the glyphs, without a filter pass.
 */
class TextField extends DisplayObject {
	static var fontSource:Void->Dynamic = null;
	static var fonts:Map<String, {def:FontDef, idx:Map<String, Int>, tex:Array<Texture>, otex:Array<Texture>}> = new Map();

	var font:{def:FontDef, idx:Map<String, Int>, tex:Array<Texture>, otex:Array<Texture>};
	// the glow of the font given as the filters of the field: drawn by the pictures of the font (FontDef.o)
	var outlined:Bool = false;
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

	// the colour of the glyphs of an embedded font (white pictures tinted): textColor, or the color of defaultTextFormat; the
	// <font color="#rrggbb"> runs of htmlText colour their characters
	public var textColor(get, set):Int;

	var color:Int = 0xFFFFFF;
	var runs:Array<Null<Int>> = null;

	inline function get_textColor()
		return color;

	function set_textColor(c:Int) {
		color = c;
		runs = null;
		if (pixiText != null)
			(pixiText.style : Dynamic).fill = c;
		else
			layout();
		return c;
	}

	// (the format of the whole text: its colour)
	public function getTextFormat():TextFormat {
		var f = new TextFormat();
		if (defaultTextFormat != null) {
			f.font = defaultTextFormat.font;
			f.size = defaultTextFormat.size;
			f.bold = defaultTextFormat.bold;
			f.align = defaultTextFormat.align;
		}
		f.color = color;
		return f;
	}

	public function setTextFormat(f:TextFormat) {
		if (f.color != null)
			textColor = f.color;
	}

	// the box of the field (Flash's bounds: Lib.flatten)
	public function boxRect():Rectangle {
		return new Rectangle(0, 0, Math.max(boxW, textWidth + 4), Math.max(boxH, textHeight + 4));
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
			f = {def: d, idx: idx, tex: Tex.get(d.a), otex: d.o != null ? Tex.get(d.o) : null};
			fonts.set(n, f);
		}
		return f;
	}

	inline function get_text()
		return str;

	function set_text(s:String) {
		str = s == null ? "" : s;
		runs = null;
		if (pixiText != null)
			pixiText.text = str;
		else
			layout();
		return s;
	}

	public var htmlText(get, set):String;

	inline function get_htmlText()
		return str;

	// (the tags are removed, the colours of <font color> kept for the embedded fonts)
	function set_htmlText(v:String) {
		var plain = new StringBuf();
		var cols:Array<Null<Int>> = [];
		var stack:Array<Null<Int>> = [];
		var cur:Null<Int> = null;
		var tag = ~/^<(\/?)([a-zA-Z]+)([^>]*)>/;
		var colRe = ~/color\s*=\s*['"]#([0-9a-fA-F]{6})['"]/;
		var i = 0;
		while (i < v.length) {
			if (v.charAt(i) == "<" && tag.match(v.substr(i))) {
				if (tag.matched(2).toLowerCase() == "font") {
					if (tag.matched(1) == "/")
						cur = stack.length > 0 ? stack.pop() : null;
					else {
						stack.push(cur);
						if (colRe.match(tag.matched(3)))
							cur = Std.parseInt("0x" + colRe.matched(1));
					}
				}
				i += tag.matched(0).length;
				continue;
			}
			plain.add(v.charAt(i));
			cols.push(cur);
			i++;
		}
		text = plain.toString();
		if (pixiText == null && cols.filter(c -> c != null).length > 0) {
			runs = cols;
			layout();
		}
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
		}
		if (f.color != null)
			color = f.color;
		if (pixiText != null) {
			var st:Dynamic = pixiText.style;
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

	// the colour of a glyph through the multipliers of the colour transform of the field (an embedded font: Trigo's combo
	// number darkened by the timeline of its box, arkadeo.Clip.attach); with colour offsets the colour matrix of
	// DisplayObject draws the whole transform
	function tintOf(c:Int):Int {
		if (ct == null || ct.redOffset != 0 || ct.greenOffset != 0 || ct.blueOffset != 0)
			return c;
		var m = ct.tint();
		var r = Math.round(((c >> 16) & 0xFF) * ((m >> 16) & 0xFF) / 255);
		var g = Math.round(((c >> 8) & 0xFF) * ((m >> 8) & 0xFF) / 255);
		var b = Math.round((c & 0xFF) * (m & 0xFF) / 255);
		return (r << 16) | (g << 8) | b;
	}

	override function applyColour() {
		super.applyColour();
		if (pixiText == null)
			layout();
	}

	// (the glow of the font: no PIXI filter, the pictures of the outline)
	override function set_filters(f:Array<BitmapFilter>) {
		var was = outlined;
		outlined = font != null && font.otex != null && f != null && f.length == 1 && isFontGlow(f[0]);
		super.set_filters(f);
		if (outlined != was)
			layout();
		return f;
	}

	override function pixiFilters() {
		if (!outlined) {
			super.pixiFilters();
			return;
		}
		var saved = flts;
		flts = [];
		super.pixiFilters();
		flts = saved;
	}

	function isFontGlow(f:BitmapFilter):Bool {
		var g = Std.downcast(f, GlowFilter);
		var d = font.def.glow;
		return g != null && d != null && !g.inner && !g.knockout && g.color == d.color && g.alpha == d.alpha && g.blurX == d.blurX && g.blurY == d.blurY
			&& g.strength == d.strength;
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
		if (outlined)
			placeGlyphs(lh, true);
		placeGlyphs(lh, false);
	}

	// the glyphs of the lines, or the pictures of their outline (under all the glyphs)
	function placeGlyphs(lh:Float, outline:Bool) {
		var d = font.def;
		var y = 2 + d.ascent;
		var ci = 0;
		// (added in one call: the anti-cheat of KadoKadeo reads a stack trace by addChild of raw PIXI objects)
		var glyphs:Array<Dynamic> = [];
		for (l in lines) {
			var w = lineWidth(l);
			var x = 2.0;
			if (align == "right")
				x = fieldWidth - 2 - w;
			else if (align == "center")
				x = (fieldWidth - w) * 0.5;
			for (i in 0...l.length) {
				var j = font.idx.get(l.charAt(i));
				var rc = runs != null ? runs[ci + i] : null;
				if (j == null)
					continue;
				var t = outline ? font.otex[j] : font.tex[j];
				var s = new PixiSprite(t);
				if (!outline)
					s.tint = tintOf(rc != null ? rc : color);
				s.anchor.copyFrom(t.defaultAnchor);
				s.x = x;
				s.y = y;
				glyphs.push(s);
				x += d.adv[j];
			}
			ci += l.length + 1;
			y += lh;
		}
		if (glyphs.length > 0)
			untyped node.addChild.apply(node, glyphs);
	}
}

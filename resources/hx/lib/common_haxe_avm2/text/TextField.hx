package common_haxe_avm2.text;

// flash.text.TextField on PIXI.Text (the embedded "def" font -> a web font
// instead). `text` comes from PIXI.Text.
class TextField extends pixi.core.text.Text {
	public var defaultTextFormat(default, set):TextFormat;
	public var embedFonts:Bool = false;
	public var multiline:Bool = false;
	public var wordWrap:Bool = false;
	public var selectable:Bool = true;
	public var autoSize:String = "none";

	public function new() {
		super("");
	}

	public var htmlText(get, set):String;
	inline function get_htmlText():String return this.text;
	function set_htmlText(v:String):String {
		// the HTML tags are removed (roughly)
		var re = ~/<[^>]*>/g;
		this.text = re.replace(v, "");
		// Flash: width / height are the box, they do NOT scale the glyphs; PIXI.Text scales the
		// glyphs with width: the scale set before the text is cancelled (tf.width = 300 on an empty text)
		scale.set(1, 1);
		return v;
	}

	function set_defaultTextFormat(f:TextFormat):TextFormat {
		defaultTextFormat = f;
		var st:Dynamic = this.style;
		if (f.size != null) st.fontSize = f.size;
		if (f.color != null) st.fill = f.color;
		if (f.font != null) st.fontFamily = "sans-serif"; // embedded font -> a web font instead
		if (f.bold == true) st.fontWeight = "bold";
		if (f.align != null) st.align = f.align;
		return f;
	}

	public function appendText(s:String):Void {
		this.text += s;
	}

	// textWidth / textHeight: size of the content (local bounds, not scaled), not the box
	public var textWidth(get, never):Float;
	inline function get_textWidth():Float return untyped this.getLocalBounds().width;
	public var textHeight(get, never):Float;
	inline function get_textHeight():Float return untyped this.getLocalBounds().height;

	public var mouseEnabled(get, set):Bool;
	inline function get_mouseEnabled():Bool return interactive;
	inline function set_mouseEnabled(v:Bool):Bool { interactive = v; return v; }

	// Flash names (PIXI.Text does not extend our flash.display.Sprite)
	public var scaleX(get, set):Float;
	inline function get_scaleX():Float return scale.x;
	inline function set_scaleX(v:Float):Float { scale.x = v; return v; }

	public var scaleY(get, set):Float;
	inline function get_scaleY():Float return scale.y;
	inline function set_scaleY(v:Float):Float { scale.y = v; return v; }
}

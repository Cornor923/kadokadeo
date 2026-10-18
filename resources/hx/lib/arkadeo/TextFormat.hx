package arkadeo;

// flash.text.TextFormat (a value)
class TextFormat {
	public var font:String;
	public var size:Null<Int>;
	public var color:Null<Int>;
	public var bold:Null<Bool>;
	public var italic:Null<Bool>;
	public var underline:Null<Bool>;
	public var align:String;
	public var leading:Null<Int>;
	public var letterSpacing:Null<Float>;

	public function new(?font:String, ?size:Int, ?color:Int, ?bold:Bool, ?italic:Bool, ?underline:Bool, ?url:String, ?target:String,
			?align:String) {
		this.font = font;
		this.size = size;
		this.color = color;
		this.bold = bold;
		this.italic = italic;
		this.underline = underline;
		this.align = align;
	}
}

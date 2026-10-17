package common_haxe_avm2.geom;

// flash.geom.ColorTransform (a value): keeps the factors; they are turned into PIXI
// (tint / alpha) where it is used.
class ColorTransform {
	public var redMultiplier:Float;
	public var greenMultiplier:Float;
	public var blueMultiplier:Float;
	public var alphaMultiplier:Float;
	public var redOffset:Float;
	public var greenOffset:Float;
	public var blueOffset:Float;
	public var alphaOffset:Float;

	public function new(?redMultiplier:Float = 1, ?greenMultiplier:Float = 1, ?blueMultiplier:Float = 1, ?alphaMultiplier:Float = 1,
			?redOffset:Float = 0, ?greenOffset:Float = 0, ?blueOffset:Float = 0, ?alphaOffset:Float = 0) {
		this.redMultiplier = redMultiplier;
		this.greenMultiplier = greenMultiplier;
		this.blueMultiplier = blueMultiplier;
		this.alphaMultiplier = alphaMultiplier;
		this.redOffset = redOffset;
		this.greenOffset = greenOffset;
		this.blueOffset = blueOffset;
		this.alphaOffset = alphaOffset;
	}

	// color = the RGB tint
	public var color(get, set):Int;
	inline function get_color():Int {
		return (Std.int(redOffset) << 16) | (Std.int(greenOffset) << 8) | Std.int(blueOffset);
	}
	inline function set_color(v:Int):Int {
		redOffset = (v >> 16) & 0xFF;
		greenOffset = (v >> 8) & 0xFF;
		blueOffset = v & 0xFF;
		redMultiplier = greenMultiplier = blueMultiplier = 0;
		return v;
	}
}

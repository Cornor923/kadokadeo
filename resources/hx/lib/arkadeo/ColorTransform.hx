package arkadeo;

// flash.geom.ColorTransform (with the ofs / mul / rst helpers of mt.gx)
class ColorTransform {
	public var redMultiplier:Float;
	public var greenMultiplier:Float;
	public var blueMultiplier:Float;
	public var alphaMultiplier:Float;
	public var redOffset:Float;
	public var greenOffset:Float;
	public var blueOffset:Float;
	public var alphaOffset:Float;

	public function new(redMultiplier:Float = 1, greenMultiplier:Float = 1, blueMultiplier:Float = 1, alphaMultiplier:Float = 1,
			redOffset:Float = 0, greenOffset:Float = 0, blueOffset:Float = 0, alphaOffset:Float = 0) {
		this.redMultiplier = redMultiplier;
		this.greenMultiplier = greenMultiplier;
		this.blueMultiplier = blueMultiplier;
		this.alphaMultiplier = alphaMultiplier;
		this.redOffset = redOffset;
		this.greenOffset = greenOffset;
		this.blueOffset = blueOffset;
		this.alphaOffset = alphaOffset;
	}

	// the colour of a Flash ColorTransform: all of it as offsets
	public var color(get, set):Int;

	function get_color():Int {
		return (Std.int(redOffset) << 16) | (Std.int(greenOffset) << 8) | Std.int(blueOffset);
	}

	function set_color(v:Int):Int {
		redOffset = (v >> 16) & 0xFF;
		greenOffset = (v >> 8) & 0xFF;
		blueOffset = v & 0xFF;
		redMultiplier = greenMultiplier = blueMultiplier = 0;
		return v;
	}

	public function ofs(r:Float = 0, g:Float = 0, b:Float = 0, a:Float = 0):ColorTransform {
		redOffset = r;
		greenOffset = g;
		blueOffset = b;
		alphaOffset = a;
		return this;
	}

	public function mul(r:Float = 1, g:Float = 1, b:Float = 1, a:Float = 1):ColorTransform {
		redMultiplier = r;
		greenMultiplier = g;
		blueMultiplier = b;
		alphaMultiplier = a;
		return this;
	}

	public function rst():ColorTransform {
		ofs();
		mul();
		return this;
	}

	public function clone():ColorTransform {
		var c = new ColorTransform();
		c.redMultiplier = redMultiplier;
		c.greenMultiplier = greenMultiplier;
		c.blueMultiplier = blueMultiplier;
		c.alphaMultiplier = alphaMultiplier;
		c.redOffset = redOffset;
		c.greenOffset = greenOffset;
		c.blueOffset = blueOffset;
		c.alphaOffset = alphaOffset;
		return c;
	}

	// this transform applied after `inner` (a picture drawn with `inner`, then given this one)
	public function after(inner:ColorTransform):ColorTransform {
		var c = new ColorTransform();
		c.redMultiplier = inner.redMultiplier * redMultiplier;
		c.greenMultiplier = inner.greenMultiplier * greenMultiplier;
		c.blueMultiplier = inner.blueMultiplier * blueMultiplier;
		c.alphaMultiplier = inner.alphaMultiplier * alphaMultiplier;
		c.redOffset = inner.redOffset * redMultiplier + redOffset;
		c.greenOffset = inner.greenOffset * greenMultiplier + greenOffset;
		c.blueOffset = inner.blueOffset * blueMultiplier + blueOffset;
		c.alphaOffset = inner.alphaOffset * alphaMultiplier + alphaOffset;
		return c;
	}

	// multiplied colour 0xRRGGBB (tint) and added colour 0xRRGGBB
	public function tint():Int {
		return (ch(redMultiplier * 255) << 16) | (ch(greenMultiplier * 255) << 8) | ch(blueMultiplier * 255);
	}

	public function add():Int {
		return (ch(redOffset) << 16) | (ch(greenOffset) << 8) | ch(blueOffset);
	}

	public function isIdentity():Bool {
		return redMultiplier == 1 && greenMultiplier == 1 && blueMultiplier == 1 && redOffset == 0 && greenOffset == 0 && blueOffset == 0;
	}

	static inline function ch(v:Float):Int {
		var i = Math.round(v);
		return i < 0 ? 0 : (i > 255 ? 255 : i);
	}
}

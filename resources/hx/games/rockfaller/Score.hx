package rockfaller;

import pixi.core.Pixi.BlendModes;

// gfx.Score: the points of a destroyed gem, in the font of the original (Alba 14 px, white, centred) with "pts" under
// them, added to the picture (BlendMode.ADD). Glyphs and layout measured in gfx.swf (Data).
class Score extends ASprite {
	public function new(value:Int) {
		super();
		var s = Std.string(value);
		var w = 0.0;
		for (i in 0...s.length)
			w += Data.SCORE_ADVANCES[s.charCodeAt(i) - "0".code];
		// (whole pixels: sharp glyphs)
		var x:Float = Math.round(Data.SCORE_CX - w / 2);
		for (i in 0...s.length) {
			var d = s.charCodeAt(i) - "0".code;
			add("scoreDigit", d + 1, x, Math.round(Data.SCORE_BASELINE));
			x += Data.SCORE_ADVANCES[d];
		}
		add("scorePts", 1, Math.round(Data.SCORE_PTS_X), Math.round(Data.SCORE_PTS_Y));
	}

	function add(name:String, frame:Int, x:Float, y:Float):Void {
		var g = new ASprite(name);
		g.gotoAndStop(frame);
		g._x = Math.round(x);
		g._y = y;
		g.blendMode = BlendModes.ADD;
		addChild(g);
	}
}

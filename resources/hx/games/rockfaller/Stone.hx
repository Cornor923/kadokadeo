package rockfaller;

// a stone: a gem (id 0-3, clips G0..G3: frame 1 still, the next ones the shine) or the black rock (id >= 10, clip
// Rock, taken by the tubes). The clip is made again when the id changes (the frames of gfx.Stone in the original).
// No prize token in KadoKadeo (the _pk of the original stays hidden).
class Stone {
	public static inline var POINTS = 100;

	public var mc:ASprite;
	public var id:Int;
	public var isNew:Bool = false;

	var curAnim:String;

	public function new() {
		draw();
	}

	public function draw():Void {
		setId(Game.me.rand(getMaxId()));
	}

	public static inline function getMaxId():Int {
		return 4;
	}

	public function setId(i:Int):Void {
		id = i;
		var anim = i >= 10 ? "Rock" : "G" + i;
		if (mc == null || curAnim != anim) {
			// (a clip of the colour: put where the old one was)
			var old = mc;
			mc = new ASprite(anim);
			Game.me.layerStones.addChild(mc);
			if (old != null) {
				mc._x = old._x;
				mc._y = old._y;
				old.removeMovieClip();
			}
			curAnim = anim;
		}
		mc.gotoAndStop(1);
	}

	// the shine of the crystal (_stone.gotoAndPlay(1) of the original): plays the clip once
	public function shine():Void {
		if (id >= 10 || mc == null)
			return;
		mc.loop = false;
		mc.gotoAndPlay(1);
	}

	public function isStone():Bool {
		return id >= 10;
	}

	// landed (Slot.fall)
	public function breakIt():Void {
		isNew = false;
	}

	public function getPoints():Int {
		return POINTS;
	}

	public function kill():Void {
		if (mc != null)
			mc.removeMovieClip();
	}
}

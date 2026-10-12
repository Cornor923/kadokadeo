package aquasplash;

import pixi.core.Pixi.BlendModes;

/**
 * flame (sprite 99, the bomb: 29 frames, removeMovieClip() on frame 30). Most of its children are drawn "add" over the
 * board (the disc, the rings, the sparks), the disc fades "screen" at the end, the flames in the middle are drawn
 * normally: one picture per run of depths of a blend (Data: flameS, flameA, flameN, flameB), stacked here with the
 * blend, playing together.
 */
class Flame extends MC {
	var layers:Array<MC>;

	public function new() {
		super();
		_totalframes = 29;
		playing = true;
		removeAt = 30;
		layers = [for (anim in ["flameS", "flameA", "flameN", "flameB"]) attach(new MC(anim))];
		layers[0].spr.blendMode = BlendModes.SCREEN;
		layers[1].setAdd();
		layers[3].setAdd();
	}

	override function onFrame():Void {
		for (l in layers)
			l.gotoAndStop(_currentframe);
	}
}

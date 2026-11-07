package trigo.fx;

import arkadeo.Clip;

// plays a clip frame by frame (gotoAndStop), from its current frame to its last one (the IntIter of the original:
// min...max, max not played)
class Play extends mt.fx.Fx {
	var frames:IntIterator;
	var mc:Clip;

	public function new(mc:Clip, ?frames:IntIterator, ?untilLabel:String) {
		super();
		if (mc == null)
			throw "mc null";
		this.mc = mc;
		if (frames == null) {
			if (untilLabel == null) {
				frames = new IntIterator(mc.currentFrame, mc.totalFrames);
			} else {
				frames = new IntIterator(mc.currentFrame, getLabelFrame(untilLabel));
			}
		}
		this.frames = frames;
	}

	function getLabelFrame(label:String) {
		for (l in mc.labels())
			if (l.name == label)
				return l.frame;
		throw "Label not found: " + label;
	}

	override function update() {
		if (frames.hasNext())
			mc.gotoAndStop(frames.next());
		else
			kill();
	}
}

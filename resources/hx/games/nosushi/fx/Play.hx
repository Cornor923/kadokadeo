package nosushi.fx;

import arkadeo.Clip;

// plays a clip frame by frame (gotoAndStop), its frames as an IntIterator (min...max: max not played)
class Play extends mt.fx.Fx {
	var frames:IntIterator;
	var mc:Clip;

	public var startFrame:Null<Int>;
	public var endFrame:Null<Int>;

	public function new(mc:Clip, ?frames:IntIterator, ?untilLabel:String) {
		super();
		if (mc == null)
			throw "mc null";
		this.mc = mc;
		if (frames == null) {
			startFrame = mc.currentFrame;
			endFrame = untilLabel == null ? mc.totalFrames : getLabelFrame(untilLabel);
			frames = new IntIterator(startFrame, endFrame);
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

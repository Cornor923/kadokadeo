package arkadeo;

// flash.display.MovieClip of the library: a Clip (timeline of the SWF)
class MovieClip extends DisplayObject {
	// every MovieClip created advances its timeline, on the display list or not (AS3)
	public static var all:Array<MovieClip> = [];

	public var clip(default, null):Clip;

	public function new(name:String) {
		clip = new Clip(name);
		super(clip);
		all.push(this);
	}

	// no more timeline (the clip is not used any more)
	public function dispose() {
		all.remove(this);
	}

	public static function tickAll() {
		for (m in all.copy())
			m.clip.tick();
	}

	// mt.gx.as.Lib.stopAllAnimation(root): every MovieClip of the display list stops (nested ones too)
	public static function stopAllIn(root:DisplayObject) {
		function walk(o:DisplayObject) {
			var m = Std.downcast(o, MovieClip);
			if (m != null)
				m.clip.stopAll();
			var c = Std.downcast(o, DisplayObjectContainer);
			if (c != null)
				for (k in c.children)
					walk(k);
		}
		walk(root);
	}

	override function nodeScale():Float {
		return clip.baseScale;
	}

	public var smc(get, never):Clip;

	inline function get_smc()
		return clip.getClip("smc");

	public inline function getClip(n:String):Clip
		return clip.getClip(n);

	public var currentFrame(get, never):Int;
	public var totalFrames(get, never):Int;
	public var currentLabel(get, never):String;
	public var currentFrameLabel(get, never):String;
	public var isPlaying(get, never):Bool;

	inline function get_currentFrame()
		return clip.currentFrame;

	inline function get_totalFrames()
		return clip.totalFrames;

	inline function get_currentLabel()
		return clip.currentLabel;

	inline function get_currentFrameLabel()
		return clip.currentFrameLabel;

	inline function get_isPlaying()
		return clip.playing();

	public inline function gotoAndStop(f:Dynamic)
		clip.gotoAndStop(f);

	public inline function gotoAndPlay(f:Dynamic)
		clip.gotoAndPlay(f);

	public inline function stop()
		clip.stop();

	public inline function play()
		clip.play();

	public inline function nextFrame()
		clip.nextFrame();

	public inline function prevFrame()
		clip.prevFrame();

	override function applyColour() {
		if (ct == null)
			clip.setColour(0xFFFFFF, 0);
		else
			clip.setColour(ct.tint(), ct.add());
	}
}

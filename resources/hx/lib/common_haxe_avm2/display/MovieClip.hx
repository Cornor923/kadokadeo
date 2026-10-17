package common_haxe_avm2.display;

// flash.display.MovieClip: a Sprite, without a timeline (the timeline methods do nothing).
class MovieClip extends Sprite {
	public var currentFrame:Int = 1;
	public var totalFrames:Int = 1;

	public function new() {
		super();
	}

	public function gotoAndStop(frame:Dynamic):Void {}
	public function gotoAndPlay(frame:Dynamic):Void {}
	public function stop():Void {}
	public function play():Void {}
}

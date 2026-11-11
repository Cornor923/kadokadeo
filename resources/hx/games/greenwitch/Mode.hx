package greenwitch;

class Mode {
	static var ALL : Array<Mode> = new Array();

	// (a new game: the modes of the previous one forgotten)
	public static function reset() {
		ALL = new Array();
	}
	
	var paused				: Bool;
	public var rendering	: Bool;
	public var root			: Sprite;
	public var tw			: mt.deepnight.Tweenie;
	
	public function new() {
		paused = false;
		rendering = true;
		tw = new mt.deepnight.Tweenie();
		ALL.push(this);
		root = new Sprite();
	}

	public function destroy() {
	}
	
	public function pause() {
		paused = true;
	}
	
	public function resume() {
		paused = false;
	}
	
	public static inline function updateAll(?render=true) {
		for(m in ALL) {
			m.rendering = render;
			if( !m.paused )
				m.update();
		}
	}
	
	public function update() {
		tw.update();
	}
}

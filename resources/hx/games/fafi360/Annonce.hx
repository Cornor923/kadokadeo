package fafi360;

// lib.Annonce of the SWF (the announce of a goal, of a lost ball, of the end): its _bg (Scrollstripe) and _illu
// (Scroll_illu: its _sub is the picture of the announce) clips, and between them the _field text field (Volter
// (Goldfish) 36, placed and coloured as in the SWF: Data.ANNONCE_*). A text field of a clip is laid out by the game. Its own
// timeline (70 frames) only places these three children on its first frame.
class Annonce extends Sprite {
	public var _bg		: MovieClip;
	public var _field	: TextField;
	public var _illu	: MovieClip;

	public function new() {
		super();
		_bg = new MovieClip("Scrollstripe");
		addChild(_bg);

		var f = new TextFormat("volter", 36, Data.ANNONCE_COLOR);
		_field = new TextField("volter");
		_field.defaultTextFormat = f;
		_field.x = Data.ANNONCE_X;
		_field.y = Data.ANNONCE_Y;
		_field.width = Data.ANNONCE_W;
		_field.height = Data.ANNONCE_H;
		addChild(_field);

		_illu = new MovieClip("Scroll_illu");
		addChild(_illu);
	}

	// (the timeline of lib.Annonce: nothing changes on its other frames)
	public function play() {}

	// its clips stop ticking (MovieClip.all)
	public function dispose() {
		_bg.dispose();
		_illu.dispose();
	}
}

package mel;

import mel.Lib;

// VScroller.hx of the original: the planes of the background scrolled by pages of Lib.h() pixels at a fraction of the
// scroll of the view (parallax), each page showing a frame of a clip (gfx.Plan3, gfx.Plan2) chosen from the seed
class VScroller {
	public var start:Int;
	public var pageSize:Int;
	public var curScroll:Int;
	public var curPage:Int;

	public var draw:Array<Int>;

	public var game(get, null):Game;

	function get_game()
		return Game.me;

	public function new(start:Int, pageSize:Int) {
		this.start = start;
		this.pageSize = pageSize;
		draw = [-1, 0];
	}

	public function refresh(scroll:Float) {
		if (scroll < start)
			scroll = start;

		curPage = Std.int((scroll + start) / pageSize + 1);

		for (i in draw)
			if (i != curPage && i != curPage + 1 && i != curPage + 2)
				hidePage(i);

		draw[0] = curPage;
		draw[1] = curPage + 1;
		draw[2] = curPage + 2;

		drawPage(curPage);
		drawPage(curPage + 1);
		drawPage(curPage + 2);

		curScroll = Std.int(scroll + 0.5);
	}

	public function getPageScroll(i:Int) {
		return start + i * pageSize;
	}

	public function hidePage(i:Int) {}

	public function drawPage(i:Int) {}
}

class KeyedBitmap extends Bmp {
	public var key:Null<Int>; // key is the num of the page regarded

	public function new() {
		super();
	}
}

class ClipScroller extends VScroller {
	// frames: the flattened pictures of the clip and the readers showing them
	public var bmps:Map<Int, {k:Int, anim:String, readers:List<KeyedBitmap>}>;
	public var heads:Pool<KeyedBitmap>;
	public var seed:Int;

	var nframes:Int;

	public function new(key:String) {
		super(-Lib.h(), Lib.h());
		heads = new Pool<KeyedBitmap>(() -> new KeyedBitmap());
		bmps = new Map();
		var frames:Array<Dynamic> = Reflect.field(Art.meta().planes, key);
		nframes = frames.length;
		for (i in 1...nframes + 1)
			bmps.set(i, {k: i, anim: key + i, readers: new List()});
	}

	function getFrame(i:Int) {
		return bmps.get(1 + new MRand(Std.int((seed * Game.getSeed() * (i * 123456743)) ^ 0xdeadbeef)).random(nframes));
	}

	override public function hidePage(i:Int) {
		super.hidePage(i);
		var f = getFrame(i);
		for (bmp in f.readers) {
			if (bmp.key == i) {
				bmp.visible = false;
				f.readers.remove(bmp);
				bmp.key = null;
				bmp.detach();
				heads.destroy(bmp);
			}
		}
	}

	function viewToScroll(f:Float):Float {
		return f * 1;
	}

	public function update() {
		super.refresh(viewToScroll(game.view.y));
	}

	function scrollY(i:Int):Float {
		return viewToScroll(game.view.y) - getPageScroll(i);
	}

	override public function drawPage(i:Int) {
		super.drawPage(i);
		var f = getFrame(i);
		for (rd in f.readers)
			if (rd.key == i) {
				rd.y = scrollY(i);
				rd.visible = true;
				return;
			}

		var rd = heads.create();
		rd.key = i;
		f.readers.add(rd);
		rd.setAnim(f.anim);
		rd.y = scrollY(i);
		rd.visible = true;
		addReader(rd);
		rd.snap();
	}

	function addReader(rd:DO) {
		throw "implement me";
	}

	public function getMaxIndex():Null<Int> {
		var n:Null<Int> = null;
		for (r in heads.getUsed()) {
			if (r.parent == null)
				continue;
			var idx = r.parent.getChildIndex(r);
			if (n == null)
				n = idx;
			else if (idx > n)
				n = idx;
		}
		return n;
	}
}

class P3Scroller extends ClipScroller {
	public function new() {
		super("plan3");
		seed = 101;
	}

	override function viewToScroll(f:Float):Float
		return f * 0.05;

	override function addReader(rd:DO) {
		game.addChild(rd);
		game.setChildIndex(rd, game.level.p3index);
	}
}

class P2Scroller extends ClipScroller {
	public function new() {
		super("plan2");
		seed = 101101;
	}

	override function viewToScroll(f:Float):Float
		return f * 0.15;

	override function addReader(rd:DO) {
		game.addChild(rd);
		var m = game.level.p3.getMaxIndex();
		game.setChildIndex(rd, (m == null ? 0 : m) + 1);
	}
}

class P2BScroller extends P2Scroller {
	public function new() {
		super();
		seed = 0x101101de;
	}

	override function viewToScroll(f:Float):Float
		return f * 0.10;

	override function addReader(rd:DO) {
		rd.scaleX = -1;
		rd.x = Lib.w();
		game.addChild(rd);
		var m = game.level.p2.getMaxIndex();
		game.setChildIndex(rd, (m == null ? 0 : m) + 1);
	}
}

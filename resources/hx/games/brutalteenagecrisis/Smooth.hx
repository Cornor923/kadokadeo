package brutalteenagecrisis;

import pixi.core.display.Container;
import pixi.core.display.DisplayObject;

private class Track {
	public var f0x:Float; // the position at the previous frame of the game
	public var f0y:Float;
	public var f1x:Float; // at the last frame of the game
	public var f1y:Float;
	public var s0x:Float; // sampled at the previous step of KadoKadeo
	public var s0y:Float;
	public var s1x:Float; // sampled at the last step
	public var s1y:Float;
	public var lx:Float; // the position of the game, kept while a picture is drawn
	public var ly:Float;
	public var fresh:Bool; // shown where it is at the next step, without moving from the previous sample
	public var mark:Int;
	public var placed:Bool; // moved by the game once since it appeared

	public function new(x:Float, y:Float, mark:Int) {
		f0x = f1x = s0x = s1x = x;
		f0y = f1y = s0y = s1y = y;
		fresh = true;
		placed = false;
		this.mark = mark;
	}
}

// Smoothed display. The game moves 30 times a second and KadoKadeo steps it 32 times (Game.update): shown as they
// are, the moves would jerk (a frame on screen for 1, 2 or 3 pictures, and one step in 16 without any move). Like the
// lagged display of Razor, each step of KadoKadeo samples the positions 30/32 of a frame behind the last frame of the
// game (always between the last two frames: the moves are even), and each picture goes from the previous sample to
// the last one with the alpha of KadoKadeo's fixed rate (like ASprite).
// Only the x / y of what the game moves (the children of the root of the game: entities, effects, and the root
// itself for the shake), and only while PIXI draws the picture: they are set before it and put back after it, so that
// the game and the tests only ever see the positions of the game. Shown at once, never smoothed: the first move of
// something that appeared (a mob or an item is made at (0, 0), without a picture, and placed by its first update) and
// a move longer than TELEPORT (a respawn, the dash of the Fly).
class Smooth {
	static inline var TELEPORT = 64;

	var root:Container;
	var tracks:js.lib.Map<DisplayObject, Track>;
	var mark:Int;
	var drawn:Array<DisplayObject>;

	public function new(root:Container) {
		this.root = root;
		tracks = new js.lib.Map();
		mark = 0;
		drawn = [];
	}

	// after each frame of the game: the positions it gave
	public function afterFrame() {
		mark++;
		track(root);
		for (o in root.children)
			track(o);
		var gone = [];
		tracks.forEach((t, o, _) -> if (t.mark != mark) gone.push(o));
		for (o in gone)
			tracks.delete(o);
	}

	function track(o:DisplayObject) {
		var t = tracks.get(o);
		if (t == null) {
			tracks.set(o, new Track(o.x, o.y, mark));
			return;
		}
		t.mark = mark;
		t.f0x = t.f1x;
		t.f0y = t.f1y;
		t.f1x = o.x;
		t.f1y = o.y;
		var moved = t.f1x != t.f0x || t.f1y != t.f0y;
		if ((moved && !t.placed) || Math.abs(t.f1x - t.f0x) > TELEPORT || Math.abs(t.f1y - t.f0y) > TELEPORT) {
			t.f0x = t.f1x;
			t.f0y = t.f1y;
			t.fresh = true;
		}
		if (moved)
			t.placed = true;
	}

	// after each step of KadoKadeo: `past` is how far the game is past its last frame, in frames (0 to 30/32)
	public function afterStep(past:Float) {
		var k = past + 1 / 16;
		tracks.forEach((t, _, _) -> {
			var x = t.f0x + (t.f1x - t.f0x) * k;
			var y = t.f0y + (t.f1y - t.f0y) * k;
			if (t.fresh) {
				t.fresh = false;
				t.s0x = x;
				t.s0y = y;
			} else {
				t.s0x = t.s1x;
				t.s0y = t.s1y;
			}
			t.s1x = x;
			t.s1y = y;
		});
	}

	// before a picture is drawn (alpha: how far between the last two steps)
	public function beforeRender(alpha:Float) {
		drawn.resize(0);
		tracks.forEach((t, o, _) -> {
			if (t.s0x == t.s1x && t.s0y == t.s1y && t.s1x == t.f1x && t.s1y == t.f1y)
				return;
			t.lx = o.x;
			t.ly = o.y;
			o.x = Math.round(t.s0x + (t.s1x - t.s0x) * alpha);
			o.y = Math.round(t.s0y + (t.s1y - t.s0y) * alpha);
			drawn.push(o);
		});
	}

	// after the picture: the positions of the game again
	public function afterRender() {
		for (o in drawn) {
			var t = tracks.get(o);
			if (t != null) {
				o.x = t.lx;
				o.y = t.ly;
			}
		}
		drawn.resize(0);
	}
}

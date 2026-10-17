package mel;

import mel.Fl;

// the symbols of gfx.swf the game creates (gfx.Hero, gfx.MovementFX...), with the rectangles of their _hit boxes
// measured in the SWF (Art.meta().hits): getRect of the original read them on the display

class Hero extends Mov {
	public function new() {
		super("hero");
	}
}

class MovementFX extends Mov {
	public function new() {
		super("movefx");
	}
}

private class HitMov extends Mov {
	static function rect(a:Array<Float>):Rect {
		return a == null ? null : new Rect(a[0], a[1], a[2], a[3]);
	}

	function hitOf(t:Dynamic, smcFrame:Int):Rect {
		var a:Array<Dynamic> = t;
		if (a == null)
			return null;
		if (Std.isOfType(a[0], Float) || Std.isOfType(a[0], Int))
			return rect(cast a);
		var i = smcFrame - 1;
		if (i < 0)
			i = 0;
		if (i >= a.length)
			i = a.length - 1;
		return rect(cast a[i]);
	}
}

// gfx.Swarm: the _hit box is a child of the clip
class Swarm extends HitMov {
	public function new() {
		super("swarm");
	}

	override public function localRect():Rect {
		var h:Array<Dynamic> = Art.meta().hits.swarm;
		return hitOf(h[clip.currentFrame - 1], 1);
	}
}

// gfx.Grabbers: the _hit box is in smc (robot1: frame 1 a grabber, 2 a bad grabber)
class Grabbers extends HitMov {
	public function new() {
		super("grabbers");
	}

	override public function localRect():Rect {
		var s = smc;
		return hitOf(Art.meta().hits.grabbers, s == null ? 1 : s.currentFrame);
	}
}

// gfx.Danger on frames 1 and 2: the burners
class Danger extends HitMov {
	public function new() {
		super("danger");
	}

	override public function localRect():Rect {
		var t:Array<Dynamic> = Art.meta().hits.torch;
		var s = smc;
		return hitOf(t[clip.currentFrame == 2 ? 1 : 0], s == null ? 1 : s.currentFrame);
	}
}

// gfx.Sentinel (the massive ones): stand / run
class Sentinel extends HitMov {
	public function new() {
		super("sentinel");
	}

	override public function localRect():Rect {
		var t:Array<Dynamic> = Art.meta().hits.sentinel;
		var s = smc;
		return hitOf(t[clip.currentFrame == 2 ? 1 : 0], s == null ? 1 : s.currentFrame);
	}
}

class LifeBar extends Mov {
	public function new() {
		super("lifebar");
	}

	public var _blink(get, never):Clip;

	inline function get__blink()
		return clip.getClip("_blink");
}

/**
 * McCache.CachedMc of the saw blade (gfx.Danger frame 3, its smc flattened frame by frame): one bitmap per frame, the
 * current one visible. getRect of the original: the bounds of the whole container (every frame's bitmap, visible or
 * not) in the space asked, moved by the current bitmap's offset and the _hit rectangle of the frame (in the space of
 * the clip: a rotated blade gets a shifted box, like the original).
 */
class Blade extends DO {
	public var cursor:Float = 0;

	var frames:Array<pixi.core.textures.Texture>;
	var defs:Array<Dynamic>;
	var union:Rect;

	public function new() {
		super(new common_haxe_avm1.display.ASprite());
		frames = Tex.get("blade");
		defs = Art.meta().blade;
		var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
		for (d in defs) {
			x0 = Math.min(x0, d.bx);
			y0 = Math.min(y0, d.by);
			x1 = Math.max(x1, d.bx + d.w);
			y1 = Math.max(y1, d.by + d.h);
		}
		union = new Rect(x0, y0, x1 - x0, y1 - y0);
		node.anchor.copyFrom(frames[0].defaultAnchor);
		update(0);
	}

	public function update(dfr:Float) {
		cursor += dfr;
		if (cursor >= defs.length)
			cursor = 0;
		node.texture = frames[Std.int(cursor)];
	}

	override public function localRect():Rect {
		return union;
	}

	override public function getRect(?space:DO):Rect {
		var mr = super.getRect(space);
		var d = defs[Std.int(cursor)];
		var cr:Array<Float> = d.hit;
		return new Rect(mr.x - d.bx + cr[0], mr.y - d.by + cr[1], cr[2], cr[3]);
	}
}

/**
 * lib.PowerUps as made by Ui.makePow (frame of the power, scale 0.8, black glow, cacheAsBitmap): the picture is drawn
 * at the scale of its variant (pow: 0.8 with the glow, the bonuses of the level; powUi / powGrey: 0.6 without filter,
 * in colour or grey, the icons of the interface).
 */
class Pow extends DO {
	public var frame(default, null):Int;

	var variant:String;
	var baked:Float;

	public function new(frame:Int, ?variant:String = "pow") {
		super(new common_haxe_avm1.display.ASprite());
		this.frame = frame;
		setVariant(variant);
		vsx = vsy = 0.8;
	}

	public function setVariant(v:String) {
		variant = v;
		baked = v == "pow" ? 0.8 : 0.6;
		var t = Tex.get(v)[frame - 1];
		node.texture = t;
		node.anchor.copyFrom(t.defaultAnchor);
	}

	override function nodeScale():Float {
		return 1 / baked;
	}

	override public function localRect():Rect {
		var r:Array<Float> = Art.meta().powRects[frame - 1];
		return new Rect(r[0], r[1], r[2], r[3]);
	}
}

// gfx.Height: the plate with its "0000000mmm" in the grid font, and the height in _txt
class HeightSign extends Spr {
	public var _txt:Txt;

	public var height(default, null):Float;

	public function new() {
		super();
		var h = Art.meta().height;
		addChild(new Bmp("heightPlate"));
		_txt = new Txt("height");
		_txt.x = h.x;
		_txt.y = h.y;
		_txt.fieldWidth = h.w;
		_txt.align = "right";
		addChild(_txt);
		height = h.fullH;
	}
}

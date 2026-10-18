package mel;

import mel.Lib;
import mel.Gfx;

// fx/Greyscale.hx: the colour matrix of the death (setStrengthBloom: from the colours to grey)
class FxGreyscale {
	var m:Array<Float>;

	public function new() {
		m = [0.3, 0.59, 0.11, 0, 0, 0.3, 0.59, 0.11, 0, 0, 0.3, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0];
	}

	public function get():BitmapFilter {
		return new ColorMatrixFilter(m);
	}

	static inline function l1v(v:Float, r:Float)
		return (v - 1) * r + 1;

	public function setStrengthBloom(f:Float) {
		var fr = l1v(0.3, f);
		var fg = l1v(0.59, f);
		var fb = l1v(0.11, f);
		m = [fr, fg, fb, 0, 0, fr, fg, fb, 0, 0, fr, fg, fb, 0, 0, 0, 0, 0, 1, 0];
	}
}

// fx/Init.hx: 4 orange arrows bouncing at the top and a big word blinking ("SAUTE !", "PULPZ!") for 200 frames
class FxInit {
	public var arrows:Array<Bitmap>;
	public var word:TextField;

	public function new(?msg:String) {
		FTimer.tick(function(r) tick(r), 200);

		arrows = [new Bitmap("arrow"), new Bitmap("arrow"), new Bitmap("arrow"), new Bitmap("arrow")];
		var arrWidth = 64;
		var i = 0;
		var p = [0.2, 0.4, 0.6, 0.8];
		for (a in arrows) {
			a.y = 0;
			a.x = p[i] * Lib.w() - arrWidth * 0.5;
			Game.me.view.parent.addChild(a);
			a.toFront();
			i++;
		}

		word = new TextField("big");
		word.text = msg != null ? msg : Text.jump;
		word.y = 200;
		word.x = (Lib.w() >> 1) - (word.textWidth * 0.5);
		word.fieldWidth = 600;
		Game.me.view.parent.addChild(word);
		word.toFront();
	}

	public function tick(r:Float) {
		for (a in arrows)
			a.y = Std.int(Math.abs(Math.sin(Game.me.time.ufr * 0.1)) * 50);
		word.alpha = Math.round(Math.abs(Math.sin(Game.me.time.ufr * 0.2)) * (1 - r));
		if (r >= 1.0)
			kill();
	}

	public function kill() {
		for (a in arrows)
			a.detach();
		arrows = null;
		word.detach();
		word = null;
	}
}

enum SMS_STATE {
	GROW;
	WRITE(n:Int);
	CLOSE;
}

// fx/SMS.hx: a black bar coming up at the bottom of the screen with a message (the radio of the resistance, the
// propaganda flashes), 180 frames, then going down
class SMS extends Fx {
	public var bg:Sprite;
	public var label:TextField;
	public var msg:String;
	public var state:SMS_STATE;
	public var H = 32;

	public function new(msg:String) {
		super();
		this.msg = msg;

		bg = new Sprite();
		var gfx = bg.graphics;
		gfx.beginFill(0x000000);
		gfx.drawRect(0, 0, Lib.w(), H);
		gfx.endFill();
		bg.y = Lib.h();
		Game.me.view.parent.addChild(bg);
		state = GROW;
		bg.alpha = 0.8;
		bg.filters = [new GlowFilter(0x000000, 1, 10, 10, 0.5)];

		label = new TextField("sms");
		label.text = msg;
		label.x = 8;
		label.y = 0;
		label.fieldWidth = Lib.w();
		bg.addChild(label);
	}

	override public function update() {
		if (bg == null)
			return;
		switch (state) {
			case GROW:
				bg.y--;
				if (bg.y <= Lib.h() - H) {
					bg.y = Lib.h() - H;
					state = WRITE(180);
				}
			case WRITE(n):
				if (n == 1)
					state = CLOSE;
				else
					state = WRITE(n - 1);
			case CLOSE:
				bg.y++;
				if (bg.y >= Lib.h())
					kill();
		}
	}

	override public function kill() {
		super.kill();
		bg.detach();
		bg = null;
		label = null;
	}
}

// fx/Score.hx: the lines of a bonus text ("DOUBLE|SAUT")
class FxScore extends Sprite {
	var tfs:Array<TextField>;

	public function new(msg:String, create:String->TextField) {
		super();
		tfs = [];
		for (m in msg.split("|")) {
			var tf = create(m);
			tfs.push(tf);
			addChild(tf);
		}
	}
}

// a frozen copy of the picture of an object (mt.deepnight.Lib.flatten with its transform), for the afterimages
class Ghost extends DisplayObject {
	var ns:Float = 1;
	var inner:ColorTransform;

	public function new(o:DisplayObject) {
		var mv = Std.downcast(o, MovieClip);
		super(mv != null ? mv.clip.snapshot(1) : new common_haxe_avm1.display.ASprite());
		if (mv != null) {
			ns = mv.clip.baseScale;
		} else {
			node.texture = o.node.texture;
			node.anchor.copyFrom(o.node.anchor);
			ns = o.nodeScaleOf();
		}
		x = o.x;
		y = o.y;
		scaleX = o.scaleX;
		scaleY = o.scaleY;
		rotation = o.rotation;
		inner = o.colorTransform;
	}

	override function nodeScale():Float {
		return ns;
	}

	// a colour transform over the copied picture (the picture has the colours of the object, its own transform too)
	public function setCT(ct:ColorTransform) {
		var c = ct.after(inner);
		var mv = Std.downcast(node, Clip);
		if (mv != null)
			mv.setColour(c.tint(), c.add());
		else
			node.tint = c.tint();
	}

	public function dispose() {
		detach();
		node.destroy({children: true});
	}
}

// fx/Shade.hx: an afterimage, coloured (0.3 x the picture + the colour) when a colour is given, fading
class FxShade extends Fx {
	var bmp:Ghost;
	var timer = 0;
	var alphaStart = 0.6;
	var fadeAlpha = true;

	public function new(mc:DisplayObject, timer:Int, ?col:Null<Int>) {
		super();
		bmp = new Ghost(mc);
		bmp.putAfter(mc);
		if (col != null) {
			var ct = new ColorTransform();
			ct.mul(0.3, 0.3, 0.3);
			ct.ofs(col >> 16, (col >> 8) & 0xFF, col & 0xFF);
			bmp.setCT(ct);
		}
		// (the picture has the alpha of the object in it, the bitmap its own)
		a0 = mc.alpha;
		fade = alphaStart;
		bmp.alpha = fade * a0;
		this.timer = timer;
	}

	var a0:Float = 1;
	var fade:Float = 0.6;

	override public function update() {
		super.update();
		if (timer-- <= 0)
			kill();
		else {
			if (fadeAlpha) {
				fade -= alphaStart * 1.0 / timer;
				bmp.alpha = fade * a0;
			}
		}
	}

	override public function kill() {
		super.kill();
		bmp.dispose();
		bmp = null;
	}
}

/**
 * fx/Shade2.hx: the afterimages of Mel during a double jump / charged jump / wall jump, behind her (0.2 x the picture +
 * an orange fading to grey, blend mode OVERLAY: OverlayBlend), alpha 0.7 fading to 0.1.
 */
class FxShade2 extends Fx {
	var bmp:Ghost;
	var timer = 0;
	var dur = 0;
	var alphaStart = 0.6;
	var ct:ColorTransform;
	var basecol:Int;

	public function new(mc:DisplayObject, timer:Int, col:Int) {
		super();
		bmp = new Ghost(mc);
		bmp.putAfter(mc);
		ct = new ColorTransform();
		ct.mul(0.2, 0.2, 0.2);
		ct.ofs(col >> 16, (col >> 8) & 0xFF, col & 0xFF);
		bmp.setCT(ct);
		bmp.node.filters = [new OverlayBlend()];
		this.timer = timer;
		basecol = col;
		dur = timer;
		// (transform.colorTransform = ct: alpha 1, until the update of the same frame)
		bmp.alpha = 1;
	}

	static function desaturate(c:Int, r:Float):Int {
		var cr = (c >> 16) & 0xFF, cg = (c >> 8) & 0xFF, cb = c & 0xFF;
		var lum = cr * 0.3 + cg * 0.59 + cb * 0.11;
		var f = function(v:Int) return Std.int(v + (lum - v) * r);
		return (f(cr) << 16) | (f(cg) << 8) | f(cb);
	}

	override public function update() {
		super.update();
		var r = 1.0 - (timer / dur);
		if (timer-- <= 0)
			kill();
		else {
			var c = desaturate(basecol, r);
			ct.ofs(c >> 16, (c >> 8) & 0xFF, c & 0xff, 0);
			bmp.setCT(ct);
			bmp.alpha = 0.1 + alphaStart * (1.0 - r);
		}
	}

	override public function kill() {
		super.kill();
		bmp.dispose();
		bmp = null;
	}
}

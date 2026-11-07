package trigo;

import trigo.Game;

// A block of the grid (Block of the original): its sprite `sp` holding the flattened picture (`bmp`, Game.flatten) and
// over it the clip gfx.Blocks / gfx.Blocks2 (`mc`), shown only to light the block up (its `_hili`) or make it sparkle (its
// `_blink`).
class Block {
	public var x:Int;
	public var y:Int;
	public var id:Null<Int>;

	public var sp:Sprite;
	public var mc:MovieClip;
	public var bmp:Bitmap;

	public var grouped:Bool;

	public function new(x, y, delay:Null<Int>, ?speed:Float) {
		this.x = x;
		this.y = y;
		this.grouped = false;

		this.id = Game.me.rand(Game.MAX_ID);
		// (the tutorial of the LvUP gave the blocks of TUTO_POS their colour; the in-game prizes of Arkadeo replaced a
		// block by a prize: Game.filteredPrizeTokens, none in KadoKadeo, no draw)

		draw(delay, speed);
	}

	// the named children of gfx.Blocks / gfx.Blocks2 (no _blink in a gfx.Blocks2)
	public var _blink(get, never):Clip;
	public var _hili(get, never):Clip;

	inline function get__blink()
		return mc.getClip("_blink");

	inline function get__hili()
		return mc.getClip("_hili");

	public function draw(delay:Null<Int>, ?speed:Null<Float>) {
		remove();

		sp = new Sprite();

		mc = new MovieClip(grouped ? Data.BLOCKS2 : Data.BLOCKS);
		mc.gotoAndStop(id + 1);

		if (_blink != null) {
			_blink.stop();
			_blink._visible = false;
		}
		_hili._visible = false;
		bmp = Game.flatten(mc, grouped, id);

		sp.addChild(bmp);
		sp.addChild(mc);
		mc.visible = false;

		var c = center();
		sp.x = c.x;
		sp.y = c.y;
		Game.me.dm.add(sp, Game.DP_BLOCKS);
		Game.me.dm.ysort(Game.DP_BLOCKS);

		if (delay != null) {
			sp.scaleX = sp.scaleY = 0;
			if (speed == null)
				speed = 0.1;
			new mt.fx.Sleep(new mt.fx.Grow(sp, speed, 1), delay);
		}

		return sp;
	}

	public function group(g:Group, delay:Int) {
		if (grouped)
			throw "already grouped";

		id = g.id;
		grouped = true;
		Game.me.gblocks.add(this);
		Game.me.swapingBlocks++;

		unblink();
		var fx = new FxSwap(sp, function() return draw(null));
		fx.onFinish = function() {
			Game.me.swapingBlocks--;
		}
		new mt.fx.Sleep(fx, null, delay);
	}

	public function destroy() {
		Game.me.grid[x][y] = null;

		mc.visible = false;

		var f = new mt.fx.FadeTo(sp, 0.3, 0, 0xFFFFFF);
		f.onFinish = function() {
			var f = new mt.fx.FadeTo(sp, 0.03, 0, 0x0);
			f.onFinish = remove;

			for (i in 0...2) {
				var p = Game.me.createPart(new Point(sp.x, sp.y), 1);
				p.timer = 50;
				p.weight = 0.4;
			}
		}
	}

	public function gather(g:Group, delay:Int) {
		Game.me.grid[x][y] = null;

		mc.visible = false;

		var f = new mt.fx.FadeTo(sp, 0.07, 0, 0xFFFFFF);
		f.curveIn(2);
		f.onFinish = function() {
			for (i in 0...2) {
				var p = Game.me.createPart(center(), 1);
				p.vy += -1.5;
				p.weight = 0.16;
				p.timer = 30 + Game.me.fxSeed.random(10);
			}
			var f = new mt.fx.Vanish(sp, 8, 8, true);
			f.onFinish = function() {
				var p = Game.me.createPart(center(), 3);
				p.weight = -0.05;
				remove();
			};
		};

		var s = new mt.fx.Sleep(f, onGather, delay);
	}

	// (the prize of the block taken: none in KadoKadeo)
	function onGather() {}

	public function mouseOver() {
		if (!grouped) {
			over();
			return;
		}
		for (b in Game.me.gblocks)
			b.over();
		return;
	}

	public function mouseOut() {
		if (!grouped)
			return out();
		for (b in Game.me.gblocks)
			b.out();
		return;
	}

	public function over() {
		mc.visible = true;
		_hili._visible = true;
		_hili._alpha = 100;
		new trigo.fx.Alpha(_hili, 0.5, 0.6);
	}

	public function out() {
		var f = new trigo.fx.Alpha(_hili, 0, 0.2);
		f.curveIn(2);
		f.onFinish = function() {
			mc.visible = false;
			_hili._visible = false;
		}
	}

	public function blink() {
		if (grouped)
			return;
		if (!_blink._visible) {
			mc.visible = true;
			_blink._visible = true;
			_blink.gotoAndPlay(1);
		}
	}

	public function unblink() {
		if (grouped)
			return;
		if (_blink._visible) {
			mc.visible = false;
			_blink.stop();
			_blink._visible = false;
		}
	}

	// (shine / unshine: the tutorial of the LvUP)

	public function remove() {
		if (sp != null && sp.parent != null)
			sp.parent.removeChild(sp);
		// (the clip is not shown any more: its timeline stops, arkadeo.MovieClip.all)
		if (mc != null)
			mc.dispose();
	}

	public function center() {
		return new Point(Game.BLOCK_SIZE * x + Game.DELTA_X, Game.BLOCK_SIZE * y + Game.DELTA_Y);
	}

	public function tl() {
		var c = center();
		return new Point(c.x - Game.BLOCK_SIZE / 2, c.y - Game.BLOCK_SIZE / 2);
	}

	public function tr() {
		var c = center();
		return new Point(c.x + Game.BLOCK_SIZE / 2, c.y - Game.BLOCK_SIZE / 2);
	}

	public function bl() {
		var c = center();
		return new Point(c.x - Game.BLOCK_SIZE / 2, c.y + Game.BLOCK_SIZE / 2);
	}

	public function br() {
		var c = center();
		return new Point(c.x + Game.BLOCK_SIZE / 2, c.y + Game.BLOCK_SIZE / 2);
	}
}

// the flip of a block joining a triangle: squeezed to nothing with a drop shadow growing, redrawn (a gfx.Blocks2) and
// widened again
class FxSwap extends mt.fx.Fx {
	static var DUR = 25;
	static var THICK = 3;

	var sp:Sprite;
	var onMiddle:Null<Void->Sprite>;
	var timer:Int;
	var x:Float;

	public function new(sp:Sprite, cb) {
		super();
		this.sp = sp;
		this.timer = DUR;
		this.onMiddle = cb;
		this.x = sp.x;
	}

	override function update() {
		if (timer > DUR / 2) {
			var r = timer * 2 / DUR - 1; // 1 -> 0
			sp.scaleX = r;
			sp.x = x - (1 - r) * THICK / 2;
			sp.filters = [new DropShadowFilter(THICK * (1 - r), 0, 0x0, 1.3, 1.3, 5)];
		} else {
			if (onMiddle != null) {
				sp = onMiddle();
				onMiddle = null;
			}
			var r = 1 - timer * 2 / DUR; // 0 -> 1
			sp.scaleX = r;
			sp.x = x + (1 - r) * THICK / 2;

			sp.filters = [new DropShadowFilter(THICK * (1 - r), 180, 0x0, 1.3, 1.3, 5)];
			if (timer == 0) {
				sp.filters = [];
				// (sp.cacheAsBitmap = true: the picture is the same)
				kill();
			}
		}

		timer--;
	}
}

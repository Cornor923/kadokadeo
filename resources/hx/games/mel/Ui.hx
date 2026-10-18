package mel;

import mel.Lib;
import mel.Gfx;

// Ui.hx of the original: the 5 power icons at the top right (grey until Mel has the power; on mouse over, a tip
// explains it) and the life bar at the top left
class Ui {
	public var powers:Array<Pow>;
	public var tip:Tip;
	public var bar:LifeBar;

	public var game(get, null):Game;

	function get_game()
		return Game.me;

	public function new() {
		var mc = new Sprite();
		powers = [];

		var border = new Sprite();
		var by = 8;
		var bx = Lib.w() - 140;
		border.x = bx;
		border.y = by;
		mc.addChild(border);

		var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
		for (p in CharPowers.createAll()) {
			var pi = p.getIndex();
			var sp = makePow(p);
			sp.x = bx + 14 + pi * 26;
			sp.y = by + 26;
			powers.push(sp);
			mc.addChild(sp);
			sp.setVariant("powGrey");
			sp.scaleX = sp.scaleY = 0.6;
			var r = sp.getRect(mc);
			x0 = Math.min(x0, r.x);
			y0 = Math.min(y0, r.y);
			x1 = Math.max(x1, r.x + r.width);
			y1 = Math.max(y1, r.y + r.height);
		}

		// (mc.width / mc.height: the icons, the empty border has no bounds)
		var g = border.graphics;
		g.beginFill(0xd3d4bf);
		g.drawRoundedRect(-1, -1, (x1 - x0) + 7, (y1 - y0) + 7, 4);
		g.endFill();

		Game.me.addChild(mc);
		mc.toFront();

		tip = new Tip();
		Game.me.addChild(tip.spr);

		Game.me.addChild(bar = new LifeBar());
		bar.x += 8;
		bar.y += 12;
		bar.stop();
	}

	public static inline var b = 32;

	// lib.PowerUps of a power (null: the empty one, the +1000 bonus), scale 0.8, black glow
	public static function makePow(p:Null<CharPowers>):Pow {
		var f = if (p == null) CharPowers.createAll().length + 1 else switch (p) {
			case CP_DOUBLE_JUMP: 3;
			case CP_WALL_STICK: 1;
			case CP_SUPER_JUMP: 2;
			case CP_KICK: 4;
			case CP_CANCEL: 5;
		}
		var sp = new Pow(f, "pow");
		sp.scaleX = sp.scaleY = 0.8;
		return sp;
	}

	public function pos(i:Int) {
		return {x: b + i * 48, y: 64};
	}

	public function update() {
		bar.gotoAndStop(Std.int((2 - game.char.pv) * 10));
		for (p in CharPowers.createAll())
			if (game.char.powers.has(p)) {
				var pp = powers[p.getIndex()];
				// (the port: in red while the Mag Grips are switched off)
				pp.setVariant(p == CP_WALL_STICK && game.char.gripOff ? "powUiRed" : "powUi");
			}
		tip.update();
	}
}

/**
 * mt.deepnight.Tip of the interface: over a power icon Mel has, the text of the power (txt_cp*) in a black box with an
 * orange border next to the mouse. Only a picture: the mouse is not recorded in the replays (the original read it
 * from mouse over events, outside of the game logic).
 */
class Tip {
	public var spr:Sprite;

	var bg:Sprite;
	var txt:TextField;
	var last:Int = -1;

	public function new() {
		spr = new Sprite();
		spr.visible = false;
		bg = new Sprite();
		spr.addChild(bg);
		txt = new TextField("tip");
		txt.x = 5;
		txt.y = 3;
		spr.addChild(txt);
	}

	public function update() {
		var game = Game.me;
		if (game.isReplayGame()) {
			spr.visible = false;
			return;
		}
		var mx = common_haxe_avm1.MouseManager.getX();
		var my = common_haxe_avm1.MouseManager.getY();
		var over = -1;
		for (p in CharPowers.createAll()) {
			if (!game.char.powers.has(p))
				continue;
			var r = game.ui.powers[p.getIndex()].getRect(null);
			if (mx >= r.x && mx < r.x + r.width && my >= r.y && my < r.y + r.height)
				over = p.getIndex();
		}
		if (over < 0) {
			spr.visible = false;
			last = -1;
			return;
		}
		if (over != last) {
			last = over;
			var t = Text.resolve('txt_cp' + over).split('\r').join("");
			t = t.split("\t").join("").split("|").join("\n");
			var lines = [for (l in t.split("\n")) StringTools.trim(l)].filter(l -> l.length > 0);
			txt.text = lines.join("\n");
			var w = txt.textWidth + 4 + 10;
			var h = Std.int(txt.textHeight + 4 + 7.5);
			var g = bg.graphics;
			g.clear();
			g.lineStyle(1.1, 0xffa000, 1);
			g.beginFill(0x0);
			g.drawRoundedRect(0, 0, w, h, 2);
			g.endFill();
			spr.alpha = 0;
		}
		spr.visible = true;
		if (spr.alpha < 1)
			spr.alpha = Math.min(1, spr.alpha + 0.2);
		var x:Float = mx + 15;
		var y:Float = my;
		var bw = txt.textWidth + 14;
		var bh = txt.textHeight + 12;
		if (x + bw >= Lib.w())
			x = mx - 15 - bw;
		if (x < 0)
			x = 0;
		if (y + bh >= Lib.h())
			y = my - bh;
		if (y < 0)
			y = 0;
		spr.x = x;
		spr.y = y;
		spr.toFront();
	}
}

// View.hx of the original: the sprite moved by the camera (the root of the level is in it)
class View extends Sprite {
	public function new() {
		super();
	}

	public function scrollPix(x:Float, y:Float) {
		this.x = Std.int(x);
		this.y = Std.int(y);
	}

	public function update() {}
}

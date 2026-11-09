package labrute;

import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import labrute.view.Ui;

// what the mouse is over: its tooltip (key: the same content, make: the content, made when it is first shown)
typedef Tip = {
	x:Float,
	y:Float,
	w:Float,
	h:Float,
	key:String,
	make:Void->TipBox,
	?m:Array<Float>,
}

// a clickable area without the look of a button (the icons of the shop)
typedef Zone = {
	x:Float,
	y:Float,
	w:Float,
	h:Float,
	action:Int,
	enabled:Bool,
	?m:Array<Float>,
}

// the box of a tip or a zone: in the frame of its matrix m [a, b, c, d, tx, ty] when it has one (a turned weapon)
typedef Box = {
	x:Float,
	y:Float,
	w:Float,
	h:Float,
	?m:Array<Float>,
}

// the actions of the screens: what the replay records for a click
class A {
	// + 0...3: hp, strength, agility, speed
	public static inline var STAT = 1;
	public static inline var NEW_WEAPON = 5;
	public static inline var NEW_SKILL = 6;
	public static inline var FIGHT = 7;
	// + 0...2: easy, medium, hard
	public static inline var PICK = 10;
	public static inline var CONTINUE = 20;
	// + the index of the perk
	public static inline var UP_WEAPON = 100;
	public static inline var UP_SKILL = 200;
	public static inline var UP_PET = 300;
}

// A screen of the game (the shop, the choice of the opponent, a fight). Its state changes in update() and apply()
// (the gameplay, the same in the replay), its pictures in render() (only when the game is drawn).
class Screen {
	var game:Game;

	// under the fighters, over them
	public var back:Container;
	public var front:Container;
	public var buttons:Array<Button> = [];
	public var zones:Array<Zone> = [];
	public var tips:Array<Tip> = [];

	var hoverG:Graphics;

	public function new(game:Game) {
		this.game = game;
		back = new Container();
		front = new Container();
		game.backLayer.addChild(back);
		game.frontLayer.addChild(front);
	}

	// the action under the mouse (-1: none)
	public function actionAt(x:Float, y:Float):Int {
		for (b in buttons)
			if (b.hit(x, y))
				return b.action;
		var z = zoneAt(x, y);
		return z != null && z.enabled ? z.action : -1;
	}

	// the zone under the mouse: the last one given (over the others, like the tips), enabled or not
	function zoneAt(x:Float, y:Float):Zone {
		var i = zones.length - 1;
		while (i >= 0) {
			if (inside(zones[i], x, y))
				return zones[i];
			i--;
		}
		return null;
	}

	public static function inside(r:Box, x:Float, y:Float):Bool {
		var m = r.m;
		if (m != null) {
			var det = m[0] * m[3] - m[1] * m[2];
			var dx = x - m[4];
			var dy = y - m[5];
			x = (m[3] * dx - m[2] * dy) / det;
			y = (m[0] * dy - m[1] * dx) / det;
		}
		return x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;
	}

	public function apply(action:Int):Void {}

	public function update():Void {}

	// t: the time of the game in frames (with the interpolation); mx, my: the mouse (live only)
	public function render(t:Float, mx:Float, my:Float, live:Bool):Void {
		for (b in buttons)
			b.setHover(live && b.contains(mx, my));
		if (hoverG == null || hoverG.parent == null) {
			hoverG = new Graphics();
			front.addChild(hoverG);
		}
		hoverG.clear();
		var z = live ? zoneAt(mx, my) : null;
		if (z != null && z.enabled) {
			hoverG.lineStyle(2, 0xFFFFFF, 0.9);
			hoverG.beginFill(0xFFFFFF, 0.2);
			if (z.m == null)
				hoverG.drawRoundedRect(z.x - 1, z.y - 1, z.w + 2, z.h + 2, 4);
			else {
				// (its box turned with it)
				var m = z.m;
				var pts = [];
				for (c in [[z.x, z.y], [z.x + z.w, z.y], [z.x + z.w, z.y + z.h], [z.x, z.y + z.h]]) {
					pts.push(m[0] * c[0] + m[2] * c[1] + m[4]);
					pts.push(m[1] * c[0] + m[3] * c[1] + m[5]);
				}
				hoverG.drawPolygon(pts);
			}
			hoverG.endFill();
		}
	}

	public function tipAt(mx:Float, my:Float):Tip {
		var i = tips.length - 1;
		while (i >= 0) {
			var t = tips[i];
			if (inside(t, mx, my))
				return t;
			i--;
		}
		return null;
	}

	public function clearUi():Void {
		buttons = [];
		zones = [];
		tips = [];
		for (c in front.children.copy())
			Ui.destroy(cast c);
		for (c in back.children.copy())
			Ui.destroy(cast c);
		hoverG = null;
	}

	public function destroy():Void {
		Ui.destroy(back);
		Ui.destroy(front);
		buttons = [];
		zones = [];
		tips = [];
	}
}

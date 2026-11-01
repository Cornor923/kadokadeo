package linea;

import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchButtonShape;
import kado.TouchControlsConfig.TouchControlsMode;
import linea.Dotter.DOT;
import linea.MC.Plans;
import pixi.core.display.Container;
import pixi.core.textures.Texture;
import pixi.filters.blur.BlurFilter;

class Hit extends MC {
	public var hit:Bool = false;
}

class EMC extends MC {
	public var x:Float;
	public var y:Float;
	public var color:Int;
	public var stopped:Bool;
	public var started:Bool;
	public var linked:Bool;
	public var a:Float;
	public var prevX:Int;
	public var prevY:Int;
}

class OBJECT extends EMC {
	public var line:Bool = false;
	public var bonus:Bool = false;
	public var vscroll:Float;
	public var added:Bool = false;
	public var camper:Bool = false;
	public var lineDone:Bool = false;
}

class AOBJECT extends OBJECT {
	public var bx:Float;
	public var by:Float;
}

// mcBonus: the 4 mcSoloBonus b1..b4, coloured by Col.setColor (one picture per colour, see linea_assets.py)
class BONUS extends AOBJECT {
	public var b1:Hit;
	public var b2:Hit;
	public var b3:Hit;
	public var b4:Hit;
	// scored (every star taken, or the lines went past it)
	public var hit:Bool = false;
	// stars taken so far, and where the last ones were (for the score shown)
	public var taken:Int = 0;
	public var hitX:Int = 0;
	public var hitY:Int = 0;

	public function new() {
		super();
		_totalframes = 2;
		playing = true;
		for (i in 0...Data.STARS_NAME.length) {
			var s = new Hit("star" + StringTools.hex(Data.COLORS[0], 6).toLowerCase());
			s._x = Data.STARS_X[i];
			s._y = Data.STARS_Y[i];
			attach(s);
			Reflect.setField(this, Data.STARS_NAME[i], s);
		}
	}

	public function setColor2(col:Int):Void {
		color = col;
		for (c in children)
			c.setFrames("star" + Game.colorKey(col));
	}

	// the bounds of the stars still there (taken stars fade out then are removed)
	override function get__width():Float {
		return children.length > 0 ? Data.BONUS_W : 0;
	}

	override function get__height():Float {
		return children.length > 0 ? Data.BONUS_H : 0;
	}
}

// mcAddline: its own timeline has one frame (the code's gotoAndStop changes nothing) but the nested mcAniglow loops
// on its 12 frames, and _width / _height follow its ring (Data.ADDLINE_W): the code reads them for the collisions
class AddlineMC extends OBJECT {
	public var glowFrame:Int = 1;

	public function new() {
		super("addline");
		_totalframes = 1;
	}

	override function advance():Void {
		glowFrame = glowFrame == 12 ? 1 : glowFrame + 1;
	}

	override function get__width():Float {
		return Data.ADDLINE_W[glowFrame - 1] * Math.abs(_xscale) / 100;
	}

	override function get__height():Float {
		return Data.ADDLINE_H[glowFrame - 1] * Math.abs(_yscale) / 100;
	}

	override function showFrame():Void {
		var t = frames[glowFrame - 1];
		if (spr.texture != t) {
			spr.texture = t;
			spr.anchor.copyFrom(t.defaultAnchor);
		}
	}
}

// mcLineScore, mcBonusScore, mcBonusCombo with their text fields set (one picture per value) and the GlowFilter
// of Game.score (a white silhouette tinted)
class BonusScore extends MC {
	public var glow:MC;

	public function new(name:String, score:Int, mult:Int) {
		super();
		var anim = name.charAt(2).toLowerCase() + name.substr(3);
		var n = switch (name) {
			case "mcLineScore": Std.int(Math.min(Math.max(score, 1), Data.LINE_SCORE_MAX));
			case "mcBonusScore": Std.int(Math.min(Math.max(mult, 1), Data.MULT_MAX));
			case _: 1;
		}
		glow = attach(new MC(anim + "G"));
		glow.gotoAndStop(n);
		attach(new MC(anim)).gotoAndStop(n);
	}
}

// mcUI: the text fields with their DropShadowFilter(s) (white silhouettes tinted), dfactor written by the code
class UI extends MC {
	var factor:Array<MC> = [];
	var text:String;

	public function new(lineCol:Int, darkCol:Int) {
		super();
		piece("uiB", false, lineCol, darkCol);
		piece("uiBottom", true, lineCol, darkCol);
		piece("uiTop", true, lineCol, darkCol);
		factor = piece("uiF", true, lineCol, darkCol);
	}

	function piece(anim:String, two:Bool, lineCol:Int, darkCol:Int):Array<MC> {
		var out = [];
		if (two) {
			var s2 = attach(new MC(anim + "S2"));
			s2.setColor(darkCol);
			out.push(s2);
		}
		var s1 = attach(new MC(anim + "S1"));
		s1.setColor(lineCol);
		out.push(s1);
		out.push(attach(new MC(anim)));
		return out;
	}

	public function setFactor(t:String):Void {
		if (t == text)
			return;
		text = t;
		var n = Std.parseInt(t);
		var show = n != null && n >= 1 && n <= Data.DFACTOR_MAX;
		for (m in factor) {
			m._visible = show;
			if (show)
				m.gotoAndStop(n);
		}
	}
}

@:expose('GameLinea')
class Game implements kado.GameInterface {
	public static inline var K = 2;

	// square arrows: up / down under the left thumb, left / right under the right thumb (both held for a diagonal)
	public static var TOUCH_CONTROLS:kado.TouchControlsConfig = {
		mode: TouchControlsMode.KEYBOARD,
		buttons: [
			{
				id: "left",
				label: "◀",
				leftPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.LEFT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "right",
				label: "▶",
				leftPx: 90,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.RIGHT,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "down",
				label: "▼",
				rightPx: 20,
				bottomPx: 20,
				size: 60,
				keyCode: KeyboardManager.DOWN,
				shape: TouchButtonShape.SQUARE,
			},
			{
				id: "up",
				label: "▲",
				rightPx: 20,
				bottomPx: 90,
				size: 60,
				keyCode: KeyboardManager.UP,
				shape: TouchButtonShape.SQUARE,
			},
		],
	};

	// ZQSD / WASD move like the arrows
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE;

	public var dm:Plans;
	public var root:MC;

	var mcStart:MC;
	var bonus2:MC;
	var bonus3:MC;
	var bonus4:MC;
	var ui:UI;
	var stopScroll:Bool = false;

	var objects:Array<OBJECT>;
	var uidots:Array<EMC>;
	var abonus:Array<BONUS>;

	var scroller:Scroller;
	var dotter:Dotter;

	var gameOver:Bool;
	var signalSent:Bool = false;
	var step:Int;
	var lastX:Float;
	var ocycle:Int;
	var bcycle:Int;
	var start:Bool;
	// never set by the original: null, and `null <= 0` is true in the compiled code (!(null > 0)): like 0
	var startCycle:Int = 0;
	var mainCycle:Int;
	var colorTheme:Int;
	var lastWasBonus:Bool;
	var keyPressed:Int;
	var camping:Int;
	var camper:Int;
	var f:Float;
	var scroll:Int;
	var bonus:Float;
	var tmod:Float;
	var keymod:Float;
	var PLines:Int;
	var PBonus:Int;
	var Phit:Int;

	var isReplay:Bool;
	// Flash frames still owed, in quarters (5 per step)
	var frameAcc:Int = 0;
	var frameCount:Int = 0;

	/* ---------------------------------------- INIT --------------------------------------- */
	public function new(mc:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var keys = new UInt16Array(4);
		keys[0] = KeyboardManager.UP;
		keys[1] = KeyboardManager.DOWN;
		keys[2] = KeyboardManager.LEFT;
		keys[3] = KeyboardManager.RIGHT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: keys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		Const.reset();
		MC.clearAll();
		Sprite.spriteList = [];
		#if debug
		// test harness: the constants, for the test modes (modes/linea.js)
		untyped js.Browser.window.LineaConst = Const;
		#end

		// the original's 300x300 pixels, drawn x2
		root = new MC(null, 1 / K);
		root.posK = K;
		mc.addChild(root.spr);
		dm = new Plans(root);

		scroller = new Scroller(dm, 300, 300);

		camping = 0;
		f = 0.0;
		camper = 2;
		keyPressed = KKApi.val(Const.KEYPRESSED);
		keymod = 0;
		tmod = 0.0;
		lastWasBonus = true;
		// the colours only change the pictures: visual random
		colorTheme = Seed.randomVfx(Const.DOTCOLORS.length);
		ocycle = Const.BONUS_GLOW;
		bcycle = Const.BONUS_GLOW;
		lastX = 0.0;
		gameOver = false;
		step = 1;
		bonus = 0.0;
		objects = new Array();
		uidots = new Array();
		Const.DOT_X_SPEED = Math.round(KKApi.val(Const.BASE_DOT_RIGHT_SPEED) / 5);
		start = false;
		mainCycle = KKApi.val(Const.MAINCYCLE);
		abonus = new Array();
		scroll = Math.round(KKApi.val(Const.BASESPEED) / 10);

		PLines = PBonus = Phit = 0;
		attachElements();
		MC.displayAll(1);
		warmShaders();
	}

	function attachElements() {
		scroller.addLayer("back");

		mcStart = dm.attach("start", Const.DP_UI);
		mcStart._y = 65;
		mcStart._visible = true;

		// mcBorder: a 300 x 20 rectangle (26, 27, 27) at 80 %
		var b = rect(Const.DP_UI, 0, 0, 300, 20, 0x1A1B1B, 80);
		var b2 = rect(Const.DP_UI, 0, 0, 300, 20, 0x1A1B1B, 80);
		b2._y = 280;

		var lineCol = Const.DOTCOLORS[colorTheme][Seed.randomVfx(Const.DOTCOLORS[colorTheme].length)];
		addUILine(Const.DP_UI, 0, 20, 300, 0, lineCol);
		addUILine(Const.DP_UI, 0, 280, 300, 0, lineCol);
		addUILine(Const.DP_UNDER, 100, 20, 0, 260, Col.brighten(lineCol, 90), 20);
		addUILine(Const.DP_UNDER, 175, 20, 0, 260, Col.brighten(lineCol, 90), 20);
		addUILine(Const.DP_UNDER, 250, 20, 0, 260, Col.brighten(lineCol, 90), 20);

		var col = Const.DOTCOLORS[colorTheme][0];
		bonus2 = addBonusGlow(100, 280, Col.brighten(col, 50), 75);
		bonus3 = addBonusGlow(175, 280, Col.brighten(col, 70), 75);
		bonus4 = addBonusGlow(250, 280, Col.brighten(col, 90), 50);

		ui = dm.add(new UI(lineCol, Col.darken(col, 90)), Const.DP_UI);
		ui.setFactor("1");

		dotter = new Dotter(dm.empty(Const.DP_BMP), Math.ceil(Const.WIDTH / 2), Const.HEIGHT, Const.XMARGIN, Const.MARGIN);

		var col = Const.DOTCOLORS[colorTheme].pop();
		dotter.addDot(col);
		addDotToUI(col);
	}

	// a filled rectangle (the white square of the sheet, 2 Flash px at 100 %)
	function rect(depth:Int, x:Float, y:Float, w:Float, h:Float, col:Int, alpha:Float = 100):MC {
		var r = dm.attach("px", depth);
		r._x = x;
		r._y = y;
		r._xscale = w * 50;
		r._yscale = h * 50;
		r.setColor(col);
		r._alpha = alpha;
		return r;
	}

	// mt.white.Geom.drawLine(l, x1, y1, col, false, 0.25, alpha): a stroke thinner than a pixel, drawn by Flash as a
	// 1 pixel hairline (1 screen pixel at x2)
	function addUILine(depth:Int, x:Int, y:Int, x1:Int, y1:Int, col:Int, alpha = 100) {
		return rect(depth, x, y, x1 == 0 ? 0.5 : x1, y1 == 0 ? 0.5 : y1, col, alpha);
	}

	// drawRectangle(bonus, width, 20, col, 100, col, 100): the fill and its hairline outline, at 80 %
	function addBonusGlow(x:Int, y:Int, col:Int, width:Int) {
		var bonus = rect(Const.DP_UI, x, y, width + 0.5, 20.5, col);
		bonus._alpha = 80;
		bonus._visible = false;
		return bonus;
	}

	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new pixi.core.sprites.Sprite(Texture.WHITE);
		var blur = new BlurFilter();
		untyped blur.quality = 2;
		blur.blurX = 4;
		blur.blurY = 0;
		s.filters = [blur];
		holder.addChild(s);
		var rt:Dynamic = (cast pixi.core.textures.RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	/* ---------------------------------------- UPDATE --------------------------------------- */
	public function update(delta:Float) {
		// Flash played Linea at 40 frames/s (the rate of the SWF) with Timer.wantedFPS = 32: tmod = 0.8, one update()
		// per Flash frame. KadoKadeo steps 32 times per second: 5 Flash frames every 4 steps
		mt.Timer.tmod = 32 / Const.FRAME_RATE;
		frameAcc += 5;
		while (frameAcc >= 4) {
			frameAcc -= 4;
			flashFrame();
		}
		MC.displayAll(frameAcc / 4);
		dotter.display(frameAcc / 4);
	}

	function flashFrame() {
		MC.frameStart();
		dotter.frameStart();
		main();
		dotter.frameEnd();
		frameCount++;
	}

	// update() of the original: one Flash frame
	function main() {
		tmod = mt.Timer.tmod;
		keymod += tmod;

		scroller.update(1, Const.DOT_X_SPEED, Const.DOT_Y_SPEED);
		updateAll();
		keymod -= 0.8;
		while (keymod > 1) {
			keymod -= 0.8;
			updateAll();
		}
	}

	function updateAll() {
		onKeyDown();

		if (shk != null)
			updateFxShake();
		if (flasher != null && flasher.length > 0)
			updateFxFlash();

		if (Sprite.spriteList.length > 0) {
			var l = Sprite.spriteList.copy();
			for (s in l) {
				s.update();
			}
		}

		if (!stopScroll) {
			scrollDots();
		}

		switch (step) {
			case 1:
				var dot = dotter.getFirst();

				if (dot.x < Const.START) {
					if (startCycle-- <= 0) {
						dot.started = true;
						dot.ready = true;
						mcStart._visible = !mcStart._visible;
						startCycle = 10;
					}
				} else {
					var p = new Phys(mcStart);
					p.timer = 15;
					p.fadeType = 4;
					start = true;
					Const.DOT_X_SPEED = 0;
					step = 2;
				}
			case 2:
				scrollObjects();
				scrollBonus();

				var dotMod = Math.max(dotter.getReady().length, 1);
				addScore(Math.ceil(KKApi.val(Const.SPEED) / 100 * bonus * dotMod));
				var xfactor = bonus + dotMod - 1;
				if (xfactor <= 0)
					ui.setFactor("-");
				else if (xfactor < 1)
					ui.setFactor("1");
				else
					ui.setFactor(Std.string(xfactor).substr(0, 3));

			case 3:
				stopScroll = true;
				gameOver = true;
		}

		if (mainCycle-- <= 0) {
			if (KKApi.val(Const.MINADD) < Const.WIDTH - 45)
				Const.MINADD = KKApi.const(KKApi.val(Const.MINADD) + 3);

			Const.VSCROLL = KKApi.const(KKApi.val(Const.VSCROLL) + 1);
			Const.BASESPEED = KKApi.const(Math.round(KKApi.val(Const.BASESPEED) + 2));
			scroll = Math.round(KKApi.val(Const.BASESPEED) / 10);
			mainCycle = KKApi.val(Const.MAINCYCLE);
		}

		if (gameOver && !signalSent) {
			#if debug
			// test harness: state of the game at its end (compared between a game and its replay)
			untyped js.Browser.window.__over = {
				frame: frameCount,
				score: KadoKadeoManager.kkm.score.get(),
				lines: PLines,
				bonus: PBonus,
				hit: Phit,
				camper: camper,
				objects: objects.length,
				scroll: scroll,
				theme: colorTheme
			};
			#end
			KadoKadeoManager.kkm.gameOver({
				Phit: Phit,
				PBonus: PBonus,
				PLines: PLines,
				PCamper: camper
			});
			signalSent = true;
		}

		if (keyPressed-- <= 0) {
			keyPressed = -1;
		}
	}

	function addScore(n:Int) {
		if (!signalSent)
			KadoKadeoManager.kkm.addScore(n);
	}

	function scrollDots() {
		dotter.updateSpeed(Const.DOT_X_SPEED, Const.DOT_Y_SPEED);

		var me = this;
		var cbk = function(d:DOT) {
			me.score(d.x, d.y, "mcLineScore", me.dotter.getLength() - 1);
			me.addDotToUI(d.color);
		}

		dotter.update(Math.ceil(KKApi.val(Const.BASE_DOT_RIGHT_SPEED) / 5), Math.ceil(KKApi.val(Const.BASE_DOT_DOWN_SPEED) / 5), scroll, cbk);

		var first = dotter.getFirst();

		// no line left (the frame after the last one broke): first.x is undefined, tx NaN, and the compiled
		// `tx >= threshold` is !(tx < threshold): true, the x8 zone lights up
		var tx:Float = first == null ? Math.NaN : first.x + scroll;
		// On check si la première ligne est dans une zone de bonus
		if (!(tx < KKApi.val(Const.BONUSX4_THRESHOLD))) {
			bonus = KKApi.val(Const.BONUSX4);
			bonus2._visible = true;
			bonus3._visible = true;
			bonus4._visible = true;
		} else if (tx >= KKApi.val(Const.BONUSX3_THRESHOLD)) {
			bonus = KKApi.val(Const.BONUSX3);
			bonus2._visible = true;
			bonus3._visible = true;
			bonus4._visible = false;
		} else if (tx >= KKApi.val(Const.BONUSX2_THRESHOLD)) {
			bonus = KKApi.val(Const.BONUSX2);
			bonus2._visible = true;
			bonus3._visible = false;
			bonus4._visible = false;
		} else {
			bonus = 1;
			bonus2._visible = false;
			bonus3._visible = false;
			bonus4._visible = false;
		}
	}

	function scrollBonus() {
		for (i in 0...abonus.length) {
			var b = abonus[i];

			if (b == null) {
				// past the end of the list after a removal: undefined in Flash, only the counter below changes
				if (bcycle-- <= 0)
					bcycle = Const.BONUS_GLOW;
				continue;
			}

			b.x -= scroll;
			b._x = b.x;

			var dy = KKApi.val(Const.VSCROLL) / 10;
			b.y += dy - (if (dotter.cannotGoY) 0 else Const.DOT_Y_SPEED);
			b._y = b.y;

			if (b.x + b._width < -5) {
				lastWasBonus = false;
				abonus.remove(b);
				b.removeMovieClip();
			}

			if (b.hit)
				continue;

			if (bcycle-- <= 0) {
				b.gotoAndStop(if (b._currentframe == 1) 2 else 1);
				bcycle = Const.BONUS_GLOW;
			}

			var mult = 0;

			var linked = dotter.getStarted();
			var first = linked[0];
			if (first != null && first.x > b.x + b._width) {
				// the lines went past it: the stars taken are scored
				if (b.taken > 0) {
					scoreBonus(b);
					continue;
				}
				var ph = new Phys(b);
				ph.timer = 10;
				ph.fadeType = 5;
				ph.vx = -scroll;
				abonus.remove(b);
				continue;
			}

			for (d in linked) {
				if (b.x - d.x > 3)
					continue;

				if (hit2(b, b.b1, d.x, d.y) && !b.b1.hit) {
					removeBonus(b.b1, b);
					mult++;
				}
				if (hit2(b, b.b2, d.x, d.y) && !b.b2.hit) {
					removeBonus(b.b2, b, 1);
					mult++;
				}
				if (hit2(b, b.b3, d.x, d.y) && !b.b3.hit) {
					removeBonus(b.b3, b, 2);
					mult++;
				}
				if (hit2(b, b.b4, d.x, d.y) && !b.b4.hit) {
					removeBonus(b.b4, b, 3);
					mult++;
				}

				b.hitX = d.x;
				b.hitY = d.y;
			}

			// the original scored the bonus on the first frame a star was taken and ignored the stars the other lines
			// reached on the next frames: they add up until the 4 are taken or the lines go past it
			b.taken += mult;
			if (b.taken >= 4)
				scoreBonus(b);
		}
	}

	function scoreBonus(b:BONUS) {
		b.hit = true;

		if (b.taken >= 4) {
			score(b.hitX, b.hitY - 50, "mcBonusCombo", KKApi.val(Const.BONUS_COMBO));
			var s = KKApi.val(Const.BONUS_COMBO);
			PBonus += s;
			addScore(s);
			return;
		}

		score(b.hitX, b.hitY - 50, "mcBonusScore", KKApi.val(Const.BASE_SCORE), b.taken, 20);
		var s = KKApi.val(Const.BASE_SCORE) * b.taken;
		PBonus += s;
		addScore(s);
	}

	function removeBonus(mc:Hit, b:BONUS, sleep = 0) {
		mc.hit = true;
		var parts = "bpart" + colorKey(b.color);
		var n = Tex.get(parts).length;
		var a = 360 / n;

		for (i in 1...n) {
			// Col.setColor(part, b.color) and its GlowFilter of the same colour: baked in the picture
			var part = dm.attach(parts, Const.DP_BONUS);
			part.gotoAndStop(i + 1);
			part._x = mc._x + b._x;
			part._y = mc._y + b._y;
			var p = new Phys(part);
			p.timer = 13;
			var an = (i + 1) * a;
			p.x = part._x + mt.white.Geom.cos(an) * 1;
			p.y = part._y + mt.white.Geom.sin(an) * 1;
			p.vx = mt.white.Geom.cos(an) * 5;
			p.vy = mt.white.Geom.sin(an) * 5;
			p.weight = 1.02;
			p.sleep = sleep;
		}
		var p = new Phys(mc);
		p.timer = 5;
	}

	function score(x:Float, y:Float, name:String, score:Int, mult:Int = 0, sleep = 0) {
		var b = dm.add(new BonusScore(name, score, mult), Const.DP_UI);
		b._x = x;
		b._y = y;
		var col = Const.OBJECTS_COLOR[colorTheme][Seed.randomVfx(Const.OBJECTS_COLOR[colorTheme].length)];
		// GlowFilter(Col.brighten(col, 90), 80, 2, 2, 5)
		b.glow.setColor(Col.brighten(col, 90));
		var p = new Phys(b);
		p.timer = 15;
		p.fadeType = 4;
		p.vy = -1.2;
		p.sleep = sleep;
	}

	function scrollObjects() {
		if (objects.length <= 0) {
			addObject();
			return;
		}

		for (i in 0...objects.length) {
			var p = objects[i];

			if (p == null) {
				objects.remove(p);
				continue;
			}

			if (p.line) {
				if (Const.DOTCOLORS[colorTheme].length <= 0) {
					objects.remove(p);
					p.removeMovieClip();
					continue;
				}

				// Animation
				if (ocycle-- <= 0) {
					p.gotoAndStop(if (p._currentframe == 1) 2 else 1);
					ocycle = Const.BONUS_GLOW;
				}
			}

			var linked = dotter.getStarted();
			// no line left (the last one broke on a previous object of this frame): first.x is undefined in Flash, the
			// test below is false and the collision loop has nothing to do
			var first = linked[0];
			if (first != null && first.x > p.x + p._width) {
				if (camper > Const.CAMPER)
					p.gotoAndStop(4);

				var ph = new Phys(p);
				ph.timer = 15;
				ph.fadeType = 5;
				ph.fadeLimit = 5;
				ph.vx = -scroll;
				objects.remove(p);
				continue;
			}

			if (first != null && (p.x - first.x) <= 1 && first.x <= p.x + p._width) {
				for (d in linked) {
					if (camper > Const.CAMPER) {
						var centerX = p.x + p._width / 2;
						var centerY = p.y + p._height / 2;
						var dx = centerX - d.x;
						var dy = centerY - d.y;
						if (Math.sqrt(dx * dx + dy * dy) < p._width * 3) {
							p.gotoAndStop(3);
						}
					}

					if (!d.started)
						continue;
					if (!hit(p, d.x, d.y))
						continue;

					if (p.line) {
						if (Const.DOTCOLORS[colorTheme].length > 0 && !p.lineDone) {
							p.lineDone = true;
							dotter.addDot(Const.DOTCOLORS[colorTheme].pop());
							PLines++;
							objects.remove(p);
							var ph = new Phys(p);
							ph.timer = 10;
							ph.fadeLimit = 20;
							ph.fadeType = 3;
							continue;
						}

						var ph = new Phys(p);
						ph.timer = 10;
						ph.fadeType = 3;
						continue;
					}

					Const.DOTCOLORS[colorTheme].push(d.color);
					fxShake(3);
					if (!d.ready)
						lastWasBonus = false;
					dotter.remove(d.uid);
					removeUIDot(d.color);
					fxFlash(p, 100, 0.8, d.color);
					if (dotter.getLength() <= 0) {
						step = 3;
					}
					Phit++;
					d.stopped = true;
					blowLine(d.x, d.y, d.color);
				}
			}

			if (p.x <= KKApi.val(Const.MINADD) && !p.added) {
				p.added = true;
				addObject();
				f = 0;
			}

			if (p.x + p._width < -5) {
				if (p.line)
					lastWasBonus = false;
				objects.remove(p);
				p.removeMovieClip();
			}

			p.x -= scroll;
			p._x = p.x;
			f += scroll;

			if (p.vscroll > 0) {
				var th = p.y + p._height;
				if (th >= Const.HEIGHT - Const.MARGIN) {
					p.vscroll = -p.vscroll;
				}
			}

			if (p.vscroll < 0) {
				if (p.y <= Const.MARGIN)
					p.vscroll = -p.vscroll;
			}

			var dy = p.vscroll * KKApi.val(Const.VSCROLL) / 10;
			p.y += dy - (if (dotter.cannotGoY) 0 else Const.DOT_Y_SPEED);
			p._y = p.y;
		}
	}

	function hit2(root:MC, mc:MC, x:Float, y:Float) {
		var dx = root._x + mc._x - x;
		var dy = root._y + mc._y - y;
		return Math.sqrt(dx * dx + dy * dy) < 8;
	}

	function hit(mc:OBJECT, x:Float, y:Float) {
		if (mc.line) {
			var dx = x - mc.x;
			var dy = y - mc.y;
			return Math.sqrt(dx * dx + dy * dy) < 15;
		}

		if (x < mc._x)
			return false;
		if (x > mc._x + mc._width)
			return false;
		return y >= mc._y && y <= mc._y + mc._height;
	}

	// drawRectangle(s, 20, 5, Col.darken(color, 50), 100, color, 100, 1): fill and 1 px stroke
	function addDotToUI(color:Int) {
		var w = 20;
		var s = dm.add(new EMC(), Const.DP_UI);
		s.attach(new MC("uidotFill")).setColor(Col.darken(color, 50));
		s.attach(new MC("uidotLine")).setColor(color);
		s._y = 7.5;
		s._x = 10 + uidots.length * w + 5;
		s.color = color;
		uidots.push(s);
	}

	function removeUIDot(color) {
		for (u in uidots) {
			if (color == u.color) {
				uidots.remove(u);
				var p = new Phys(u);
				p.timer = 20;
				p.fadeType = 4;
			}
		}
		for (i in 0...uidots.length) {
			var u = uidots[i];
			u._x = 10 + i * 20 + 5;
		}
	}

	// Explosion de la ligne en cas de collision
	function blowLine(x:Float, y:Float, color:Int) {
		var r = 2;
		var max = 10;
		var a = 360 / max;
		for (j in 0...4) {
			for (i in 0...max) {
				var o = dm.attach("part", Const.DP_DOT);
				// Col.setColor(o.smc, color): mcPart has no child named smc, the particles stay white
				var an = a * i;
				o._x = x + mt.white.Geom.cos(an) * (r * j);
				o._y = y + mt.white.Geom.sin(an) * (r * j);
				o._rotation = an;
				var p = new Phys(o);
				p.timer = 20;
				p.vx = mt.white.Geom.cos(an) * (8 / (j + 1)) - (if (step < 3) scroll else 0);
				p.vy = mt.white.Geom.sin(an) * (8 / (j + 1));
			}
		}
	}

	// FX
	var shk:Null<Float>;
	var shkFrict:Float;

	function fxShake(sh:Float, shf = 0.5) {
		shk = sh;
		shkFrict = shf;
		updateFxShake();
	}

	function updateFxShake() {
		root._y = shk;
		shk *= -shkFrict;
		if (Math.abs(shk) < 0.2) {
			root._y = 0;
			shk = null;
		}
	}

	var flasher:List<MC>;

	function fxFlash(mc:MC, flh = 100.0, coef = 0.75, col = 0xFFFFFF) {
		if (flasher == null)
			flasher = new List();
		mc._flhPrc = flh;
		mc._flhCoef = coef;
		mc._flhCol = col;
		mc.setPercentColor(flh, col);
		for (mc2 in flasher)
			if (mc == mc2)
				return;
		flasher.push(mc);
	}

	function updateFxFlash() {
		for (mc in flasher) {
			var prc = mc._flhPrc;
			mc._flhPrc *= mc._flhCoef;
			if (mc._flhPrc < 1) {
				prc = 0;
				flasher.remove(mc);
			}
			// (the flashed square ends without its colour: setPercentColor replaced the one of Col.setColor)
			mc.setPercentColor(prc, mc._flhCol);
		}
	}

	/* ---------------------------------------- OBJECTS --------------------------------------- */
	function square():OBJECT {
		var o = dm.add(new OBJECT("square"), Const.DP_OBJECTS);
		o.setSize(Data.SQUARE_W, Data.SQUARE_H);
		return o;
	}

	function addObject(dx:Float = 0) {
		if (objects.length <= 0) {
			lastX = Const.HEIGHT;
		}

		// A modifier ! Actuellement c'est trop simple : il faut que le block oblige un vrai mouvement
		if (camping > 30) {
			camping = 0;
			camper++;
			// no line left: undefined.y is NaN, and the compiled `y >= ...` is !(y < ...): the first case
			var first = dotter.getFirst();
			var y:Float = first == null ? Math.NaN : first.y;
			var o = square();
			o.gotoAndStop(if (camper > Const.CAMPER) 2 else 1);
			o._x = o.x = lastX;

			if (!(y < Const.HEIGHT - Const.MARGIN - o._height)) {
				y = Math.ceil(Const.HEIGHT - Const.MARGIN - o._height / 2);
			} else if (y > Const.MARGIN + o._height) {
				y = Math.floor(y - o._height / 2);
			} else if (y < Const.MARGIN + o._height) {
				y = Math.floor(Const.MARGIN - o._height / 3);
			}

			o.y = o._y = y;
			o.vscroll = 0;
			o.camper = true;
			var c = Col.brighten(Const.OBJECTS_COLOR[colorTheme][Seed.randomVfx(Const.DOTCOLORS[colorTheme].length)], 80);
			o.setColor(c);
			objects.push(o);
			var n = o.x + o._width * 1.1;
			lastX = n;
			return;
		}

		if (Seed.random(50) == 0 && !lastWasBonus) {
			var o = dm.add(new BONUS(), Const.DP_BONUS);
			o.vscroll = 0;
			o.bx = o._x = o.x = Const.HEIGHT + scroll;
			o.by = o._y = o.y = Const.MARGIN + Seed.random(Math.ceil(Const.HEIGHT - Const.MARGIN * 2 - o._height));
			var c = Const.OBJECTS_COLOR[colorTheme][Seed.randomVfx(Const.DOTCOLORS[colorTheme].length)];
			o.setColor2(c);
			o.bonus = true;
			abonus.push(o);
			lastX = o.x + 5;
			lastWasBonus = true;
			return;
		}

		if (Seed.random(100) <= KKApi.val(Const.LINE_BONUS) && Const.DOTCOLORS[colorTheme].length > 0 && !lastWasBonus) {
			var o = dm.add(new AddlineMC(), Const.DP_BONUS);
			o.gotoAndStop(1);
			o.vscroll = if (Seed.random(2) == 0) -1 else 1;
			o.line = true;
			o._x = o.x = Const.HEIGHT + scroll;
			o._y = o.y = Const.MARGIN + Seed.random(Math.floor(Const.HEIGHT - Const.MARGIN * 2 - o._height));
			objects.push(o);
			lastX = o.x + o._width * 1.5;
			lastWasBonus = true;
			return;
		}

		var o = square();
		o._x = o.x = Const.HEIGHT + scroll * objects.length;
		o.gotoAndStop(if (camper > Const.CAMPER) 2 else 1);
		o.y = o._y = getY(o);
		o.vscroll = if (Seed.random(2) == 0) -1 - camper % 2 else 1 + camper % 2;
		var c = Col.brighten(Const.OBJECTS_COLOR[colorTheme][Seed.randomVfx(Const.DOTCOLORS[colorTheme].length)], 80);
		o.setColor(c);
		objects.push(o);
		var n = o.x + o._width * 1.1;
		lastX = n;
		lastWasBonus = false;
	}

	function getY(o:MC):Float {
		var y = Seed.random(Const.HEIGHT);

		if (y <= Const.MARGIN)
			return Const.MARGIN - 1;
		if (y >= (Const.HEIGHT - Const.MARGIN - o._height)) {
			y = Const.HEIGHT - Const.MARGIN - Math.floor(o._height) + 2;
			return y;
		}
		return y;
	}

	public static function colorKey(col:Int):String {
		return StringTools.hex(col, 6).toLowerCase();
	}

	/* ---------------------------------------- CONTROLS --------------------------------------- */
	public function onKeyDown() {
		if (!start)
			return;

		Const.DOT_Y_SPEED = 0;
		Const.DOT_X_SPEED = 0;
		Const.SPEED = Const.BASESPEED;
		camping++;

		if (KeyboardManager.isDown(KeyboardManager.UP)) {
			Const.DOT_Y_SPEED = getSpeed(KKApi.val(Const.BASE_DOT_UP_SPEED));
			Const.SPEED = Const.MINSPEED;
			if (Const.DOT_X_SPEED != 0)
				camping = 0;
		}
		if (KeyboardManager.isDown(KeyboardManager.DOWN)) {
			Const.DOT_Y_SPEED = getSpeed(KKApi.val(Const.BASE_DOT_DOWN_SPEED));
			Const.SPEED = Const.MINSPEED;
			if (Const.DOT_X_SPEED != 0)
				camping = 0;
		}
		if (KeyboardManager.isDown(KeyboardManager.LEFT)) {
			Const.DOT_X_SPEED = getSpeed(KKApi.val(Const.BASE_DOT_LEFT_SPEED));
			if (Const.DOT_Y_SPEED != 0)
				camping = 0;
		}
		if (KeyboardManager.isDown(KeyboardManager.RIGHT)) {
			Const.DOT_X_SPEED = getSpeed(KKApi.val(Const.BASE_DOT_RIGHT_SPEED));
			if (Const.DOT_Y_SPEED != 0)
				camping = 0;
		}
	}

	function getSpeed(speed:Int) {
		return Math.round(speed / 10);
	}

	public function destroy():Void {
		// every clip, the scene included (and the trail sprite with its plane), then the trail canvas
		MC.clearAll();
		dotter.destroy();
		Sprite.spriteList = [];
		Const.reset();
	}
}

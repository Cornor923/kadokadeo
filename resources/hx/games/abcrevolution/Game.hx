package abcrevolution;

import common_haxe_avm1.KeyboardManager;
import haxe.io.UInt16Array;
import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import pixi.core.sprites.Sprite as PixiSprite;
import pixi.core.textures.RenderTexture;
import pixi.core.textures.Texture;
import pixi.filters.colormatrix.ColorMatrixFilter;

// ABC Revolution (KadoKado, Motion-Twin): ported from the original sources (Manager, Game, Level, Word, Words, Score,
// Teddy, Particules, Dico of the abcrevolution folder) and the graphics of its SWF. Words roll on three shelves from
// the right: type their letters (keyboard, A-Z) before the boxes fall on the teddy bear. The game runs in the Flash
// pixels of the original (300 x 300), drawn x2.

@:expose('GameABCRevolution')
class Game implements kado.GameInterface {
	public static inline var K = 2;

	// the keys of the letters (and the two other keys of M on the keyboards of the original)
	static var LETTER_KEYS = [for (i in 0...26) 65 + i].concat([186, 188]);

	public static var me:Game;

	public var dmanager:Plans;
	public var root:ASprite;
	public var mcs:Array<Mc>;

	var bg:Clip;

	public var teddy:Teddy;
	public var score:Score;
	public var level:Level;
	public var words:Words;
	public var particules:Particules;

	var kflags:Array<Bool>;

	var scene:ASprite;
	var touchKeys:TouchKeys;
	var over:Bool;

	public var frameCount(default, null):Int;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: UInt16Array.fromArray(LETTER_KEYS),
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: UInt16Array.fromArray([]),
		});
		me = this;
		mcs = [];
		over = false;
		frameCount = 0;
		Clip.flushRemoved();

		scene = root.createEmptyMovieClip("scene", 0);
		scene._xscale = scene._yscale = 100 * K;
		scene.updateState();
		this.root = scene.createEmptyMovieClip("world", 0);
		dmanager = new Plans(this.root);

		// Manager.init: new Game(root_mc, [4,2,10,8,5,1,1,3])
		var wtbl = [4, 2, 10, 8, 5, 1, 1, 3];
		bg = dmanager.add(new Clip("bg"), 0);
		teddy = new Teddy(dmanager);
		score = new Score(dmanager, this.root);
		particules = new Particules(dmanager);
		level = new Level(this);
		words = new Words(wtbl);
		kflags = [];

		// a keyboard on the screen for touch screens (it presses the same keys as the real keyboard)
		if (!isReplay && TouchKeys.wanted())
			touchKeys = new TouchKeys(scene);
		warmShaders();
	}

	function isDown(k:Int):Bool {
		if (k == 77)
			return KeyboardManager.isDown(77) || KeyboardManager.isDown(188) || KeyboardManager.isDown(186); // M
		return KeyboardManager.isDown(k);
	}

	// time of the Flash player (getTimer, ms): the frames of the game, so that replays give the same combos
	public function getTimer():Float {
		return frameCount * 1000 / 32;
	}

	// one frame of the Flash player
	public function update(delta:Float) {
		frameCount++;
		Clip.flushRemoved();
		advanceClips();

		if (!over) {
			var codeA = "A".code;
			for (i in 0...26)
				if (isDown(codeA + i)) {
					if (!kflags[i]) {
						kflags[i] = true;
						level.activateKey(codeA + i);
					}
				} else
					kflags[i] = false;

			if (!level.main()) {
				score.finishCombo();
				over = true;
				KadoKadeoManager.kkm.gameOver(score.statsObject());
			}
		}

		teddy.main();
		score.main();
		particules.main();
	}

	public function pollTouchControls():Void {
		if (touchKeys != null)
			touchKeys.poll();
	}

	public function addScore(n:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	function advanceClips() {
		var i = 0;
		var n = mcs.length;
		while (i < n) {
			var m = mcs[i];
			if (m.dead || m.parent == null) {
				mcs[i] = mcs[n - 1];
				mcs.pop();
				n--;
				continue;
			}
			m.advance();
			i++;
		}
	}

	// the red flash of a wrong key is a colour matrix filter: its shader compiled at the start, not during the game
	function warmShaders() {
		var renderer:Dynamic = KadoKadeoManager.kkm.renderer;
		var holder = new Container();
		var s = new PixiSprite(Texture.WHITE);
		s.filters = [new ColorMatrixFilter()];
		holder.addChild(s);
		var rt:RenderTexture = (cast RenderTexture : Dynamic).create({width: 32, height: 32});
		renderer.render(holder, {renderTexture: rt, clear: true});
		holder.destroy({children: true});
		rt.destroy(true);
	}

	public function destroy():Void {
		if (touchKeys != null) {
			touchKeys.dispose();
			touchKeys = null;
		}
		Clip.flushRemoved();
		mcs = [];
	}
}

// ---------------------------------------------------------------- Level
class Level {
	public static inline var NRAILS = 3;
	public static inline var XMIN = 60;
	static inline var BASE_Y = 80;

	var game:Game;

	var rails:Array<Clip>;
	var words:Array<Word>;
	var no_more_words:Bool;
	var multi_probas:Float;

	public function new(g:Game) {
		game = g;
		words = [];
		multi_probas = 10;
		no_more_words = false;
		initLevel();
	}

	function initLevel() {
		rails = [];
		for (i in 0...NRAILS) {
			var b = game.dmanager.add(new Clip("etagere"), 1);
			b.gotoAndStop(3 - i);
			b._x = 300;
			b._y = BASE_Y + i * 60;
			b.updateState();
			rails.push(b);
		}
	}

	public function killWord(w:Word) {
		for (i in 0...NRAILS)
			if (words[i] == w) {
				words[i] = null;
				multi_probas *= Cs.pow(0.05, 1 / game.words.nwords);
				return;
			}
	}

	function addWord() {
		var p = Seed.random(NRAILS);
		if (words[p] != null)
			return;
		var w = game.words.get();
		if (w == null) {
			no_more_words = true;
			return;
		}
		words[p] = new Word(game, w, BASE_Y - 15 + p * 60);
	}

	function keyEqual(k1:Int, k2:Int):Bool {
		if (k1 == k2)
			return true;
		return switch (k2) {
			case 65: (k1 == 81); // A
			case 81: (k1 == 65); // Q
			case 90: (k1 == 87); // Z
			case 87: (k1 == 90); // W
			default: false;
		}
	}

	public function activateKey(k:Int) {
		var n = 0;
		for (i in 0...NRAILS) {
			var w = words[i];
			if (w == null)
				continue;
			var x = w.posX();
			var l = w.currentLetter();
			// (no box on the shelf any more, or the word is not in yet: no letter)
			if (x != null && l != null && keyEqual(k, l.charCodeAt(0))) {
				game.score.validKey(x - XMIN, w.speed);
				w.nextLetter();
				n++;
			}
		}
		if (n == 0)
			game.score.invalidKey();
		else if (n > 1)
			game.score.mixKey(n);
	}

	public function main():Bool {
		var nr = 0;
		for (i in 0...NRAILS)
			if (words[i] != null)
				nr++;

		var r = Std.int(100 * (nr * multi_probas + 0.1) / Timer.tmod);
		if (Seed.random(r) < 3)
			addWord();

		var flag = false;
		for (i in 0...NRAILS) {
			var w = words[i];
			if (w != null)
				w.main();
			// (read again: the word may have left its shelf)
			if (words[i] != null)
				flag = true;
		}
		if (!flag && no_more_words)
			return false;
		return true;
	}
}

// ---------------------------------------------------------------- Word
typedef Falling = {mc:WordBox, speed:Float, grav:Float, reb:Bool};

class Word {
	static var SPEEDS = [1, 1, 1, 1, 1.5, 2, 2, 3, 4];

	var game:Game;

	var mcs:Array<WordBox>;
	var falling:Array<Falling>;
	var word:String;
	var pos:Int;
	var y:Float;

	public var speed:Float;

	var danger_flag:Bool;

	public function new(game:Game, word:String, y:Float) {
		this.game = game;
		this.word = word;
		this.y = y;
		this.pos = 0;
		this.speed = selectSpeed();
		danger_flag = false;
		falling = [];
		initWord();
	}

	function selectSpeed():Float {
		var n = Seed.random(Std.int(SPEEDS.length * 5 / word.length));
		if (n >= SPEEDS.length)
			n = SPEEDS.length - 1;
		return SPEEDS[n];
	}

	function initWord() {
		mcs = [];
		var n = word.length;
		var t = Seed.random(10) + 1;
		for (i in 0...n) {
			var m = game.dmanager.add(new WordBox(), 1);
			m.setColour(1 + Seed.random(WordBox.NCOLOURS));
			m.setLetter(t, word.substr(i, 1).toUpperCase());
			m._x = 310 + i * 23;
			m._y = y;
			m.updateState();
			mcs.push(m);
		}
	}

	public function posX():Null<Float> {
		return mcs.length > 0 ? mcs[0]._x : null;
	}

	public function currentLetter():String {
		if (mcs.length == 0 || mcs[0]._x > 290)
			return null;
		return word.substr(pos, 1).toUpperCase();
	}

	public function nextLetter() {
		var m = mcs[0];
		mcs.remove(m);
		pos++;
		for (i in 0...5)
			game.particules.addWordPart(m._x, m._y, m.colour);
		m.removeMovieClip();
	}

	public function main() {
		var sc = speed;

		if (mcs.length > 0 && mcs[mcs.length - 1]._x > 290)
			sc = 10;

		var i = 0;
		while (i < mcs.length) {
			var m = mcs[i];
			m._x -= sc * Timer.tmod;
			m._y = y + Seed.randomVfx(3) - 1;
			if (!danger_flag && m._x < 80) {
				danger_flag = true;
				game.score.danger();
			}
			if (m._x < Level.XMIN) {
				pos++;
				game.score.falling();
				mcs.remove(m);
				i--;
				falling.push({
					mc: m,
					speed: speed,
					grav: speed,
					reb: false
				});
			}
			i++;
		}
		var i = 0;
		while (i < falling.length) {
			var m = falling[i];
			m.grav += Timer.tmod;
			m.speed *= Math.pow(0.97, Timer.tmod);
			m.mc._x -= m.speed * Timer.tmod;
			m.mc._y += m.grav * Timer.tmod;
			m.mc._rotation -= m.grav * 5 * Timer.tmod;
			if (!m.reb && m.mc._y > 230) {
				game.teddy.hit(m.mc._x, m.mc._y, m.grav);
				m.grav *= -0.6;
				m.reb = true;
			}
			if (m.reb && m.mc._y > 320) {
				falling.remove(m);
				i--;
				m.mc.removeMovieClip();
			}
			i++;
		}
		if (falling.length == 0 && mcs.length == 0)
			game.level.killWord(this);
	}
}

// a "wordbox" of the SWF: the box (frame = its colour, its wheels turning) and the letter in one of the 10 typefaces
// of `typos` (text field t)
class WordBox extends ASprite {
	public static inline var NCOLOURS = 6;

	public var colour(default, null):Int;

	var box:Clip;

	public function new() {
		super();
		box = new Clip("wordbox");
		addChild(box);
		colour = 1;
	}

	public function setColour(f:Int) {
		colour = f;
		box.gotoAndStop(f);
	}

	public function setLetter(typo:Int, letter:String) {
		var k = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".indexOf(letter);
		if (k < 0)
			return;
		var t = new Mc("typo" + typo, false);
		t.gotoAndStop(k + 1);
		t.updateState();
		addChild(t);
	}
}

// ---------------------------------------------------------------- Words
class Words {
	var tbl:Array<String>;

	public var nwords(default, null):Int;

	public function new(lens:Array<Int>) {
		Dico.init();

		tbl = [];
		for (i in 0...lens.length) {
			var n = lens[i];
			while (n > 0) {
				var w = generate(i + 2);
				if (w != null)
					tbl.push(w);
				n--;
			}
		}
		nwords = tbl.length;
	}

	function generate(l:Int):String {
		var max = Dico.LENGTHS[l].length;
		var n = Seed.random(max);
		return Dico.LENGTHS[l][n];
	}

	public function get():String {
		var n = Seed.random(tbl.length);
		var w = tbl[n];
		tbl.splice(n, 1);
		return w;
	}
}

// ---------------------------------------------------------------- Teddy
class Teddy {
	var mc:Clip;
	var mc2:Clip;
	var timer:Float;

	public function new(dman:Plans) {
		mc = dman.add(new Clip("teddy"), 1);
		mc2 = dman.add(new Clip("teddy"), 1);
		mc.gotoAndStop(1);
		mc2.gotoAndStop(2);
		mc._x = 20;
		mc._y = 230;
		mc2._x = mc._x;
		mc2._y = mc._y;
		mc2._visible = false;
		mc.updateState();
		mc2.updateState();
		timer = 0;
	}

	public function main() {
		if (timer > 0) {
			timer -= Timer.deltaT;
			if (timer <= 0) {
				mc._visible = true;
				mc2._visible = false;
			}
		}
	}

	public function hit(x:Float, y:Float, g:Float) {
		timer = 0.3;
		mc._visible = false;
		mc2._visible = true;
	}
}

// ---------------------------------------------------------------- Particules
typedef Part = {
	mc:Clip,
	x:Float,
	y:Float,
	a:Float,
	vx:Float,
	vy:Float,
	va:Float,
	ax:Float,
	ay:Float,
	f:Float
};

class Particules {
	var dmanager:Plans;
	var tbl:Array<Part>;

	public function new(dman:Plans) {
		dmanager = dman;
		tbl = [];
	}

	function randAngle():Float {
		return (Seed.randomVfx(3600) / 10) / (Math.PI * 2);
	}

	public function addWordPart(x:Float, y:Float, f:Int) {
		var mc = dmanager.add(new Clip("particule"), 2);
		var s = Seed.randomVfx(30) - 15;
		mc.gotoAndStop(f);
		mc._x = x;
		mc._y = y;
		mc.updateState();
		tbl.push({
			mc: mc,
			x: x,
			y: y,
			a: randAngle(),
			vx: s,
			vy: -(Seed.randomVfx(5) + 10),
			va: s,
			ax: 0,
			ay: 1,
			f: 0.97
		});
	}

	public function main() {
		var i = 0;
		while (i < tbl.length) {
			var p = tbl[i];
			var f = Math.pow(p.f, Timer.tmod);
			p.vx *= f;
			p.vy *= f;
			p.vx += p.ax;
			p.vy += p.ay;
			p.x += p.vx;
			p.y += p.vy;
			p.a += p.va;
			p.mc._x = p.x;
			p.mc._y = p.y;
			p.mc._rotation = p.a * 180 / Math.PI;
			if (p.x < -100 || p.x > 400 || p.y < -100 || p.y > 400) {
				p.mc.removeMovieClip();
				tbl.splice(i, 1);
				i--;
			}
			i++;
		}
	}
}

// ---------------------------------------------------------------- Score
typedef Announce = {
	mc:AnnounceMc,
	z:Float,
	a:Float,
	zmin:Float,
	zmax:Float,
	zway:Bool,
	time:Float,
	frame:Int,
	slot:Int
};

class Score {
	static inline var C1000 = 1000;
	static inline var C100 = 100;
	static inline var C10 = 10;

	var dmanager:Plans;
	var nmiss:Int;
	var ncombos:Int;
	var combo:Announce;
	var lastKey:Float;

	var slots:Array<Bool>;
	var announces:Array<Announce>;

	var target:ASprite;
	var color:ColorMatrixFilter;
	var flash_time:Float;

	// stats of the original ($f falls, $i wrong keys, $m mixes, $c Bouh / OK / Great / Perfect, $k combos)
	var st_f:Int;
	var st_i:Int;
	var st_m:Int;
	var st_c:Array<Int>;
	var st_k:Array<Int>;

	public function new(dman:Plans, root:ASprite) {
		dmanager = dman;
		st_f = 0;
		st_i = 0;
		st_m = 0;
		st_c = [0, 0, 0, 0];
		st_k = [];
		// new Color(dmanager.getMC()): the colour transform of the whole game
		target = root;
		color = new ColorMatrixFilter();
		flash_time = 0;
		slots = [];
		announces = [];
		nmiss = 0;
		ncombos = 0;
		lastKey = -1e9;
	}

	public function statsObject():Dynamic {
		var o = {};
		Reflect.setField(o, "$f", st_f);
		Reflect.setField(o, "$i", st_i);
		Reflect.setField(o, "$m", st_m);
		Reflect.setField(o, "$c", st_c);
		Reflect.setField(o, "$k", st_k);
		return o;
	}

	inline function addScore(n:Int) {
		Game.me.addScore(n);
	}

	public function falling() {
		st_f++;
		addScore(-C100);
		display(7, 0.9, 1.1);
	}

	public function invalidKey() {
		st_i++;
		nmiss++;
		if (nmiss > 6)
			nmiss = 6;
		flash_time = 1;
		addScore(-Std.int(nmiss * C10));
		display(8, 0.8, 1.2);
	}

	public function validKey(dist:Float, speed:Float) {
		var d = dist * Math.sqrt(speed);

		addScore(Std.int(d));
		if (d < 80) {
			st_c[0]++;
			display(2, 0.95, 1.05); // Bouh
		} else if (d < 250) {
			st_c[1]++;
			display(3, 0.9, 1.1); // OK
		} else if (d < 300) {
			st_c[2]++;
			display(4, 0.85, 1.15); // Great
		} else {
			st_c[3]++;
			display(5, 0.8, 1.2); // Perfect
		}

		var time = Game.me.getTimer();
		if (time - lastKey < 180 || combo != null) {
			ncombos++;
			display(6, 0.8, 1.2);
			combo.mc.setCombo(ncombos);
		}
		lastKey = time;
	}

	public function mixKey(n:Int) {
		st_m++;
		addScore(C1000 * n);
		display(9, 0.8, 1.2); // mix
	}

	public function danger() {
		display(1, 0.9, 1.1);
	}

	function display(frame:Int, zmin:Float, zmax:Float) {
		var is_combo = (frame == 6);

		if (is_combo && combo != null) {
			combo.time = -1;
			return;
		}

		var i = announces.length - 1;
		while (i >= 0) {
			if (announces[i].frame == frame) {
				announces[i].time = -1;
				return;
			}
			i--;
		}

		var mc = dmanager.add(new AnnounceMc(), 1);
		var slot = 0;
		if (is_combo) {
			mc._x = 250;
			mc._y = 260;
			slot = -1;
		} else {
			while (slots[slot])
				slot++;
			slots[slot] = true;
			mc._x = 260 - slot * 40;
			mc._y = 30;
		}
		mc.show(frame);
		var a:Announce = {
			mc: mc,
			frame: frame,
			z: zmin,
			zmin: zmin,
			zmax: zmax,
			zway: true,
			a: 0,
			time: -1,
			slot: slot
		};
		mc._xscale = mc._yscale = a.z * 100;
		mc._alpha = 0;
		mc.updateState();
		if (is_combo)
			combo = a;
		announces.push(a);
	}

	public function finishCombo() {
		combo = null;
		if (ncombos > 0) {
			st_k.push(ncombos);
			addScore(ncombos * C100);
		}
		ncombos = 0;
	}

	public function main() {
		if (flash_time > 0) {
			flash_time -= Timer.tmod / 10;
			if (flash_time < 0) {
				flash_time = 0;
				target.filters = null;
			} else {
				// setTransform: red offset 100 * flash_time (of 255)
				color.matrix = [
					1,
					0,
					0,
					0,
					Std.int(100 * flash_time) / 255,
					0,
					1,
					0,
					0,
					0,
					0,
					0,
					1,
					0,
					0,
					0,
					0,
					0,
					1,
					0
				];
				target.filters = [color];
			}
		}

		var i = 0;
		while (i < announces.length) {
			var a = announces[i];
			if (a.time == -1) {
				a.a += 30 * Timer.tmod;
				if (a.a >= 100)
					a.time = 0.2;
			} else if (a.time > 0)
				a.time -= Timer.deltaT;
			else {
				a.a -= 30 * Timer.tmod;
				if (a.a <= 0) {
					if (a == combo)
						finishCombo();
					a.mc.removeMovieClip();
					if (a.slot >= 0)
						slots[a.slot] = false;
					announces.splice(i, 1);
					i--;
				}
			}
			if (a.zway) {
				a.z += 0.03 * Timer.tmod;
				if (a.z > a.zmax) {
					a.z = a.zmax;
					a.zway = false;
				}
			} else {
				a.z -= 0.03 * Timer.tmod;
				if (a.z < a.zmin) {
					a.z = a.zmin;
					a.zway = true;
				}
			}
			a.mc._xscale = a.z * 100;
			a.mc._yscale = a.z * 100;
			// (Flash shows an _alpha over 100 as 100)
			a.mc._alpha = Math.max(0, Math.min(100, a.a));
			i++;
		}
	}
}

// "announce" of the SWF (frame = the message) and its field t (number of the combo, frame 6): the field is at depth 4,
// under the white "COMBO" of depth 5 (the last layer of the clip on that frame)
class AnnounceMc extends ASprite {
	var clip:Clip;
	var field:Digits;

	public function new() {
		super();
		clip = new Clip("announce");
		addChild(clip);
	}

	public function show(frame:Int) {
		clip.gotoAndStop(frame);
		if (frame == 6 && field == null) {
			field = new Digits(Data.COMBO_FIELD, "comboGlyph", Data.COMBO_CHARS, Data.COMBO_ADV, Data.COMBO_ASC, true);
			// (inside a clip: its pixels, K x its resolution per Flash pixel)
			field._xscale = field._yscale = 100 * Game.K * clip.def.r;
			field.updateState();
			clip.addChildAt(field, clip.children.length - 1);
		}
	}

	public function setCombo(n:Int) {
		if (field != null)
			field.setText(Std.string(n));
	}
}

// text of a field drawn with the glyphs of the SWF font ([left, width, top] of the field, centred or left aligned)
class Digits extends ASprite {
	var field:Array<Float>;
	var anim:String;
	var chars:String;
	var adv:Array<Float>;
	var asc:Float;
	var centred:Bool;
	var text:String;

	public function new(field:Array<Float>, anim:String, chars:String, adv:Array<Float>, asc:Float, centred:Bool) {
		super();
		this.field = field;
		this.anim = anim;
		this.chars = chars;
		this.adv = adv;
		this.asc = asc;
		this.centred = centred;
		text = null;
	}

	public function setText(s:String) {
		if (s == text)
			return;
		text = s;
		removeChildren();
		var width = 0.0;
		var space = adv[0] * 0.3;
		for (i in 0...s.length) {
			var k = chars.indexOf(s.charAt(i));
			width += k >= 0 ? adv[k] : space;
		}
		var pen = centred ? field[0] + (field[1] - width) / 2 : field[0];
		var base = field[2] + asc;
		for (i in 0...s.length) {
			var k = chars.indexOf(s.charAt(i));
			if (k < 0) {
				pen += space;
				continue;
			}
			var g = new Mc(anim, false);
			g.gotoAndStop(k + 1);
			g._x = pen;
			g._y = base;
			g.updateState();
			addChild(g);
			pen += adv[k];
		}
	}
}

// ---------------------------------------------------------------- touch screens
// The original is played with the keyboard. On a touch screen, a keyboard (AZERTY, like the French site) at the
// bottom of the game: a key touched is pressed like a key of the real keyboard (queued for the next frame of the game,
// held at least one frame), so that replays are the same.
class TouchKeys extends ASprite {
	static var ROWS = ["AZERTYUIOP", "QSDFGHJKLM", "WXCVBN"];
	static inline var KW = 29;
	static inline var KH = 21;
	static inline var GAP = 1;
	static inline var TOP = 300 - 3 * (KH + GAP);

	var keys:Array<{
		code:Int,
		x:Float,
		y:Float,
		g:Graphics
	}>;
	var held:Map<Int, Int>;
	var ops:Array<{code:Int, down:Bool}>;
	var sent:Map<Int, Bool>;
	var canvas:js.html.CanvasElement;

	public static function wanted():Bool {
		var nav:Dynamic = js.Browser.navigator;
		var touch = nav.maxTouchPoints != null && nav.maxTouchPoints > 0;
		var coarse = js.Browser.window.matchMedia != null && js.Browser.window.matchMedia("(pointer: coarse)").matches;
		return touch && coarse;
	}

	public function new(parent:ASprite) {
		super();
		parent.addChild(this);
		keys = [];
		held = new Map();
		ops = [];
		sent = new Map();
		for (r in 0...ROWS.length) {
			var row = ROWS[r];
			var x0 = (300 - row.length * (KW + GAP) + GAP) / 2;
			for (i in 0...row.length) {
				var c = row.charAt(i);
				var x = x0 + i * (KW + GAP);
				var y = TOP + r * (KH + GAP);
				var g = new Graphics();
				g.beginFill(0xFFFFFF, 0.55);
				g.lineStyle(1, 0x5A3E8C, 0.8);
				g.drawRoundedRect(x, y, KW, KH, 4);
				g.endFill();
				addChild(g);
				var l = new Mc("typo1", false);
				l.gotoAndStop("ABCDEFGHIJKLMNOPQRSTUVWXYZ".indexOf(c) + 1);
				l._x = x + KW / 2;
				l._y = y + KH / 2;
				l.updateState();
				addChild(l);
				keys.push({
					code: c.charCodeAt(0),
					x: x,
					y: y,
					g: g
				});
			}
		}
		canvas = KadoKadeoManager.kkm.canvas;
		canvas.addEventListener("pointerdown", onDown);
		canvas.addEventListener("pointerup", onUp);
		canvas.addEventListener("pointercancel", onUp);
	}

	function keyAt(e:js.html.PointerEvent):Int {
		var r = canvas.getBoundingClientRect();
		if (r.width <= 0 || r.height <= 0)
			return -1;
		// canvas 600 x 640: the game is the 600 x 600 top, 2 px per Flash pixel (the logical size: canvas.width is the size
		// of the picture, devicePixelRatio and the size on the screen included)
		var screen = KadoKadeoManager.kkm.screen;
		var x = (e.clientX - r.left) * screen.width / r.width / Game.K;
		var y = (e.clientY - r.top) * screen.height / r.height / Game.K;
		for (i in 0...keys.length) {
			var k = keys[i];
			if (x >= k.x - GAP && x < k.x + KW + GAP && y >= k.y - GAP && y < k.y + KH + GAP)
				return i;
		}
		return -1;
	}

	function onDown(e:js.html.PointerEvent) {
		var i = keyAt(e);
		if (i < 0)
			return;
		// ANTI CHEAT: the touches of the player only (their time is the one of the virtual key)
		if (Math.isNaN(common_haxe_avm1.kac.Natives.takeInput(e)))
			return;
		e.preventDefault();
		var prev = held.get(e.pointerId);
		if (prev != null)
			release(e.pointerId);
		held.set(e.pointerId, i);
		keys[i].g.alpha = 0.4;
		ops.push({code: keys[i].code, down: true});
	}

	function onUp(e:js.html.PointerEvent) {
		if (held.exists(e.pointerId))
			release(e.pointerId);
	}

	function release(id:Int) {
		var i = held.get(id);
		held.remove(id);
		keys[i].g.alpha = 1;
		ops.push({code: keys[i].code, down: false});
	}

	// before each frame of the game: the keys touched since the last one
	public function poll() {
		var later = [];
		var downNow = new Map<Int, Bool>();
		for (op in ops) {
			if (op.down) {
				if (later.length > 0) {
					later.push(op);
					continue;
				}
				KeyboardManager.queueVirtualKeyDown(op.code);
				downNow.set(op.code, true);
				sent.set(op.code, true);
			} else {
				// a key touched and released during the same frame stays down for this frame
				if (downNow.exists(op.code) || later.length > 0) {
					later.push(op);
					continue;
				}
				KeyboardManager.queueVirtualKeyUp(op.code);
				sent.remove(op.code);
			}
		}
		ops = later;
	}

	public function dispose() {
		canvas.removeEventListener("pointerdown", onDown);
		canvas.removeEventListener("pointerup", onUp);
		canvas.removeEventListener("pointercancel", onUp);
		for (code in sent.keys())
			KeyboardManager.queueVirtualKeyUp(code);
		removeMovieClip();
	}
}

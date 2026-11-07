package pioutch;

import common_haxe_avm1.KeyboardManager;
import haxe.io.UInt16Array;
import kado.TouchControlsConfig.TouchControlsMode;
import mt.DepthManager;
import kado.TouchControlsConfig.TouchButtonShape;

// a bird shot by the magic gate: speed (dx, dy), spin (k) and colour (type: 0 = 200 points, 1 = 500, 2 = 3000,
// 3 = one more fury)
private typedef Piou = {mc:Clip, dx:Float, dy:Float, k:Float, type:Int};

// a particle moved by the code (dx, dy: speed or spin)
private typedef Part = {mc:Clip, dx:Float, dy:Float};

// Pioutch: port of the original sources (KadoKado, Game.mt) on the released SWF (pioucanon.swf).
// The hero runs left and right with a pillow and bounces the birds shot by the magic gate to the crate; Space
// releases a fury (3 at the start, the orange birds give more) that throws all the birds up.
@:expose('GamePioutch')
class Game implements kado.GameInterface {
	// mobile: left / right buttons + fury button
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
				id: "fury",
				label: "✴",
				rightPx: 14,
				bottomPx: 14,
				size: 84,
				keyCode: KeyboardManager.SPACE,
			},
		],
	};

	// QD / AD move like the arrows, Enter releases the fury like Space
	public static var KEY_ALIASES = KeyboardManager.ALIASES_MOVE.concat(KeyboardManager.ALIASES_ENTER_SPACE);

	static inline var PLAN_BG1 = 0;
	static inline var PLAN_PARTBIRD = 1;
	static inline var PLAN_BG2 = 2;
	static inline var PLAN_CAISSE = 3;
	static inline var PLAN_HERO = 4;
	static inline var PLAN_PIOU = 5;
	static inline var PLAN_PART = 6;
	static inline var PLAN_BG3 = 7;
	static inline var PLAN_INTERF = 8;

	// game play
	static var SIMULTANOUS = [0, 4, 30, 100, 200];
	static var INIT_LIFE = KKApi.const(5);
	static var INIT_SPECIAL = KKApi.const(3);
	static var POINTS = KKApi.aconst([200, 500, 3000]);
	static var TYPE_PROBAS = [50, 10, 1, 1];

	// game feeling
	static inline var ACC = 1.3;
	static inline var FRIC = 0.65;
	static inline var GRAVITY = 0.95;
	static inline var MINSPEED = 2;
	static inline var MAXSPEED = 7;
	static inline var PIOUSPEED = 0.9;

	// gfx
	static inline var REPEAT = 10;
	static inline var MINX = 10;
	static inline var MAXX = 228;
	static inline var MIDDLEX = (MINX + MAXX) / 2;
	static inline var INIT_FRAMES = 4;
	static inline var MAXY = 295;
	static inline var HIGHY = 70;
	static inline var SAVEX = 275;
	static inline var SAVEY = 200;
	static inline var BASEGATE = 145;

	// instance names of the released SWF (obfuscated): hero.sub, hero.sub.sub (idle), its pillow c, head h
	static inline var SUB = "0tJ";
	static inline var PILLOW = "*";
	static inline var HEAD = "1";

	var dm:DepthManager;
	var scene:ASprite;
	var hero:Clip;
	var magicGate:Clip;
	var gateSub:ASprite;
	var shadowGate:Clip;
	var caisse:Clip;
	var bug:Clip;
	var hanim:Float;
	var hspeed:Float;
	var hx:Float;
	var dir:Int;
	var shakeY:Float;
	var shakeFact:Float;
	var rootY:Float;
	var gateY:Float;
	var cooldown:Int;
	var bugProb:Int;
	var timer:Float;
	var speed:Float;
	var furie:Bool;
	var head_pos:Float;
	var parts:Array<Part>;
	var partsP:Array<Part>;
	var partsBird:Array<Part>;
	var partsBug:Array<Part>;
	var partsBlob:Array<Clip>;
	var splatches:Array<Clip>;
	var pious:Array<Piou>;
	var statC:Int;
	var statS:Int;
	var statL:Int;
	// for the achievements: the furies used, the birds lost by type, the score at the first bird lost or the first fury
	// (-1: neither), the most furies held at once
	var statF:Int;
	var statLT:Array<Int>;
	var statFS:Int;
	var statMF:Int;

	var lifeIcons:Array<Clip>;
	var specialIcons:Array<Clip>;
	var lifeCount:KKConst;
	var specialCount:KKConst;
	var pressSpace:Bool;
	var bg:Clip;
	var bg2:Clip;
	var bg3:Clip;
	var cl1:Clip;

	#if debug
	// test harness: the snail in every game
	public static var FORCE_BUG = false;
	#end

	var over:Bool;
	var noInput:Bool;
	var isReplay:Bool;
	var frameCount:Int;

	public function new(root:ASprite, ?isReplay:Bool = false) {
		this.isReplay = isReplay;
		var replayKeys = new UInt16Array(3);
		replayKeys[0] = KeyboardManager.LEFT;
		replayKeys[1] = KeyboardManager.RIGHT;
		replayKeys[2] = KeyboardManager.SPACE;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: false,
			recordedMouseButtons: new UInt16Array(0),
		});
		Clip.clearLater();
		over = false;
		frameCount = 0;

		// the game runs in the Flash pixels of the original (300 x 300), drawn x2
		scene = root.createEmptyMovieClip("scene", 0);
		scene._xscale = scene._yscale = 100 * Clip.K;
		scene.updateState();
		dm = new DepthManager(scene);

		bg = Clip.attach(dm, "sky", PLAN_BG1);
		cl1 = Clip.attach(dm, "clouds", PLAN_BG1);
		// the snail crossing the background: one game in 500
		bugProb = Seed.random(500);
		#if debug
		if (FORCE_BUG)
			bugProb = 0;
		#end
		if (bugProb == 0)
			bug = Clip.attach(dm, "bug", PLAN_BG1);
		// clouds2 and background2 (one picture: always tinted together)
		bg2 = Clip.attach(dm, "bgMid", PLAN_BG2);
		caisse = Clip.attach(dm, "caisse", PLAN_CAISSE);
		caisse._x = 300;
		caisse._y = 300;
		bg3 = Clip.attach(dm, "bushes", PLAN_BG3);

		hero = Clip.attach(dm, "hero", PLAN_HERO);
		magicGate = Clip.attach(dm, "magicGate", PLAN_BG2);
		gateSub = magicGate.get(SUB);
		shadowGate = Clip.attach(dm, "shadowGate", PLAN_BG2);
		magicGate._x = -9;
		magicGate._y = BASEGATE - 5;
		shadowGate._x = 25;
		shadowGate._y = 294;
		hero.gotoAndStop("1");
		if (bug != null) {
			bug.getClip(SUB).gotoAndStop(Seed.randomVfx(4) + 1);
			bug._x = 500;
			bug._y = 260;
		}
		cooldown = 80;
		hx = MIDDLEX;
		hero._y = MAXY;
		hspeed = 0;
		hanim = 0;
		head_pos = 0;
		speed = PIOUSPEED;
		dir = 1;
		timer = 3;
		statC = 0;
		statS = 0;
		statL = 0;
		statF = 0;
		statLT = [0, 0, 0, 0];
		statFS = -1;
		statMF = KKApi.val(INIT_SPECIAL);
		pious = [];
		parts = [];
		partsP = [];
		partsBird = [];
		partsBug = [];
		partsBlob = [];
		splatches = [];

		lifeIcons = [];
		specialIcons = [];
		lifeCount = INIT_LIFE;
		specialCount = INIT_SPECIAL;
		pressSpace = false;
		furie = false;

		for (i in 0...KKApi.val(lifeCount))
			addLife();
		for (i in 0...KKApi.val(specialCount))
			addSpecial();

		rootY = 0;
		initShake(0, 0);
		gateY = 0;

		// main() of the constructor: one step before the first frame (no keys read: the same in a replay)
		noInput = true;
		main(1 / 32);
		noInput = false;
		Clip.runLater();
		syncDisplay();
	}

	function addLife() {
		var ico = Clip.attach(dm, "lifeIcon", PLAN_INTERF);
		ico._x = 280 - lifeIcons.length * 23;
		ico._y = 20;
		ico.stop();
		lifeIcons.push(ico);
	}

	function addSpecial() {
		var ico = Clip.attach(dm, "specialIcon", PLAN_INTERF);
		ico._x = 20 + specialIcons.length * 25;
		ico._y = 20;
		ico.stop();
		specialIcons.push(ico);
	}

	function genPiou():Bool {
		if (pious.length < SIMULTANOUS.length && statC < SIMULTANOUS[pious.length])
			return false;
		var xlimit = (MAXX + MINX) / 2 + statC * 3;
		var ylimit = HIGHY - statC / 3;
		var xmin = MINX + 50;
		for (p in pious)
			if (p.mc._x > xlimit || (p.mc._x > xmin && p.mc._y < ylimit))
				return false;
		statC++;
		var n = Seed.random(3);
		var dx = 4 - Seed.rand();
		var type = randomProbas(TYPE_PROBAS);
		var mc = Clip.attach(dm, "piou" + type, PLAN_PIOU);
		mc._x = 35;
		mc._y = 120 + n * 50;
		var p:Piou = {
			mc: mc,
			dx: dx,
			dy: -12,
			k: 2 * (Seed.randVfx() * 2 - 1),
			type: type
		};
		genPartBlob(mc._x, mc._y);
		mc.gotoAndStop(Seed.randomVfx(2) + 1);
		p.dx *= speed;
		p.dy *= speed;
		mc.updateState();
		pious.push(p);
		return true;
	}

	// Tools.randomProbas of the original
	static function randomProbas(a:Array<Int>):Int {
		var n = 0;
		for (v in a)
			n += v;
		n = Seed.random(n);
		var i = 0;
		while (n >= a[i]) {
			n -= a[i];
			i++;
		}
		return i;
	}

	function newPart(link:String, plan:Int):Clip {
		return Clip.attach(dm, link, plan);
	}

	function genPart() {
		var part = newPart("smokePart", PLAN_PART);
		part._x = hx + (Seed.randomVfx(8) + 8);
		part._y = hero._y - (Seed.randomVfx(10) + 2);
		part.gotoAndStop(Seed.randomVfx(3) + 1);
		parts.push({mc: part, dx: 0, dy: 0});
	}

	function genPartCoussin() {
		var part = newPart("smokePart", PLAN_PART);
		part._x = hx + (Seed.randomVfx(30) + 20);
		part._y = hero._y - (Seed.randomVfx(10) - 5);
		part._xscale = Seed.randomVfx(20) + 60;
		part._yscale = part._yscale;
		part._alpha = 70;
		part.gotoAndStop(Seed.randomVfx(3) + 1);
		parts.push({mc: part, dx: 0, dy: 0});
	}

	function genPartPlume(mc:ASprite) {
		var part = newPart("plumePart", PLAN_PART);
		if (mc == hero) {
			part._x = mc._x + (Seed.randomVfx(10) + 30);
			part._y = mc._y - (Seed.randomVfx(10) + 25);
		} else {
			part._x = mc._x + (Seed.randomVfx(10) - 20);
			part._y = mc._y + Seed.randomVfx(10);
		}
		part.gotoAndPlay(Seed.randomVfx(part._totalframes) + 1);
		part._xscale = 100;
		part._yscale = part._yscale;
		part._alpha = 100;
		partsP.push({mc: part, dx: -(Seed.randomVfx(3) + 3), dy: Seed.randomVfx(4) + 4});
	}

	function genPartPlumeCaisse() {
		var part = newPart("plumePart", PLAN_PART);
		part._x = 230 + (Seed.randomVfx(10) + 30);
		part._y = 310 - (Seed.randomVfx(25) + 10);
		part.gotoAndPlay(Seed.randomVfx(part._totalframes) + 1);
		part._xscale = 100;
		part._yscale = part._yscale;
		part._alpha = 100;
		partsP.push({mc: part, dx: -(Seed.randomVfx(3) + 3), dy: Seed.randomVfx(4) + 4});
	}

	function genPartBird() {
		var part = newPart("partBird", PLAN_PARTBIRD);
		part._x = Seed.randomVfx(30) + 160;
		part._y = Seed.randomVfx(20) + 200;
		part._xscale = Seed.randomVfx(50) + 50;
		part._yscale = part._xscale;
		part.gotoAndPlay(Seed.randomVfx(5) + 1);
		partsBird.push({mc: part, dx: 0, dy: 0});
	}

	function genSmokeBug() {
		var part = newPart("smokePart", PLAN_BG1);
		part._x = bug._x + (Seed.randomVfx(150) - 150);
		part._y = bug._y - (Seed.randomVfx(20) + 20);
		part._xscale = Seed.randomVfx(200) + 200;
		part._yscale = part._xscale;
		var dx = 3 * (Seed.randomVfx(2) * 2 - 1);
		part.gotoAndStop(Seed.randomVfx(3) + 1);
		partsBug.push({mc: part, dx: dx, dy: 0});
	}

	// a blob at the mouth of the gate, in gate.sub (masked by the light cone of the gate, moves with it)
	function genPartBlob(x:Float, y:Float) {
		if (gateSub == null)
			return;
		var part = new Clip("partBlob", Clip.K);
		var ppu = Clip.K * magicGate.def.r;
		part._x = x * ppu;
		part._y = (y - 20 - magicGate._y - gateSub._y / ppu) * ppu;
		gateSub.addChildAt(part, 0);
		part.updateState();
		partsBlob.push(part);
	}

	function initShake(sy:Float, sf:Float) {
		shakeY = sy;
		shakeFact = sf;
	}

	function shake() {
		shakeFact *= 0.8;
		shakeY = (shakeFact - rootY) * 1.5 + 0.5 * shakeY;
		// _y of a clip is kept in twips (1/20 px): the shake stops exactly at 0
		rootY = Math.round((rootY + shakeY) * 20) / 20;
	}

	function moveGate() {
		gateY = (BASEGATE - magicGate._y) * 0.002 + 1 * gateY;
		magicGate._y += gateY;
	}

	function moveBug() {
		cooldown--;
		if (cooldown <= 0) {
			bug._x -= 40;
			bug.gotoAndPlay("1");
			cooldown = 80;
		}
		if (bug.frame == 37) {
			var compt = Seed.randomVfx(5) + 5;
			for (j in 0...compt + 1)
				genSmokeBug();
			initShake(0, 1);
			if (bug._x <= 330 && bug._x >= 300) {
				var len = Seed.randomVfx(10) + 5;
				for (i in 0...len + 1)
					genPartBird();
			}
		}
	}

	inline function decorPlay(f:String) {
		bg.gotoAndPlay(f);
		bg2.gotoAndPlay(f);
		bg3.gotoAndPlay(f);
		cl1.gotoAndPlay(f);
	}

	inline function keyDown(k:Int):Bool {
		return !noInput && KeyboardManager.isDown(k);
	}

	inline function sub():Clip {
		return hero.getClip(SUB);
	}

	// ---------------------------------------------------------------- MAIN
	public function update(delta:Float) {
		frameCount++;
		Clip.flushRemoved();
		main(Timer.deltaT);
		Clip.runLater();
		syncDisplay();
		#if debug
		// test harness (window.__traceOn): gameplay state of every frame (a replay must give the same list)
		if (untyped !js.Browser.window.__traceOn)
			return;
		var tr:Array<String> = untyped js.Browser.window.__trace;
		if (tr == null)
			untyped js.Browser.window.__trace = tr = [];
		var sx = 0.0, sy = 0.0;
		for (p in pious) {
			sx += p.mc._x;
			sy += p.mc._y + p.dy;
		}
		tr.push(frameCount + " " + (keyDown(KeyboardManager.LEFT) ? "L" : "") + (keyDown(KeyboardManager.RIGHT) ? "R" : "")
			+ (keyDown(KeyboardManager.SPACE) ? "S" : "") + " " + hx + " " + hspeed + " " + timer + " " + pious.length + " " + sx + " " + sy
			+ " " + rootY + " " + hero.frame + " " + sub().frame + " " + statC + " " + statS + " " + statL);
		#end
	}

	function syncDisplay() {
		scene._y = rootY * Clip.K;
	}

	function main(deltaT:Float) {
		var tmod = Timer.tmod;
		timer -= deltaT;
		if (timer <= 0) {
			if (!genPiou())
				timer += Seed.random(1000) / 2000;
			else {
				timer = Seed.random(1500) + 500;
				timer *= Math.max((50 - (statC + statS)) / 50, 0.1);
				timer /= 1000;
			}
		}

		var press = false;
		if (keyDown(KeyboardManager.LEFT)) {
			dir = -1;
			press = true;
		}
		if (keyDown(KeyboardManager.RIGHT)) {
			dir = 1;
			press = true;
		}

		if (keyDown(KeyboardManager.SPACE) && KKApi.val(specialCount) > 0) {
			if (!pressSpace && !furie) {
				statF++;
				markFirstMistake();
				specialCount = KKApi.const(KKApi.val(specialCount) - 1);
				specialIcons.pop().play();
				// (dmanager.attach("shock") of the original: the symbol was never exported, nothing shown)
				decorPlay("2");
				hero.gotoAndStop("3");
				furie = true;
				for (p in pious) {
					p.dy = -Math.abs(p.dy * 1.5);
					p.dx += 1;
				}
				pressSpace = true;
			}
		} else
			pressSpace = false;

		if (press && hspeed < MINSPEED)
			hspeed = MINSPEED;

		var special = hero.frame == 3;

		if (special) {
			hspeed = 0;
			hanim += tmod;
			press = false;
		} else if (furie) {
			furie = false;
			decorPlay("5");
		}

		// Math.pow(press ? ACC : FRIC, Timer.tmod): tmod is 1 at the fixed step of 32 per second
		hspeed *= tmod == 1 ? (press ? ACC : FRIC) : Math.pow(press ? ACC : FRIC, tmod);
		if (!special && hspeed < 0.5) {
			hspeed = 0;
			hanim = 0;
			head_pos = 0;
		} else {
			hanim += hspeed / 8 * tmod;
			while (hanim >= sub().def.n) {
				if (special) {
					hero.gotoAndStop("2");
					break;
				}
				hanim -= (sub().def.n - INIT_FRAMES);
			}
			if (hspeed > MAXSPEED)
				hspeed = MAXSPEED;
		}

		shake();
		moveGate();
		if (bugProb == 0 && bug != null) {
			if (bug._x >= -20)
				moveBug();
			else {
				bug.removeMovieClip();
				bug = null;
			}
		}

		var s = sub();
		if (hspeed > 4 && ((s.frame >= 7 && s.frame <= 9) || (s.frame >= 13 && s.frame <= 15)))
			genPart();

		var idle = s.getClip(SUB);
		if (idle != null && idle.frame == 4) {
			for (i in 0...6)
				genPartCoussin();
		}
		hx += dir * hspeed * tmod;
		if (hx < MINX)
			hx = MINX;
		else if (hx > MAXX)
			hx = MAXX;
		hero._x = hx;
		if (!special) {
			hero.gotoAndStop((dir == 1) ? "1" : "2");
			var ang = Math.PI;
			var dist = 9999999.0;
			for (p in pious) {
				var dy = (hero._y - 45) - p.mc._y;
				var dx = (hero._x - p.mc._x);
				var d = dx * dx + dy * dy;
				if (d < dist) {
					ang = Math.atan2(dy, dx);
					dist = d;
				}
			}
			var hframe = 60 * (Math.PI - ang) / Math.PI;
			if (hframe < 0)
				hframe = 0;
			else if (hframe > 59)
				hframe = 59;
			head_pos = head_pos * 0.95 + hframe * 0.05;
			var h = sub().getClip(HEAD);
			if (h != null)
				h.gotoAndStop(Std.int(head_pos + 1));
		}
		s = sub();
		s.gotoAndStop(Std.int(hanim + 1));

		// the birds move in REPEAT steps per frame (bounce test on the pillow at each step)
		var f = speed / REPEAT * tmod;
		var k = REPEAT;
		if (special && s.frame < 26)
			k = 0;
		var heroIdx = hero.frame - 1;
		var hit = Data.HIT[heroIdx][s.frame - 1];
		var subPos = Data.SUB_POS[heroIdx];
		for (n in 0...k) {
			for (p in pious) {
				var mc = p.mc;
				mc._rotation = mc._rotation + p.k;
				mc._x += p.dx * f;
				mc._y += p.dy * f;
				p.dy += GRAVITY * f;
				if (hit != null && hitTest(hit, subPos, mc._x, mc._y)) {
					var pillow = idleClip(s);
					if (pillow != null)
						pillow.gotoAndPlay("2");
					p.dy *= -1;
					p.k = 2 * (Seed.randVfx() * 2 - 1);
					mc.gotoAndStop(Seed.randomVfx(3) + 1);
					var count = Seed.randomVfx(2) + 1;
					for (j in 0...count + 1) {
						genPartCoussin();
						genPartPlume(hero);
					}
					p.dx += (mc._x - (hx + subPos[0] + hit[0])) * 1.5 / hit[2];
					if (p.dx < 0)
						p.dx = 0;
					mc._y = hero._y + subPos[1] + hit[1] - 1;
				}
			}
		}
		if (caisse.frame == 18) {
			var countC = Seed.randomVfx(3) + 1;
			for (j in 0...countC + 1)
				genPartPlumeCaisse();
		}
		var i = 0;
		while (i < pious.length) {
			var p = pious[i];
			var mc = p.mc;
			if (mc._x > 285)
				mc._x = 285;
			if (mc._x > SAVEX && mc._y > SAVEY - 50 && p.dy > 0) {
				if (mc._y > SAVEY) {
					statS++;
					if (p.type == 3) {
						specialCount = KKApi.const(KKApi.val(specialCount) + 1);
						if (KKApi.val(specialCount) > statMF)
							statMF = KKApi.val(specialCount);
						addSpecial();
					} else
						addScore(KKApi.val(POINTS[p.type]));
					var sc = Clip.attach(dm, "score", PLAN_INTERF);
					sc.getClip(SUB).gotoAndStop(p.type + 1);
					caisse.gotoAndPlay("2");
					mc.removeMovieClip();
					pious.splice(i--, 1);
				} else
					dm.swap(mc, PLAN_BG2);
			} else if (mc._y >= 280) {
				statL++;
				statLT[p.type]++;
				markFirstMistake();
				var sp = Clip.attach(dm, "splatch", PLAN_PART);
				sp._x = mc._x;
				sp._y = 295;
				splatches.push(sp);
				var rf = Clip.attach(dm, "redFade", PLAN_BG3);
				rf._x = 0;
				rf._y = 0;
				mc.removeMovieClip();
				pious.splice(i--, 1);
				var count = Seed.randomVfx(10) + 5;
				for (j in 0...count + 1)
					genPartPlume(sp);
				lifeCount = KKApi.const(KKApi.val(lifeCount) - 1);
				lifeIcons.pop().play();
				if (KKApi.val(lifeCount) == 0) {
					timer = 1000;
					for (q in pious)
						q.mc.removeMovieClip();
					pious = [];
					gameOver();
					break;
				}
			}
			i++;
		}

		// smoke of the run
		i = 0;
		while (i < parts.length) {
			var p = parts[i].mc;
			p._y -= 0.5 + (Seed.randomVfx(10) / 10);
			p._rotation = p._rotation - Seed.randomVfx(20);
			p._xscale -= 5 + Seed.randomVfx(90) / 10;
			p._yscale = p._xscale;
			p._alpha -= 5;
			if (p._xscale <= 1) {
				p.removeMovieClip();
				parts.splice(i--, 1);
			}
			i++;
		}

		// feathers
		i = 0;
		while (i < partsP.length) {
			var o = partsP[i];
			var p = o.mc;
			o.dx += 0.3;
			o.dy -= 0.45;
			if (o.dx >= 5)
				o.dx = 5;
			p._y -= o.dy;
			p._x -= o.dx;
			p._alpha -= Std.int((Seed.randomVfx(3) + 1) / 2);
			if (p._alpha <= 1) {
				p.removeMovieClip();
				partsP.splice(i--, 1);
			}
			i++;
		}

		// birds flying away from the snail
		i = 0;
		while (i < partsBird.length) {
			var pb = partsBird[i].mc;
			pb._x -= Seed.randomVfx(3) + 1;
			pb._y -= Seed.randomVfx(3) + 1;
			if (pb._x <= 0 || pb._y <= 0) {
				pb.removeMovieClip();
				partsBird.splice(i--, 1);
			}
			i++;
		}

		// smoke of the snail
		i = 0;
		while (i < partsBug.length) {
			var o = partsBug[i];
			var pb = o.mc;
			pb._xscale += 5;
			pb._yscale = pb._xscale;
			pb._alpha -= (Seed.randomVfx(4) + 2);
			pb._rotation = pb._rotation + o.dx;
			pb._y -= Seed.randomVfx(1) + 0.5;
			if (pb._alpha <= 0) {
				pb.removeMovieClip();
				partsBug.splice(i--, 1);
			}
			i++;
		}

		// blobs and splatches stay on their last frame in the original, an empty one: removed when they are over
		removeFinished(partsBlob);
		removeFinished(splatches);
	}

	static function removeFinished(list:Array<Clip>) {
		var i = 0;
		while (i < list.length) {
			var c = list[i];
			if (c.finished()) {
				c.removeMovieClip();
				c.destroy({children: true});
				list.splice(i--, 1);
			}
			i++;
		}
	}

	// the idle animation of hero.sub (hero.sub.sub) and its pillow (hero.sub.sub.c): only when the hero stands still
	function idleClip(s:Clip):Clip {
		var idle = s.getClip(SUB);
		return idle == null ? null : idle.getClip(PILLOW);
	}

	// hero.sub.hit.hitTest(x, y, false): the bounding box of the hit zone in global coordinates (the root of the
	// game moves with the shake), tested with the local coordinates of the bird like the original
	inline function hitTest(hit:Array<Float>, subPos:Array<Float>, x:Float, y:Float):Bool {
		var ox = hx + subPos[0];
		var oy = MAXY + subPos[1] + rootY;
		return x >= ox + hit[3] && x <= ox + hit[5] && y >= oy + hit[4] && y <= oy + hit[6];
	}

	// ---------------------------------------------------------------- SCORE / END
	// the score before the first bird lost or the first fury (the achievement clean_score)
	function markFirstMistake() {
		if (statFS == -1)
			statFS = KadoKadeoManager.kkm.score.get();
	}

	function addScore(n:Int) {
		if (!over)
			KadoKadeoManager.kkm.addScore(n);
	}

	function gameOver() {
		if (over)
			return;
		over = true;
		// stats of the original ($c: birds shot, $s: saved, $l: lost), keys without $ like the other games, and the ones of
		// the achievements
		var stats = {
			c: statC,
			s: statS,
			l: statL,
			f: statF,
			lt: statLT,
			fs: statFS,
			mf: statMF
		};
		#if debug
		// test harness: state of the game at its end (compared between a game and its replay)
		untyped js.Browser.window.__over = {
			frame: frameCount,
			score: KadoKadeoManager.kkm.score.get(),
			hx: hx,
			hspeed: hspeed,
			hanim: hanim,
			gateY: magicGate._y,
			stats: haxe.Json.stringify(stats)
		};
		#end
		KadoKadeoManager.kkm.gameOver(stats);
	}

	// TOUCH: joystick -> arrow keys (polled and recorded like the keyboard)
	public function pollTouchControls():Void {
		var joystick = KadoKadeoManager.kkm.getTouchJoystickState();
		if (joystick == null)
			return;
		var axisX = joystick.active ? joystick.dirX : 0;
		setDirectionalKey(KeyboardManager.LEFT, axisX < 0);
		setDirectionalKey(KeyboardManager.RIGHT, axisX > 0);
	}

	inline function setDirectionalKey(keyCode:Int, down:Bool):Void {
		if (down) {
			KeyboardManager.setKeyDown(keyCode);
		} else {
			KeyboardManager.setKeyUp(keyCode);
		}
	}

	#if debug
	// test harness only: clips drawn on a grid over the game, each one created, its nested clips forced to frames
	// (paths of instance names) and played for some ticks, then frozen
	// cell: {n: clip, f: frame, play: Bool, force: [[path, frame]], ticks: Int, x, y (px), s: scale (1 = x2)}
	public function debugCells(list:Array<Dynamic>, bgColor:Int) {
		var stage:Dynamic = untyped KadoKadeoManager.kkm.stage;
		var box = new ASprite();
		var g = box.getGraphics();
		g.beginFill(bgColor);
		g.drawRect(0, 0, 600, 640);
		g.endFill();
		for (o in list) {
			var c = new Clip(o.n, Clip.K * o.s);
			if (o.play)
				c.gotoAndPlay(o.f);
			else
				c.gotoAndStop(o.f);
			Clip.runLater();
			var force:Array<Array<Dynamic>> = o.force;
			for (fp in force) {
				var t:Clip = c;
				for (n in (fp[0] : String).split("/"))
					t = t == null ? null : t.getClip(n);
				if (t != null)
					t.gotoAndStop(fp[1]);
				Clip.runLater();
			}
			var ticks:Int = o.ticks;
			for (i in 0...ticks) {
				c.update();
				Clip.flushRemoved();
				Clip.runLater();
			}
			c.freeze();
			c._x = o.x;
			c._y = o.y;
			// each cell clipped to its box (120 x 160)
			var m = new pixi.core.graphics.Graphics();
			m.beginFill(0xFFFFFF);
			if (o.full == true) m.drawRect(0, 0, 600, 640) else m.drawRect(Math.floor(o.x / 120) * 120, Math.floor(o.y / 160) * 160, 120, 160);
			m.endFill();
			var holder = new ASprite();
			holder.addChild(m);
			holder.mask = m;
			holder.addChild(c);
			box.addChild(holder);
		}
		box.updateState();
		box.updateGraphics(1);
		stage.addChild(box);
	}
	#end

	public function destroy():Void {
		Clip.clearLater();
	}
}

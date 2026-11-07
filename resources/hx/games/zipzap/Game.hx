package zipzap;

import common_haxe_avm1.KeyboardManager;
import common_haxe_avm1.KKApi;
import common_haxe_avm1.MouseManager;
import haxe.io.UInt16Array;
import kado.Seed;
import kado.KadoKadeoManager;
import mt.bumdum.Lib;
import mt.DepthManager;
import mt.Timer;

@:expose('GameZipZap')
class Game implements kado.GameInterface {
	var bg:ASprite;

	public var dmanager:DepthManager;

	var hero:Hero;

	public var bals:Array<Ballon>;
	public var level:Int;

	var nblacks:Int;
	var time:Float;
	var nbals:Int;
	var counter:ASprite;

	public var last:Null<Int>;

	var bcounter:Int;
	var have_effect:Bool;
	var waitTimer:Float;

	public var stats:{
		c:Array<Int>,
		m:Int,
		pa:Array<Array<Int>>, // per action [pop100, pop250, pop500, pop1000, pop5000, popBlack]
		bb:Array<Array<Int>>, // black balloons : [[level, nbalsRemaining]]
	};

	public function new(root:ASprite, ?isReplay:Bool = false) {
		var replayKeys = new UInt16Array(5);
		replayKeys[0] = KeyboardManager.UP;
		replayKeys[1] = KeyboardManager.DOWN;
		replayKeys[2] = KeyboardManager.LEFT;
		replayKeys[3] = KeyboardManager.RIGHT;
		replayKeys[4] = KeyboardManager.SPACE;
		var replayMouseButtons = new UInt16Array(1);
		replayMouseButtons[0] = MouseManager.BUTTON_LEFT;
		KadoKadeoManager.kkm.replay.init({
			recordedKeys: replayKeys,
			recordInputs: true,
			recordEvents: false,
			recordMousePosition: true,
			recordedMouseButtons: replayMouseButtons,
		});

		dmanager = new DepthManager(root);
		bg = dmanager.attach("bg", Cs.PLAN_BG);
		counter = dmanager.attach("compteur", Cs.PLAN_INTERF);
		counter._x = KadoKadeoManager.I(300);
		var txt = counter.initTextField("field", {
			font: "IronMan",
			size: 30,
			color: 0xFFFFFF,
			align: "right",
		});
		txt.x = -KadoKadeoManager.I(20);
		bals = [];
		time = 0;
		nblacks = 0;
		waitTimer = 0;
		stats = {
			m: 0,
			c: [0, 0, 0, 0, 0],
			pa: [],
			bb: [],
		};
		hero = new Hero(this);
		level = -1;

		nbals = 0;
		for (levelData in Cs.LEVEL) {
			nbals += levelData.n;
		}
		(cast counter : Dynamic).field.text = Std.string(nbals);

		nextLevel();
	}

	function nextLevel():Void {
		level++;
		if (Cs.LEVEL[level] == null) {
			KadoKadeoManager.kkm.gameOver(stats);
		} else {
			initBals(Cs.LEVEL[level].n);
		}
	}

	function initBals(n:Int):Void {
		var probas = [1 + Seed.random(3), 1 + Seed.random(3), 1 + Seed.random(3)];
		for (_ in 0...n) {
			var b = new Ballon(this, randomProbas(probas));
			bals.push(b);
		}
	}

	function randomProbas(probas:Array<Int>):Int {
		var total = 0;
		for (v in probas) {
			total += v;
		}
		if (total <= 0) {
			return 0;
		}
		var rnd = Seed.random(total);
		for (i in 0...probas.length) {
			rnd -= probas[i];
			if (rnd < 0) {
				return i;
			}
		}
		return probas.length - 1;
	}

	inline function getCheat<T>(arr:Array<T>):Bool {
		return false;
	}

	public function getBallon(b:Ballon):Int {
		if (b.t == last) {
			bcounter++;
		} else {
			bcounter = 1;
			last = b.t;
		}
		if (b.t == 3) {
			var pa = dmanager.attach("partPlouch", Cs.PLAN_PART);
			pa._x = b.x;
			pa._y = b.y;
			pa.play();
			pa.removeOnFrame = 19;
			KadoKadeoManager.kkm.gameOver(stats);
			hero.doGameOver();

			b.destroy();
			bals.remove(b);
			time = 0;

			return 5;
		}
		var f = Std.int(Math.min(bcounter - 1, Cs.POINTS.length - 1));
		var s = Cs.POINTS[f];
		stats.c[f]++;
		KadoKadeoManager.kkm.addScore(s);
		b.plop(f);
		nbals--;
		(cast counter : Dynamic).field.text = Std.string(nbals);
		b.destroy();
		bals.remove(b);
		time = 0;

		return Std.int(Math.min(bcounter - 1, Cs.POINTS.length - 1));
	}

	public function update(delta:Float):Void {
		var mouseY = Num.q(MouseManager.getY());
		hero.ty = mouseY;
		// hero.mc._y = mouseY;

		if (MouseManager.isButtonJustPressed(MouseManager.BUTTON_LEFT) && hero.moving == null) {
			waitTimer = 0;
			hero.action();
		}

		var steps:Int = 7;
		time += Timer.tmod;
		waitTimer += Timer.tmod;
		if (nblacks < 10 && time > 320) {
			time = 0;
			nblacks++;
			bals.push(new Ballon(this, 3));
			stats.bb.push([level, nbals]);
		}

		if (getBalsLength() > 6 && Seed.random(10000) == 0) {
			if (Seed.random(5) != 0 || waitTimer > 160) {
				var n = getBalsLength();
				for (i in 0...n) {
					var b = bals[i];
					b.tx = Num.q(KadoKadeoManager.I(150) + Math.cos(i / n * Math.PI * 2) * KadoKadeoManager.I(100));
					b.ty = Num.q(KadoKadeoManager.I(150) + Math.sin(i / n * Math.PI * 2) * KadoKadeoManager.I(100));
					b.mind = 0;
					b.timer = 160;
				}
			} else {
				var ys = [KadoKadeoManager.I(50), KadoKadeoManager.I(150), KadoKadeoManager.I(250)];
				var c = [0, 0, 0];
				for (b in bals) {
					if (b.t != 3) {
						var x = c[b.t]++;
						x = (((x % 2) > 0) ? 1 : -1) * KadoKadeoManager.I(15) * x;
						b.tx = Num.q(KadoKadeoManager.I(150) + x);
						b.ty = ys[b.t];
						b.mind = 0;
						b.timer = 160;
					}
				}
			}
		}

		for (_ in 0...steps) {
			hero.update(steps);
		}

		var i = 0;
		while (i < getBalsLength()) {
			if (!bals[i].update(i)) {
				bals.splice(i--, 1);
			}
			i++;
		}

		if (Cs.LEVEL[level] != null && getBalsLength() - nblacks <= Cs.LEVEL[level].m) {
			nextLevel();
		}

		if (getCheat(bals)) {
			KKApi.flagCheater();
		}
	}

	public function destroy():Void {}

	public function getBalsLength():Int {
		return bals.length;
	}
}

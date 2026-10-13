package digestomax;

// Piou.hx of the original: Pioupiou, a Ball of colour 20 (mcBall frame 21: its smc is the animation of the hero, whose
// labels the code plays). He walks, swallows the fruit beside him, under him or above him, and poops the fruits of his
// stomach upwards (he climbs on them).
class Piou extends Ball {
	public static var STOMACH_MODE = 2;

	public var fallCoef:Float;
	public var eatUpWait:Null<Int>;
	// (undefined before the first walk: NaN in sens * 100, a scale Flash ignores)
	public var sens:Null<Int>;
	public var frame:Int;
	public var stomachSize:Int;

	public var ox:Float;

	public var action:Void->Void;
	public var stomach:Array<Int>;

	public function new(x:Int, y:Int) {
		super(x, y, 20);
		ox = 0;
		frame = 0;
		stomach = [];
		stomachSize = 6;
		smc().stop();
		// Reflect.setField(skin.smc, "$big", false): false > 0 is false, 50 + false * 10 = 50
		smc().big = 0;
	}

	// skin.smc: the hero's animation (a removed skin: none)
	inline function smc():Clip {
		var s = skin.sub("smc");
		return s != null ? s : NONE;
	}

	// what the code does on an undefined skin.smc (after the hero's death): nothing
	static var NONE_:Clip;
	static var NONE(get, never):Clip;

	static function get_NONE():Clip {
		if (NONE_ == null)
			NONE_ = new Clip(Clip.EMPTY);
		return NONE_;
	}

	public static function reset() {
		NONE_ = null;
		STOMACH_MODE = 2;
	}

	// skin.smc.smc._xscale = sens * 100 (the fruit in the beak; NaN before the first walk: ignored)
	function setFruitSens() {
		smc().setSub("smc", null, null, sens != null ? sens * 100 : Math.NaN);
	}

	public function init() {
		smc().big = stomach.length;

		if (stomach.length > stomachSize) {
			explode();
		} else {
			Game.me.checkEnd();
		}
	}

	public function update() {
		// (an action set to null: calling it does nothing in Flash)
		if (action != null)
			action();
	}

	public function control() {
		var flFall = Game.me.fallList.length > 0;

		if (KeyboardManager.isDown(KeyboardManager.LEFT))
			walk(-1);
		else if (KeyboardManager.isDown(KeyboardManager.RIGHT))
			walk(1);
		else if (KeyboardManager.isDown(KeyboardManager.DOWN) && !flFall)
			dig();
		else if (KeyboardManager.isDown(KeyboardManager.UP) && !flFall)
			initEatUp(true);
		else if (KeyboardManager.isDown(KeyboardManager.SPACE) && !flFall)
			initEatUp(false);
	}

	// CLIMB
	public function walk(sens:Int) {
		setSens(sens);
		ox += sens * 0.15;

		var flAnim = true;

		if (ox * sens > 0) {
			if (Game.me.fallList.length == 0) {
				var next = Game.me.cell(px + sens, py);
				if (Cs.isOut(px + sens, py)) {
					ox = 0;
				}
				// (no ball there: undefined.flFruit is false)
				if (next != null && next.flFruit) {
					if (canEat())
						eat(sens, next);
					else
						ox = 0;
				}
				if (Math.abs(ox) >= 0.5) {
					ox -= sens;
					move(sens, 0);
					Game.me.initFall();
				};
			} else {
				flAnim = false;
				ox = 0;
			}
		}

		display(px + ox, py);

		if (smc().frame < 10 && flAnim) {
			frame = (frame + 1) % 8;
			smc().gotoAndStop(frame + 1);
		}
	}

	// STOMACH
	public function feed(fruit:Ball) {
		switch (fruit.color) {
			case 4:
				Game.me.fxFlash(0xFF88FF);
				incStomach(1);

			case 5:
				Game.me.fxFlash(0x00FFFF);

				if (stomach.length > 0) {
					var sc = KKApi.cmult(Cs.SCORE_FRUIT, KKApi.const(2 * stomach.length));
					Game.me.addScore(sc);
					var p = Game.me.newScore(fruit.root._x, fruit.root._y, KKApi.val(sc), 0x0000FF);
					p.vy = -3;
					stomach = [];
					Game.me.displayStomach();
				}

			default:
				if (fruit.color >= 10) {
					var id = fruit.color - 10;
					Game.me.fxFlash(Cs.FRUIT_COLOR[id]);
					Game.me.explodeAll(id);
					// (fix: the original only showed this score, explodeAll leaves scoreSpawn empty and it was never given; no
					// fruit of that colour left: the original showed -300, now nothing shown nor taken, like a single fruit)
					var sc = Cs.getScore(Game.me.work.length);
					if (KKApi.val(sc) > 0) {
						Game.me.addScore(sc);
						var p = Game.me.newScore(fruit.root._x, fruit.root._y, KKApi.val(sc), Cs.FRUIT_COLOR[id]);
					}
				} else {
					if (stomach.length < stomachSize) {
						stomach.unshift(fruit.color);
					} else {
						Game.me.fxFlash(0xFF0000);
						Game.me.upc = Math.min(Game.me.upc + 0.1, 1);
					}
				}
		}

		fruit.kill();
		// (the animation draws the fruit in the beak from this frame on)
		fruit.root.removeNow();
		// UPDATE STOMACH
		Game.me.displayStomach();
	}

	// EAT
	public function dig() {
		var next = Game.me.cell(px, py + 1);

		if (next == null || !next.flFruit || !canEat())
			return;

		if (Math.abs(ox) > 0.1) {
			ox *= 0.5;
			display(px + ox, py);
			return;
		}

		action = anim;
		coef = 0;
		spc = 0.12;

		smc().gotoAndPlay("dig");
		var s = smc().getClip("smc");
		if (s != null)
			s.gotoAndStop(next.color + 1);
		setFruitSens();

		// KILL
		feed(next);
		#if debug
		Game.me.stats.dig++;
		#end

		// MOVE
		move(0, 1);
		ox = 0;
		display(px, py);
		root.showNow();
		Game.me.initFall();
	}

	public function eat(sens:Int, next:Ball) {
		feed(next);
		#if debug
		Game.me.stats.eaten++;
		#end
		ox = 0;
		move(sens, 0);

		action = anim;
		coef = 0;
		spc = 0.16;
		smc().gotoAndPlay("swallow");
		var s = smc().getClip("smc");
		if (s != null)
			s.gotoAndStop(next.color + 1);
		setFruitSens();

		display(px, py);
		root.showNow();
		Game.me.initFall();
	}

	public function initEatUp(flBoth:Bool) {
		if (Game.me.fallList.length > 0 || py == 0)
			return;

		if (Math.abs(ox) > 0.1) {
			ox *= 0.5;
			display(px + ox, py);
			return;
		}

		var next = Game.me.cell(px, py - 1);
		if (next == null || !next.flFruit) {
			initPoop();
			return;
		}

		if (!canEat() || !flBoth)
			return;

		smc().fruit = next.color + 1;
		smc().sens = sens;

		eatUpWait = 4;
		smc().gotoAndPlay("initEatUp");

		setAction(updateInitEatUp);

		ox = 0;
		display(px, py);
	}

	public function updateInitEatUp() {
		if (eatUpWait-- == 0)
			startEatUp();
	}

	public function startEatUp() {
		var next = Game.me.cell(px, py - 1);
		smc().fruit = next.color + 1;
		smc().gotoAndPlay("eatUp");
		feed(next);
		#if debug
		Game.me.stats.eatUp++;
		#end
		eatUpWait = 6;
		setAction(eatUp);
		Game.me.initFall();
	}

	public function eatUp() {
		if (eatUpWait-- == 0) {
			var up = Game.me.cell(px, py - 1);
			if (KeyboardManager.isDown(KeyboardManager.UP) && up != null && up.flFruit && canEat()) {
				startEatUp();
			} else {
				eatUpWait = null;
				smc().gotoAndPlay("endEatUp");
				init();
			}
		}
	}

	// STOMACH
	public function incStomach(inc:Int) {
		stomachSize += inc;
		while (stomach.length > stomachSize)
			stomach.pop();
		Game.me.displayJauge();
		Game.me.displayStomach();
	}

	// POOP
	public function initPoop() {
		if (stomach.length == 0 || py <= 0)
			return;
		setAction(poop);
	}

	// (the cell above is only checked by initEatUp: the next poops of the same row climb through what is there)
	public function poop() {
		move(0, -1);
		display(px, py);

		var color = stomach.pop();
		#if debug
		Game.me.stats.poops++;
		#end
		var ball = new Ball(px, py + 1);
		ball.setColor(color);
		Game.me.displayStomach();

		// a new animation clip (the goto to frame 1 removes it, the goto to frame 21 places a new one, playing)
		skin.gotoAndStop(1);
		skin.gotoAndStop(21);
		smc().big = stomach.length;
		smc().gotoAndPlay("windUp");

		if (stomach.length == 0 || py <= 0) {
			Game.me.checkCombo();
			smc().play();
			init();
		}
	}

	public function canEat() {
		return true;
	}

	public function anim() {
		coef += spc;
		if (coef >= 1) {
			smc().gotoAndStop(1);
			init();
		}
	}

	public function setSens(n:Int) {
		sens = n;
		root._xscale = sens * 100;
	}

	public function setAction(f:Void->Void) {
		action = f;
	}

	override public function explode() {
		var mc = Game.me.dm.attach("piouExplode", Game.DP_PIOU);
		// (a second explosion of a dead hero, at the game over: its removed clip reads undefined, the explosion stays
		// at (0, 0))
		mc._x = root._x;
		mc._y = root._y;
		setAction(null);
		kill();
	}
}

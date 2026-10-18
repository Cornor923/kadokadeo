package mel;

import mel.Lib;
import mel.Gfx;
import mel.Entity;

// Bonus.hx of the original: the +1000 bonus (the empty power up), base of UpBonus
class Bonus extends Entity {
	var disapear = false;

	public var isPow = false;

	public function new(n:Int) {
		super();
		page = n;

		if (mc == null)
			mc = Ui.makePow(null);

		flags.unset(GRAVITY);
		flags.set(FLY);
		ry = 1.0;

		name = "bonus";
	}

	public function getValue()
		return 1000;

	public function kill() {
		if (mc != null && !disapear) {
			var v = new Vanish(mc);
			v.setFadeBlur(0, 2);
			v.setFadeScale(-1, 1);
			v.fadeAlpha = true;
			v.timer = 10;
			disapear = true;
		}
	}

	public function kill2() {
		if (mc != null && !disapear) {
			var v = new Vanish(mc);
			v.fadeAlpha = true;
			v.timer = 10;
			disapear = true;
		}
	}

	public function getHitLabel() {
		return "+1000";
	}

	override public function onProc() {
		var bv = 1000;
		game.fixScore += bv;
		var txt = getHitLabel();

		var b = 0;
		function gtf(txt:String) {
			var t = Lib.getTf(txt, 10);
			t.y = b += 20;
			var b = 10;
			t.fieldWidth = t.textWidth + b;
			t.x = -t.fieldWidth * 0.5 + b * 0.5;
			return t;
		}
		var char = game.char;
		var sc = new FxScore(txt, gtf);
		sc.x = Std.int(game.char.mc.x);
		sc.y = char.mc.y - char.heightOfMc() - 50;

		// (on top of the parent of Mel: the root of the level)
		if (game.level.dm.owns(char.mc))
			game.level.dm.addTop(sc);
		else
			char.mc.parent.addChild(sc);

		game.tweenie.create(sc, "y", sc.y - 35, TEaseIn, 500);
		var v = new Vanish(sc, 80);
		v.fadeAlpha = true;

		game.level.others.remove(this);
		kill2();
	}
}

class UpBonus extends Bonus {
	public var pow:CharPowers;
	public var staged = false;
	public var uid = 0;

	static var guid = 0;

	public function new(n:Int, p:CharPowers) {
		super(n);
		pow = p;
		if (mc != null)
			mc.detach();
		mc = Ui.makePow(p);
		isPow = true;
		name = "upbonus" + (uid = guid++);
		syncPos();
	}

	public function toString() {
		return name + " " + cx + " " + cy;
	}

	override public function restage() {
		if (game.char.powers.has(pow) && mc != null) {
			mc.detach();
			mc.visible = false;
			staged = false;
			return;
		} else {
			staged = true;
			super.restage();
		}
	}

	override public function getHitLabel() {
		return Text.resolve('bonusTxtHit_' + pow.getIndex());
	}

	override public function updatePhy() {
		if (game.char.powers.has(pow))
			FTimer.delay(kill, 1);
		else
			super.updatePhy();
	}

	public function powLit(p:CharPowers) {
		return switch (p) {
			case CP_DOUBLE_JUMP: "dbl";
			case CP_WALL_STICK: "grab";
			case CP_SUPER_JUMP: "super";
			case CP_KICK: "kick";
			case CP_CANCEL: "cancel";
		}
	}

	override public function kill2() {}

	override public function onProc() {
		var char = game.char;
		super.onProc();

		char.powers.set(pow);
		var i = 0;
		while (i < game.level.bonuses.length) {
			if (game.level.bonuses[i].pow == pow) {
				game.level.bonuses.splice(i, 1);
				break;
			}
			i++;
		}

		var pos = mc.getRect(Game.me.gs);
		mc.detach();
		mc.x = pos.x;
		mc.y = pos.y;
		mc.snap();
		game.addChild(mc);

		var m = mc;
		var oe = function() {
			m.detach();
			mc = null;
			char.powers.set(pow);
		}
		var b = game.ui.powers[pow.getIndex()];
		var tx = game.tweenie.create(mc, "x", b.x, TBurnIn, 675);
		var ty = game.tweenie.create(mc, "y", b.y, TBurnOut, 675);
		mc.alpha = 0.5;
		tx.onEnd = oe;

		if (!Game.isLowQuality())
			tx.onUpdateT = function(r) new FxShade(m, 5);
	}
}

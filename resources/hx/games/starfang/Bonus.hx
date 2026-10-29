package starfang;

import kado.KadoKadeoManager;
import mt.bumdum.Lib.Num;
import mt.bumdum.Part;
import common_haxe_avm1.KKApi;
import mt.DepthManager;

@:publicFields
class Bonus extends Phys {
	static var ID_MAX = 4;
	static var BOUNCE_MAX = 5;
	static var SPEED = KadoKadeoManager.I(3);

	static var SCORE = KKApi.aconst([1000, 3000, 12000]);
	static var STATS = [
		120, // NORMAL
		100, // SPEEDER
		30, // ONDE
		80, // FLAMER
		1, // BLACK SPOT
		70, // AIRSTRIKE
		30, // SHIELD
		70, // MAGIC BALL
		80, // TELEPORT
		20, // HYPERTHRUST
		7, // POWER BALL
		0,
		0,
		0,
		0,
		300, // GREEN
		50, // BLUE
		5 // PINK
	];

	var id:Int;
	var bounce:Int;
	var dm:DepthManager;

	function new(mc, ?forcedId:Int, ?forcedDir:Int) {
		Cs.game.bonusList.push(this);
		super(mc);
		bounce = 0;
		ray = KadoKadeoManager.I(15);
		dm = new DepthManager(root);
		id = forcedId == null ? getRandomId() : forcedId;
		var dir = forcedDir == null ? Seed.random(4) : forcedDir;
		var a = 0.775 + dir * 1.57;
		vx = Math.cos(a) * SPEED;
		vy = Math.sin(a) * SPEED;
		root.gotoAndStop(id + 1);
	}

	public static function getRandomId() {
		var max = 0;
		for (i in 0...STATS.length) {
			max += STATS[i];
		}
		var rnd = Seed.random(max);
		var cur = 0;
		for (i in 0...STATS.length) {
			cur += STATS[i];
			if (cur > rnd) {
				return i;
			}
		}
		return 0;
	}

	override function update() {
		super.update();
		if (collide(Cs.game.hero))
			take();

		if (bounce < BOUNCE_MAX) {
			checkBounds();
		} else {
			if (isOut(ray, Cs.mcw, Cs.mch))
				kill();
		}
		if (id >= 15 && id <= 17) {
			for (i in 0...2) {
				var p = new Part(dm.attach("partRay", 1));
				p.root.gotoAndStop(id - 14);
				p.vr = (Seed.randVfx() * 2 - 1) * 10;
				p.fadeType = 3;
				p.scale = 50 + Seed.randVfx() * 100;
				p.root._xscale = 10 + Seed.randVfx() * 20;
				p.root._yscale = p.scale;
				p.root._rotation = Seed.randVfx() * 360;
				p.timer = 10 + Seed.randVfx() * 10;
				p.root._x = 0;
				p.root._y = 0;
			}
		}
	}

	function take() {
		Cs.game.stats.b.push(id);
		switch (id) {
			case 0 | 1 | 2 | 3 | 4:
				Cs.game.hero.updateWeapon(id);

			case 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14:
				Cs.game.hero.updateSecondary(id - 5);

			case 15 | 16 | 17:
				var sc = SCORE[id - 15];
				KadoKadeoManager.kkm.addScore(sc);
				var mc = new Part(Cs.game.dm.empty(Game.DP_PARTS));
				var txt = mc.root.initTextField("txt", {
					font: "Orbitron",
					size: 30,
					color: 0xFFFFFF,
					align: "center",
				});
				mc.root._x = x;
				mc.root._y = y;
				txt.text = Std.string(KKApi.val(sc));
				mc.timer = 20;
				mc.root._x = x;
				mc.root._y = y;
				exploPaillette();
		}
		kill();
	}

	function exploPaillette() {
		for (i in 0...24) {
			var p = new Part(Cs.game.dm.attach("partPaillette", Game.DP_PARTS));
			p.root.gotoAndStop(id - 14);
			var a = Seed.randVfx() * 6.28;
			var ca = Math.cos(a);
			var sa = Math.sin(a);
			var r = KadoKadeoManager.I(5) + Seed.randVfx() * ray;
			var sp = KadoKadeoManager.S(0.5 + Seed.randVfx() * 2);
			p.x = x + ca * r;
			p.y = y + sa * r;
			p.vx = ca * sp;
			p.vy = sa * sp;
			p.vr = (Seed.randVfx() * 2 - 1) * 20;
			p.timer = 10 + Seed.randVfx() * 20;
			p.setScale(10 + Seed.randVfx() * 50);
			p.root._rotation = Seed.randVfx() * 360;
			p.fadeType = 0;
		}
		for (i in 0...12) {
			var p = newPart("partLight", ray, KadoKadeoManager.S(1 + Seed.randVfx() * 3));
			p.setScale(50 + Seed.randVfx() * 100);
		}
	}

	function newPart(link, r:Float, sp:Float) {
		var p = new Part(Cs.game.dm.attach(link, Game.DP_PARTS));
		var a = Seed.randVfx() * 6.28;
		var ca = Math.cos(a);
		var sa = Math.sin(a);
		p.x = x + ca * r;
		p.y = y + sa * r;
		p.vx = ca * sp;
		p.vy = sa * sp;
		p.timer = 10 + Seed.randVfx() * 10;
		p.fadeType = 0;
		return p;
	}

	function checkBounds() {
		if (x < ray || x > Cs.mcw - ray) {
			vx *= -1;
			x = Num.mm(ray, x, Cs.mcw - ray);
			bounce++;
		}
		if (y < ray || y > Cs.mch - ray) {
			vy *= -1;
			y = Num.mm(ray, y, Cs.mch - ray);
			bounce++;
		}
	}

	override function kill() {
		Cs.game.bonusList.remove(this);
		super.kill();
	}
}

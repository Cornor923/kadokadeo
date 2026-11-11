package charlottesquest;

class Enemy extends Entity {
	public static var WAVE_ID = 0;
	public static var WAVES:Array<{total:Int, list:Array<Enemy>}> = [];

	var score:Int;
	var waveId:Int;
	var wrand:Rand;

	public var hasToBeKilled:Bool;
	public var hitsPlayer:Bool;

	public function new() {
		super();

		waveId = WAVE_ID;
		var wave = getWave();
		wave.total++;
		wave.list.push(this);
		wrand = new Rand(0);
		wrand.initSeed(game.seed + waveId * 109);
		alertOutside = wave.list.length == 1;
		hitsPlayer = true;
		score = 1;

		initLife(2);
		game.enemies.add(this);
		hasToBeKilled = true;
		game.sdm.add(spr, Game.DP_ENEMY);
		autoKill = LeaveScreen;
	}

	public static function initWave() {
		WAVES[++WAVE_ID] = {
			total: 0,
			list: new Array(),
		}
	}

	override public function toString() {
		return "Enemy#" + uid;
	}

	override public function unregister() {
		super.unregister();
		game.enemies.remove(this);
	}

	public inline function getWave() {
		return WAVES[waveId];
	}

	public inline function waveCount() {
		return WAVES[waveId].list.length;
	}

	public function waveKilled() {
		return getWave().list.length == 0;
	}

	// (League: from every side; the LvUP chose the sides by its level)
	function getRandomPopSide(popLevel:Int):Int {
		return wrand.random(4);
	}

	function getOppositeDir(dir:Int) {
		return switch (dir) {
			case 0: 2;
			case 1: 3;
			case 2: 0;
			case 3: 1;
			default: throw "dir" + dir;
		}
	}

	override public function checkHit(e:Entity, precise) {
		return if (hasCD("shield") || e.hasCD("shield")) false; else super.checkHit(e, precise);
	}

	override public function onDie() {
		super.onDie();
		getWave().list.remove(this);
		var pt = getPoint();
		if (game.perf >= 0.9) {
			var mc = fx.anim(new MovieClip("Puf"), pt.x, pt.y);
			mc.blendMode = BlendMode.ADD;
		}

		if (game.perf >= 0.75)
			fx.splash(game.player, this);

		if (waveKilled())
			game.addSkill(0.2);
		else
			game.addSkill(0.03);
	}

	override public function hit(pow:Float, ?from:Entity) {
		if (hasCD("shield"))
			return;
		super.hit(pow, from);
		setCD("shield", 1);
		game.addScore(score);
	}

	override public function update() {
		super.update();

		if (hitsPlayer && checkHit(game.player, true) && !game.player.hasCD("shield")) {
			kill();
			if (!game.player.hasCD("uber"))
				game.player.hit(1, this);
		}
	}
}

package happyptitank;

// @:bind Nature (symbol 73): the particles of a death (pictures only: visual random)
class Nature extends MovieClip {
	public var vect:{x:Float, y:Float};
	public var speed:Float;
	public var rotationSpeed:Float;
	public var scaleMax:Float;

	public function new() {
		super(73);
		gotoAndStop(Seed.randomVfx(totalFrames) + 1);
		rotationSpeed = 0;
		speed = 0;
		scaleMax = 1;
	}
}

class EnemyDeathAnim extends Sprite implements Anim {
	static var WHITE = 0;
	static var PARTICULES = 1;
	static var FADE = 2;

	static var BOOM_TIME = 0.5;
	static var FADE_TIME = 1;

	var enemy:Enemy;
	var hurt:HurtAnim;
	var state:Int;
	var time:Float;
	var particules:List<Nature>;

	public function new(enemy:Enemy) {
		super();
		this.state = WHITE;
		this.enemy = enemy;
		this.x = enemy.x;
		this.y = enemy.y;
		this.hurt = new HurtAnim(enemy, 200);
		// (port fix) no flash puts the colours back: the enemy stays white until it bursts (removed during that Flash
		// frame, it is still shown until the next one, Display.hx: with its colours back, it blinked)
		enemy.hurt = null;
		this.time = 0.0;
		Game.instance.fxLayer.addChild(this);
		Game.instance.addAnimation(this);
	}

	function boom() {
		particules = new List();
		var n = 15 + Seed.randomVfx(10);
		if (Game.instance.slowLevel == 3)
			n = Math.ceil(n / 4);
		else if (Game.instance.slowLevel == 2)
			n = Math.ceil(n / 3);
		else if (Game.instance.slowLevel == 1)
			n = Math.ceil(n / 2);
		var sr = 60 / Timer.wantedFPS;
		for (i in 0...n) {
			var n = new Nature();
			n.x = 0;
			n.y = 0;
			n.vect = {
				x: 1 - 2 * Seed.randVfx(),
				y: 1 - 2 * Seed.randVfx(),
			};
			n.rotationSpeed = (5 - Seed.randVfx() * 10) * sr;
			n.speed = (1.5 + Seed.randVfx() * 3) * sr;
			n.scaleMax = 0.5 * n.speed;
			addChild(n);
			particules.push(n);
		}
	}

	public function update():Bool {
		time += Timer.deltaT;
		switch (state) {
			case 0: // WHITE
				if (!hurt.update()) {
					boom();
					enemy.parent.removeChild(enemy);
					state++;
				}
			case 1: // PARTICULES
				var dt = Math.min(time, BOOM_TIME) / BOOM_TIME;
				for (p in particules) {
					p.x += Timer.tmod * (1 - dt) * p.speed * p.vect.x;
					p.y += Timer.tmod * (1 - dt) * p.speed * p.vect.y;
					p.rotation += p.rotationSpeed * Timer.tmod;
					p.scaleX = p.scaleMax * dt;
					p.scaleY = p.scaleMax * dt;
				}
				if (time >= BOOM_TIME) {
					state = FADE;
					time = 0;
				}
			case 2: // FADE
				var dt = Math.min(time, FADE_TIME) / FADE_TIME;
				for (p in particules) {
					p.x += Timer.tmod * p.speed * p.vect.x * 0.1;
					p.y += Timer.tmod * p.speed * p.vect.y * 0.1;
					p.rotation += p.rotationSpeed * Timer.tmod * 0.1;
					p.scaleX = p.scaleMax * (1 - dt);
					p.scaleY = p.scaleMax * (1 - dt);
					if (dt == 1) {
						removeChild(p);
						particules.remove(p);
					}
				}
				if (dt == 1 || particules.length == 0)
					return false;
		}
		return true;
	}
}

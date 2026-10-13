package happyptitank;

// @:bind XBall (symbol 197)
class XBall extends Enemy {
	public function new() {
		super(197);
		life = maxLife = 20;
	}
}

// @:bind XLink (symbol 199, a Sprite)
class XLink extends MovieClip {
	public function new() {
		super(199, true);
	}
}

enum XBallState {
	MOVE;
	WAIT;
	FIRE;
	WAITFIRE;
}

class XBalls extends Enemy {
	var state:XBallState;
	var stateEnd:Float;
	var link:XLink;
	var balls:Array<XBall>;

	public function new() {
		super();
		value = KKApi.const(600);
		balls = [];
		link = new XLink();
		addChild(link);
		for (c in [{x: -20, y: 0, r: 0}, {x: 0, y: -20, r: 90}, {x: 20, y: 0, r: 180}, {x: 0, y: 20, r: 270}]) {
			var b = new XBall();
			b.x = c.x;
			b.y = c.y;
			b.rotation = c.r;
			addChild(b);
			balls.push(b);
		}
		setState(MOVE, 1000);
		life = maxLife = 1000;
	}

	function setState(st, dur) {
		stateEnd = Game.instance.now + dur;
		state = st;
	}

	override public function collideWithShot(shot:Shot) {
		for (b in balls.copy()) {
			if (Collision.isColliding(shot, b, Game.instance.gameLayer, false, 0)) {
				b.damaged(shot.power);
				if (b.life <= 0) {
					removeChild(b);
					balls.remove(b);
					var angle = Geom.deg2rad(rotation);
					var origin = {x: b.x, y: b.y};
					Geom.rotate(origin, angle);
					Game.instance.fxLayer.addChild(b);
					b.x = x + origin.x;
					b.y = y + origin.y;
					// (port fix) the original kept the ball's rotation in the XBalls (0, 90, 180 or 270): out of the
					// turning XBalls, the dead ball flashed white turned away from where it was, detached from the
					// turret. Turned like it was shown (the picture only: nothing reads it)
					b.rotation = rotation + b.rotation;
					var f = new EnemyDeathAnim(b);
					if (balls.length == 0)
						life = 0;
				}
				return true;
			}
		}
		return false;
	}

	override public function update() {
		switch (state) {
			case MOVE:
				rotation += Timer.tmod * 5;
				if (Game.instance.now >= stateEnd)
					setState(WAIT, 250);

			case WAIT:
				if (Game.instance.now >= stateEnd)
					setState(FIRE, 0);

			case FIRE:
				var angle = Geom.deg2rad(rotation);
				for (b in balls) {
					var origin = {x: b.x, y: b.y};
					Geom.rotate(origin, angle);
					origin.x += x;
					origin.y += y;
					Game.instance.createEnemyLazer(origin, rotation + Geom.angleDeg({x: 0.0, y: 0.0}, b));
				}
				setState(WAITFIRE, 400);

			case WAITFIRE:
				if (Game.instance.now >= stateEnd)
					setState(MOVE, 1000);
		}
	}
}

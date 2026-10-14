package happyptitank;

import happyptitank.MoveManager;
import happyptitank.ShotManager;

// (a flash.display.MovieClip of the code; its subclasses bound to a symbol give their symbol, the others draw a
// DummyFoe)
class Enemy extends MovieClip {
	public var move:MoveManager;
	public var shot:ShotManager;

	public var wave:Bool;
	public var life:Int;
	public var maxLife:Int;
	public var lastShot:Float;
	public var shotRate:Float;
	public var value:KKConst;
	public var speed:Float;
	public var spawner:Spawner;
	// (port) the last HurtAnim of the enemy
	public var hurt:HurtAnim = null;

	private function new(?sym:Int = -1) {
		super(sym);
		wave = false;
		life = maxLife = 10;
		lastShot = Game.instance.now;
		shotRate = 1000;
		value = KKApi.const(100);
		speed = 0;
		Config.addGroundShadow(this);
	}

	public function setPos(p:Geom.Pt) {
		x = p.x;
		y = p.y;
	}

	public function damaged(pow:Int) {
		life = Std.int(Math.max(0, life - pow));
		Game.instance.addAnimation(new HurtAnim(this));
	}

	public function onDeath() {
		if (spawner != null)
			spawner.onChildDeath();
	}

	public function update() {
		if (shot != null)
			shot.update();
		if (move != null)
			move.update();
	}

	public function collideWithShot(shot:Shot) {
		if (Collision.isColliding(shot, this, Game.instance.gameLayer, false, 0)) {
			damaged(shot.power);
			return true;
		}
		return false;
	}
}

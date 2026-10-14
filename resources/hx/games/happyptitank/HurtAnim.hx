package happyptitank;

class HurtAnim implements Anim {
	var obj:DisplayObject;
	var end:Float;

	public function new(e:DisplayObject, time:Int = 100) {
		obj = e;
		end = Game.instance.now + time;
		obj.setColorTransform(1.0, 1.0, 1.0, 1.0, 1000.0, 1000.0, 1000.0, 1000.0);
		var en = Std.downcast(e, Enemy);
		if (en != null)
			en.hurt = this;
	}

	public function update():Bool {
		if (end <= Game.instance.now) {
			// (port fix) only the last flash of an enemy puts its colours back (none for a dying one, EnemyDeathAnim):
			// in the original, the flash of the killing shot (100 ms, Enemy.damaged) ended in the middle of the one of
			// the death (200 ms), the enemy killed (an XBall left behind by its turret) came back to its colours for
			// 100 ms before bursting. The picture only: the collisions ignore the colours (Collision.hx)
			var en = Std.downcast(obj, Enemy);
			if (en == null || en.hurt == this)
				obj.setColorTransform(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0);
			return false;
		}
		return true;
	}
}

package happyptitank;

import happyptitank.ShotManager;

// (a subclass of Foe: the burger of symbol 142 too)
class FoeShooter extends Foe {
	public function new() {
		super();
		shot = new ShotManager(this, [Pause(1000), Shot]);
	}

	override public function updateLeader() {
		var distToTank = Geom.distance(this, Game.instance.tank);
		if (distToTank <= 100) {
			// escape
			var angleToTank = Geom.angleRad(this, Game.instance.tank);
			var leftAngle = Geom.fixRadianAngle(angle - Math.PI / 4);
			var rightAngle = Geom.fixRadianAngle(angle + Math.PI / 4);
			if (Geom.angleDiff(leftAngle, angleToTank) > Geom.angleDiff(rightAngle, angleToTank)) {
				angle = leftAngle;
			} else {
				angle = rightAngle;
			}
		} else if (distToTank >= 175) {
			// aim tank
			angle = Geom.averageRadianAngle(angle, Geom.angleRad(this, Game.instance.tank));
		} else {
			// move along previous angle with minor change
			angle = Geom.fixRadianAngle(angle + 0.01);
		}
		Geom.moveAngle(this, angle, speed * Timer.tmod);
		if (Game.instance.warZone.isOutOfZone(this)) {
			angle = Geom.fixRadianAngle(angle + Math.PI);
			// (port fix) the original only turned back once out: the leader, then the burgers on its trail, went up
			// to a step (6 px) past the border, over the tape. Brought back to the border like the tank (Tank.update)
			Game.instance.warZone.recall(this);
		}
	}
}

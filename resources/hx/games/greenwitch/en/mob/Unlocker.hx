package greenwitch.en.mob;

class Unlocker extends greenwitch.en.Mob {
	// La porte que cet Unlocker a verrouillée OUVERTE (reste ouverte tant qu'il vit).
	var lockedDoor : greenwitch.en.Door;

	public function new(x,y) {
		super(x,y);

		maxPathLen = 30;

		coward = true;
		setSpeed(1.1);
		maxPathLen = 20;
		radius = 8;
		initLife(3);
		weight = 10;
		baseScore = 30;

		sprite.swap("unlocker");
		setShadow(true);
	}

	override function getLoot():Null<Int> { return 2; }
	override function getXp():Null<Int> { return 5; }

	override function moveAI() {
		if( cd.has("moveDecision") )
			return;

		// Joueur dans le coin ?
		if( roomId==hero.roomId || sightCheck(hero) ) {
			super.moveAI();
			return;
		}

		// A déjà verrouillé sa porte → ne cherche plus de porte (son rôle est fait), il erre.
		if( lockedDoor!=null ) {
			wander();
			decisionCD(30);
			return;
		}

		// Cherche une porte fermée
		var doors = greenwitch.en.Door.getDoors(roomId);
		var targets : Array<greenwitch.en.Door> = [];
		for(d in doors)
			if( d.isClosed() ) {
				if( d.inRoom(hero.roomId) || distance(d)<120 ) // proche, ou bien qui mène au joueur :)
					targets.insert(0, d);
				else
					targets.push(d);
			}

		if( targets.length>0 ) {
			fx.marker(targets[0].xx, targets[0].yy, 0x0080FF);
			if( gotoFreeCoord(targets[0].xx, targets[0].yy) ) {
				decisionCD(50);
				return;
			}
		}

		// Bah on se promène alors
		wander();
		decisionCD(30);
	}

	override private function onTouchDoor(d:greenwitch.en.Door) {
		// Verrouille la PREMIÈRE porte fermée atteinte : elle s'ouvre et reste bloquée
		// ouverte (verrou) tant que cet Unlocker n'est pas tué (cf. detach()).
		if( lockedDoor==null && d.isClosed() ) {
			cd.unset("moveDecision");
			d.forceOpen();
			d.locked = true;
			lockedDoor = d;
			fx.pop(d.xx,d.yy, Lang.DoorUnlocked, 0x7AE61A);
		}
	}

	override public function detach() {
		// Mort / retrait de l'Unlocker → on relâche le verrou : la porte peut de nouveau se fermer.
		if( lockedDoor!=null ) {
			lockedDoor.locked = false;
			// Verrou retiré → la porte reprend AUSSITÔT son comportement normal, sans qu'on
			// ait à aller l'actionner : fermée si la sorcière est loin, laissée ouverte si
			// elle est à portée (la gestion auto des portes du héros reprend la main ensuite).
			lockedDoor.set( hero==null || !lockedDoor.canBeReachedBy(hero) );
			lockedDoor = null;
		}
		super.detach();
	}

	override function update() {
		super.update();
		sprite.scaleX = dx>0 ? 1 : -1;
	}
}

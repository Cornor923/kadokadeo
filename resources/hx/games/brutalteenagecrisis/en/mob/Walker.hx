package brutalteenagecrisis.en.mob;

class Walker extends brutalteenagecrisis.en.Mob {
	public static var ALL : Array<Walker> = [];
	static var JUMP_DX = 0.03;

	var blockedCounter		: Int;
	var jumping				: Bool;
	public var canClimb		: Bool;
	var animBaseKey(default,set)	: String;

	public function new(x,y) {
		super(x,y);

		animBaseKey = "mob_b";
		canClimb = true;
		jumping = false;
		blockedCounter = 0;
		ALL.push(this);

		resetIgnoreLadder();

		fx.spawn(xx,yy);
	}

	override function unregister() {
		super.unregister();
		ALL.remove(this);
	}

	function set_animBaseKey(s:String) {
		animBaseKey = s;

		sprite.a.removeAllStateAnims();
		sprite.a.registerStateAnim( animBaseKey+"_climb", 1, function() return climbing );
		sprite.a.registerStateAnim( animBaseKey+"_run", 0 );

		return s;
	}

	function resetIgnoreLadder() {
		cd.set("ignoreLadder", Const.seconds( rnd(0, 4) ));
	}

	override function onBeginFloor() {
		super.onBeginFloor();
		resetIgnoreLadder();
	}

	override public function hit(ox,oy,d) {
		if( climbing ) {
			leaveLadder();
			resetIgnoreLadder();
		}

		super.hit(ox,oy, d);

		sprite.a.play(animBaseKey+"_hit");
		jumping = false;
	}


	function grabLadder() {
		climbing = true;
		stable = false;
		dx*=0.2;
		dy = 0;
	}

	function leaveLadder() {
		climbing = false;
		stable = false;
		dy*=0.5;
		dx*=0.5;
	}

	function jumpX() {
		dx = 0.3*dir;
		dy = -0.40;
		stable = false;
		jumping = true;
	}

	override function onLand() {
		jumping = false;
		if( climbing )
			leaveLadder();

		super.onLand();
	}


	function onAboutToFall() {
		blockedCounter++;
		if( blockedCounter<=8 ) { // Drops down when blocked on this floor
			// Stays on the current floor
			if( hasCollision(cx+dir*3, cy+1) && !hasCollision(cx+dir*3, 0) )
				jumpX();
			else {
				xr = dir==1 ? 0.8 : 0.2;
				dx = 0;
				dir*=-1;
			}
		}
	}

	function onWallBounce() {
		blockedCounter++;
		dir*=-1;
		dx = 0;
		xr = 0.5;
	}


	override function preX() {
		super.preX();
		if( stable && !cd.has("stun") ) {
			// Right
			if( dir==1 ) {
				if( hasCollision(cx+dir,cy) && xr>=0.5 )
					onWallBounce();

				if( !hasCollision(cx+dir,cy+1) && xr>=0.8 )
					onAboutToFall();
			}

			// Left
			if( dir==-1 ) {
				if( hasCollision(cx+dir,cy) && xr<=0.5 )
					onWallBounce();

				if( !hasCollision(cx+dir,cy+1) && xr<=0.2 )
					onAboutToFall();
			}
		}
	}

	public function onReachTop() {
		if( mode.hero.hasLeft )
			cy = -100;
		else {
			destroy();
			mode.hero.loseCredit();
			fx.loseLife(xx);
		}
	}


	override function update() {
		// Warning!
		if( !mode.hero.hasLeft && mode.time%10==0 && climbing && mode.level.hasLadder(cx,cy) ) {
			var lcy = cy;
			while( lcy>0 && !hasCollision(cx,lcy) )
				lcy--;
			if( lcy<=0 )
				fx.danger(cx);
		}

		if( climbing && cy<0 ) {
			onReachTop();
			return;
		}

		if( !cd.has("stun") )  {
			if( climbing ) {
				// Climbs a ladder
				dy -= speed*0.4;
			}
			else if( jumping )
				// Jumping
				dx += dir * JUMP_DX;
			else {
				// Walks
				dx += dir * speed;
			}

			if( mode.level.hasLadder(cx,cy) ) {
				blockedCounter = 0;
				// Grabs a ladder
				if( canClimb && !cd.has("ignoreLadder") && stable && !climbing ) {
					yr = 0.8;
					grabLadder();
				}
			}
		}

		// Leaves the ladder
		if( climbing && !mode.level.hasLadder(cx,cy) )
			leaveLadder();

		// Stunned
		if( cd.has("stun") )
			dx*=0.8;

		super.update();

		if( climbing )
			sprite.y += Std.int( Math.sin(mode.time*0.6)*3 );
	}
}


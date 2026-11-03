package fafi360.en;

typedef Point = {
	var x : Float;
	var y : Float;
}

enum ShootMode {
	Full360;
	Restrict(baseAng:Float, range:Float, ?raise:Bool);
}

// A player of the League. Its picture is lib.Perso: the code plays the pose (label) and the frames of its _skin, _shoes,
// _hair (and its _sub: the hair style) and _maillot (coloured by the team) clips, the nested clips of arkadeo.Clip.
class Player extends Entity {
	public var reach		: Float;
	public var origin		: Point;
	public var precision	: Float;
	public var accel		: Float;
	public var speedMul		: Float;
	public var normalFrict	: Float;
	public var strength		: Int;
	var shootMode			: ShootMode;
	public var isGoal		: Bool;


	public var gotBallThisRound	: Bool;

	public var team		: TeamInfos;
	public var id		: Int;
	public var mc		: MovieClip;
	var anim			: {k:String, frame:Float, loop:Bool};
	var idleSpeed		: Float;

	public var dir		: Int;
	public var side		: Int;
	var arrow			: Sprite;
	var radiusSpr		: Bitmap;
	var target			: Null<Point>;
	public var ang		: Float;
	public var seekingBall	: Bool;

	var hitRadius		: Float;
	var fightRadius		: Float;

	var hairId			: Int;
	var shirtFilter		: Null<ColorMatrixFilter>;

	public function new(s:Int, ti:TeamInfos) {
		super();

		team = ti;
		idleSpeed = rnd(0.6, 1.3);
		side = s;
		id = getTeamPlayers().length;
		ang = 0;
		dir = 1;
		speedMul = 1;
		hitRadius = 8;
		normalFrict = frict = 0.85;
		colBounce = 0.3;
		zbounce = 0.2;
		gotBallThisRound = false;
		hairId = side==0 ? id+1 : team.hairFrame;
		shootMode = Full360;
		fightRadius = 15;
		origin = {x:0, y:0}

		getTeamPlayers().push(this);
		game.allPlayers.push(this);

		shirtFilter = new ColorMatrixFilter();

		// (blendMode LAYER: the alpha of the player is given to each of its parts, PIXI has no layer)
		mc = new MovieClip("Perso");
		spr.addChild(mc);
		setAnim("idle");

		//#if debug if( debug() ) for(l in mc.currentLabels) trace(l.name); #end

		// Flèche de visée
		arrow = new Sprite();
		if( isPlayable() ) {
			var c = 0x784BCB;
			game.sdm.add(arrow, Game.DP_BG2);
			var g = arrow.graphics;
			g.beginFill(c, 1);
			g.moveTo(0, -10);
			g.lineTo(25, 0);
			g.lineTo(0, 10);
			g.lineTo(5, 0);
			g.endFill();
			arrow.blendMode = BlendMode.ADD;
			arrow.filters = [
				new GlowFilter(c,0.7, 16,16,1),
			];
		}

		setShadow(20,7);
		updateStats();
	}

	public function updateStats() {
		initSeed();

		shirtFilter = mt.deepnight.Color.getColorizeFilter(getColor(), 1, 0);
		part("_maillot").filters = [shirtFilter.toPixi()];

		// Mode League
		if( game.isLeague() ) {
			if( id==0 && (isPlayable() || game.getPlayerScore()>=2) )
				isGoal = true;
			else
				isGoal= false;

			accel = isPlayable() ? 0.060 : 0.045;
			precision = isGoal ? rnd(0.4, 0.8) : rnd(0,1);
			strength = isPlayable() ? 50 : 50;
			reach = isPlayable() ? rnd(30,50) : 80;
		}

		// Mode LevelUp
		if( game.isProgression() ) {
			isGoal = id==0 && ( side==0 || side==1 && !team.hasPerk(_PNoGoal) );
			accel = 0.045;
			precision = rnd(0, 0.3);
			strength = 50;
			reach = isPlayable() ? 40 : 80;

			if( team.hasPerk(_PSuperStrong) )
				strength = 99999;
			if( team.hasPerk(_PWeak) )
				strength = 5;

			if( isGoal ) {
				if( team.hasPerk(_PPreciseGoal) )
					precision = 0.8;
				if( team.hasPerk(_PReachGoal) )
					reach += 20;
				if( team.hasPerk(_PStrongGoal) )
					strength = 999999;
			}

			if( !isGoal && isDefense() ) {
				if( team.hasPerk(_PPreciseDefense) )
					precision = 0.5;
				if( team.hasPerk(_PStrongDefense) )
					strength += 30;
				if( team.hasPerk(_PFastDefense) )
					accel = 0.050;
				if( team.hasPerk(_PReachDefense) )
					reach+=20;
			}
			if( !isDefense() ) {
				if( team.hasPerk(_PPreciseAttack) )
					precision = 0.5;
				if( team.hasPerk(_PFastAttack) )
					accel = 0.050;
				if( team.hasPerk(_PReachAttack) )
					reach+=20;
			}
			if( team.hasPerk(_PReachAll) )
				reach += 10;
			if( team.hasPerk(_PLowRange) )
				reach = 30;
			if( team.hasPerk(_PSlow) )
				accel = 0.030;
		}


		updateRadius();
	}

	function isDefense() {
		return
			if( side==0 )
				origin.x < Game.GRID*(Game.FPADDING+Game.FWID*0.5);
			else
				origin.x > Game.GRID*(Game.FPADDING+Game.FWID*0.5);
	}

	function updateRadius() {
		if( radiusSpr!=null ) {
			if( radiusSpr.bitmapData!=null )
				radiusSpr.bitmapData.dispose();
			radiusSpr.parent.removeChild(radiusSpr);
		}

		// (the range of the players of the opponent is never shown: no picture drawn for it, a RenderTexture each, all of
		// them again at each round)
		if( !isPlayable() ) {
			radiusSpr = new Bitmap();
			game.sdm.add(radiusSpr, Game.DP_BG2);
			radiusSpr.visible = false;
			return;
		}

		var s = new Sprite();
		var m = new Matrix();
		m.createGradientBox(reach*2, reach*2, 0);
		var c = 0xFFFFFF;
		s.graphics.beginGradientFill(GradientType.RADIAL, [c,c], [0, 0.2], [180,255], m);
		s.graphics.drawCircle(reach,reach,reach);
		s.graphics.endFill();

		radiusSpr = new Bitmap( new BitmapData(Math.ceil(reach*2), Math.ceil(reach*2), true, 0x0) );
		game.sdm.add(radiusSpr, Game.DP_BG2);
		radiusSpr.visible = isPlayable();
		radiusSpr.bitmapData.draw(s);
		// blendMode OVERLAY: the overlay of arkadeo.OverlayBlend (Game registers its blend mode)
		radiusSpr.node.filters = [new OverlayBlend()];
		radiusSpr.alpha = 0.3;
	}

	public override function toString() {
		return "Team"+side+"#"+id+"@"+(cx+Math.round(xr*100)/100)+","+(cy+Math.round(yr*100)/100);
	}

	public override function unregister() {
		super.unregister();

		game.allPlayers.remove(this);
		getTeamPlayers().remove(this);

		if( arrow.parent!=null )
			arrow.parent.removeChild(arrow);
		radiusSpr.parent.removeChild(radiusSpr);
		if( radiusSpr.bitmapData!=null )
			radiusSpr.bitmapData.dispose();
		mc.dispose();
	}

	inline function debug() {
		return id==0 && side==0;
	}

	public inline function getTeamPlayers() {
		return side==0 ? game.playerTeam.players : game.oppTeam.players;
	}

	public inline function getColor() {
		//return side==0 ? 0x3980F4 : 0xDA5454;
		return isGoal ? 0xFFD735 : team.color;
	}

	// mc._skin, mc._shoes, mc._hair, mc._maillot: the nested clips of the current pose
	inline function part(name:String):Clip {
		return mc.getClip(name);
	}

	public inline function isPlayable() {
		return side==0;
	}

	public inline function isKnocked() {
		return cd.has("knock");
	}

	public function knock(a:Float, ?pow=1.0) {
		if( team.hasPerk(_PKamikaze) ) {
			cd.set("kamikaze", 30);
			cd.onComplete("kamikaze", function() explode(60));
		}

		clearTarget();
		arrow.visible = false;
		cd.unset("animLock");

		var s = 0.4*pow;
		dx = Game.cos(a)*s;
		dy = Game.sin(a)*s;
		dir = dx<0 ? -1 : 1;
		cd.set("knock", 60);
		if( hasBall() )
			kickBall(a, rnd(0.5, 0.8), rnd(0.4, 0.8));
	}

	public function battle(e:Player) {
		if( isKnocked() || e.isKnocked() )
			return;

		if( side==e.side )
			return;

		fx.clash(this, e);

		var winner;
		var loser;
		if( e.strength-strength>1000 ) {
			winner = e;
			loser = this;
		}
		else if( strength-e.strength>1000 ) {
			winner = this;
			loser = e;
		}
		else {
			var rlist = new RandList();
			rlist.add(this, strength);
			rlist.add(e, e.strength);
			winner = rlist.draw(rseed.random);
			loser = winner!=this ? this : e;
		}

		if( winner.team.hasPerk(_PSuperStrong) )
			fx.flashBang(0xFF0000, 0.5, 500);

		var a = Math.atan2(loser.yy-winner.yy, loser.xx-winner.xx);
		loser.knock(a);
	}

	public function takeBall(gainMul:Bool) {
		setRestrictMode(false);

		if( gainMul && game.isLeague() ) {
			if( side==0 && !gotBallThisRound ) {
				game.pass++;
				if( game.pass>0 )
					game.onSuccessfulPass(this);
				game.onPassChange();
			}
			if( side==0 && game.pass<0 ) {
				game.pass = 0;
				game.onPassChange();
			}
			if( side==1 ) {
				if( game.pass>0 )
					fx.popPass(xx,yy, -1);
				game.pass = -1;
				game.onPassChange();
			}
		}

		gotBallThisRound = true;

		if( isPlayable() )
			fx.surprise(this);

		fx.glow(this, getColor(), 800);
		if( game.ball.z>=9 ) {
			setAnim("saute");
			dz = 1;
		}
		game.ball.takenBy(this);
		game.resetCharge();
		clearTarget();

		if( !isPlayable() ) {
			if( isGoal )
				cd.set("waitKick", rnd(5,8));
			else
				cd.set("waitKick", rnd(7,12));
		}
	}

	public function setRestrictMode(b:Bool) {
		var base = side==0 ? 0 : 3.14;
		var range = 3.14;
		shootMode = b ? Restrict(base, range) : Full360;
		ang = base+range*0.5;
	}

	inline function getPositionRatio() {
		return {
			x : (cx-Game.FPADDING)/Game.FWID,
			y : (cy-Game.FPADDING)/Game.FHEI,
		}
	}

	inline function getPositionQuality() {
		var r = getPositionRatio();
		return (1-Math.min(1, r.x/0.5)) * Math.min(1, 1-Math.abs(0.5-r.y)/0.5);
	}

	public function iaKick() {
		if( !game.isPlaying() )
			return;

		var closeRange = 55;

		var pr = getPositionRatio();

		// Tir générique
		var a = 3.14 + rnd(0, 0.4, true);
		var pow = rnd(0.5, 0.7);
		var aerial = rnd(0, 0.7);

		if( team.getSkill()>=2 ) {
			a = Math.atan2(Game.FPADDING+Game.FHEI*0.5 - cy, -1-cx) + rnd(0.10, 0.30, true);
			pow = rnd(0.7, 0.9);
		}

		// Moitié supérieure
		if( pr.y<0.4 )
			a-=0.7;

		// Moitié inférieure
		if( pr.y>0.6 )
			a+=0.7;

		if( isGoal ) {
			// Dégagement du gardien
			a = 3.14 + rnd(0.2, 0.4, true);
			pow = rnd(0.9, 1.1);
			aerial = rnd(0.7, 1);
		}
		else {
			if( pr.x<=0.2 && pr.y<=0.3 ) {
				// Corner haut
				a = rnd(0.7, 1.57);
			}
			else if( pr.x<=0.2 && pr.y>=0.7 ) {
				// Corner base
				a = -rnd(0.7, 1.57);
			}
			else if( pr.x<=0.35 && pr.y>=0.30 && pr.y<=0.70 ) {
				// Tir au but !
				var r = game.getGoalRectangle(0);
				var pt = { x:(r.x+r.w)*Game.GRID, y:(r.y+r.h*0.5)*Game.GRID }
				a = Math.atan2(pt.y-yy, pt.x-xx);
				switch( team.getSkill() ) {
					case 0 :
						pow = rnd(0.4, 0.6);
						aerial = rnd(0, 0.8);
						a += rnd(0.2, 0.4, true);
					case 1 :
						pow = rnd(0.6, 0.8);
						aerial = rseed.random(100)<70 ? rnd(0.2, 0.4) : rnd(0.8, 1);
						a += rnd(0.05, 0.25, true);
					default :
						a += rnd(0, 0.15, true);
						pow = 1;
						aerial = rnd(0.6, 0.7);
				}
			}
			else {
				// Vise un allié
				var maxDist = switch( team.getSkill() ) {
					case 0 : 170;
					case 1 : 250;
					default : 350;
				}
				var targets = Lambda.array( Lambda.filter(getTeamPlayers(), function(p) {
					var d = distance(p);
					return p.cx<cx && d>=closeRange && d<maxDist;
				}) );
				targets.sort(function(p1,p2) return -Reflect.compare(p1.getPositionQuality(), p2.getPositionQuality()));

				if( targets.length>0 ) {
					var p = targets[0];
					var pdist = distance(p);
					a = Math.atan2(p.yy-yy, p.xx-xx);
					pow = Math.min(1, pdist/300);
					switch( team.getSkill() ) {
						case 0 : aerial = rnd(0, 1);
						case 1 : aerial = rnd(0.3, 1);
						default :
							aerial = pdist<=160 ? rnd(0, 0.3) : rnd(0.5, 1);
					}
					// Erreur de visée
					switch( team.getSkill() ) {
						case 0 : a+=rnd(0.25, 0.45, true);
						case 1 : a+=rnd(0.10, 0.30, true);
						default : a+=rnd(0, 0.12, true);
					}
				}
			}
		}

		// On empêche les voisins de bus de prendre le ballon...
		for(p in game.allPlayers)
			if( p!=this && p.side==1 && distance(p)<=closeRange )
				p.cd.set("catchLock",40);

		kickBall(a, pow, aerial);
	}

	public function kickBall(a:Float, ?power=1.0, ?aerialPower=0.0) {
		var b = game.ball;
		//power-=aerialPower*0.2;
		var s = 0.68; // 0.65
		b.dx = Game.cos(a)*s*power;
		b.dy = Game.sin(a)*s*power;
		b.dz = 0.5 + aerialPower * 6.5;
		b.onKick();

		game.fx.grassKick(xx,yy, a, 15);
		game.fx.hit(b.xx, b.yy);
		game.fx.lightSlash(b.xx, b.yy, a);
		game.allowRun = true;

		dir = b.dx<0 ? -1 : 1;
		dz = 1.8;
		dx = 0;

		setAnim("shoot", 6, false);

		cd.set("stop", 20);

		for( p in game.allPlayers )
			p.clearTarget();

		//cd.set("stop", 30*6);
		//b.dx = 0.1;
		//b.dy = 0.1;
		//b.dz = 0;
	}

	public inline function hasBall() {
		return game.ball.owner==this;
	}

	public function clearTarget() {
		target = null;
	}

	public function setTarget(x:Float,y:Float, ?spd=1.0) {
		if( game.matchEnded() )
			return;
		speedMul = spd;
		target = {x:x, y:y}
	}

	public function setAnim(k:String, ?duration=-1, ?loop=true) {
		if( hasAnim(k) || cd.has("animLock") )
			return;
		if( duration>0 )
			cd.set("animLock", duration);
		//var inf = animInfos.get(k);
		mc.gotoAndStop(k);
		// (the first frame of the animation only changes the picture: the random of the effects)
		anim = {k:k, frame:Seed.randomVfx(part("_skin").totalFrames)+1, loop:loop}
		part("_skin").gotoAndStop(anim.frame);
		part("_shoes").gotoAndStop(anim.frame);
		part("_hair").gotoAndStop(anim.frame);
		part("_maillot").gotoAndStop(anim.frame);
		var smc = part("_hair").getClip("_sub");
		smc.gotoAndStop(hairId);

		part("_maillot").filters = [shirtFilter.toPixi()];
	}

	public function hasAnim(k:String) {
		return anim!=null && anim.k==k;
	}

	inline function isGoodTarget() {
		return game.isPlaying() && isPlayable() && game.isLeague() && game.ball.hasOwner() && game.ball.owner.side==side && !gotBallThisRound;
	}

	public inline function nearOrigin() {
		return mt.deepnight.Lib.distanceSqr(xx,yy, origin.x, origin.y)<=30*30;
	}


	override public function update() {
		fl_collide = !game.isWaitingPlayers();

		var isOnScreen = onScreen();
		var suspend = game.isSuspended();
		var b = game.ball;

		if( !suspend && !isKnocked() ) {
			// Tir de l'IA
			if( hasBall() && !isPlayable() && !cd.has("waitKick") && z==0 )
				iaKick();

			// Course après le ballon
			if( b.free() && !cd.has("stop") ) {
				var d = mt.deepnight.Lib.distance(xx,yy, b.xx, b.yy);
				if( d<=120 ) {
					var anticip = if( d<=30 ) 20 else 120;

					setTarget(b.xx + b.dx*anticip, b.yy + b.dy*anticip, d<=reach && !cd.has("catchLock") ? 1 : 0.3);
					seekingBall = d<=reach;
				}
				else {
					seekingBall = false;
					dx*=0.8;
					dy*=0.8;
				}

				// Attrape le ballon
				if( d<=hitRadius*3 && game.isPlaying() && !cd.has("catchLock") )
					if( Math.abs(z-b.z)<=15 ) {
						if( z>0 ) {
							if( isGoal )
								fx.flashBang(team.color, 0.3, 1000);
							fx.airGrab(this);
						}
						takeBall(true);
						cd.set("catchLock", 40);
					}

				// Saut pour rattraper la balle
				if( !hasBall() && d<=hitRadius*2 && game.isPlaying() && Math.abs(z-b.z)>15 && z==0 ) {
					if( isGoal && team.hasPerk(_PGoalJump) || isDefense() && team.hasPerk(_PDefenseJump) ) {
						if( isPlayable() )
							dz = 3.5;
						else
							dz = isGoal ? 5 : 3;
						dx*=0.4;
						dy*=0.4;
						setAnim("saute");

						var fail = game.isProgression() ? 33 : 50;
						if( rseed.random(100)<fail )
							cd.set("catchLock", 30); // loupé...
					}
				}
			}

			// Retour à la position normale
			if( b.hasOwner() && !hasBall() && !cd.has("manualRun") )
				setTarget(origin.x, origin.y, game.isPlaying() ? 0.4 : 1.6);

			// Mouvement vers la cible
			if( target!=null && z<=0 ) {
				var d = mt.deepnight.Lib.distance(xx,yy, target.x,target.y);
				if( d<=5 ) {
					clearTarget();
					dx*=0.7;
					dy*=0.7;
				}
				else {
					var a = Math.atan2(target.y-yy, target.x-xx);
					dx += Game.cos(a)*accel*speedMul;
					dy += Game.sin(a)*accel*speedMul;
				}
			}

			// Rotation
			if( isPlayable() && !cd.has("shootDelay") ) {
				arrow.visible = hasBall() && game.isPlaying();
				if( arrow.visible ) {
					arrow.rotation = mt.MLib.toDeg(ang);
					arrow.x = spr.x + Game.cos(ang)*20;
					arrow.y = spr.y + Game.sin(ang)*20;
					arrow.transform.colorTransform = game.isClicking() ? mt.deepnight.Color.getColorizeCT(0xFFAC00, game.getClickPower()) : new ColorTransform();
					// (the debug build of the original aimed at the mouse: not ported, the debug build is the one tested)
					if( !game.isClicking() ) {
						var as = 0.16  +  0.08*(1-precision)  +  0.20*Math.min(1, game.diff/10);
						switch( shootMode ) {
							case Full360 :
								ang += as;
							case Restrict(base, range, raise) :
								if( raise==true ) {
									ang+=as;
									var d = base-ang;
									if( d>=Math.PI ) d-=Math.PI*2;
									if( Math.abs(d)>=range*0.5 ) {
										ang = base+range*0.5;
										shootMode = Restrict(base, range, !raise);
									}
								}
								else {
									ang-=as;
									var d = base-ang;
									if( d>=Math.PI ) d-=Math.PI*2;
									if( Math.abs(d)>=range*0.5 ) {
										ang = base-range*0.5;
										shootMode = Restrict(base, range, !raise);
									}
								}
								//ang += raise ? as : -as;
								//if( raise!=true && ang<=a-r*0.5 ) { // false ou null
									//ang = a-r*0.5;
									//shootMode = Restrict(a,r,true);
								//}
								//if( raise==true && ang>=a+r*0.5 ) {
									//ang = a+r*0.5;
									//shootMode = Restrict(a,r,false);
								//}
						}
					}
					var pi = Math.PI;
					while(ang>pi) ang-=pi*2;
					while(ang<-pi) ang+=pi*2;
				}
			}

			// Repoussement
			if( game.isPlaying() ) {
				var r = hitRadius;
				for( p in game.allPlayers ) {
					if( p==this )
						continue;
					var d = mt.deepnight.Lib.distanceSqr(xx, yy, p.xx, p.yy);
					var maxDist = hitRadius+p.hitRadius;
					if( d<=maxDist*maxDist ) {
						d = Math.sqrt(d);
						if( d <= maxDist ) {
							var pow = isKnocked() || p.isKnocked() || p.side==side ? 0.16 : 0.4;
							var a = Math.atan2(p.yy-yy, p.xx-xx);
							var midX = xx + (p.xx-xx)*0.5;
							var midY = yy + (p.yy-yy)*0.5;
							dx+= -Game.cos(a)*pow;
							dy+= -Game.sin(a)*pow;
							p.dx+= Game.cos(a)*pow;
							p.dy+= Game.sin(a)*pow;
							battle(p);
						}
					}
				}
			}

		}

		// Direction
		if( isOnScreen && z==0 && !cd.has("stop") ) {
			if( dx>0 )
				dir = 1;
			if( dx<0 )
				dir = -1;
			if( dx==0 && dy==0 && !isKnocked() ) {
				if( hasBall() )
					dir = side==0 ? 1 : -1; // le porteur regarde le but
				else
					if( game.ball.xx<xx )
						dir = -1;
					if( game.ball.xx>xx )
						dir = 1;
			}
			if( isGoal ) {
				var prx = getPositionRatio().x;
				if( side==0 && prx>=-0.03 && prx<=0.15 )
					dir = 1;
				if( side==1 && prx>=0.85 && prx<=1.03 )
					dir = -1;
			}
		}
		mc.scaleX = dir;


		// (the debug build of the original kept the normal friction with the ball: not ported)
		if( game.isPlaying() && hasBall() )
			frict = isGoal ? 0.7 : 0.8;
		else
			frict = isKnocked() ? 0.94 : normalFrict;

		shadow.visible = spr.visible = isOnScreen;

		super.update();

		var curSpd = getActualSpeed();
		var isOnScreen = onScreen();

		// Animation
		if( isOnScreen ) {
			if( isKnocked() )
				setAnim("fail");
			else if( z==0 ) {
					if( curSpd>=0.10 && !team.hasPerk(_PSlow) )
						setAnim("sprint");
					else if( curSpd>=0.02 )
						setAnim("walk");
					else
						if( hasBall() )
							setAnim("idle_drunk");
						else
							if( isGoodTarget() && !suspend )
								setAnim("moi");
							else
								setAnim("idle");
				}

			var aspd = 1.0;
			aspd += curSpd*2;
			if( hasAnim("idle") || hasAnim("idle_drunk") )
				aspd*=idleSpeed;
			anim.frame+=aspd;
			if( anim.loop )
				while( anim.frame>part("_skin").totalFrames )
					anim.frame -= part("_skin").totalFrames;
			else if( anim.frame>part("_skin").totalFrames )
				anim.frame = part("_skin").totalFrames;
			var f = Std.int(anim.frame);
			part("_skin").gotoAndStop(f);
			part("_shoes").gotoAndStop(f);
			part("_hair").gotoAndStop(f);
			part("_maillot").gotoAndStop(f);

			if( curSpd>=0.1 )
				fx.smoke(xx,yy);
		}


		// Gestion du radius
		if( radiusSpr.visible ) {
			radiusSpr.x = spr.x - radiusSpr.width*0.5;
			radiusSpr.y = spr.y - radiusSpr.height*0.5;
		}
		if( (b.free() || suspend) && radiusSpr.alpha>0.35 )
			radiusSpr.alpha-=0.1;
		if( !suspend && !b.free() && b.owner.side==side && radiusSpr.alpha<1 )
			radiusSpr.alpha+=0.1;

		spr.alpha = !isKnocked() ? 1 : (game.time%3==0 ? 0.5 : 0.8);
		if( !isKnocked() )
			if( !b.free() && b.owner.side!=side && !isPlayable() )
				spr.alpha = 0.7;
			else
				spr.alpha = 1;

		if( isOnScreen && !suspend && game.time%10==0 && isGoodTarget() )
			fx.glow(this, 0xFFFF00, 300 );
	}
}

package brutalteenagecrisis.mode;

class League extends Mode {

	public function new(g) {
		super(g);
		hero.setCredits(3);
		nextPowerUp = Const.seconds(6);
	}

	override function isLeague() {
		return true;
	}

	override function newLevel() {
		super.newLevel();
		level = new Level();
		level.readFromFile(0);
		level.render();

		cd.unset("mobSpawn");

		hero = new brutalteenagecrisis.en.Hero();
	}

	override function addPowerUp() {
		super.addPowerUp();

		var pt = level.getRandomSpotFar();

		var rlist = new mt.deepnight.RandList();
		rlist.add( function() new brutalteenagecrisis.en.it.Bomb(pt.cx, pt.cy), 100 );
		rlist.add( function() new brutalteenagecrisis.en.it.SuperPower(pt.cx, pt.cy), 5 );
		rlist.add( function() new brutalteenagecrisis.en.it.MegaBomb(pt.cx, pt.cy), 10 );
		rlist.draw(Seed.random)();

		nextPowerUp = Const.seconds( Seed.range(5,7) );
	}

	public inline function getMaxMobs() {
		return Std.int( 3 + diff*0.05 );
	}

	public function addMob() {
		var pt = level.getRandomSpotFar( Seed.irange(0,1) );

		var rlist = new mt.deepnight.RandList();
		// Small and slow
		rlist.add( function() new brutalteenagecrisis.en.mob.Simple(pt.cx, pt.cy), Std.int(Math.max(0, 500 * (1-diff/20))) );

		// Normal
		rlist.add( function() new brutalteenagecrisis.en.mob.Classic(pt.cx, pt.cy), 100 );

		// Explosive
		rlist.add( function() new brutalteenagecrisis.en.mob.Bomber(pt.cx, pt.cy), 3 );

		// Big
		if( diff>=50 && brutalteenagecrisis.en.mob.Big.COUNT<2 )
			rlist.add( function() new brutalteenagecrisis.en.mob.Big(pt.cx, pt.cy), 10 );

		// Smart
		if( diff>=90 )
			rlist.add( function() new brutalteenagecrisis.en.mob.Smart(pt.cx, pt.cy), 10 );

		// Flying
		if( diff>=250 )
			rlist.add( function() new brutalteenagecrisis.en.mob.Fly(), 10 );

		rlist.draw(Seed.random)();
		var d = 30 * ( 0.25 + 1.25 * Math.max(0, 1-diff/60) );
		cd.set( "mobSpawn", d );
	}

	override function update() {
		super.update();

		// Enemies respawn
		if( !cd.has("mobSpawn") && countRealMobs() < getMaxMobs() )
			addMob();

		// Difficulty goes up by itself
		var diffFreq : Float = Const.AUTODIFF;
		diffFreq -= 15*skill;
		if( !cd.hasSet("autoDiff", diffFreq) )
			diff++;
	}

}

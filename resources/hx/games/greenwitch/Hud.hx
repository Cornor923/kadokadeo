package greenwitch;



class Hud {
	static inline var WID = Std.int( Const.WID*0.5 );
	static inline var XP_WID = 70;
	static inline var XP_HEI = 3;
	var game				: greenwitch.mode.Play;
	
	var wrapper				: Sprite;
	
	var wicon				: BSprite;
	var ticon				: BSprite;
	var ammo				: TextField;
	var turrets				: TextField;
	var textFilters			: Array<BitmapFilter>;
	
	var blink				: Bitmap;
	var warnAmmo			: Bitmap;
	var warnTurrets			: Bitmap;
	
	var xp					: TextField;
	var xpBar				: Bitmap;
	#if gw_debug
	var debug				: TextField;
	#end
	
	public function new() {
		game = greenwitch.mode.Play.ME;
		
		textFilters = [
			new DropShadowFilter(1,90, 0xFFFFFF,0.4, 0,0,1, 1,true),
			new GlowFilter(0x0,0.5, 2,2, 4),
		];
		
		wrapper = new Sprite();
		game.buffer.dm.add(wrapper, Const.DP_INTERF);
		wrapper.mouseChildren = wrapper.mouseEnabled = false;
		wrapper.y = game.buffer.height-22;

		#if gw_debug
		var tf = game.createField("???");
		game.buffer.dm.add(tf, Const.DP_INTERF);
		debug = tf;
		tf.x = 50;
		tf.width = 300;
		tf.height = 16;
		tf.y = 5;
		#end
		
		// Munitions
		var tf = game.createField("???");
		wrapper.addChild(tf);
		ammo = tf;
		tf.width = 50;
		tf.height = 16;
		tf.x = 24;
		tf.y = 3;
		tf.filters = textFilters;
		
		// Icone munitions
		wicon = game.char.get("stuffIcon", 0);
		wrapper.addChild(wicon);
		wicon.setCenter(0,0);
		wicon.x = 1;
		wicon.filters = [ new GlowFilter(0x0,1, 2,2,3) ];
		
		if( game.isProgression() ) {
			// Barre XP
			xpBar = new Bitmap( new BitmapData(XP_WID, XP_HEI, true, 0x0) );
			xpBar.bitmapData.fillRect( new Rectangle(0,0, XP_WID, XP_HEI), Color.addAlphaF(0x0) );
			wrapper.addChild(xpBar);
			xpBar.x = Std.int(WID*0.5-XP_WID*0.5);
			xpBar.y = 12;
			xpBar.filters = [
				new GlowFilter(0x0,1, 2,2,6),
				new GlowFilter(0x97C0CC,1, 2,2,8),
				new GlowFilter(0x0,1, 2,2,6),
				//new DropShadowFilter(1,90, 0x0,0.2, 2,2,1),
			];
			// Texte XP
			var tf = game.createField("?", 0x97C0CC);
			wrapper.addChild(tf);
			xp = tf;
			tf.width = 50;
			tf.height = 16;
			tf.x = xpBar.x-10;
			tf.y = 4;
			tf.filters = textFilters;
			tf.filters = [
				new GlowFilter(0x0,1, 2,2,6),
			];
		}
		
		// Tourelles
		var tf = game.createField("???");
		wrapper.addChild(tf);
		turrets = tf;
		tf.width = 50;
		tf.height = 16;
		tf.y = 3;
		tf.filters = textFilters;
				
		// Icon tourelles
		ticon = game.char.get("stuffIcon", 0);
		wrapper.addChild(ticon);
		ticon.setCenter(1,0);
		ticon.x = WID-1;
		ticon.filters = [ new GlowFilter(0x0,1, 2,2,3) ];

		var s = new Sprite();
		s.graphics.beginFill(0xFF0000,1);
		s.graphics.drawCircle(0,0,50);
		s.filters = [ new BlurFilter(64,64,2) ];

		// (Arkadeo HTML5 port) the blink of a dispenser: a cyan circle flattened and drawn in ADD like the warnings (the
		// original: the red circle of the warnings tinted cyan by a colour matrix, in NORMAL), hidden until it plays, centred
		// on the warnings, not played by the equipment given at the start
		var sc = new Sprite();
		sc.graphics.beginFill(0x00FFFF,1);
		sc.graphics.drawCircle(0,0,50);
		sc.filters = [ new BlurFilter(64,64,2) ];

		blink = mt.deepnight.Lib.flatten(sc, 64);
		wrapper.addChild(blink);
		blink.blendMode = BlendMode.ADD;
		blink.y = 20-blink.height*0.5;
		blink.alpha = 0;

		warnAmmo = mt.deepnight.Lib.flatten(s, 64);
		wrapper.addChild(warnAmmo);
		warnAmmo.blendMode = BlendMode.ADD;
		warnAmmo.x = -warnAmmo.width*0.5;
		warnAmmo.y = 20-warnAmmo.height*0.5;
		warnAmmo.alpha = 0;

		warnTurrets = mt.deepnight.Lib.flatten(s, 64);
		wrapper.addChild(warnTurrets);
		warnTurrets.blendMode = BlendMode.ADD;
		warnTurrets.x = WID-warnTurrets.width*0.5;
		warnTurrets.y = 20-warnTurrets.height*0.5;
		warnTurrets.alpha = 0;
	}
	
	public function blinkTurret() {
		if( game.time<20 ) return;
		game.tw.terminate(blink);
		blink.alpha = 0.8;
		blink.x = WID-blink.width*0.5;
		game.tw.create(blink, "alpha", 0, 800);
	}


	public function blinkWeapon() {
		if( game.time<20 ) return;
		game.tw.terminate(blink);
		blink.alpha = 0.8;
		blink.x = -blink.width*0.5;
		game.tw.create(blink, "alpha", 0, 800);
	}
	
	
	public function refresh() {
		var hero = game.hero;
		
		if( hero==null )
			return;
			
		ticon.setFrame( switch( hero.turretType ) {
			case T_Gatling : 2;
			case T_Shield : 0;
			case T_Slow : 1;
			case T_Burner : 3;
		});
		
		wicon.setFrame( switch( hero.weaponType ) {
			case W_Basic : 6;
			case W_Grenade : 5;
			case W_Lazer : 4;
			case W_Lightning : 7;
		});
		
		if( game.isProgression() ) {
			var r = hero.xp / greenwitch.en.Hero.getNextLevelXp(hero.level);
			xpBar.bitmapData.fillRect( new Rectangle(0,0, XP_WID, XP_HEI), Color.addAlphaF(0x002940) );
			xpBar.bitmapData.fillRect( new Rectangle(0,0, r*XP_WID, 2), Color.addAlphaF(0x51C2FF) );
			xpBar.bitmapData.fillRect( new Rectangle(0,2, r*XP_WID, XP_HEI-2), Color.addAlphaF(0x00A6FF) );
			xp.text = Std.string(hero.level+1);
		}
		
		ammo.textColor = hero.ammo<=10 ? 0xFFAC00 : 0xD1D1D1;
		if( hero.ammo==0 )
			ammo.text = Lang.AmmoDepleted;
		else
			ammo.text = Std.string(hero.ammo);
		ammo.visible = hero.ammo<999;

		if( hero.turrets==0 )
			turrets.text = Lang.TurretDepleted;
		else
			turrets.text = Std.string(hero.turrets);
		turrets.x = WID-turrets.textWidth-27;
		turrets.textColor = hero.turrets<=1 ? 0xFFAC00 : 0xD1D1D1;
		
		update();
	}
	
	public function update() {
		warnAmmo.alpha = game.hero.ammo>10 ? 0 : (Std.int(game.time/2)%3==0 ? 1 : 0.8);
		warnTurrets.alpha = game.hero.turrets>1 ? 0 : (Std.int(game.time/2)%3==0 ? 1 : 0.8);
		
		#if gw_debug
		var m = game.getMouseCase();
		//debug.text = game.currentLevel.getRoomId(m.cx, m.cy)+" reachable="+game.currentLevel.canBeReached(m.cx,m.cy);
		debug.text = Math.round(api.AKApi.getPerf()*100)/100 + " ("+Math.round(api.AKApi.getPerfCap()*100)/100+")";
		//debug.text = "dif="+Math.round(game.difficulty*100)/100 + " sk="+Math.round(game.skill*100)/100;
		#end
	}
}



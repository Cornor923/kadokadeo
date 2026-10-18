package brutalteenagecrisis;

import mt.deepnight.Color;
import mt.deepnight.slb.BLib;
import mt.deepnight.slb.BSprite;

// The tutorials of the original (and their cinematics; Progression only: never shown in the League) and the in-game
// prizes of Arkadeo are not ported; the random generators of the original (mt.Rand) are
// KadoKadeo's seed (kado.Seed, Seed.*Vfx for the pictures). The base is the
// mt.deepnight.Mode of the lib: root, cd / delayer / tw updated each frame by super.update(), pause.
class Mode extends mt.deepnight.Mode {
	public static var ME : Mode;

	public var dm			: DepthManager;
	public var level		: Level;
	public var fx			: Fx;
	public var hud			: Hud;
	public var hero			: brutalteenagecrisis.en.Hero;
	public var diff			: Int;
	public var skill(default, set)	: Float;
	public var nextPowerUp	: Float;

	public var tiles		: BLib;
	public var bgs			: BLib;
	public var phaseMask	: Bitmap;

	public function new(g:Game) {
		super();
		ME = this;
		g.addChild(root);

		dm = new DepthManager(root);

		diff = 0;
		skill = 0;
		nextPowerUp = 0;
		cd.set("autoDiff", Const.AUTODIFF);

		// the sheet of the game (atlases of the original: sheet.xml with ShoeBox, backgrounds.xml with TexturePacker)
		tiles = BLib.fromSheet(g.sheets, "", Data.ANIMS);
		tiles.setDefaultCenter(0,0);

		bgs = BLib.fromSheet(g.sheets, "bgs/");

		// Various tools
		fx = new Fx();

		// HUD
		hud = new Hud();

		// Phase mask
		phaseMask = new Bitmap(new BitmapData(Const.WID, Const.HEI, true, Color.addAlphaF(0x1B0F3C, 0.8)));
		dm.add(phaseMask, Const.DP_PHASE);
		phaseMask.visible = false;

		var perlin = new BitmapData(Const.WID, Const.HEI, false, 0x0);
		perlin.perlinNoise(128, 64, 3, 1866, false, true, 1, true);
		phaseMask.bitmapData.draw(perlin, new ColorTransform(1,1,1, 0.5), BlendMode.OVERLAY);
		perlin.dispose();

		// Level
		newLevel();

		hud.refresh();
	}


	override public function destroy() {
		super.destroy();
		fx.destroy();
	}


	function set_skill(s:Float) {
		if( s>1 ) s = 1;
		if( s<0 ) s = 0;
		return skill = s;
	}


	public function isLeague() {
		return false;
	}

	public function asLeague() : brutalteenagecrisis.mode.League {
		return cast this;
	}


	public function newLevel() {
		nextPowerUp = Const.seconds( Seed.irange(2, 5) );
	}


	public function createField(str:Dynamic, ?col=0xFFFFFF, ?adjustSize=false) {
		var f = new TextFormat();
		f.font = "def";
		f.size = 16;
		f.color = col;

		var tf = new TextField();
		tf.width = adjustSize ? 500 : 300;
		tf.height = 50;
		tf.mouseEnabled = tf.selectable = false;
		tf.defaultTextFormat = f;
		tf.embedFonts = true;
		tf.htmlText = Std.string(str);
		tf.multiline = tf.wordWrap = true;
		if( adjustSize ) {
			tf.width = tf.textWidth+5;
			tf.height = tf.textHeight+5;
		}

		tf.filters = [
			new GlowFilter(0x0,1, 4,4,4),
		];

		return tf;
	}

	public function addPowerUp() {
	}

	public inline function countRealMobs() {
		var n = 0;
		for(e in brutalteenagecrisis.en.Mob.ALL)
			if( e.countAsMob )
				n++;
		return n;
	}

	public function gameOver(win:Bool) {
		if( paused )
			return;
		pause();
		Game.ME.onGameOver(win);
	}

	public function onHeroDeath() {
		delayer.add( function() {
			gameOver(false);
		}, 1000);
	}

	override function update() {
		super.update();

		// Entities
		BSprite.updateAll();
		for(e in Entity.ALL)
			e.update();
		for(e in Entity.TOKILL)
			e.unregister();
		Entity.TOKILL = new Array();


		// Power-ups
		if( nextPowerUp--<=0 )
			addPowerUp();

		skill -= 0.001;


		fx.update();
		hud.update();
	}

}

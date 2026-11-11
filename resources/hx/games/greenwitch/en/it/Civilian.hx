package greenwitch.en.it;

class Civilian extends greenwitch.en.Item {
	static var PERFECT = 25000;
	static var VALUE = 5000;
	public static var TOTAL = 0;
	public static var ALL : Array<Civilian> = [];
	public static var ROUND : Int = 0;
	
	var kind		: Int;
	
	public function new(x,y) {
		super(x,y);
		
		duration = -1;
		
		zsortable = true;
		kind = rseed.irange(0,2);
		TOTAL++;
		
		sprite.swap("prince", kind*2);
		setShadow(true);
	}
	
	override public function register() {
		super.register();
		ALL.push(this);
	}
	
	override function destroy() {
		super.destroy();
		ALL.remove(this);
	}
	
	override private function onPickUp() {
		// FIX bug princier : on relâche l'emplacement "used" réservé au spawn (le prince
		// ne bouge pas → cx,cy = sa case meta). Sinon les cases ne sont JAMAIS libérées →
		// `used` sature au fil des vagues → getMetaOnceFarFromOthers finit par renvoyer
		// null → crash dans League.repopCivilians (pt.cx sur null) + princes agglutinés.
		// setUsed est prévu pour libérer via son 3e argument.
		if( game.currentLevel!=null )
			game.currentLevel.setUsed(cx, cy, false);
		super.onPickUp();
		var col = 0x00D2FF;
		
		game.addScorePop(xx+2,yy-20, VALUE);
		ALL.remove(this);
		
		game.addSkill(0.3);
		
		var s = game.char.get("prince", kind*2+1);
		game.sdm.add(s, Const.DP_FX);
		s.x = xx;
		s.y = yy;
		game.tw.create(s, "alpha", 0, TEaseOut, 2000).onEnd = function() {
			s.destroy();
		}
		
		// (the progression bar and the tutorial of the LvUP campaign: not ported)
		
		fx.prince(xx,yy, col);
		
		if( ALL.length==0 ) {
			{
				game.addScorePop(xx, yy-30, PERFECT);
				if( game.isProgression() )
					game.notify( Lang.AllCiviliansProgress, col );
				else
					game.notify( Lang.AllCiviliansLeague({_n:PERFECT}), col );
			}
			game.onLevelComplete();
			S.BANK.prince01().play();
		}
		else {
			if( game.isProgression() )
				if( ALL.length==1 )
					fx.pop(xx,yy, Lang.RemainingCivilian, col, true);
				else
					fx.pop(xx,yy, Lang.RemainingCivilians({_n:ALL.length}), col, true);
			S.BANK.prince02().play(0.4);
		}
		
		game.hud.refresh();
	}
}
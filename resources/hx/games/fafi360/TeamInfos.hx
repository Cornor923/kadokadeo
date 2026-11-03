package fafi360;

enum Perk {
	_PPreciseGoal;
	_PStrongGoal;
	_PReachGoal;

	_PPreciseDefense;
	_PStrongDefense;
	_PReachDefense;
	_PFastDefense;

	_PReachAll;
	_PMagneticBall;

	_PPreciseAttack;
	_PReachAttack;
	_PFastAttack;

	_PExtraTime1;
	_PExtraTime2;
	_PBonusGrab;
	_PGoalJump;
	_PDefenseJump;
	_PDoubleAttack;

	@ai _PWeak;
	@ai _PSuperStrong;
	@ai _PNoGoal;
	@ai _PCornerCage;
	@ai _PRandomCage;
	@ai _PSmallCage;
	@ai _PLargeCage;
	@ai _PPlayerLargeCage;
	@ai _PMineField;
	@ai _PLowRange;
	@ai _PKamikaze;
	@ai _PSlow;

	@ai _PRocks;
	@ai _PPumpkins;
	@ai _PMissiles;

	@ai _PSnowTerrain;
	@ai _PWetTerrain;
	@ai _PExtraWater;
	@ai _PGlueTerrain;
	@ai _PLeatherTerrain;
}

// The opponent of the League and the human team: the LvUP campaign (the teams of teams.xml, the perks chosen between the
// levels and saved by Arkadeo, the MISSION mode) is not ported, its perks are kept for the code that tests them (the League
// only gives GoalJump to the opponent)
class TeamInfos {
	public var side			: Int;

	public var name			: String;
	public var color		: Int;
	public var playerCount	: Int;
	public var hairFrame	: Int;
	public var perkCache	: Map<Int,Bool>;
	public var skill		: Int;

	public var players		: Array<fafi360.en.Player>;

	public function new() {
		var game = Game.ME;

		skill = 0;
		name = "Unknown";
		color = 0xDF2046;
		hairFrame = 17;
		perkCache = new Map();
		players = new Array();
		playerCount = game.isLeague() ? 9 : 11;

		if( game.isLeague() ) {
			var rseed = new Rand(0);
			rseed.initSeed(game.seed);
			var hairs = [13,14,15, 36,37,38];
			hairFrame = hairs[rseed.random(hairs.length)];
		}
	}

	public inline function getSkill() {
		return skill;
	}

	public function addPerk(p:Perk) {
		perkCache.set(Type.enumIndex(p), true);
	}

	public function getPerks() {
		var a = [];
		for( id in perkCache.keys() )
			a.push(Type.createEnumIndex(Perk, id));
		return a;
	}

	public inline function hasPerk(p:Perk) {
		return perkCache.exists(Type.enumIndex(p));
	}
}

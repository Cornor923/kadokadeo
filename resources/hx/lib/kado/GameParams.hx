package kado;

typedef GameParams = {
	var replayData:String;
	var isDaily:Bool;
	var name:String;
	var seed:String;
	var contractScore:Int;
	var contractPoints:Int;
	var gameId:Int;
	// version of the game bundle (hash of the manifest): sent when a run begins, to replay it with the same version
	@:optional var build:String;
	// the clan run of the page (/clans/play/{action}): sent when a run begins, see App\Services\ClanRunService::pageAction
	@:optional var clanAction:Int;
	// folder of the spritesheet of an old version of the game (replays), instead of /assets/img/content/<name>/
	@:optional var assetBase:String;
	// ANTI CHEAT: functions of the browser taken when the page loaded (resources/js/anticheat/natives.js), see kac.Natives
	@:optional var natives:Dynamic;
	// a replay played by the replay verifier (resources/js/replay-verifier/verify.mjs): nothing is seen, see headless
	@:optional var headless:Bool;
	var canvasWidth:Int;
	var canvasHeight:Int;
}

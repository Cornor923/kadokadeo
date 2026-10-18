package kado;

typedef RunDTO = {
	var run_id:String;
	var server_time:Int;
	var contract_score:Int;
	var contract_points:Int;
	var seed:String;
	// the daily game: the same seed for every player, the draws are not stirred (Seed.stir)
	@:optional var shared_seed:Bool;
	// a clan run: shown in the bottom bar instead of the contract
	@:optional var clan:ClanGoalDTO;
};

// App\Services\ClanRunService::goal
typedef ClanGoalDTO = {
	// "attack", "defense" or "mission"
	var type:String;
	// the score to reach (a defense, a mission step), the score of the attack to improve (0 for a new attack)
	var score:Int;
	// the clan games left: the attack games of the day, the paid ones
	var attack_games:Int;
	var clan_games:Int;
};

typedef ApiResponse<T> = {
	data:T,
};

// a request that failed: status 0 when the server could not be reached (no network)
typedef ApiError = {
	var status:Int;
	var message:String;
}

// the run before encryption (what the server decodes)
typedef EndRunPlainDTO = {
	var run_id:String;
	var score:Int;
	var timestamp:Int;
	var replay:String;
	var data:Dynamic;
	var ac:Dynamic;
}

// a run that could not be sent, kept in the local storage to be sent again later
typedef PendingRunDTO = {
	var run_id:String;
	var game_id:Int;
	var game_name:String;
	var saved_at:String;
	var request:EndRunPlainDTO;
	var error:ApiError;
	var attempts:Int;
}

typedef PublicKeyDTO = {
	var public_key:String;
}

typedef EndRunRequestDTO = {
	var payload:String;
	var key:String;
	var sign:String;
}

typedef EndRunResponseDTO = {
	var is_best:Bool;
	var previous_star:Int;
	var current_star:Int;
	var people_to_beat:Int;
}

typedef BeginRunParamsDTO = {
	var daily:Bool;
	var gameId:Int;
	@:optional var build:String;
}

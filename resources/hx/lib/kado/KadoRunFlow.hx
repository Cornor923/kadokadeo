package kado;

enum RunState {
	Boot;
	Intro;
	ContractLoading;
	ReadyToStart;
	Playing;
	SubmittingRun;
	SubmitFailed;
	EndScreen;
	ReplayTransition;
}

typedef RunStartContext = {
	var runDetails:Dto.RunDTO;
	var seedHash:Int;
	var diffWithServerTime:Int;
}

class KadoRunFlow {
	public var state(default, null):RunState = Boot;

	var params:GameParams;
	var currentContext:RunStartContext;

	public function new(params:GameParams) {
		this.params = params;
	}

	public function transition(next:RunState, ?reason:String):Void {
		var previous = state;
		if (previous == next) {
			return;
		}

		if (!isTransitionAllowed(previous, next)) {
			trace("Unexpected state transition: " + stateLabel(previous) + " -> " + stateLabel(next));
		}

		state = next;
	}

	public function createReplayContext():Null<RunStartContext> {
		if (params.replayData == null) {
			return null;
		}

		currentContext = {
			runDetails: {
				run_id: "",
				server_time: 0,
				contract_score: params.contractScore,
				contract_points: params.contractPoints,
				seed: params.seed,
			},
			seedHash: hashFNV1a(params.seed),
			diffWithServerTime: 0,
		};
		return currentContext;
	}

	#if debug
	public function createDebugContext():RunStartContext {
		currentContext = {
			runDetails: {
				run_id: "",
				server_time: 0,
				contract_score: 0,
				contract_points: 0,
				seed: "123",
			},
			seedHash: hashFNV1a("123"),
			diffWithServerTime: 0,
		};
		return currentContext;
	}
	#end

	public function requestContract(onSuccess:RunStartContext->Void, onError:Dto.ApiError->Void):Void {
		Api.askContract({daily: params.isDaily, gameId: params.gameId, build: params.build}).then((data:Dto.ApiResponse<Dto.RunDTO>) -> {
			currentContext = {
				runDetails: data.data,
				seedHash: hashFNV1a(data.data.seed),
				diffWithServerTime: Std.int(Date.now().getTime() / 1000) - data.data.server_time,
			};
			onSuccess(currentContext);
		}, (error:Dynamic) -> {
			onError(Api.toError(error));
		});
	}

	public function currentTimestamp():Int {
		var diff = currentContext == null ? 0 : currentContext.diffWithServerTime;
		return Std.int(Date.now().getTime() / 1000) + diff;
	}

	public function getRunDetails():Dto.RunDTO {
		return currentContext == null ? null : currentContext.runDetails;
	}

	function hashFNV1a(s:String):Int {
		var hash = 0x811C9DC5;
		for (i in 0...s.length) {
			hash ^= s.charCodeAt(i);
			hash *= 0x01000193;
		}
		return hash;
	}

	inline function stateLabel(value:RunState):String {
		return switch (value) {
			case Boot: "Boot";
			case Intro: "Intro";
			case ContractLoading: "ContractLoading";
			case ReadyToStart: "ReadyToStart";
			case Playing: "Playing";
			case SubmittingRun: "SubmittingRun";
			case SubmitFailed: "SubmitFailed";
			case EndScreen: "EndScreen";
			case ReplayTransition: "ReplayTransition";
		}
	}

	function isTransitionAllowed(from:RunState, to:RunState):Bool {
		if (from == to) {
			return true;
		}

		return switch ([from, to]) {
			case [Boot, Intro] | [Intro, ContractLoading] | [Intro, Playing] | [ContractLoading, ReadyToStart] | [ContractLoading, Intro] |
				[ReadyToStart, Playing] | [Playing, SubmittingRun] | [Playing, EndScreen] | [SubmittingRun, EndScreen] | [SubmittingRun, SubmitFailed] |
				[SubmitFailed, EndScreen] | [EndScreen, ReplayTransition] |
				[ReplayTransition, Intro]:
				true;
			case _:
				false;
		}
	}
}

package kado;

import js.lib.Promise;

class Api {
	public static var baseUrl:String = "http://kadokadeo.localhost";

	// the player is authenticated by the session cookie of the site, sent by the browser (same origin, HttpOnly: no
	// script reads it); the requests carry back the CSRF token of the session (the cookie XSRF-TOKEN of Laravel)
	public static function buildClient(url:String = null) {
		var http = new haxe.Http(baseUrl + url);

		http.setHeader("Content-Type", "application/json");
		http.setHeader("Accept", "application/json");
		var xsrf = xsrfToken();
		if (xsrf != null) {
			http.setHeader("X-XSRF-TOKEN", xsrf);
		}

		return http;
	}

	static function xsrfToken():Null<String> {
		for (cookie in js.Browser.document.cookie.split(";")) {
			var pair = StringTools.trim(cookie);
			if (StringTools.startsWith(pair, "XSRF-TOKEN=")) {
				return js.Syntax.code("decodeURIComponent({0})", pair.substr("XSRF-TOKEN=".length));
			}
		}
		return null;
	}

	// rejected with a Dto.ApiError (the message of the server: no games left, the daily game already played...)
	public static function askContract(runParams:Dto.BeginRunParamsDTO):Promise<Dto.ApiResponse<Dto.RunDTO>> {
		var req:Dynamic = {};
		var http = buildClient("/api/runs/games/" + runParams.gameId);
		if (runParams.daily) {
			req.daily = true;
		}
		if (runParams.build != null) {
			req.build = runParams.build;
		}
		// (ClanRunService::pageAction)
		if (runParams.clanAction != null) {
			req.clan_action = runParams.clanAction;
		}
		http.setPostData(haxe.Json.stringify(req));
		return send(http, true);
	}

	// "Changer de partie": the run begun is replaced by a new one (RunController::reroll); rejected with a Dto.ApiError
	public static function rerollRun(runId:String, build:String):Promise<Dto.ApiResponse<Dto.RunDTO>> {
		var req:Dynamic = {};
		var http = buildClient("/api/runs/" + runId + "/reroll");
		if (build != null) {
			req.build = build;
		}
		http.setPostData(haxe.Json.stringify(req));
		return send(http, true);
	}

	public static function endRun(runId:String, request:Dto.EndRunRequestDTO):Promise<Dto.ApiResponse<Dynamic>> {
		var http = buildClient("/api/runs/" + runId + "/finish");
		http.setPostData(haxe.Json.stringify(request));
		return send(http, true);
	}

	public static function getPublicKey():Promise<Dto.ApiResponse<Dto.PublicKeyDTO>> {
		return send(buildClient("/api/runs/public-key"), false);
	}

	// rejected with a Dto.ApiError
	static function send<T>(http:haxe.Http, post:Bool):Promise<T> {
		return new Promise((resolve, reject) -> {
			var status = 0;
			http.onStatus = (s:Int) -> status = s;
			http.onData = (data:String) -> {
				try {
					resolve(haxe.Json.parse(data));
				} catch (e:Dynamic) {
					reject(({status: status, message: "Invalid response: " + Std.string(e)} : Dto.ApiError));
				}
			}
			http.onError = (error:String) -> {
				reject(({status: status, message: responseMessage(http, error)} : Dto.ApiError));
			}
			http.request(post);
		});
	}

	// the message of a Laravel error response, if any
	static function responseMessage(http:haxe.Http, fallback:String):String {
		try {
			var body:Dynamic = haxe.Json.parse(http.responseData);
			if (body != null && body.message != null) {
				return Std.string(body.message);
			}
		} catch (_:Dynamic) {}
		return fallback;
	}

	public static function toError(error:Dynamic):Dto.ApiError {
		if (error != null && Reflect.hasField(error, "status") && Reflect.hasField(error, "message")) {
			return cast error;
		}
		var message:String = error != null && Reflect.hasField(error, "message") ? Std.string(Reflect.field(error, "message")) : Std.string(error);
		return {status: -1, message: message};
	}
}

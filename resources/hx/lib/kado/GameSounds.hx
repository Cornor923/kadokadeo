package kado;

/**
 * The sounds and the music of a game, with Web Audio: the files are public/assets/sound/<game>/<name>.mp3, loaded once
 * by init (a sound asked before its file is there is not played).
 *
 * Nothing is played while a replay is sought or caught up (many steps at once) or sped up more than twice, a paused
 * replay pauses the music. Key M: the music on / off, key B: the sounds on / off, kept in the browser for each game (not
 * keys of the game: not in the replays). The same sound starts once per step at most (step(), once per update).
 *
 *   GameSounds.init("rockfaller", ["Pipe", ...]);    GameSounds.playMusic("Music", 0.6);    GameSounds.play("Pipe");
 */
class GameSounds {
	static inline var BASE = "/assets/sound/";

	static var ctx:Dynamic = null;
	static var master:Dynamic;
	static var sfxGain:Dynamic;
	static var musicGain:Dynamic;
	static var listening = false;

	static var game:String = null;
	static var buffers:Map<String, Dynamic> = new Map();
	static var loading:Map<String, Bool> = new Map();
	static var lastStep:Map<String, Int> = new Map();
	static var stepCount:Int = 0;

	static var music:String = null;
	static var musicVolume:Float = 1;
	static var musicSrc:Dynamic = null;

	public static var musicOn(default, null):Bool = true;
	public static var soundsOn(default, null):Bool = true;

	// the audio of the page (once) and the files of the game
	public static function init(gameKey:String, sounds:Array<String>) {
		if (!createContext())
			return;
		if (game != gameKey) {
			stopMusic();
			buffers = new Map();
			loading = new Map();
			game = gameKey;
		}
		lastStep = new Map();
		try {
			musicOn = js.Browser.getLocalStorage().getItem(game + ".music") != "0";
			soundsOn = js.Browser.getLocalStorage().getItem(game + ".sounds") != "0";
		} catch (e:Dynamic) {}
		setGains();
		for (s in sounds)
			load(s);
	}

	static function createContext():Bool {
		if (ctx != null)
			return true;
		var w:Dynamic = js.Browser.window;
		var C:Dynamic = w.AudioContext != null ? w.AudioContext : w.webkitAudioContext;
		if (C == null)
			return false;
		try {
			ctx = js.Syntax.code("new {0}()", C);
		} catch (e:Dynamic) {
			ctx = null;
			return false;
		}
		master = ctx.createGain();
		master.connect(ctx.destination);
		sfxGain = ctx.createGain();
		sfxGain.connect(master);
		musicGain = ctx.createGain();
		musicGain.connect(master);
		listen();
		return true;
	}

	static function listen() {
		if (listening)
			return;
		listening = true;
		var w:Dynamic = js.Browser.window;
		// (the browsers start the audio after an action of the player: a key, a click, a touch)
		var resume = function(_) {
			if (ctx != null && ctx.state == "suspended" && !replayPaused())
				ctx.resume();
		};
		w.addEventListener("keydown", resume);
		w.addEventListener("pointerdown", resume);
		w.addEventListener("touchstart", resume);
		w.addEventListener("keydown", function(e:Dynamic) {
			if (e.repeat || game == null || isTyping(e))
				return;
			if (e.keyCode == 77)
				toggleMusic();
			else if (e.keyCode == 66)
				toggleSounds();
		});
		// (a replay paused: the music too)
		w.setInterval(function() {
			if (ctx == null || ctx.state == "closed")
				return;
			var paused = replayPaused();
			if (paused && ctx.state == "running")
				ctx.suspend();
			else if (!paused && ctx.state == "suspended" && untyped (w.navigator.userActivation == null || w.navigator.userActivation.hasBeenActive))
				ctx.resume();
		}, 250);
	}

	static function isTyping(e:Dynamic):Bool {
		var t:Dynamic = e.target;
		if (t == null || t.tagName == null)
			return false;
		var n = (t.tagName : String).toUpperCase();
		return n == "INPUT" || n == "TEXTAREA" || n == "SELECT" || t.isContentEditable;
	}

	static function load(name:String) {
		if (buffers.exists(name) || loading.exists(name))
			return;
		loading.set(name, true);
		var key = game;
		var w:Dynamic = js.Browser.window;
		var p:Dynamic = w.fetch(BASE + game + "/" + name + ".mp3").then(function(r:Dynamic) {
			return r.ok ? r.arrayBuffer() : null;
		}).then(function(data:Dynamic) {
			if (data == null || key != game)
				return;
			ctx.decodeAudioData(data, function(b:Dynamic) {
				if (key != game)
					return;
				buffers.set(name, b);
				// (the music asked before its file was there)
				if (music == name && musicSrc == null)
					startMusic();
			}, function(_) {});
		});
		js.Syntax.code("{0}.catch(function () {})", p);
	}

	// (a replay sought or caught up, sped up: many steps in a short time)
	static function quiet():Bool {
		var k = KadoKadeoManager.kkm;
		if (k == null)
			return false;
		return @:privateAccess (k.seekTarget != null || k.catchUpTarget != null || (k.replay.isPlayingReplay() && k.replaySpeed > 2));
	}

	static function replayPaused():Bool {
		var k = KadoKadeoManager.kkm;
		if (k == null)
			return false;
		return @:privateAccess (k.replay.isPlayingReplay() && k.replayPaused);
	}

	// one step of the game
	public static function step() {
		stepCount++;
	}

	public static function play(name:String, ?volume:Float = 1) {
		if (ctx == null || !soundsOn || quiet())
			return;
		var b = buffers.get(name);
		if (b == null)
			return;
		if (lastStep.get(name) == stepCount)
			return;
		lastStep.set(name, stepCount);
		var src = ctx.createBufferSource();
		src.buffer = b;
		if (volume == 1) {
			src.connect(sfxGain);
		} else {
			var g = ctx.createGain();
			g.gain.value = volume;
			g.connect(sfxGain);
			src.connect(g);
		}
		src.start(0);
	}

	// the music of the game, played in a loop (loaded with the sounds)
	public static function playMusic(name:String, ?volume:Float = 1) {
		if (ctx == null)
			return;
		music = name;
		musicVolume = volume;
		setGains();
		load(name);
		startMusic();
	}

	public static function stopMusic() {
		music = null;
		stopSource();
	}

	public static function toggleMusic() {
		musicOn = !musicOn;
		save("music", musicOn);
		setGains();
	}

	public static function toggleSounds() {
		soundsOn = !soundsOn;
		save("sounds", soundsOn);
		setGains();
	}

	static function save(what:String, on:Bool) {
		try {
			js.Browser.getLocalStorage().setItem(game + "." + what, on ? "1" : "0");
		} catch (e:Dynamic) {}
	}

	static function setGains() {
		if (musicGain != null)
			musicGain.gain.value = musicOn ? musicVolume : 0;
		if (sfxGain != null)
			sfxGain.gain.value = soundsOn ? 1 : 0;
	}

	static function startMusic() {
		stopSource();
		if (music == null)
			return;
		var b = buffers.get(music);
		if (b == null)
			return;
		musicSrc = ctx.createBufferSource();
		musicSrc.buffer = b;
		musicSrc.loop = true;
		musicSrc.connect(musicGain);
		musicSrc.start(0);
	}

	static function stopSource() {
		if (musicSrc != null) {
			try {
				musicSrc.stop(0);
			} catch (e:Dynamic) {}
			musicSrc.disconnect();
			musicSrc = null;
		}
	}
}

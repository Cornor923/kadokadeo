package common_haxe_avm1.kac;

import js.Syntax;

// ANTI CHEAT: integrity of a game played live against a script of the page (a "wallhack" of the console reading the
// game, hooking its methods to draw over it...). The classes of the game can't be reached from window (ES module, see
// resources/js/games/builds/bundle.mjs), but its objects can be found from the global PIXI: so
// - lock (when the manager is built): the prototypes of the classes of the game are frozen (their methods can't be
//   replaced), and the functions of the classes of the framework that matter (Seed, ReplayManager...) too;
// - check (every 64 frames and at the end of the game): what was replaced anyway, the display objects added by
//   something else than the game, PIXI and the functions of the browser replaced, the inputs made by a script. What is
//   found goes in the AntiCheat mask sent with the run (hard bits: the run is marked as cheated; soft bits: the run
//   goes in the queue of the suspicious runs of the admin).
// Nothing is done for a replay (the replay verifier, the replay page), nor in a debug build (test harness).
class Integrity {
	// classes of the framework whose static functions are locked too
	static var LOCKED_STATICS = [
		"kado.Seed", "kado.ReplayManager", "kado.KadoEndRun", "kado.KadoCrypto", "kado.KadoKadeoManager", "mt.Rand",
		"common_haxe_avm1.MouseManager", "common_haxe_avm1.KeyboardManager", "common_haxe_avm1.kac.AntiCheat",
		"common_haxe_avm1.kac.Integrity", "common_haxe_avm1.kac.Natives"
	];
	// PIXI classes whose methods are compared (without a snapshot of the page)
	static var PIXI_CLASSES = ["Application", "Container", "DisplayObject", "Sprite", "Graphics", "Text", "Ticker", "Renderer"];
	static inline var CHECK_EVERY = 64;

	static var locked:Bool = false;
	// [object, name, function]: the methods (prototypes) and locked statics at the lock, read again by check
	static var baseline:Array<Array<Dynamic>> = null;
	static var frozen:Array<Dynamic> = null;
	// names of methods the game assigns to its instances (given by the bundler): an own function with that name is no
	// sign of a script
	static var assigned:Dynamic = null;
	static var pixiBaseline:Array<Array<Dynamic>> = null;
	static var pixiClassBaseline:Array<Array<Dynamic>> = null;
	static var pixi:Dynamic = null;
	static var bundlePath:String = null;
	// display objects without a Haxe class (raw PIXI objects): added by the game / by something else
	static var legit:Dynamic = null;
	static var foreign:Dynamic = null;
	static var stackUnreadable:Bool = false;
	// the objects of the game being played (armed: a live game)
	static var armed:Array<Dynamic> = null;
	static var armedPrototypes:Array<Dynamic> = null;
	static var stage:Dynamic = null;

	// when the manager of a live game is built, before the game can be reached
	public static function lock(kkm:Dynamic):Void {
		if (locked) {
			return;
		}
		locked = true;
		try {
			var fns = Natives.get();
			bundlePath = scriptPath(Syntax.code("(new Error()).stack"));
			var names:Array<String> = Syntax.code("(typeof __kadoAssignedNames != 'undefined' ? __kadoAssignedNames : null)");
			assigned = Syntax.code("new Set({0} || [])", names);
			#if !kado_no_freeze
			// (without the names of the bundler, a test build: not frozen)
			if (names != null) {
				freezePrototypes(fns);
			}
			#end
			takeBaseline(fns);
			lockStatics(fns);
			watchDisplayList(fns, kkm);
		} catch (e:Dynamic) {
			AntiCheat.flag(AntiCheat.CHECK_FAILED);
		}
	}

	// beginning of a live game: the objects to check
	public static function arm(kkm:Dynamic, game:Dynamic, replay:Dynamic, runFlow:Dynamic):Void {
		if (!locked) {
			return;
		}
		var fns = Natives.get();
		armed = [game, kkm, replay, runFlow];
		armedPrototypes = [for (o in armed) o == null ? null : fns.getPrototypeOf(o)];
		stage = kkm.stage;
	}

	public static function disarm():Void {
		armed = null;
		armedPrototypes = null;
	}

	public static inline function shouldCheck(frame:Int):Bool {
		return armed != null && frame % CHECK_EVERY == 0;
	}

	public static function check():Void {
		if (armed == null) {
			return;
		}
		try {
			var fns = Natives.get();
			checkCode(fns);
			checkInstances(fns);
			checkDisplayList();
			checkPixi(fns);
			checkNatives(fns);
			if (Natives.untrustedCount > 0) {
				AntiCheat.flag(AntiCheat.UNTRUSTED_INPUT);
			}
			if (Natives.forgedCount > 0) {
				AntiCheat.flag(AntiCheat.FORGED_EVENT);
			}
			if (stackUnreadable) {
				AntiCheat.flag(AntiCheat.CHECK_FAILED);
			}
		} catch (e:Dynamic) {
			AntiCheat.flag(AntiCheat.CHECK_FAILED);
		}
	}

	// LOCK

	// the classes of the bundle (not the ones of the browser Haxe registers too: Array, String, Date...)
	static function hxClasses():Array<Dynamic> {
		var all:Dynamic = Syntax.code("(typeof $hxClasses != 'undefined' ? $hxClasses : {})");
		var list:Array<Dynamic> = Syntax.code("Object.keys({0}).map(function (k) { return {0}[k] })", all);
		return list.filter(c -> Syntax.typeof(c) == "function" && c.prototype != null && Syntax.typeof(c.prototype) == "object"
			&& !Natives.isNative(c));
	}

	// the methods the game assigns to its instances become accessors: an assignment to an instance gives it its own
	// property (instead of a TypeError: a frozen prototype can't be shadowed by an assignment), an assignment to the
	// prototype is refused. Then the prototype is frozen.
	static function freezePrototypes(fns:Dynamic):Void {
		frozen = [];
		var onPatch = () -> AntiCheat.flag(AntiCheat.CODE_PATCHED);
		for (c in hxClasses()) {
			var proto:Dynamic = c.prototype;
			for (name in (fns.getOwnPropertyNames(proto) : Array<String>)) {
				var d:Dynamic = fns.getOwnPropertyDescriptor(proto, name);
				if (d.configurable && Syntax.typeof(d.value) == "function" && assigned.has(name)) {
					fns.defineProperty(proto, name, accessor(fns, proto, name, d.value, d.enumerable, onPatch));
				}
			}
			fns.freeze(proto);
			frozen.push(proto);
		}
	}

	static function accessor(fns:Dynamic, proto:Dynamic, name:String, fn:Dynamic, enumerable:Bool, onPatch:Void->Void):Dynamic {
		return Syntax.code("{
			get: function () { return {3} },
			set: function (v) {
				if (this === {1} || {0}.isFrozen(this)) { {5}(); return }
				{0}.defineProperty(this, {2}, { value: v, writable: true, enumerable: true, configurable: true })
			},
			enumerable: {4},
			configurable: false
		}", fns, proto, name, fn, enumerable, onPatch);
	}

	static function takeBaseline(fns:Dynamic):Void {
		baseline = [];
		for (c in hxClasses()) {
			var proto:Dynamic = c.prototype;
			for (name in (fns.getOwnPropertyNames(proto) : Array<String>)) {
				var current = methodOf(fns, proto, name);
				if (current != null) {
					baseline.push([proto, name, current]);
				}
			}
		}
	}

	static function lockStatics(fns:Dynamic):Void {
		var all:Dynamic = Syntax.code("(typeof $hxClasses != 'undefined' ? $hxClasses : {})");
		for (className in LOCKED_STATICS) {
			var c:Dynamic = all[cast className];
			if (c == null) {
				continue;
			}
			for (name in (fns.getOwnPropertyNames(c) : Array<String>)) {
				var d:Dynamic = fns.getOwnPropertyDescriptor(c, name);
				if (name == "prototype" || d == null || Syntax.typeof(d.value) != "function") {
					continue;
				}
				if (d.configurable) {
					fns.defineProperty(c, name, {writable: false, configurable: false});
				}
				baseline.push([c, name, d.value]);
			}
		}
	}

	// a method of an object: the function of its data property, or the getter of an accessor made by freezePrototypes
	static function methodOf(fns:Dynamic, o:Dynamic, name:String):Dynamic {
		var d:Dynamic = fns.getOwnPropertyDescriptor(o, name);
		if (d == null) {
			return null;
		}
		if (Syntax.typeof(d.value) == "function") {
			return d.value;
		}
		return d.get != null && d.set != null && !d.configurable ? d.get : null;
	}

	// PIXI.Container.addChild / addChildAt: the raw display objects (no Haxe class) are sorted by who added them: the
	// game (its bundle is the first caller outside of PIXI) or something else (a script of the page)
	static function watchDisplayList(fns:Dynamic, kkm:Dynamic):Void {
		legit = Syntax.code("new WeakSet()");
		foreign = Syntax.code("new WeakSet()");
		var page:Dynamic = fns.pixi;
		pixi = page != null ? page.PIXI : Syntax.code("globalThis.PIXI");
		if (pixi == null) {
			return;
		}
		var proto:Dynamic = pixi.Container.prototype;
		var original = originalPixiMethod(page, proto, "addChild");
		var originalAt = originalPixiMethod(page, proto, "addChildAt");
		// (the stack is read in the wrapper: its first frame, then the caller; only for a child not sorted yet, a stack costs
		// tens of microseconds and a game adds its children again at each frame: depth sorting, particles)
		var sort = (child:Dynamic, stack:String) -> sortChild(child, stack);
		var unsorted = (child:Dynamic) -> isUnsorted(child);
		proto.addChild = Syntax.code("function () {
			var stack = null;
			for (var i = 0; i < arguments.length; i++) {
				if (!{2}(arguments[i])) continue;
				if (stack == null) stack = new Error().stack;
				{0}(arguments[i], stack);
			}
			return {1}.apply(this, arguments)
		}", sort, original, unsorted);
		proto.addChildAt = Syntax.code("function (child, index) { if ({2}(child)) {0}(child, new Error().stack); return {1}.call(this, child, index) }",
			sort, originalAt, unsorted);
		proto.addChild.__kadoOriginal = original;
		proto.addChildAt.__kadoOriginal = originalAt;
		// what the manager already shows
		markTree(kkm.stage);
		takePixiBaseline(fns, page);
	}

	static function originalPixiMethod(page:Dynamic, proto:Dynamic, name:String):Dynamic {
		if (page != null) {
			for (m in (page.methods : Array<Dynamic>)) {
				if (m[0] == proto && m[1] == name) {
					return m[2];
				}
			}
		}
		var current:Dynamic = Reflect.field(proto, name);
		// (a wrapper of a game mounted before: its original)
		return current.__kadoOriginal != null ? current.__kadoOriginal : current;
	}

	static function markTree(node:Dynamic):Void {
		if (node == null) {
			return;
		}
		if (node.__class__ == null) {
			legit.add(node);
		}
		var children:Array<Dynamic> = node.children;
		if (children != null) {
			for (c in children) {
				markTree(c);
			}
		}
	}

	// a raw display object (no Haxe class) not sorted yet
	static function isUnsorted(child:Dynamic):Bool {
		return child != null && child.__class__ == null && !legit.has(child) && !foreign.has(child);
	}

	static function sortChild(child:Dynamic, stack:String):Void {
		if (!isUnsorted(child)) {
			return;
		}
		var caller = firstCaller(stack);
		if (caller == null) {
			stackUnreadable = true;
			legit.add(child);
		} else if (caller == bundlePath) {
			legit.add(child);
		} else {
			foreign.add(child);
		}
	}

	// the script of the caller of the wrapper (first frame of the stack), skipping PIXI; "" for a frame without script
	// (the console, an extension), null when the stack can't be read
	static function firstCaller(stack:String):Null<String> {
		if (stack == null || bundlePath == null) {
			return null;
		}
		var seenWrapper = false;
		for (line in stack.split("\n")) {
			var path = scriptPath(line);
			if (!seenWrapper) {
				seenWrapper = path != null;
				continue;
			}
			if (path != null && path != bundlePath && path.toLowerCase().indexOf("pixi") >= 0) {
				continue;
			}
			if (path == null && StringTools.trim(line) == "") {
				continue;
			}
			return path == null ? "" : path;
		}
		return seenWrapper ? "" : null;
	}

	static var URL_IN_STACK = ~/((?:https?|file|blob):\/\/[^\s()@]+?):\d+:\d+/;

	// the script of the first frame of a stack (or of a line of it), without its query and fragment
	static function scriptPath(text:String):Null<String> {
		if (text == null) {
			return null;
		}
		var lines = text.split("\n");
		for (line in lines) {
			if (URL_IN_STACK.match(line)) {
				var url = URL_IN_STACK.matched(1);
				var cut = url.indexOf("#");
				if (cut >= 0) {
					url = url.substr(0, cut);
				}
				cut = url.indexOf("?");
				if (cut >= 0) {
					url = url.substr(0, cut);
				}
				return url;
			}
		}
		return null;
	}

	static function takePixiBaseline(fns:Dynamic, page:Dynamic):Void {
		pixiBaseline = [];
		pixiClassBaseline = [];
		if (page != null) {
			for (m in (page.methods : Array<Dynamic>)) {
				pixiBaseline.push([m[0], m[1], m[2]]);
			}
			for (c in (page.classes : Array<Dynamic>)) {
				pixiClassBaseline.push([c[0], c[1]]);
			}
			return;
		}
		for (name in PIXI_CLASSES) {
			var c:Dynamic = Reflect.field(pixi, name);
			if (c == null) {
				continue;
			}
			pixiClassBaseline.push([name, c]);
			for (key in (fns.getOwnPropertyNames(c.prototype) : Array<String>)) {
				var d:Dynamic = fns.getOwnPropertyDescriptor(c.prototype, key);
				if (d != null && Syntax.typeof(d.value) == "function") {
					pixiBaseline.push([c.prototype, key, d.value]);
				}
			}
		}
	}

	// CHECKS

	static function checkCode(fns:Dynamic):Void {
		for (entry in baseline) {
			if (methodOf(fns, entry[0], entry[1]) != entry[2]) {
				AntiCheat.flag(AntiCheat.CODE_PATCHED);
				return;
			}
		}
		if (frozen != null) {
			for (proto in frozen) {
				if (!fns.isFrozen(proto)) {
					AntiCheat.flag(AntiCheat.CODE_PATCHED);
					return;
				}
			}
		}
		for (i in 0...armed.length) {
			if (armed[i] != null && fns.getPrototypeOf(armed[i]) != armedPrototypes[i]) {
				AntiCheat.flag(AntiCheat.CODE_PATCHED);
				return;
			}
		}
	}

	// an own function of an object of the game named like a method of its Haxe classes (not one the game assigns)
	static function checkInstances(fns:Dynamic):Void {
		for (o in armed) {
			if (o == null) {
				continue;
			}
			for (name in (fns.getOwnPropertyNames(o) : Array<String>)) {
				var d:Dynamic = fns.getOwnPropertyDescriptor(o, name);
				if (d == null || assigned.has(name) || (Syntax.typeof(d.value) != "function" && d.get == null && d.set == null)) {
					continue;
				}
				if (isHaxeMethod(fns, o, name)) {
					AntiCheat.flag(AntiCheat.INSTANCE_SHADOWED);
					return;
				}
			}
		}
	}

	static function isHaxeMethod(fns:Dynamic, o:Dynamic, name:String):Bool {
		var p:Dynamic = fns.getPrototypeOf(o);
		while (p != null) {
			if (fns.getOwnPropertyDescriptor(p, "__class__") != null && fns.getOwnPropertyDescriptor(p, name) != null) {
				return true;
			}
			p = fns.getPrototypeOf(p);
		}
		return false;
	}

	static function checkDisplayList():Void {
		if (stage == null || legit == null) {
			return;
		}
		if (hasForeign(stage)) {
			AntiCheat.flag(AntiCheat.FOREIGN_DISPLAY_OBJECT);
		}
	}

	// a raw display object added by something else than the game, or not by addChild (pushed in `children`)
	static function hasForeign(node:Dynamic):Bool {
		if (node.__class__ == null && !legit.has(node)) {
			return true;
		}
		var children:Array<Dynamic> = node.children;
		if (children != null) {
			for (c in children) {
				if (c != null && hasForeign(c)) {
					return true;
				}
			}
		}
		return false;
	}

	static function checkPixi(fns:Dynamic):Void {
		if (pixi == null || pixiBaseline == null) {
			return;
		}
		var global:Dynamic = Syntax.code("globalThis.PIXI");
		if (global != pixi) {
			AntiCheat.flag(AntiCheat.PIXI_PATCHED);
			return;
		}
		for (c in pixiClassBaseline) {
			if (Reflect.field(pixi, c[0]) != c[1]) {
				AntiCheat.flag(AntiCheat.PIXI_PATCHED);
				return;
			}
		}
		var container:Dynamic = pixi.Container.prototype;
		for (m in pixiBaseline) {
			// (addChild / addChildAt: wrapped by watchDisplayList)
			if (m[0] == container && (m[1] == "addChild" || m[1] == "addChildAt")) {
				continue;
			}
			var d:Dynamic = fns.getOwnPropertyDescriptor(m[0], m[1]);
			if (d == null || d.value != m[2]) {
				AntiCheat.flag(AntiCheat.PIXI_PATCHED);
				return;
			}
		}
	}

	// the functions of the browser of the page now, against the ones taken when it loaded
	static function checkNatives(fns:Dynamic):Void {
		var current:Dynamic = Syntax.code("(function (g) {
			var d = g.Object.getOwnPropertyDescriptor(g.Event.prototype, 'timeStamp');
			return [d && d.get, g.EventTarget.prototype.addEventListener, g.Function.prototype.toString, g.Reflect.apply,
				g.Object.getOwnPropertyDescriptor];
		})(globalThis)");
		if (Natives.isFromPage()) {
			var expected:Array<Dynamic> = [fns.timeStamp, fns.addEventListener, fns.fnToString, fns.apply, fns.getOwnPropertyDescriptor];
			for (i in 0...expected.length) {
				if (current[i] != expected[i]) {
					AntiCheat.flag(AntiCheat.NATIVE_PATCHED);
					return;
				}
			}
		} else {
			for (fn in (current : Array<Dynamic>)) {
				if (!Natives.isNative(fn)) {
					AntiCheat.flag(AntiCheat.NATIVE_PATCHED);
					return;
				}
			}
		}
	}
}

package labrute;

// The randomness of LaBrute (core/src/utils/random.ts, weightedRandom.ts, server/src/utils/shuffle.ts) on the gameplay
// random of KadoKadeo (kado.Seed: stirred at each frame, replayed exactly). Only called during the update of the game.
// (mt.Rand gives 1/10007 steps: two draws make one value, LaBrute's odds go down to 0.14 out of 600.)
class Rng {
	public static inline var STEPS = 10007;

	// Math.random()
	public static function random():Float {
		return (Seed.random(STEPS) + Seed.rand()) / STEPS;
	}

	// randomBetween: integers, min and max included
	public static function between(min:Int, max:Int):Int {
		if (min > max)
			return 0;
		if (min == max)
			return min;
		return Math.floor(random() * (max - min + 1) + min);
	}

	// randomItem
	public static function item<T>(items:Array<T>):T {
		if (items.length == 0)
			throw "No items";
		if (items.length == 1)
			return items[0];
		return items[between(0, items.length - 1)];
	}

	// weightedRandom
	public static function weighted<T>(items:Array<T>, odds:T->Float):T {
		if (items.length == 0)
			throw "No items";
		var total = 0.0;
		for (i in items)
			total += odds(i);
		var weights:Array<Float> = [];
		for (i in 0...items.length)
			weights[i] = odds(items[i]) / total + (i > 0 ? weights[i - 1] : 0);
		var r = random() * weights[weights.length - 1];
		var i = 0;
		while (i < weights.length) {
			if (weights[i] > r)
				break;
			i++;
		}
		return i < items.length ? items[i] : items[0];
	}

	// shuffle (Fisher-Yates, a new array). Also replaces the `sort(() => Math.random() - 0.5)` of LaBrute: the order of
	// the calls of a comparator depends on the browser, a replay would not be the same game
	public static function shuffle<T>(items:Array<T>):Array<T> {
		var a = items.copy();
		var i = a.length - 1;
		while (i > 0) {
			var j = Math.floor(random() * (i + 1));
			var t = a[i];
			a[i] = a[j];
			a[j] = t;
			i--;
		}
		return a;
	}
}

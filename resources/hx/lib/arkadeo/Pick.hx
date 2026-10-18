package arkadeo;

// random picks of mt.gx (LambdaEx.random, ListEx.random, ArrayEx.normRand): with a mt.Rand, or Std.random (here the
// random of the effects of KadoKadeo: only pictures)
class Pick {
	public static function index(count:Int, ?rd:Rand):Int {
		if (rd != null)
			return rd.random(count);
		return count <= 0 ? 0 : kado.Seed.randomVfx(count);
	}

	public static function array<T>(a:Array<T>, ?rd:Rand):T {
		var i = index(a.length, rd);
		return i < a.length ? a[i] : null;
	}

	public static function list<T>(l:List<T>, ?rd:Rand):T {
		var i = index(l.length, rd);
		var k = 0;
		for (x in l) {
			if (k == i)
				return x;
			k++;
		}
		return null;
	}

	// index of an entry drawn by weight (ArrayEx.normRand)
	public static function normRand<T:{weight:Int}>(a:Array<T>, ?rd:Rand):Null<Int> {
		var tot = 0;
		for (e in a)
			tot += e.weight;
		var r:Int = index(tot, rd);
		var i = 0;
		for (e in a) {
			r -= e.weight;
			if (r < 0)
				return i;
			i++;
		}
		return null;
	}
}

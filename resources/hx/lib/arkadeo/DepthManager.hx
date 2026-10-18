package arkadeo;

/**
 * mt.flash.DepthManager (AS3) on mt.DepthManager: every plan is a Sprite of the root, an empty clip of mt.DepthManager
 * (empty(plan): ordered by its depth, plan x stride), an object added to a plan goes on top of it. The root holds nothing
 * else (mt.DepthManager sorts all its children by depth).
 *
 * In AS3 the objects of every plan were children of the root itself: what an original does to the root goes through
 * this manager (owns / remove / toTop / addTop). TOP is the top of the root (root.addChild, root.setChildIndex(o,
 * numChildren - 1)): a plan over all the others.
 */
class DepthManager {
	public static inline var TOP = 0x7FFF;

	var root:DisplayObjectContainer;
	var inner:mt.DepthManager;
	var plans:Array<Sprite> = [];

	public function new(root:DisplayObjectContainer) {
		if (root.numChildren > 0 || root.node.children.length > 0)
			throw "DepthManager: the root must be empty";
		this.root = root;
		inner = new mt.DepthManager(root.node);
	}

	public function getMC():DisplayObjectContainer {
		return root;
	}

	public function getPlan(p:Int):Sprite {
		var s = plans[p];
		if (s != null)
			return s;
		s = new Sprite(inner.empty(p));
		s.name = "Plan#" + p;
		plans[p] = s;
		root.adoptNodes([for (q in plans) if (q != null) q]);
		return s;
	}

	public function add<T:DisplayObject>(o:T, p:Int):T {
		o.detach();
		getPlan(p).addChild(o);
		return o;
	}

	// a child of the root in AS3
	public function owns(o:DisplayObject):Bool {
		return o.parent != null && plans.indexOf(cast o.parent) >= 0;
	}

	// root.removeChild(o)
	public function remove(o:DisplayObject) {
		if (owns(o))
			o.detach();
	}

	// root.addChild(o)
	public function addTop<T:DisplayObject>(o:T):T {
		return add(o, TOP);
	}

	// root.setChildIndex(o, root.numChildren - 1): over everything, shown from where it is (not a new object)
	public function toTop(o:DisplayObject) {
		var t = getPlan(TOP);
		t.moveChildAt(o, t.numChildren);
	}

	// over / under the other objects of its plan
	public function over(o:DisplayObject) {
		if (owns(o))
			o.toFront();
	}

	public function under(o:DisplayObject) {
		if (owns(o))
			o.toBack();
	}

	// the objects of a plan in the order of their y (the lowest on top)
	public function ysort(p:Int) {
		var s = plans[p];
		if (s == null)
			return;
		var a = s.children.copy();
		var i = 1;
		while (i < a.length) {
			var o = a[i];
			var j = i - 1;
			while (j >= 0 && a[j].y > o.y) {
				a[j + 1] = a[j];
				j--;
			}
			a[j + 1] = o;
			i++;
		}
		for (k in 0...a.length)
			s.setChildIndex(a[k], k);
	}

	public function clear(p:Int) {
		var s = plans[p];
		if (s != null)
			while (s.numChildren > 0)
				s.removeChild(s.getChildAt(0));
	}

	public function destroy() {
		for (p in 0...plans.length)
			clear(p);
	}
}

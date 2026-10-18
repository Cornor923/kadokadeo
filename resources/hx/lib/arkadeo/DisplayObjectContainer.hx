package arkadeo;

// flash.display.DisplayObjectContainer
class DisplayObjectContainer extends DisplayObject {
	public var children(default, null):Array<DisplayObject> = [];
	public var mouseChildren:Bool = true;

	// PIXI children under the Flash children (a Sprite's graphics)
	var base:Int = 0;

	public var numChildren(get, never):Int;

	inline function get_numChildren()
		return children.length;

	public function addChild(o:DisplayObject):DisplayObject {
		if (o.parent == this) {
			setChildIndex(o, children.length - 1);
			return o;
		}
		return addChildAt(o, children.length);
	}

	public function addChildAt(o:DisplayObject, i:Int):DisplayObject {
		if (o.parent != null)
			o.parent.removeChild(o);
		if (i < 0)
			i = 0;
		if (i > children.length)
			i = children.length;
		children.insert(i, o);
		node.addChildAt(o.node, i + base);
		o.attached(this);
		return o;
	}

	// o from its parent to this container at i, shown from where it is (the transform of both parents is the same: the
	// planes of a DepthManager)
	public function moveChildAt(o:DisplayObject, i:Int) {
		if (o.parent == this) {
			setChildIndex(o, i);
			return;
		}
		if (o.parent != null) {
			var p = o.parent;
			p.children.remove(o);
			p.node.removeChild(o.node);
		}
		if (i < 0)
			i = 0;
		if (i > children.length)
			i = children.length;
		children.insert(i, o);
		node.addChildAt(o.node, i + base);
		o.reparented(this);
	}

	// children whose nodes were put in the node of this container by someone else (DepthManager: mt.DepthManager), in the
	// order of their nodes
	public function adoptNodes(objs:Array<DisplayObject>) {
		for (o in objs)
			if (o.parent != this)
				o.attached(this);
		objs.sort((a, b) -> node.getChildIndex(a.node) - node.getChildIndex(b.node));
		children = objs;
	}

	public function removeChild(o:DisplayObject):DisplayObject {
		var i = children.indexOf(o);
		if (i < 0)
			return o;
		children.splice(i, 1);
		node.removeChild(o.node);
		o.detached();
		return o;
	}

	public inline function getChildAt(i:Int):DisplayObject {
		return children[i];
	}

	public inline function getChildIndex(o:DisplayObject):Int {
		return children.indexOf(o);
	}

	public function setChildIndex(o:DisplayObject, i:Int) {
		var j = children.indexOf(o);
		if (j < 0)
			return;
		if (i < 0)
			i = 0;
		if (i > children.length - 1)
			i = children.length - 1;
		if (i == j)
			return;
		children.splice(j, 1);
		children.insert(i, o);
		node.removeChild(o.node);
		node.addChildAt(o.node, i + base);
	}

	public function contains(o:DisplayObject):Bool {
		while (o != null) {
			if (o == this)
				return true;
			o = o.parent;
		}
		return false;
	}

	// the content of the children, through their matrix (Flash's bounds)
	override public function contentRect():Rectangle {
		var r:Rectangle = null;
		for (c in children) {
			if (!c.visible)
				continue;
			var cr = c.contentRect();
			if (cr == null)
				continue;
			var xs = [cr.x, cr.x + cr.width, cr.x + cr.width, cr.x];
			var ys = [cr.y, cr.y, cr.y + cr.height, cr.y + cr.height];
			c.applyMatrix(xs, ys);
			r = union(r, DisplayObject.boxOf(xs, ys));
		}
		return r;
	}

	public static function union(a:Rectangle, b:Rectangle):Rectangle {
		if (a == null)
			return b;
		if (b == null)
			return a;
		var x0 = Math.min(a.x, b.x), y0 = Math.min(a.y, b.y);
		var x1 = Math.max(a.x + a.width, b.x + b.width), y1 = Math.max(a.y + a.height, b.y + b.height);
		return new Rectangle(x0, y0, x1 - x0, y1 - y0);
	}

	// with the drawing of a Graphics (in the same space)
	public static function unionGraphics(r:Rectangle, g:Graphics):Rectangle {
		if (g == null || untyped g.geometry.graphicsData.length == 0)
			return r;
		var b = g.getLocalBounds();
		return union(r, new Rectangle(b.x, b.y, b.width, b.height));
	}

	override public function keepPrev() {
		super.keepPrev();
		for (c in children)
			c.keepPrev();
	}

	override public function checkJumps() {
		super.checkJumps();
		for (c in children)
			c.checkJumps();
	}

	override public function show(frac:Float) {
		super.show(frac);
		for (c in children)
			c.show(frac);
	}
}

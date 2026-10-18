package mt.fx;

// on the display objects of arkadeo (the AS3 games)
class Visibility extends Fx{//}



	public var alpha:Float;
	public var fadeAlpha:Bool;
	var fadeScale: { sx:Int, sy:Int, scx:Float, scy:Float };
	var fadeBlur: { x:Float, y:Float };

	var root:arkadeo.DisplayObject;


	public function new(mc:arkadeo.DisplayObject) {
		super();
		root = mc;
	}


	function setVisibility(c:Float) {
		if( fadeAlpha ) root.alpha = c * alpha;
		if( fadeBlur != null ) 	root.filters = [ new arkadeo.BlurFilter(fadeBlur.x*(1-c),fadeBlur.y*(1-c)) ];

		if( fadeScale != null ) {
			switch(fadeScale.sx) {
				case -1 :	root.scaleX =  fadeScale.scx / c;
				case 1 :	root.scaleX =  fadeScale.scx * c;
				case _ :
			}
			switch(fadeScale.sy) {
				case -1 :	root.scaleY =  fadeScale.scy / c;
				case 1 :	root.scaleY =  fadeScale.scy * c;
				case _ :
			}
		}

		//reminder :
		#if debug
		if (!fadeAlpha && fadeBlur == null && fadeScale == null)
			trace( "wrong setup" );
		#end
		return this;
	}



//{
}

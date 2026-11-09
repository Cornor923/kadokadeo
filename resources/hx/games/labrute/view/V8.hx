package labrute.view;

// The fighters of LaBrute are drawn by labrute-pixi-fighter (MIT, the animations of the original SWF), made for
// PixiJS 8: the site is on PixiJS 6 (the global PIXI). Both are bundled into the game (esbuild, builds/bundle.mjs) and
// PixiJS 8 draws into a canvas of its own, shown in the PixiJS 6 stage of KadoKadeo as a texture (Actors).

@:js.import("pixi.js", "Application")
extern class V8Application {
	public function new();
	public function init(options:Dynamic):js.lib.Promise<Dynamic>;
	public var stage:V8Container;
	public var renderer:Dynamic;
	public var ticker:Dynamic;
	public var canvas:js.html.CanvasElement;
	public function render():Void;
	public function destroy(?rendererDestroyOptions:Dynamic, ?options:Dynamic):Void;
}

@:js.import("pixi.js", "Container")
extern class V8Container {
	public function new(?options:Dynamic);
	public var x:Float;
	public var y:Float;
	public var scale:Dynamic;
	public var visible:Bool;
	public var alpha:Float;
	public var zIndex:Float;
	public var sortableChildren:Bool;
	public var filters:Dynamic;
	public var children:Array<Dynamic>;
	public var parent:Dynamic;
	public var destroyed:Bool;
	// PixiJS 8: the tint of a container goes to its children
	public var tint:Int;
	public var mask:Dynamic;
	public function addChild(child:Dynamic):Dynamic;
	public function addChildAt(child:Dynamic, index:Int):Dynamic;
	public function removeChild(child:Dynamic):Dynamic;
	public function destroy(?options:Dynamic):Void;
	// its bounds in its own space (minX, minY, maxX, maxY)
	public function getLocalBounds():Dynamic;
	// drawn once into a texture (its filters too), drawn from it until updateCacheTexture()
	public function cacheAsTexture(val:Dynamic):Void;
	public function updateCacheTexture():Void;
}

@:js.import("pixi.js", "Graphics")
extern class V8Graphics {
	public function new(?options:Dynamic);
	public var x:Float;
	public var y:Float;
	public var visible:Bool;
	public function rect(x:Float, y:Float, w:Float, h:Float):V8Graphics;
	public function fill(style:Dynamic):V8Graphics;
	public function destroy(?options:Dynamic):Void;
}

@:js.import("pixi.js", "Sprite")
extern class V8Sprite {
	public function new(?texture:Dynamic);
	public var x:Float;
	public var y:Float;
	public var scale:Dynamic;
	public var tint:Int;
	public var alpha:Float;
	public var zIndex:Float;
	public var rotation:Float;
	public var visible:Bool;
	public var anchor:Dynamic;
	public var filters:Dynamic;
	public function destroy(?options:Dynamic):Void;
}

@:js.import("pixi.js", "Texture")
extern class V8Texture {
	public static function from(source:Dynamic):Dynamic;
}

@:js.import("pixi.js", "BlurFilter")
extern class V8BlurFilter {
	public function new(?options:Dynamic);
}

@:js.import("pixi.js", "ColorMatrixFilter")
extern class V8ColorMatrixFilter {
	public function new(?options:Dynamic);
	public var matrix:Array<Float>;
	public var resolution:Dynamic;
}

// labrute-pixi-fighter FighterHolder: one fighter, its animations on the ticker of the application
@:js.import("labrute-pixi-fighter", "FighterHolder")
extern class V8FighterHolder {
	public function new(app:V8Application, appearance:Dynamic, speed:Dynamic, ?scale:Float);
	public var container:V8Container;
	public var shadow:V8Container;
	public var ready:js.lib.Promise<Dynamic>;
	public var loaded:Bool;
	public var weapon:Null<String>;
	public var shield:Bool;
	public var idleAnimation:String;
	public var animation:String;
	public var baseWidth:Float;
	public var baseHeight:Float;
	public var animationSpeed:Float;
	public function setAnimation(animation:String, ?frame:Int, ?seeking:Bool):Void;
	public function setAirborn(airborn:Bool, ?seeking:Bool):Void;
	public function play():Void;
	public function pause():Void;
	public function destroy():Void;
}

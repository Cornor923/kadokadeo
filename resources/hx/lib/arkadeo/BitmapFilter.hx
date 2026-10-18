package arkadeo;

// flash.filters.BitmapFilter: a filter of the original applied at run time (DisplayObject.filters), drawn by a PIXI filter
// (the filters of the timelines are baked in the pictures)
class BitmapFilter {
	// the PIXI filter (null: draws nothing)
	public function toPixi():Dynamic {
		return null;
	}

	public function clone():BitmapFilter {
		return this;
	}
}

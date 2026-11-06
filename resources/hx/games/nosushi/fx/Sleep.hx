package nosushi.fx;

class Sleep extends mt.fx.Fx {
	var counter:Int;

	public function new(counter:Int) {
		super();
		this.counter = counter;
	}

	override function update() {
		counter--;
		if (counter == 0)
			kill();
	}
}

package arkadeo;

// flash.display.GradientType (Graphics.beginGradientFill)
enum abstract GradientType(String) from String to String {
	var LINEAR = "linear";
	var RADIAL = "radial";
}

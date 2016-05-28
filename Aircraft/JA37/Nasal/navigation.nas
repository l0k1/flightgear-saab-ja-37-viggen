############################################################
### Datapanel and Navpanel
############################################################
#/sim/ja37/navigation
#				<rensa-cover type="float">0</rensa-cover> <!-- the cover over the "clear" button -->
#				<tils-group type="bool">false</tils-group> <!-- false: group 1-10, true: group 11-20 -->
#				<tils-knob type="int">-1</tils-knob> <!-- -1 is for automatic setting -->
#				<ispos type="bool">true</ispos> <!-- positive/negative switch, defaults to positive -->
#				<inout type="bool">true</inout> <!-- in/out switch, defaults to out -->
#				<dp-mode type="int">1</dp-mode> <!-- mode knob -->
#				<dp-display type="int" n="0">-1</dp-display> <!-- display, -1 = "X" -->
#				<dp-display type="int" n="1">-1</dp-display>
#				<dp-display type="int" n="2">-1</dp-display>
#				<dp-display type="int" n="3">-1</dp-display>
#				<dp-display type="int" n="4">-1</dp-display>
#				<dp-display type="int" n="5">-1</dp-display>
#				<dp-display type="int" n="6">-1</dp-display>
#				<dp-display-readout type="int">0</dp-display-readout>
#				<dp-display-pos type="int">0</dp-display-pos>



datpan = {
	nav:				"/sim/ja37/navigation",
	dp_display:			"/sim/ja37/navigation/dp-display",
	dp_display_pos:		"/sim/ja37/navigation/dp-display-pos",
	dp_display_readout:	"/sim/ja37/navigation/dp-display-readout",
	inout:				"/sim/ja37/navigation/inout",
	ispos:				"/sim/ja37/navigation/ispos",
	tils_knob:			"/sim/ja37/navigation/tils-knob",
	tils_group:  		"/sim/ja37/navigation/tils-group",
};

foreach(var name; keys(datpan)) {
	datpan[name] = props.globals.getNode(datpan[name], 1);
}

# If a button on the numpad is entered, run this function.
var data_display = func ( key ) {
	var disp = "";
	if ( key >= 0 ) {
		var dat_pos = datpan.dp_display_pos.getValue();
		datpan.nav.getNode("dp-display["~dat_pos~"]").setValue( key );
		datpan.dp_display_pos.setValue( datpan.dp_display_pos.getValue() + 1 );
		if ( datpan.dp_display_pos.getValue() > 6 ) { datpan.dp_display_pos.setValue( 0 ); }
	} elsif ( key == -1 ) {
		foreach(var datum; datpan.nav.getChildren("dp-display")) { datum.setValue(-1); }
		datpan.dp_display_pos.setValue(0);
		
	}
	foreach(var datum; datpan.nav.getChildren("dp-display")) {
		if ( datum.getValue() != -1 ) {
			disp = disp ~ datum.getValue();
		}
	}
	if ( disp != "" ) { datpan.dp_display_readout.setValue( num( disp ) ); } else { datpan.dp_display_readout.setValue( 0 ) }
}

var nav_button = func ( key ) {
	return;
}

############################################################
### Radio Navigation
############################################################

######## radio nav initialization

input = {
	radioComNav:	"instrumentation/radio/switches/com-nav",
	radioMhzKhz:	"instrumentation/radio/switches/mhz-khz",
	radioDisplFreq: "instrumentation/radio/display-freq",
	radioHeadNorm:	"instrumentation/radio/heading-indicator-norm",
	AdfBearing:		"instrumentation/adf/indicated-bearing-deg",
	commSelMhz:  	"instrumentation/comm/frequencies/selected-mhz",
	adfSelKhz:		"instrumentation/adf/frequencies/selected-khz",
	navSelMhz:		"instrumentation/nav/frequencies/selected-mhz",
	navNeedle:		"instrumentation/nav/heading-needle-deflection-norm",
};

foreach(var name; keys(input)) {
	input[name] = props.globals.getNode(input[name], 1);
}

input.radioComNav.setBoolValue(0); # 0 is for com, 1 is for nav.
input.radioMhzKhz.setBoolValue(0); # 0 is for mhz, 1 is for khz.
input.radioDisplFreq.setDoubleValue(input.commSelMhz.getValue());# set up the radio panel display
input.radioHeadNorm.setDoubleValue(0); #heading indicator for the left-hand side attitude display
input.AdfBearing.setDoubleValue(0);


######## radio panel display update code

var display_freq = func {
	#print("inside display_freq function");
	#print("com-nav switch = " ~ getprop("instrumentation/radio/switches/com-nav"));
	#print("mhz-khz switch = " ~ getprop("instrumentation/radio/switches/mhz-khz"));
	if ( input.radioComNav.getValue() == 1 ) {
		if ( input.radioMhzKhz.getValue() == 1 ) {
			input.radioDisplFreq.setDoubleValue(input.adfSelKhz.getValue());
		} else {
			input.radioDisplFreq.setDoubleValue(input.navSelMhz.getValue());
		}
	} else {
		input.radioDisplFreq.setDoubleValue(input.commSelMhz.getValue());
	}
}

#i don't like all these listeners, to be honest. but it works and it's not heavy.
setlistener("instrumentation/radio/switches/com-nav",display_freq);
setlistener("instrumentation/radio/switches/mhz-khz",display_freq);
setlistener("instrumentation/adf/frequencies/selected-khz",display_freq);
setlistener("instrumentation/nav/frequencies/selected-mhz",display_freq);
setlistener("instrumentation/comm/frequencies/selected-mhz",display_freq);

######## heading indicator code.

var heading_indicator = func {
	if ( input.radioMhzKhz.getValue() == 1 ) {
		#locate afds - it's +/- 60* from an ndb, and the needle will start moving.
		var adf_bearing = input.AdfBearing.getValue();
		if ( adf_bearing > 360 ) {
			adf_bearing = 0;
		} elsif ( adf_bearing > 60 and adf_bearing < 180 ) {
			adf_bearing = 1;
		} elsif (adf_bearing >= 180 and adf_bearing < 300 ) {
			adf_bearing = -1;
		} elsif (adf_bearing < 360 and adf_bearing > 300 ) {
			adf_bearing = ( adf_bearing - 360 ) / 60;
		} else {
			adf_bearing = adf_bearing / 60;
		}
		input.radioHeadNorm.setDoubleValue(adf_bearing);
	} elsif (input.navNeedle.getValue() != nil) {
		#vor navving
		input.radioHeadNorm.setDoubleValue(input.navNeedle.getValue()); #just use the regular ol' nav heading indicator.
	}
	settimer(heading_indicator, 0);
}

heading_indicator();
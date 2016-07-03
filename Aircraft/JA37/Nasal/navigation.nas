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
#				<idnr type="int">0</idnr>



datpan = {
	nav:					"/sim/ja37/navigation",
	dp_mode:				"/sim/ja37/navigation/dp-mode",
	dp_display:				"/sim/ja37/navigation/dp-display",
	dp_display_pos:			"/sim/ja37/navigation/dp-display-pos",
	dp_display_readout:		"/sim/ja37/navigation/dp-display-readout",
	inout:					"/sim/ja37/navigation/inout",
	ispos:					"/sim/ja37/navigation/ispos",
	tils_knob:				"/sim/ja37/navigation/tils-knob",
	tils_group:  			"/sim/ja37/navigation/tils-group",
	dp_prop_input:			"/sim/ja37/navigation/dp-display-input",
	np_last_pressed:		"/sim/ja37/navigation/np-last-pressed",
	idnr:					"/sim/ja37/navigation/idnr",
};

foreach(var name; keys(datpan)) {
	datpan[name] = props.globals.getNode(datpan[name], 1);
}

# If a button on the numpad is entered, run this function.
# Only run it if the switch is in the "IN" position.
var data_display = func ( key ) {
	if ( datpan.inout.getValue() == 1 ) { return; }
	var disp = "";
	if ( key >= 0 ) {
		var dat_pos = datpan.dp_display_pos.getValue();
		datpan.nav.getNode("dp-display["~dat_pos~"]").setValue( key );
		datpan.dp_display_pos.setValue( datpan.dp_display_pos.getValue() + 1 );
		if ( datpan.dp_display_pos.getValue() > 6 ) { datpan.dp_display_pos.setValue( 0 ); }
	} elsif ( key == -1 ) {
		clear_display();
	}
	
	foreach(var datum; datpan.nav.getChildren("dp-display")) {
		if ( datum.getValue() != -1 ) {
			disp = disp ~ datum.getValue();
		} else {
			break;
		}
	}
	
	if ( disp != "" ) { datpan.dp_display_readout.setValue( num( disp ) ); } else { datpan.dp_display_readout.setValue( 0 ) }
}

# If a button on the navpanel is pressed, run this one.
var nav_button = func ( key ) {
	#-3 is landingsbas button
	#-2 is startbas button
	#-1 is BX
	# 0 is nil
	# 1-9 is B1-B9
	# if landing, starting, or 1-9, then check if the waypoint is valid. if it is, then set to that. otherwise, set to the current or set to 0.
	# need to handle all this in this function?
	datpan.np_last_pressed.setValue(key);
	
	#update waypoint if in/out is out and knob is at wind/route/target
	#doing this 
	if ( datpan.inout.getValue() == 0 and datpan.dp_mode.getValue() == 3 )
		var key = datpan.np_last_pressed.getValue();
		if ( key == -2 ) {
			props.globals.getNode("/autopilot/route-manager/current-wp").setValue(0);
		} elsif ( key == -3 ) {
			var final_wp = props.globals.getNode("/autopilot/route-manager/route/num").getValue() - 1;
			props.globals.getNode("/autopilot/route-manager/current-wp").setValue( final_wp );
		} elsif ( key <= props.globals.getNode("/autopilot/route-manager/route/num").getValue() - 1 ) {
			props.globals.getNode("/autopilot/route-manager/current-wp").setValue( key );
		}
		datpan.np_last_pressed.setValue(0);
	}
}

# Used for updating display output when the in/out switch is set to "out".
# Run this function on startup, also.
var display_update = func() {
	
	# if the switch is in the "IN" position, exit this function.
	if ( datpan.inout.getValue() == 0 ) { return; }
	
	var key = datpan.np_last_pressed.getValue()
	
	########################### knob is at act-pos ###########################
	# display alternates between lat and lon - using decimal format here for simplicities sake.
	if ( datpan.dp_mode.getValue() == 0 ) {
		
		
		if ( int(math.mod(props.globals.getNode("/sim/time/elapsed-sec").getValue(), 2)) == 1 ) {
			# update longitude on odd seconds
			datpan.dp_prop_input.setValue( abs(props.globals.getNode("/position/longitude-deg/").getValue()) * 10000 );
		} else {
			# update latitude
			datpan.dp_prop_input.setValue( abs(props.globals.getNode("/position/latitude-deg/").getValue()) * 10000 );
		}
		
		# update every second
		# doing it this way, as pressing a nav_button will call the display_update function, and I want to avoid unnecessary multiple settimers()
		if ( key == 0 ) {
			settimer( func { display_update(); }, 1);
		} else {
			datpan.np_last_pressed.setValue(0);
		}
		
	########################### knob is at ref/lola ###########################
	# show lat/lon of current waypoint/bp button/landing button.
	} elsif ( datpan.dp_mode.getValue() == 1 ) {
		# when the knob is rotated, np_last_pressed is set to 0 for nil
		# find which waypoint we need to display.
		if ( props.globals.getNode("/autopilot/route-manager/active").getValue() == 1 ) {
			if ( key == 0 or props.globals.getNode("/autopilot/route-manager/route/wp["~ key ~"]") == nil ) {
				var current_wp = props.globals.getNode("autopilot/route-manager/current-wp").getValue();
			} else {
				if ( key == -2 ) {
					var current_wp = 0;
				} elsif ( key == -3 ) {
					var current_wp = props.globals.getNode("/autopilot/route-manager/route/num").getValue() - 1;
				} elsif ( key <= props.globals.getNode("/autopilot/route-manager/route/num").getValue() - 1 ) {
					var current_wp = key;
				}
			}
			
			if ( int(math.mod(props.globals.getNode("/sim/time/elapsed-sec").getValue(), 2)) == 1 ) {
				# update longitude on odd seconds
				datpan.dp_prop_input.setValue( abs(props.globals.getNode("/autopilot/route-manager/route/wp["~current_wp~"]/longitude-deg").getValue()) * 10000 );
			} else {
				# update latitude
				datpan.dp_prop_input.setValue( abs(props.globals.getNode("/autopilot/route-manager/route/wp["~current_wp~"]/latitude-deg").getValue()) * 10000 );
			}
		} else {
			clear_display();
		}
	
	########################### knob is at WP ###########################
	## show lat/lon of L/LS/L1/L2 base and tils channel.
	## if pressed b1-b9,show limits of nav point
	## just gonna do the limits, as the lat/lon is already covered by ref/lola, and tils channel... not sure if going to be used yet.
	} elsif ( datpan.dp_mode.getValue() == 2 ) {
		# first need to find waypoint to show.
		if ( props.globals.getNode("/autopilot/route-manager/active").getValue() == 1 ) {
			if ( key == 0 or props.globals.getNode("/autopilot/route-manager/route/wp["~ key ~"]") == nil ) {
				var current_wp = props.globals.getNode("autopilot/route-manager/current-wp").getValue();
			} else {
				if ( key == -2 ) {
					var current_wp = 0;
				} elsif ( key == -3 ) {
					var current_wp = props.globals.getNode("/autopilot/route-manager/route/num").getValue() - 1;
				} elsif ( key <= props.globals.getNode("/autopilot/route-manager/route/num").getValue() - 1 ) {
					var current_wp = key;
				}
			}
			if ( props.globals.getNode("/autopilot/route-manager/route/wp["~current_wp~"]/limit[0]") != nil ) {
				var limit_output1 = props.globals.getNode("/autopilot/route-manager/route/wp["~current_wp~"]/limit[0]").getValue();
				ouput_normalize_3(limit_output1);
				if ( props.globals.getNode("/autopilot/route-manager/route/wp["~current_wp~"]/limit[1]") != nil ) {
					var limit_output2 = props.globals.getNode("/autopilot/route-manager/route/wp["~current_wp~"]/limit[1]").getValue();
					ouput_normalize_3(limit_output2);
				} else {
					limit_output2 = "";
				}
				datpan.dp_prop_input.setValue(limit_output1 ~ limit_output2);
			}
		} else {
			clear_display();
		}
	
	########################### knob is at wind/route/target ###########################
	# shows wind value
	# if a B# button is pressed, update the current waypoint to that waypoint (handled in the B# button listener).
	} elsif ( datpan.dp_mode.getValue() == 3 ) {
		#output wind values
		var output1 = output_normalize_3(int(props.globals.getNode("/environment/wind-from-heading-deg").getValue()));
		var output2 = output_normalize_2(int(props.globals.getNode("/environment/wind-speed-kt").getValue()));
		datpan.dp_prop_input.setValue(output1 ~ output2);
		settimer( func { display_update(); }, 5);
	
	########################### knob is at time ###########################
	## UTC time displayed if LS
	## Attack time for target breakpoint if target breakpoint button pressed
	## if there's a timetable inputted, default to time table error
	## if not, estimated total flight time displayed default
	} elsif ( datpan.dp_mode.getValue() == 4 ) {
		var cur_hour = output_normalize_2(props.globals.getNode("/sim/time/utc/hour").getValue());
		var cur_minute = output_normalize_2(props.globals.getNode("/sim/time/utc/minute").getValue());
		var cur_second = output_normalize_2(props.globals.getNode("/sim/time/utc/second").getValue());
		#output normal time
		if ( key == -2 ) {
			datpan.dp_prop_input.setValue(cur_hour ~ cur_minute ~ cur_second);
		} elsif ( key > 0 and props.globals.getNode("/autopilot/route-manager/route/wp["~ key ~"]") != nil and props.globals.getNode("/autopilot/route-manager/route/wp["~ key ~"]/time_arrival") != nil ) {
			var time_arrival = props.globals.getNode("/autopilot/route-manager/route/wp["~ key ~"]/time_arrival").getValue();
			#arrival time - current time
			var time_offset_hour = num(left(time_arrival,2)) - cur_hour;
			if ( time_offset_hour < 0 ) { 
				time_offset_hour = time_offset_hour + 24;
			}
			time_offset_hour = output_normalize_2(time_offset_hour);
			
			var time_offset_minute = num(right(left(time_arrival,4),2) - cur_minute;
			if ( time_offset_minute < 0 ) { 
				time_offset_minute = time_offset_minute + 60;
				time_offset_hour = time_offset_hour + 1;
			}
			time_offset_minute = output_normalize_2(time_offset_minute);
			
			var time_offset_second = num(right(left(time_arrival,4),2) - cur_second;
			if ( time_offset_second < 0 ) { 
				time_offset_second = time_offset_second + 60;
				time_offset_minute = time_offset_minute + 1;
				if ( time_offset_minute > 60 ) { 
					time_offset_minute = time_offset_minute - 60;
					time_offset_hour = time_offset_hour + 1;
				}
			}
			time_offset_second = output_normalize_2(time_offset_second);
			
			datpan.dp_prop_input.setValue( time_offset_hour ~ time_offset_minute ~ time_offset_second );
		} else {
			#show estimated time to arrival
			var time_left = int(props.globals.getNode("/autopilot/route-manager/ete").getValue());
			# 3 599 999 is 999 hours, 59 minutes, 59 seconds, and is the max our display can handle
			if ( time_left > 3599999 ) {
				clear_display();
				return;
			}
			var time_hour = output_normalize_3( int(time_left/60/60) );
			var time_minute = output_normalize_2( int( ((time_left/60/60) - int(time_left/60/60)) * 60 ) );
			var time_second = output_normalize_2( (((time_left/60/60) - int(time_left/60/60)) * 60) - int((((time_left/60/60) - int(time_left/60/60)) * 60)) * 60 );
			datpan.dp_prop_input.setValue( time_hour ~ time_minute ~ time_second );
		}
		
		settimer( func { display_update(); }, 1);
			
	########################### knob is at tact ###########################
	## shows remaining fuel in kilograms
	} elsif ( datpan.dp_mode.getValue() == 5 ) {
		var current_fuel_kg = props.globals.getNode("/consumables/fuel/total-fuel-kg").getValue();
		datpan.dp_prop_input.setValue( int(current_fuel_kg );
		
		if ( key == 0 ) {
			settimer( func { display_update(); }, 1);
		} else {
			datpan.np_last_pressed.setValue(0);
		}
	
	########################### knob is at id-nr ###########################
	} elsif ( datpan.dp_mode.getValue() == 6 ) {
		datpan.dp_prop_input.setValue( datpan.idnr.getValue() );
	}
}

# Clear the datapanel display
var clear_display = func () {
	foreach(var datum; datpan.nav.getChildren("dp-display")) { datum.setValue(-1); }
	datpan.dp_display_pos.setValue(0);
}

# I feel like this function is hacky, but it works and I can't think of a better way. Nasal's shortcomings seem to be shining through here.
var readout_listener = func () {
	clear_display();
	var display_datum = datpan.dp_prop_input.getValue();
	var divisor = 1000000;
	if ( display_datum == 0 ) { return; }
	#find the top divisor
	while ( int(display_datum / divisor) == 0 ) {
		divisor = divisor / 10;
	}
	
	#to set up the exit condition on the below loop correctly, we need to multiply the divisor by 10.
	divisor = divisor * 10;
	
	foreach(var datum; datpan.nav.getChildren("dp-display")) { 
		divisor = divisor / 10;
		datum.setValue( int(display_datum / divisor) );
		display_datum = display_datum - (int(display_datum / divisor) * divisor);
		if ( divisor == 1 ) { break };
	}
	
	datpan.dp_display_readout.setValue( datpan.dp_prop_input.getValue() );
}

var ouput_normalize_2 = func (value) {
	if ( size(value) == 1 ) {
		value = "0" ~ value;
	}
	return value;
}

var ouput_normalize_3 = func (value) {
	if ( size(value) == 1 ) {
		value = "00" ~ value;
	} elsif ( size(value) == 2 ) {
		value = "0" ~ value;
	}
	return value;
}

# display input property listener
setlistener(datpan.dp_prop_input, func { readout_listener(); });

# in/out switch listener
setlistener(datpan.inout, func {
	# if switch is set to IN
	if ( datpan.inout.getValue() == 0 ) { 
		clear_display();
	# if switch is set to OUT
	} else {
		readout_listener();
	}
});

# knob listener
setlistener(datpan.dp_mode, func {
	if ( datpan.dp_mode.getValue() == 1 and datpan.inout == 1 ) {
		datpan.np_last_pressed.setValue(0);
	}
});
		
# setting up and getting things running.
display_update();

#if in/out switch is IN

# if act pos
## do nothing

# if ref/lola
## entering waypoints. some waypoints are stored in the airplanes memory (still stored as lat/lon)
## if entering a reference number, it's in the format of 90xx, where X is 1-69. [we could do 9xxx to support up to 999 custom waypoints. hardcode the first 20 though]
## to enter: put in reference number, then press B1-B9, or BX then 0-9 [we could modify this to BX, ##, BX)
## for landing bases - 9013 = landing base, 9913 = alternate base. [maybe use 8913 for alternate base? or 99130]
## if L1 is not specified, LS data is copied to L1.
## to clear landing bases, enter 9000 and 9900 [us 9000 and 8000, or something]
## longitudes and latitudes, if entered, need to be between 40 and 90 (latitude) or <40 (longitude) [obv wont work for us, plan to do all coords are okay, down to minutes/seconds]
## longitude and latitude can be entered in any order [latitude first, because reasons]
## put in the latitude, press the "B" button or the "L" button (if BX, handle that), followed by longitutde.
## L2 can't be entered via latitude and longitude.

# if "WP"
## runway heading is entered via the first four positions [five for us], and last two indicate TILS channel [maybe? need to think about how to implement TILS].
## press LS or L for storing. runway and TILS can't be entered for L2.
## to enter "limits", or approach vectors, first three numbers are limit 1, and second three are limit 2. Use 0's to clear out lines.

# if wind/route/goal
## first three are wind direction, next two are speed in km/h - for forecasted wind.
## route/goal is weapons related, will fill in later. See the ULTRA SECRET MANUAL!!!!!!1!11!!

# if time
## format hhmmss
## press "LS" to set current time
## press B1-BX to set time expected to be at waypoint
## press "L" to set cruising mach number, first three positions in the format: 125, which equals 1.25 mach. anything over 399 fails.
### (not sure what this is supposed to do - maybe counts in with the fuel consumption?)
## fuel calcs beginat mach 055, and don't go over mach 085

# if takt
## set bingo fuel with format 51xx, where xx is a percent between 10 and 99.
## to set targets, see the ULTRA SECRET MANUAL!!!!!!1!11!!

# if ID-NR
## put assignment and division number, press B1 to store.
## put yy-mm-dd, then press B2 to store date.



# if in/out switch is OUT

# if act pos
## toggle between lat/lon every second [don't include drift as last digit)

# if ref/lola
## show lat/lon of current waypoint/bp button/landing button.

# if "WP"
## show lat/lon of L/LS/L1/L2 base and tils channel.
## if pressed b1-b9,show limits of nav point

# if wind/route/goal
## show current wind, format direction ddd followed by speed ss. If doppler, last pos is a zero. If forecast, last pos is a [1].
## MOAR IN DU SECRUT PART

# if time
## Civvie time displayed if LS
## Attack time for target breakpoint if target breakpoint button pressed
## if there's a timetable inputted, default to time table error
## if not, estimated total flight time displayed default
## if nav breakpoint, cruising mach is displayed.
## MOAR IN DA SECRUT MANUAL

# if takt
## checks if breakpoint is a target breakpoint - if it is, displays "900000"
## if takt/in, then "5100000", then takt/out, shows fuel reserve [is this necessary?]
## MOARRRRRRRRRRR IN SEECCCRRRUUUUUUUUUT

# if ID-NR
## press B1 to see assignment and division number
## press B2 to see date yy-mm-dd
## more in the secret part.

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
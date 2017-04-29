# todo:
# servicable, indicated
# buttons functions
# geo grid
# radar echoes types
# runway proper styles
# steerpoint symbols: # ?
# full OOP
# use Pinto's model
var (width,height) = (381,512);#381.315

#var window = canvas.Window.new([height, height],"dialog")
#					.set('x', width*2.75)
#                   .set('title', "TI display");
#var gone = 0;
#window.del = func() {
#  print("Cleaning up window:","TI","\n");
  #update_timer.stop();
#  gone = TRUE;
# explanation for the call() technique at: http://wiki.flightgear.org/Object_oriented_programming_in_Nasal#Making_safer_base-class_calls
#  call(canvas.Window.del, [], me);
#};
#var root = window.getCanvas(1).createGroup();
var canvas = canvas.new({
  "name": "TI",   # The name is optional but allow for easier identification
  "size": [height, height], # Size of the underlying texture (should be a power of 2, required) [Resolution]
  "view": [height, height],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
                        # which will be stretched the size of the texture, required)
  "mipmapping": 0       # Enable mipmapping (optional)
});
var root = canvas.createGroup();
root.set("font", "LiberationFonts/LiberationMono-Regular.ttf");
#window.getCanvas(1).setColorBackground(0.3, 0.3, 0.3, 1.0);
#window.getCanvas(1).addPlacement({"node": "ti_screen", "texture": "ti.png"});
canvas.setColorBackground(0.3, 0.3, 0.3, 1.0);
canvas.addPlacement({"node": "ti_screen", "texture": "ti.png"});

var (center_x, center_y) = (width/2,height/2);

var MM2TEX = 1;
var texel_per_degree = 2*MM2TEX;

# map setup

var tile_size = 256;
var zoom = 9;
var type = "light_nolabels";

# index   = zoom level
# content = meter per pixel of tiles
#                   0                             5                               10                               15                      19
meterPerPixel = [156412,78206,39103,19551,9776,4888,2444,1222,610.984,305.492,152.746,76.373,38.187,19.093,9.547,4.773,2.387,1.193,0.596,0.298];
zooms      = [4, 7, 9, 11, 13];
zoomLevels = [200, 400, 800, 1.6, 3.2];
zoom_curr  = 2;

var M2TEX = 1/meterPerPixel[zoom];

var zoomIn = func() {
  zoom_curr += 1;
  if (zoom_curr > 4) {
  	zoom_curr = 0;
  }
  zoom = zooms[zoom_curr];
  M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));
}

var zoomOut = func() {
  zoom_curr -= 1;
  if (zoom_curr < 0) {
  	zoom_curr = 4;
  }
  zoom = zooms[zoom_curr];
  M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));
}

var maps_base = getprop("/sim/fg-home") ~ '/cache/mapsTI';

# max zoom 18
# light_all,
# dark_all,
# light_nolabels,
# light_only_labels,
# dark_nolabels,
# dark_only_labels

var makeUrl =
  string.compileTemplate('http://cartodb-basemaps-c.global.ssl.fastly.net/{type}/{z}/{x}/{y}.png');#http://otile2.mqcdn.com/tiles/1.0.0/{type}/{z}/{x}/{y}.jpg'
var makePath =
  string.compileTemplate(maps_base ~ '/cartoL/{z}/{x}/{y}.png');#/osm-{type}/{z}/{x}/{y}.jpg
var num_tiles = [5, 5];

var center_tile_offset = [(num_tiles[0] - 1) / 2,(num_tiles[1] - 1) / 2];#(width/tile_size)/2,(height/tile_size)/2];
#  (num_tiles[0] - 1) / 2,
#  (num_tiles[1] - 1) / 2
#];

##
# initialize the map by setting up
# a grid of raster images  

var tiles = setsize([], num_tiles[0]);


var last_tile = [-1,-1];
var last_type = type;

# stuff

var FLIGHTDATA_ON = 2;
var FLIGHTDATA_CLR = 1;
var FLIGHTDATA_OFF = 0;

var CLEANMAP = 0;
var PLACES   = 1;

var brightness = func {
	bright += 1;
};

var bright = 0;

#TI symbol colors
var rWhite = 1.0; # other / self / own_missile
var gWhite = 1.0;
var bWhite = 1.0;

var rYellow = 1.0;# possible threat
var gYellow = 1.0;
var bYellow = 0.0;

var rRed = 1.0;   # threat
var gRed = 0.0;
var bRed = 0.0;

var rGreen = 0.0; # own side
var gGreen = 1.0;
var bGreen = 0.0;

var rTyrk = 0.25; # navigation aid
var gTyrk = 0.88;
var bTyrk = 0.81;

var rGrey = 0.5;   # inactive
var gGrey = 0.5;
var bGrey = 0.5;

var rBlack = 0.0;   # active
var gBlack = 0.0;
var bBlack = 0.0;

var rGB = 0.5;   # flight data
var gGB = 0.5;
var bGB = 0.75;

var a = 1.0;#alpha
var w = 1.0;#stroke width

var fpi_min = 3;
var fpi_med = 6;
var fpi_max = 9;

var maxTracks   = 32;# how many radar tracks can be shown at once in the TI (was 16)
var maxMissiles = 6;
var maxThreats  = 5;

var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v };

var FALSE = 0;
var TRUE = 1;


var dictSE = {
	'HORI': {'0': [TRUE, "AV"], '1': [TRUE, "RENS"], '2': [TRUE, "PA"]},
	'0':   {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"]},
	'8':   {'8': [TRUE, "R7V"], '9': [TRUE, "V7V"], '10': [TRUE, "S7V"], '11': [TRUE, "S7H"], '12': [TRUE, "V7H"], '13': [TRUE, "R7H"],
			'7': [TRUE, "MENY"], '14': [TRUE, "AKAN"], '15': [FALSE, "RENS"]},
	'9':   {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
	 		'1': [TRUE, "SLACK"], '2': [FALSE, "DL"], '4': [FALSE, "B"], '5': [FALSE, "UPOL"], '6': [TRUE, "TRAP"], '7': [TRUE, "MENY"],
	 		'14': [FALSE, "JAKT"], '15': [FALSE, "HK"],'16': [FALSE, "APOL"], '17': [FALSE, "LA"], '18': [FALSE, "LF"], '19': [FALSE, "LB"],'20': [FALSE, "L"]},
	'TRAP':{'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
	 		'2': [FALSE, "INLA"], '3': [TRUE, "AVFY"], '4': [FALSE, "FALL"], '5': [FALSE, "MAN"], '6': [FALSE, "SATT"], '7': [TRUE, "MENY"], '14': [TRUE, "RENS"], '17': [FALSE, "ALLA"], '19': [TRUE, "NED"], '20': [TRUE, "UPP"]},
	'10':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
			'3': [FALSE, "ELKA"], '4': [TRUE, "ORTS"], '6': [TRUE, "SKAL"], '7': [TRUE, "MENY"], '14': [FALSE, "EOMR"], '15': [FALSE, "EOMR"], '16': [TRUE, "TID"], '17': [TRUE, "HORI"], '18': [FALSE, "HKM"], '19': [FALSE, "DAG"]},
	'11':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
			'4': [FALSE, "EDIT"], '6': [FALSE, "EDIT"], '7': [TRUE, "MENY"], '14': [FALSE, "EDIT"], '15': [FALSE, "APOL"], '16': [FALSE, "EDIT"], '17': [FALSE, "UPOL"], '18': [FALSE, "EDIT"], '19': [TRUE, "EGLA"], '20': [FALSE, "KMAN"]},
	'12':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
	 		'7': [TRUE, "MENY"], '19': [TRUE, "NED"], '20': [TRUE, "UPP"]},
	'13':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
			'5': [FALSE, "SVY"], '6': [FALSE, "FR28"], '7': [TRUE, "MENY"], '14': [TRUE, "GPS"], '19': [FALSE, "LAS"]},
	'GPS': {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "FLDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'7': [TRUE, "MENU"], '14': [FALSE, "FIX"], '15': [FALSE, "INIT"]},
};

var dictEN = {
	'HORI': {'0': [TRUE, "OFF"], '1': [TRUE, "CLR"], '2': [TRUE, "ON"]},
	'0':   {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "FLDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"]},
	'8':   {'8': [TRUE, "T7L"], '9': [TRUE, "W7L"], '10': [TRUE, "F7L"], '11': [TRUE, "F7R"], '12': [TRUE, "W7R"], '13': [TRUE, "T7R"],
			'7': [TRUE, "MENU"], '14': [TRUE, "AKAN"], '15': [FALSE, "CLR"]},
    '9':   {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "FLDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'1': [TRUE, "OFF"], '2': [FALSE, "DL"], '4': [FALSE, "B"], '5': [FALSE, "UPOL"], '6': [TRUE, "TRAP"], '7': [TRUE, "MENU"],
	 		'14': [FALSE, "FGHT"], '15': [FALSE, "CURV"],'16': [FALSE, "POLY"], '17': [FALSE, "WAYP"], '18': [FALSE, "LF"], '19': [FALSE, "LB"],'20': [FALSE, "L"]},
	'TRAP':{'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "FLDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'2': [FALSE, "LOCK"], '3': [TRUE, "FIRE"], '4': [FALSE, "ECM"], '5': [FALSE, "MAN"], '6': [FALSE, "LAND"], '7': [TRUE, "MENU"], '14': [TRUE, "CLR"], '17': [FALSE, "ALL"], '19': [TRUE, "DOWN"], '20': [TRUE, "UP"]},
	'10':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "FLDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'3': [FALSE, "MAP"], '4': [TRUE, "TEXT"], '6': [TRUE, "SCAL"], '7': [TRUE, "MENU"], '14': [FALSE, "HSTL"], '15': [FALSE, "FRND"], '16': [TRUE, "TIME"], '17': [TRUE, "HORI"], '18': [FALSE, "CURS"], '19': [FALSE, "DAY"]},
	'11':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "FLDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'4': [FALSE, "EDIT"], '6': [FALSE, "EDIT"], '7': [TRUE, "MENU"], '14': [FALSE, "EDIT"], '15': [FALSE, "POLY"], '16': [FALSE, "EDIT"], '17': [FALSE, "UPOL"], '18': [FALSE, "EDIT"], '19': [TRUE, "MYPS"], '20': [FALSE, "MMAN"]},
	'12':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "FLDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'7': [TRUE, "MENU"], '19': [TRUE, "DOWN"], '20': [TRUE, "UP"]},
	'13':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "FLDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'5': [FALSE, "SIDE"], '6': [FALSE, "FR28"], '7': [FALSE, "MENU"], '14': [TRUE, "GPS"], '19': [FALSE, "LOCK"]},
	'GPS': {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
			'7': [TRUE, "MENU"], '14': [FALSE, "FIX"], '15': [FALSE, "INIT"]},
};

var TI = {

	setupCanvasSymbols: func {
		me.mapCentrum = root.createChild("group")
			.set("z-index", 1)
			.setTranslation(width/2,height*2/3);
		me.mapCenter = me.mapCentrum.createChild("group");
		me.mapRot = me.mapCenter.createTransform();
		me.mapFinal = me.mapCenter.createChild("group");
		me.mapFinal.setTranslation(-tile_size*center_tile_offset[0],-tile_size*center_tile_offset[1]);

		me.rootCenter = root.createChild("group")
			.setTranslation(width/2,height*2/3)
			.set("z-index",  9);
		me.rootRealCenter = root.createChild("group")
			.setTranslation(width/2,height/2)
			.set("z-index", 10);
		me.selfSymbol = me.rootCenter.createChild("path")
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo( 5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 5*MM2TEX,  5*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
		me.selfVectorG = me.rootCenter.createChild("group")
			.setTranslation(0,-10*MM2TEX);
		me.selfVector = me.selfVectorG.createChild("path")
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);

		me.radar_group = me.rootCenter.createChild("group");
		me.echoesAircraft = [];
		me.echoesAircraftVector = [];
		for (var i = 0; i < maxTracks; i += 1) {
			var grp = me.radar_group.createChild("group")
				.set("z-index", maxTracks-i);
			var grp2 = grp.createChild("group")
				.setTranslation(0,-10*MM2TEX);
			var vector = grp2.createChild("path")
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(i!=0?rYellow:rRed,i!=0?gYellow:gRed,i!=0?bYellow:bRed, a)
		      .setStrokeLineWidth(w);
			grp.createChild("path")
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo( 5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 5*MM2TEX,  5*MM2TEX)
		      .setColor(i!=0?rYellow:rRed,i!=0?gYellow:gRed,i!=0?bYellow:bRed, a)
		      .setStrokeLineWidth(w);
		    append(me.echoesAircraft, grp);
		    append(me.echoesAircraftVector, vector);
		}

	    me.dest = me.rootCenter.createChild("group")
            .hide()
            .set("z-index", 5);
	    me.dest_runway = me.dest.createChild("path")
	               .moveTo(0, 0)
	               .lineTo(0, -1)
	               .setStrokeLineWidth(w)
	               .setColor(rTyrk,gTyrk,bTyrk, a)
	               .hide();
	    me.dest_circle = me.dest.createChild("path")
	               .moveTo(-25, 0)
	               .arcSmallCW(25, 25, 0, 50, 0)
	               .arcSmallCW(25, 25, 0, -50, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rTyrk,gTyrk,bTyrk, a);
	    me.approach_circle = me.rootCenter.createChild("path")
	               .moveTo(-100, 0)
	               .arcSmallCW(100, 100, 0, 200, 0)
	               .arcSmallCW(100, 100, 0, -200, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rTyrk,gTyrk,bTyrk, a);

	    me.threats = [];
	    for (var i = 0; i < maxThreats; i += 1) {
	    	append(me.threats, me.radar_group.createChild("path")
	               .moveTo(-100, 0)
	               .arcSmallCW(100, 100, 0, 200, 0)
	               .arcSmallCW(100, 100, 0, -200, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rRed,gRed,bRed, a));
	    }

	    me.missiles = [];
	    me.missilesVector = [];
	    for (var i = 0; i < maxMissiles; i += 1) {
	    	var grp = me.radar_group.createChild("group")
				.set("z-index", maxTracks-i);
			var grp2 = grp.createChild("group")
				.setTranslation(0,-10*MM2TEX);
			var vector = grp2.createChild("path")
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
			grp.createChild("path")
		      .moveTo(-2.5*MM2TEX,  5*MM2TEX)
		      .lineTo(   0,       -10*MM2TEX)
		      .moveTo( 2.5*MM2TEX,  5*MM2TEX)
		      .lineTo(   0,       -10*MM2TEX)
		      .moveTo(-2.5*MM2TEX,  5*MM2TEX)
		      .lineTo( 2.5*MM2TEX,  5*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
		    append(me.missiles, grp);
		    append(me.missilesVector, vector);
	    }

	    me.gpsSymbol = me.radar_group.createChild("path")
		      .moveTo(-5*MM2TEX, 10*MM2TEX)
		      .vert(            -20*MM2TEX)
		      .moveTo( 5*MM2TEX, 10*MM2TEX)
		      .vert(            -20*MM2TEX)
		      .moveTo(-10*MM2TEX, 5*MM2TEX)
		      .horiz(            20*MM2TEX)
		      .moveTo(-10*MM2TEX,-5*MM2TEX)
		      .horiz(            20*MM2TEX)
		      .setColor(rTyrk,gTyrk,bTyrk, a)
		      .setStrokeLineWidth(w);

		me.radar_limit_grp = me.radar_group.createChild("group");

		me.bottom_text_grp = root.createChild("group");
		me.textBArmType = me.bottom_text_grp.createChild("text")
    		.setText("74")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-top")
    		.setTranslation(0, height-height*0.09)
    		.setFontSize(35, 1);
    	me.textBArmAmmo = me.bottom_text_grp.createChild("text")
    		.setText("71")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(25, height-height*0.01)
    		.setFontSize(15, 1);
    	me.textBTactType1 = me.bottom_text_grp.createChild("text")
    		.setText("J")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-top")
    		.setTranslation(55, height-height*0.08)
    		.setFontSize(13, 1);
    	me.textBTactType2 = me.bottom_text_grp.createChild("text")
    		.setText("K")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-top")
    		.setTranslation(55, height-height*0.08+15)
    		.setFontSize(13, 1);
    	me.textBTactType3 = me.bottom_text_grp.createChild("text")
    		.setText("T")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-top")
    		.setTranslation(55, height-height*0.08+30)
    		.setFontSize(13, 1);
    	me.textBTactType = me.bottom_text_grp.createChild("path")
    		.moveTo(50, height-height*0.09)
    		.horiz(12)
    		.vert(45)
    		.horiz(-12)
    		.vert(-45)
    		.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
    	me.textBBase = me.bottom_text_grp.createChild("text")
    		.setText("9040T")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(80, height-height*0.01)
    		.setFontSize(10, 1);
    	me.textBlink = me.bottom_text_grp.createChild("text")
    		.setText("DL")
    		.setColor(rGrey,gGrey,bGrey, a)
    		.setAlignment("center-top")
    		.setTranslation(72, height-height*0.08)
    		.setFontSize(10, 1);
    	me.textBLinkFrame = me.bottom_text_grp.createChild("path")
    		.moveTo(65, height-height*0.085)
    		.horiz(16)
    		.vert(12)
    		.horiz(-16)
    		.vert(-12)
    		.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.textBerror = me.bottom_text_grp.createChild("text")
    		.setText("F")
    		.setColor(rGrey,gGrey,bGrey, a)
    		.setAlignment("center-top")
    		.setTranslation(89, height-height*0.08)
    		.set("z-index", 10)
    		.setFontSize(10, 1);
    	me.textBerrorFrame1 = me.bottom_text_grp.createChild("path")
    		.moveTo(85, height-height*0.085)
    		.horiz(10)
    		.vert(12)
    		.horiz(-10)
    		.vert(-12)
    		.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.textBerrorFrame2 = me.bottom_text_grp.createChild("path")
    		.moveTo(85, height-height*0.085)
    		.horiz(10)
    		.vert(12)
    		.horiz(-10)
    		.vert(-12)
    		.setColor(rWhite,gWhite,bWhite, a)
    		.hide()
    		.set("z-index", 1)
		    .setColorFill(rGreen, gGreen, bGreen, a)
		    .setStrokeLineWidth(w);
    	me.textBMode = me.bottom_text_grp.createChild("text")
    		.setText("LF")
    		.setColor(rTyrk,gTyrk,bTyrk, a)
    		.setAlignment("center-center")
    		.setTranslation(125, height-height*0.05)
    		.setFontSize(40, 1);
    	me.textBDistN = me.bottom_text_grp.createChild("text")
    		.setText("A")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-bottom")
    		.setTranslation(width/2, height-height*0.015)
    		.setFontSize(20, 1);
    	me.textBDist = me.bottom_text_grp.createChild("text")
    		.setText("11")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-bottom")
    		.setTranslation(width/2, height-height*0.015)
    		.setFontSize(30, 1);
    	me.textBAlpha = me.bottom_text_grp.createChild("text")
    		.setText("ALFA 20,5")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-bottom")
    		.setTranslation(width, height-height*0.01)
    		.setFontSize(18, 1);
    	me.textBWeight = me.bottom_text_grp.createChild("text")
    		.setText("VIKT 13,4")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-top")
    		.setTranslation(width, height-height*0.085)
    		.setFontSize(18, 1);

    	me.menuMainRoot = root.createChild("group")
    		.set("z-index", 20)
    		.hide();
    	me.logRoot = root.createChild("group")
    		.set("z-index", 5)
    		.hide();
    	me.errorList = me.logRoot.createChild("text")
    		.setText("..OKAY..\n..OKAY..")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-top")
    		.setTranslation(0, 20)
    		.setFontSize(10, 1);

    	me.menuFastRoot = root.createChild("group")
    		.set("z-index", 20);
    		#.hide();

    	# text for outer menu items
		#
    	me.menuButton = [nil];
    	for(var i = 1; i <= 7; i+=1) {
			append(me.menuButton,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setAlignment("left-center")
    				.setTranslation(width*0.025, height*0.09+(i-1)*height*0.11)
    				.setFontSize(12.5, 1));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButton, me.menuMainRoot.createChild("text")
    			.setText("MAIN")
    			.setColor(rWhite,gWhite,bWhite, a)
    			.setAlignment("center-bottom")
    			.setPadding(0,0,0,0)
    			.setTranslation(width*0.135+(i-8)*width*0.1475, height)
    			.setFontSize(13, 1));
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButton,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setAlignment("right-center")
    				.setTranslation(width*0.975, height*0.09+(6-(i-14))*height*0.11)
    				.setFontSize(12.5, 1));
		}

		# boxes for outer menu items
		#
		me.menuButtonBox = [nil];
    	for(var i = 1; i <= 7; i+=1) {
			append(me.menuButtonBox,
				me.menuFastRoot.createChild("path")
    				.moveTo(width*0.025-3.125, height*0.09+(i-1)*height*0.11-6.25*4)
    				.horiz(6.25*2)
    				.vert(6.25*8)
    				.horiz(-6.25*2)
    				.vert(-6.25*8)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButtonBox, me.menuMainRoot.createChild("path")
					.moveTo(width*0.135+((i-8)*width*0.1475)-6.25*3, height)
    				.horiz(6.25*6)
    				.vert(-6.25*2)
    				.horiz(-6.25*6)
    				.vert(6.25*2)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButtonBox,
				me.menuFastRoot.createChild("path")
					.moveTo(width*0.975+3.125, height*0.09+(6-(i-14))*height*0.11-6.25*4)
    				.horiz(-6.25*2)
    				.vert(6.25*8)
    				.horiz(6.25*2)
    				.vert(-6.25*8)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}

		# text for inner menu items
		#
		me.menuButtonSub = [nil];
		for(var i = 1; i <= 7; i+=1) {
			append(me.menuButtonSub,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setColorFill(rGrey,gGrey,bGrey, a)
    				.setAlignment("left-center")
    				.setTranslation(width*0.060, height*0.09+(i-1)*height*0.11)
    				.setFontSize(12.5, 1));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButtonSub, nil);
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButtonSub,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setColorFill(rGrey,gGrey,bGrey, a)
    				.setAlignment("right-center")
    				.setTranslation(width*0.940, height*0.09+(6-(i-14))*height*0.11)
    				.setFontSize(12.5, 1));
		}

		# boxes for inner menu items
		#
		me.menuButtonSubBox = [nil];
    	for(var i = 1; i <= 7; i+=1) {
			append(me.menuButtonSubBox,
				me.menuFastRoot.createChild("path")
    				.moveTo(width*0.060-3.125, height*0.09+(i-1)*height*0.11-6.25*4)
    				.horiz(6.25*2)
    				.vert(6.25*8)
    				.horiz(-6.25*2)
    				.vert(-6.25*8)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButtonSubBox, nil);
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButtonSubBox,
				me.menuFastRoot.createChild("path")
					.moveTo(width*0.940+3.125, height*0.09+(6-(i-14))*height*0.11-6.25*4)
    				.horiz(-6.25*2)
    				.vert(6.25*8)
    				.horiz(6.25*2)
    				.vert(-6.25*8)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}

		var fpi_min = 3;
		var fpi_med = 6;
		var fpi_max = 9;

		me.fpi = me.rootRealCenter.createChild("path")
		      .moveTo(texel_per_degree*fpi_max, -w*2)
		      .lineTo(texel_per_degree*fpi_min, -w*2)
		      .moveTo(texel_per_degree*fpi_max,  w*2)
		      .lineTo(texel_per_degree*fpi_min,  w*2)
		      .moveTo(texel_per_degree*fpi_max, 0)
		      .lineTo(texel_per_degree*fpi_min, 0)
		      .arcSmallCCW(texel_per_degree*fpi_min, texel_per_degree*fpi_min, 0, -texel_per_degree*fpi_med, 0)
		      .arcSmallCCW(texel_per_degree*fpi_min, texel_per_degree*fpi_min, 0,  texel_per_degree*fpi_med, 0)
		      .close()
		      .moveTo(-texel_per_degree*fpi_min, -w*2)
		      .lineTo(-texel_per_degree*fpi_max, -w*2)
		      .moveTo(-texel_per_degree*fpi_min,  w*2)
		      .lineTo(-texel_per_degree*fpi_max,  w*2)
		      .moveTo(-texel_per_degree*fpi_min,  0)
		      .lineTo(-texel_per_degree*fpi_max,  0)
		      #tail
		      .moveTo(-w*1, -texel_per_degree*fpi_min)
		      .lineTo(-w*1, -texel_per_degree*fpi_med)
		      .moveTo(w*1, -texel_per_degree*fpi_min)
		      .lineTo(w*1, -texel_per_degree*fpi_med)
		      .setStrokeLineWidth(w)
		      .setColor(rGB,gGB,bGB, a);

		
		me.horizon_group = me.rootRealCenter.createChild("group");
		me.horz_rot = me.horizon_group.createTransform();
		me.horizon_group2 = me.horizon_group.createChild("group");
		me.horizon_line = me.horizon_group2.createChild("path")
		                     .moveTo(-height*0.75, 0)
		                     .horiz(height*1.5)
		                     .setStrokeLineWidth(w)
		                     .setColor(rGB,gGB,bGB, a);
		me.horizon_alt = me.horizon_group2.createChild("text")
				.setText("????")
				.setFontSize((25/512)*width, 1.0)
		        .setAlignment("center-bottom")
		        .setTranslation(-width*1/3, -w*4)
		        .setColor(rGB,gGB,bGB, a);

		# ground
		me.ground_grp = me.rootRealCenter.createChild("group");
		me.ground2_grp = me.ground_grp.createChild("group");
		me.ground_grp_trans = me.ground2_grp.createTransform();
		me.groundCurve = me.ground2_grp.createChild("path")
				.moveTo(0,0)
				.lineTo( -30*texel_per_degree, 7.5*texel_per_degree)
				.moveTo(0,0)
				.lineTo(  30*texel_per_degree, 7.5*texel_per_degree)
				.moveTo( -30*texel_per_degree, 7.5*texel_per_degree)
				.lineTo( -60*texel_per_degree, 30*texel_per_degree)
				.moveTo(  30*texel_per_degree, 7.5*texel_per_degree)
				.lineTo(  60*texel_per_degree, 30*texel_per_degree)
				.setStrokeLineWidth(w)
		        .setColor(rGB,gGB,bGB, a);

		    # Collision warning arrow
		me.arr_15  = 5*0.75;
		me.arr_30  = 5*1.5;
		me.arr_90  = 3*9;
		me.arr_120 = 3*12;

		me.arrow_group = me.rootRealCenter.createChild("group");  
		me.arrow_trans = me.arrow_group.createTransform();
		me.arrow =
		      me.arrow_group.createChild("path")
		      .setColor(rRed,gRed,bRed, a)
		      .setColorFill(rRed,gRed,bRed, a)
		      .moveTo(-me.arr_15*MM2TEX,  me.arr_90*MM2TEX)
		      .lineTo(-me.arr_15*MM2TEX, -me.arr_90*MM2TEX)
		      .lineTo(-me.arr_30*MM2TEX, -me.arr_90*MM2TEX)
		      .lineTo(  0,                         -me.arr_120*MM2TEX)
		      .lineTo( me.arr_30*MM2TEX, -me.arr_90*MM2TEX)
		      .lineTo( me.arr_15*MM2TEX, -me.arr_90*MM2TEX)
		      .lineTo( me.arr_15*MM2TEX,  me.arr_90*MM2TEX)
		      .setStrokeLineWidth(w);

		me.textTime = root.createChild("text")
    		.setText("h:min:s")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-top")
    		.setTranslation(width, 4)
    		.set("z-index", 7)
    		.setFontSize(13, 1);
	},

	new: func {
	  	var ti = { parents: [TI] };
	  	ti.input = {
			alt_ft:               "instrumentation/altimeter/indicated-altitude-ft",
			APLockAlt:            "autopilot/locks/altitude",
			APTgtAgl:             "autopilot/settings/target-agl-ft",
			APTgtAlt:             "autopilot/settings/target-altitude-ft",
			heading:              "instrumentation/heading-indicator/indicated-heading-deg",
			hydrPressure:         "fdm/jsbsim/systems/hydraulics/system1/pressure",
			rad_alt:              "position/altitude-agl-ft",
			radarEnabled:         "ja37/hud/tracks-enabled",
			radarRange:           "instrumentation/radar/range",
			radarScreenVoltage:   "systems/electrical/outputs/dc-voltage",
			radarServ:            "instrumentation/radar/serviceable",
			radarVoltage:         "systems/electrical/outputs/ac-main-voltage",
			rmActive:             "autopilot/route-manager/active",
			rmDist:               "autopilot/route-manager/wp/dist",
			rmId:                 "autopilot/route-manager/wp/id",
			rmTrueBearing:        "autopilot/route-manager/wp/true-bearing-deg",
			RMCurrWaypoint:       "autopilot/route-manager/current-wp",
			roll:                 "instrumentation/attitude-indicator/indicated-roll-deg",
			screenEnabled:        "ja37/radar/enabled",
			timeElapsed:          "sim/time/elapsed-sec",
			viewNumber:           "sim/current-view/view-number",
			headTrue:             "orientation/heading-deg",
			headMagn:             "orientation/heading-magnetic-deg",
			twoHz:                "ja37/blink/two-Hz/state",
			station:          	  "controls/armament/station-select",
			roll:             	  "orientation/roll-deg",
			units:                "ja37/hud/units-metric",
			callsign:             "ja37/hud/callsign",
			hdgReal:              "orientation/heading-deg",
			tracks_enabled:   	  "ja37/hud/tracks-enabled",
			radar_serv:       	  "instrumentation/radar/serviceable",
			tenHz:            	  "ja37/blink/ten-Hz/state",
			qfeActive:        	  "ja37/displays/qfe-active",
	        qfeShown:		  	  "ja37/displays/qfe-shown",
	        station:          	  "controls/armament/station-select",
	        currentMode:          "ja37/hud/current-mode",
	        ctrlRadar:        	  "controls/altimeter-radar",
	        acInstrVolt:      	  "systems/electrical/outputs/ac-instr-voltage",
	        nav0InRange:      	  "instrumentation/nav[0]/in-range",
	        fullMenus:            "ja37/displays/show-full-menus",
      	};
   
      	foreach(var name; keys(ti.input)) {
        	ti.input[name] = props.globals.getNode(ti.input[name], 1);
      	}

      	ti.setupCanvasSymbols();
      	ti.setupMap();

      	ti.lastRRT = 0;
		ti.lastRR  = 0;
		ti.lastZ   = 0;


		ti.brightness = 1;

		ti.menuShowMain = FALSE;
		ti.menuShowFast = FALSE;
		ti.menuMain     = 9;
		ti.menuTrap     = TRUE;
		ti.menuSvy      = FALSE;
		ti.menuGPS      = FALSE;

		ti.trapFire     = FALSE;

		ti.upText = FALSE;
		ti.logPage = 0;
		ti.off = FALSE;
		ti.showFullMenus = TRUE;
		ti.displayFlight = FLIGHTDATA_OFF;
		ti.displayTime = FALSE;
		ti.ownPosition = 0.25;
		ti.mapPlaces = CLEANMAP;

      	return ti;
	},

	########################################################################################################
	########################################################################################################
	#
	#  begin main loops
	#
	#
	########################################################################################################
	########################################################################################################
	loop: func {
		#if ( gone == TRUE) {
		#	return;
		#}
		if (bright > 0) {
			bright -= 1;
			me.brightness -= 0.25;
			if (me.brightness < 0.25) {
				me.brightness = 1;
			}
		}
		if (me.input.acInstrVolt.getValue() < 100 or me.off == TRUE) {
			setprop("ja37/avionics/brightness-ti", 0);
			#setprop("ja37/avionics/cursor-on", FALSE);
			settimer(func me.loop(), 0.25);
			return;
		} else {
			setprop("ja37/avionics/brightness-ti", me.brightness);
			#setprop("ja37/avionics/cursor-on", cursorOn);
		}
		me.interoperability = me.input.units.getValue();

		me.updateMap();
		M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));
		me.showSelfVector();
		me.displayRadarTracks();
		me.showRunway();
		me.showRadarLimit();
		me.showBottomText();
		me.menuUpdate();
		me.showTime();

		settimer(func me.loop(), 0.5);
	},

	loopFast: func {
		if (me.input.acInstrVolt.getValue() < 100 or me.off == TRUE) {
			settimer(func me.loopFast(), 0.05);
			return;
		} else {
		}
		me.updateFlightData();

		settimer(func me.loopFast(), 0.05);
	},

	########################################################################################################
	########################################################################################################
	#
	#  menu display
	#
	#
	########################################################################################################
	########################################################################################################

	menuUpdate: func {
		me.showFullMenus = me.input.fullMenus.getValue();
		if (me.menuShowMain == TRUE) {
			me.menuShowFast = TRUE;#figure this out better
			me.menuMainRoot.show();
			me.updateMainMenu();
			me.upText = TRUE;
		} elsif (me.menuShowMain == FALSE and me.menuMain == 8) {
			me.menuShowFast = TRUE;#figure this out better
			me.menuMainRoot.show();
			me.updateMainMenu();
			me.upText = TRUE;
		} else {
			me.menuMainRoot.hide();
			me.upText = FALSE;
		}
		if (me.menuShowFast == TRUE) {
			me.menuFastRoot.show();
			me.updateFastMenu();
			me.updateFastSubMenu();
		} else {
			me.menuFastRoot.hide();
		}
		if (me.menuMain == 9) {
			if (me.trapFire == TRUE){
				me.hideMap();
				me.logRoot.show();
				var str = armament.fireLog;
				me.errorList.setText(str);
				me.logRoot.setTranslation(0,  -(height-height*0.025*me.upText)*me.logPage);
				me.clip2 = 0~"px, "~width~"px, "~(height-height*0.025*me.upText)~"px, "~0~"px";
				me.logRoot.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
			} else{
				me.showMap();
			}
		} elsif (me.menuMain == 12) {
			# failure menu
			me.hideMap();
			me.logRoot.show();
			call(func {
				var buffer = FailureMgr.get_log_buffer();
				var str = "";
    			foreach(entry; buffer) {
      				str = str~entry.time~" "~entry.message~"\n";
    			}
				me.errorList.setText(str)});
			me.logRoot.setTranslation(0,  -(height-height*0.025*me.upText)*me.logPage);
			me.clip2 = 0~"px, "~width~"px, "~(height-height*0.025*me.upText)~"px, "~0~"px";
			me.logRoot.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		} else {
			me.showMap();
		}
	},

	showMap: func {
		me.logPage = 0;
		me.mapCentrum.show();
		me.rootCenter.show();
		me.logRoot.hide();
		me.bottom_text_grp.show();
	},

	hideMap: func {
		me.mapCentrum.hide();
		me.rootCenter.hide();
		me.bottom_text_grp.hide();
	},

	updateMainMenu: func {
		for(var i = 8; i <= 13; i+=1) {
			me.menuButton[i].setText(me.compileMainMenu(i));
			if (me.menuMain == 8) {
				me.updateMainMenuTextWeapons(i);
			} else {
				if (me.menuMain == i) {
					me.menuButtonBox[i].show();
				} else {
					me.menuButtonBox[i].hide();
				}
			}
		}
		if (me.menuMain == 8) {
			if (me.input.station.getValue() == 5) {
				me.menuButtonBox[8].show();
			} else {
				me.menuButtonBox[8].hide();
			}
			if (me.input.station.getValue() == 1) {
				me.menuButtonBox[9].show();
			} else {
				me.menuButtonBox[9].hide();
			}
			if (me.input.station.getValue() == 2) {
				me.menuButtonBox[10].show();
			} else {
				me.menuButtonBox[10].hide();
			}
			if (me.input.station.getValue() == 4) {
				me.menuButtonBox[11].show();
			} else {
				me.menuButtonBox[11].hide();
			}
			if (me.input.station.getValue() == 3) {
				me.menuButtonBox[12].show();
			} else {
				me.menuButtonBox[12].hide();
			}
			if (me.input.station.getValue() == 6) {
				me.menuButtonBox[13].show();
			} else {
				me.menuButtonBox[13].hide();
			}
		}
	},

	updateMainMenuTextWeapons: func (position) {
		var pyl = 0;
		if (position == 8) {
			pyl = 5;
		} elsif (position == 9) {
			pyl = 1;
		} elsif (position == 10) {
			pyl = 2;
		} elsif (position == 11) {
			pyl = 4;
		} elsif (position == 12) {
			pyl = 3;
		} elsif (position == 13) {
			pyl = 6;
		}
		me.pylon = displays.common.armNamePylon(pyl);
		if (me.pylon != nil) {
			me.menuButton[position].setText(me.pylon);
		}
	},

	compileMainMenu: func (button) {
		var str = nil;
		if (me.interoperability == displays.METRIC) {
			str = dictSE[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":''~me.menuMain)];
		} else {
			str = dictEN[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":''~me.menuMain)];
		}
		if (str != nil) {
			str = str[''~button];
			if (str != nil and (me.showFullMenus == TRUE or str[0] == TRUE)) {
				return str[1];
			}
		}
		return "";
	},

	updateFastMenu: func {
		for(var i = 1; i <= 7; i+=1) {
			me.menuButton[i].setText(me.compileFastMenu(i));
			me.menuButtonBox[i].hide();
		}
		for(var i = 14; i <= 20; i+=1) {
			me.menuButton[i].setText(me.compileFastMenu(i));
			me.menuButtonBox[i].hide();
		}
		if (me.menuMain == 8 and me.input.station.getValue() == 0) {
			me.menuButtonBox[14].show();
		}
		if (me.menuMain == 10 and me.displayTime == TRUE) {
			me.menuButtonBox[16].show();
		}
		if (me.menuMain == 10 and me.mapPlaces == TRUE) {
			me.menuButtonBox[4].show();
		}
	},

	compileFastMenu: func (button) {
		var str = nil;
		if (me.interoperability == displays.METRIC) {
			str = dictSE[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":''~me.menuMain)];
		} else {
			str = dictEN[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":''~me.menuMain)];
		}
		if (str != nil) {
			str = str[''~button];
			if (str != nil and (me.showFullMenus == TRUE or str[0] == TRUE)) {
				return me.vertStr(str[1]);
			}
		}
		return "";
	},

	vertStr: func (str) {
		var compiled = "";
		for(var i = 0; i < size(str); i+=1) {
			compiled = compiled ~substr(str,i,1)~(i==(size(str)-1)?"":"\n");
		}
		return compiled;
	},

	updateFastSubMenu: func {
		for(var i = 1; i <= 7; i+=1) {
			me.menuButtonSub[i].hide();
			me.menuButtonSubBox[i].hide();
		}
		for(var i = 14; i <= 20; i+=1) {
			me.menuButtonSub[i].hide();
			me.menuButtonSubBox[i].hide();
		}
		me.menuButtonSub[7].show();
		me.menuButtonSubBox[7].show();
		var seven = nil;
		if (me.interoperability == displays.METRIC) {
			seven = me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(dictSE['0'][''~me.menuMain][1]));
		} else {
			seven = me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(dictEN['0'][''~me.menuMain][1]));
		}
		me.menuButtonSub[7].setText(me.vertStr(seven));
		if (me.menuMain == 10) {
			#show flight data
			me.menuButtonSub[17].show();
			me.menuButtonSubBox[17].show();
			var seventeen = nil;
			if (me.interoperability == displays.METRIC) {
				seventeen = dictSE['HORI'][''~me.displayFlight][1];
			} else {
				seventeen = dictEN['HORI'][''~me.displayFlight][1];
			}
			me.menuButtonSub[17].setText(me.vertStr(seventeen));
			# zoom level
			me.menuButtonSub[6].show();
			me.menuButtonSubBox[6].show();
			var six = zoomLevels[zoom_curr]~"";
			me.menuButtonSub[6].setText(me.vertStr(six));
		}
	},

	menuNoSub: func {
		me.menuTrap = FALSE;
		me.menuSvy  = FALSE;
		me.menuGPS  = FALSE;
		me.trapFire = FALSE;
	},

	########################################################################################################
	########################################################################################################
	#
	#  misc overlays
	#
	#
	########################################################################################################
	########################################################################################################

	showTime: func {
		if (me.displayTime == TRUE) {
			me.textTime.setText(getprop("sim/time/gmt-string")~" Z");# should really be local time
			me.textTime.show();
		} else {
			me.textTime.hide();
		}
	},

	updateFlightData: func {
		me.fData = FALSE;
		if (getprop("ja37/sound/terrain-on") == TRUE) {
			me.fData = TRUE;
#			if (me.menuMain == 12 or (me.menuTrap == TRUE and me.trapFire == TRUE)) {
#				me.menuShowMain = FALSE;
#				me.menuShowFast = FALSE;
#				me.menuNoSub();
#				me.menuTrap = TRUE;
#				me.menuMain = 9;
#			}
		} elsif (me.displayFlight == FLIGHTDATA_ON) {
			me.fData = TRUE;
		} elsif (me.displayFlight == FLIGHTDATA_CLR and (me.input.alt_ft.getValue()*FT2M < 1000 or getprop("orientation/pitch-deg") > 10 or math.abs(getprop("orientation/roll-deg")) > 45)) {
			me.fData = TRUE;
		}
		if (me.fData == TRUE) {
			me.displayFPI();
			me.displayHorizon();
			me.displayGround();
			me.displayGroundCollisionArrow();
		} else {
			me.fpi.hide();
			me.horizon_group2.hide();
			me.ground_grp.hide();
			me.arrow.hide();
		}
	},

	displayFPI: func {
		me.fpi_x_deg = getprop("ja37/displays/fpi-horz-deg");
		me.fpi_y_deg = getprop("ja37/displays/fpi-vert-deg");
		if (me.fpi_x_deg == nil) {
			me.fpi_x_deg = 0;
			me.fpi_y_deg = 0;
		}
		me.fpi_x = me.fpi_x_deg*texel_per_degree;
		me.fpi_y = me.fpi_y_deg*texel_per_degree;
		me.fpi.setTranslation(me.fpi_x, me.fpi_y);
		me.fpi.show();
	},

	displayHorizon: func {
		me.rot = -getprop("orientation/roll-deg") * D2R;
		me.horz_rot.setRotation(me.rot);
		me.horizon_group2.setTranslation(0, texel_per_degree * getprop("orientation/pitch-deg"));
		me.alt = getprop("instrumentation/altimeter/indicated-altitude-ft");
		if (me.alt != nil) {
			me.text = "";
			if (me.interoperability == displays.METRIC) {
				if(me.alt*FT2M < 1000) {
					me.text = ""~roundabout(me.alt*FT2M/10)*10;
				} else {
					me.text = sprintf("%.1f", me.alt*FT2M/1000);
				}
			} else {
				if(me.alt < 1000) {
					me.text = ""~roundabout(me.alt/10)*10;
				} else {
					me.text = sprintf("%.1f", me.alt/1000);
				}
			}
			me.horizon_alt.setText(me.text);
		} else {
			me.horizon_alt.setText("");
		}
		me.horizon_group2.show();
	},

	displayGroundCollisionArrow: func () {
	    if (getprop("/instrumentation/terrain-warning") == TRUE) {
	      me.arrow_trans.setRotation(-getprop("orientation/roll-deg") * D2R);
	      me.arrow.show();
	    } else {
	      me.arrow.hide();
	    }
	},

	displayGround: func () {
		me.time = getprop("fdm/jsbsim/gear/unit[0]/WOW") == TRUE?0:getprop("fdm/jsbsim/systems/indicators/time-till-crash");
		if (me.time != nil and me.time >= 0 and me.time < 40) {
			me.timeC = clamp(me.time - 10,0,30);
			me.dist = (me.timeC/30) * (height/2);
			me.ground_grp.setTranslation(me.fpi_x, me.fpi_y);
			me.ground_grp_trans.setRotation(-getprop("orientation/roll-deg") * D2R);
			me.groundCurve.setTranslation(0, me.dist);
			if (me.time < 10 and me.time != 0) {
				me.groundCurve.setColor(rRed,gRed,bRed, a);
			} else {
				me.groundCurve.setColor(rGB,gGB,bGB, a);
			}
			me.ground_grp.show();
		} else {
			me.ground_grp.hide();
		}
	},

	showBottomText: func {
		#clip is in canvas coordinates
		me.clip2 = 0~"px, "~width~"px, "~(height-height*0.1-height*0.025*me.upText)~"px, "~0~"px";
		me.rootCenter.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		me.mapCentrum.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		me.bottom_text_grp.setTranslation(0,-height*0.025*me.upText);
		me.textBArmType.setText(displays.common.currArmNameSh);
		me.ammo = armament.ammoCount(me.input.station.getValue());
	    if (me.ammo == -1) {
	    	me.ammoT = "  ";
	    } else {
	    	me.ammoT = me.ammo~"";
	    }
		me.textBArmAmmo.setText(me.ammoT);
		if (me.interoperability == displays.METRIC) {
			if (displays.common.currArmNameSh == "70") {
				me.textBTactType1.setText("A");
				me.textBTactType2.setText("T");
				me.textBTactType3.setText("T");
			} else {
				me.textBTactType1.setText("J");
				me.textBTactType2.setText("K");
				me.textBTactType3.setText("T");
			}
		} else {
			if (displays.common.currArmNameSh == "70") {
				me.textBTactType1.setText("A");
				me.textBTactType2.setText("T");
				me.textBTactType3.setText("T");
			} else {
				me.textBTactType1.setText("F");
				me.textBTactType2.setText("G");
				me.textBTactType3.setText("T");
			}
		}
		me.icao = land.icao~((me.input.nav0InRange.getValue() == TRUE)?" T":"  ");
		me.textBBase.setText(me.icao);
		
		me.mode = "";
		# DL: data link
		# RR: radar
		if (land.mode < 3 and land.mode > 0) {
			me.mode = "LB";# landing waypoint
		} elsif (land.mode > 2) {
			me.mode = "LF";# landing touchdown point
		} elsif (me.input.currentMode.getValue() == displays.LANDING) {
			me.mode = "L ";# landing
		} else {
			me.mode = "  ";# 
		}
		me.textBMode.setText(me.mode);

		if (displays.common.distance_m != -1) {
			if (me.interoperability == displays.METRIC) {
				me.distance_un = displays.common.distance_m/1000;
				me.textBDistN.setText("A");
			} else {
				me.distance_un = displays.common.distance_m*M2NM;
				me.textBDistN.setText("NM");
			}
			if (me.distance_un < 10) {
				me.textBDist.setText(sprintf("%.1f", me.distance_un));
			} else {
				me.textBDist.setText(sprintf("%d", me.distance_un));
			}
		} else {
			me.textBDist.setText("  ");
			me.textBDistN.setText(" ");
		}
		if (me.input.currentMode.getValue() == displays.LANDING) {
			me.alphaT  = me.interoperability == displays.METRIC?"ALFA":"ALPH";
			me.weightT = me.interoperability == displays.METRIC?"VIKT":"WEIG";
			if (me.interoperability == displays.METRIC) {
				me.weight = getprop("fdm/jsbsim/inertia/weight-lbs")*0.453592*0.001;
			} else {
				me.weight = getprop("fdm/jsbsim/inertia/weight-lbs")*0.001;
			}
			var weight = getprop("fdm/jsbsim/inertia/weight-lbs");
			me.alpha   = 9 + ((weight - 28000) / (38000 - 28000)) * (12 - 9);
			me.weightT = me.weightT~sprintf(" %.1f", me.weight);
			me.alphaT  = me.alphaT~sprintf(" %.1f", me.alpha);
			me.textBWeight.setText(me.weightT);
			me.textBAlpha.setText(me.alphaT);
		} elsif (me.input.currentMode.getValue() == displays.COMBAT) {
			if (radar_logic.selection != nil) {
				me.textBWeight.setText(radar_logic.selection.get_Callsign());
				me.textBAlpha.setText(radar_logic.selection.get_model());
			} else {
				me.textBWeight.setText("");
				me.textBAlpha.setText("");
			}
		} else {
			me.textBWeight.setText("");
			me.textBAlpha.setText("");
		}
		if (displays.common.error == FALSE) {
			me.textBerror.setColor(rGrey, gGrey, bGrey, a);
			me.textBerrorFrame2.hide();
			me.textBerrorFrame1.show();
		} else {
			me.textBerror.setColor(rBlack, gBlack, bBlack, a);
			me.textBerrorFrame1.hide();
			me.textBerrorFrame2.show();
		}
	},

	showRadarLimit: func {
		if (me.input.currentMode.getValue() == canvas_HUD.COMBAT and me.input.tracks_enabled.getValue() == TRUE) {
			if (me.lastZ != zoom_curr or me.lastRR != me.input.radarRange.getValue() or me.input.timeElapsed.getValue() - me.lastRRT > 1600) {
				me.radar_limit_grp.removeAllChildren();
				var rdrField = 61.5*D2R;
				var radius = M2TEX*me.input.radarRange.getValue();
				var (leftX, leftY)   = (-math.sin(rdrField)*radius, -math.cos(rdrField)*radius);
				me.radarLimit = me.radar_limit_grp.createChild("path")
					.moveTo(leftX, leftY)
					.arcSmallCW(radius, radius, 0, -leftX*2, 0)
					.moveTo(leftX, leftY)
					.lineTo(leftX*0.75, leftY*0.75)
					.moveTo(-leftX, leftY)
					.lineTo(-leftX*0.75, leftY*0.75)
					.setColor(rTyrk,gTyrk,bTyrk, a)
			    	.setStrokeLineWidth(w);
			    me.lastRRT = me.input.timeElapsed.getValue();
			    me.lastRR  = me.input.radarRange.getValue();
			    me.lastZ  = zoom_curr;
			}
			me.radar_limit_grp.show();
	    } else {
	    	me.radar_limit_grp.hide();
	    }
	},

	showRunway: func {
		if (land.show_waypoint_circle == TRUE or land.show_runway_line == TRUE) {
		  me.x = math.cos(-(land.runway_bug-90) * D2R) * land.runway_dist*NM2M*M2TEX;
		  me.y = math.sin(-(land.runway_bug-90) * D2R) * land.runway_dist*NM2M*M2TEX;

		  me.dest.setTranslation(me.x, -me.y);		  

		  if (land.show_waypoint_circle == TRUE) {
		  	  #me.scale = clamp(2000*M2TEX/100, 25/100, 50);
		      #me.dest_circle.setStrokeLineWidth(w/me.scale);
		      #me.dest_circle.setScale(me.scale);
		      me.dest_circle.show();
		  } else {
		      me.dest_circle.hide();
		  }

		  if (land.show_runway_line == TRUE) {
		    # 10 20 20 40 Km long line, depending on radar setting, as per AJ manual.
		    me.runway_l = land.line*1000;
		#        if (me.radarRange == 120000 or me.radarRange == 180000) {
		#          me.runway_l = 40000;
		#        } elsif (me.radarRange == 60000) {
		#          me.runway_l = 20000;
		#        } elsif (me.radarRange == 30000) {
		#          me.runway_l = 20000;
		#        }
		    me.scale = me.runway_l*M2TEX;
		    me.dest_runway.setScale(1, me.scale);
		    me.heading = me.input.heading.getValue();#true
		    me.dest.setRotation((180+land.head-me.heading)*D2R);
		    me.dest_runway.show();
		    if (land.show_approach_circle == TRUE) {
		      me.scale = 4100*M2TEX/100;
		      me.approach_circle.setStrokeLineWidth(w/me.scale);
		      me.approach_circle.setScale(me.scale);
		      me.acir = radar_logic.ContactGPS.new("circle", land.approach_circle);
		      me.distance = me.acir.get_polar()[0];
		      me.xa_rad   = me.acir.get_polar()[1];
		      me.pixelDistance = -me.distance*M2TEX; #distance in pixels
		      #translate from polar coords to cartesian coords
		      me.pixelX =  me.pixelDistance * math.cos(me.xa_rad + math.pi/2);
		      me.pixelY =  me.pixelDistance * math.sin(me.xa_rad + math.pi/2);
		      me.approach_circle.setTranslation(me.pixelX, me.pixelY);
		      me.approach_circle.show();
		    } else {
		      me.approach_circle.hide();#pitch.......1x.......................................................
		    }            
		  } else {
		    me.dest_runway.hide();
		    me.approach_circle.hide();
		  }
		  me.dest.show();
		} else {
		me.dest_circle.hide();
		me.dest_runway.hide();
		me.approach_circle.hide();
		}
	},

	displayRadarTracks: func () {

	  	var mode = canvas_HUD.mode;
		me.threatIndex = -1;
		me.missileIndex = -1;
	    me.track_index = 1;
	    me.isGPS = FALSE;
	    me.selection_updated = FALSE;
	    me.tgt_dist = 1000000;
	    me.tgt_callsign = "";

	    if(me.input.tracks_enabled.getValue() == 1 and me.input.radar_serv.getValue() > 0) {
			me.radar_group.show();

			me.selection = radar_logic.selection;

			if (me.selection != nil and me.selection.parents[0] == radar_logic.ContactGPS) {
		        me.displayRadarTrack(me.selection);
		    }

			# do yellow triangles here
			foreach(hud_pos; radar_logic.tracks) {
				me.displayRadarTrack(hud_pos);
			}
			if(me.track_index != -1) {
				#hide the the rest unused echoes
				for(var i = me.track_index; i < maxTracks ; i+=1) {
			  		me.echoesAircraft[i].hide();
				}
			}
			if(me.threatIndex < maxThreats-1) {
				#hide the the rest unused threats
				for(var i = me.threatIndex; i < maxThreats-1 ; i+=1) {
			  		me.threats[i+1].hide();
				}
			}
			if(me.missileIndex < maxMissiles-1) {
				#hide the the rest unused missiles
				for(var i = me.missileIndex; i < maxMissiles-1 ; i+=1) {
			  		me.missiles[i+1].hide();
				}
			}
			if(me.selection_updated == FALSE) {
				me.echoesAircraft[0].hide();
			}
			if (me.isGPS == FALSE) {
				me.gpsSymbol.hide();
		    }
	    } else {
	      	# radar tracks not shown at all
	      	me.radar_group.hide();
	    }
	},

	displayRadarTrack: func (contact) {
		me.texelDistance = contact.get_polar()[0]*M2TEX;
		me.angle         = contact.get_polar()[1];
		me.pos_xx		 = -me.texelDistance * math.cos(me.angle + math.pi/2);
		me.pos_yy		 = -me.texelDistance * math.sin(me.angle + math.pi/2);

		me.showmeT = TRUE;

		me.currentIndexT = me.track_index;

		me.ordn = contact.get_type() == radar_logic.ORDNANCE;

		if(contact == radar_logic.selection and contact.get_cartesian()[0] != 900000) {
			me.selection_updated = TRUE;
			me.currentIndexT = 0;
		}

		if(me.currentIndexT > -1 and (me.showmeT == TRUE or me.currentIndexT == 0)) {
			me.tgtHeading = contact.get_heading();
		    me.tgtSpeed = contact.get_Speed();
		    me.myHeading = me.input.hdgReal.getValue();
		    if (me.currentIndexT == 0 and contact.parents[0] == radar_logic.ContactGPS) {
		    	me.gpsSymbol.setTranslation(me.pos_xx, me.pos_yy);
		    	me.gpsSymbol.show();
		    	me.isGPS = TRUE;
		    	me.echoesAircraft[me.currentIndexT].hide();
		    } elsif (me.ordn == FALSE) {
		    	me.echoesAircraft[me.currentIndexT].setTranslation(me.pos_xx, me.pos_yy);
			    if (me.tgtHeading != nil) {
			        me.relHeading = me.tgtHeading - me.myHeading;
			        #me.relHeading -= 180;
			        me.echoesAircraft[me.currentIndexT].setRotation(me.relHeading * D2R);
			    }
			    if (me.tgtSpeed != nil) {
			    	me.echoesAircraftVector[me.currentIndexT].setScale(1, clamp((me.tgtSpeed/60)*NM2M*M2TEX, 1, 750*MM2TEX));
		    	} else {
		    		me.echoesAircraftVector[me.currentIndexT].setScale(1, 1);
		    	}
				me.echoesAircraft[me.currentIndexT].show();
				me.echoesAircraft[me.currentIndexT].update();
			} else {
				if (me.missileIndex < maxMissiles-1) {
					me.missileIndex += 1;
					me.missiles[me.missileIndex].setTranslation(me.pos_xx, me.pos_yy);					
					if (me.tgtHeading != nil) {
				        me.relHeading = me.tgtHeading - me.myHeading;
				        #me.relHeading -= 180;
				        me.missiles[me.missileIndex].setRotation(me.relHeading * D2R);
				    }
				    if (me.tgtSpeed != nil) {
				    	me.missilesVector[me.missileIndex].setScale(1, clamp((me.tgtSpeed/60)*NM2M*M2TEX, 1, 750*MM2TEX));
			    	} else {
			    		me.missilesVector[me.missileIndex].setScale(1, 1);
			    	}
			    	me.missiles[me.missileIndex].show();
			    	me.missiles[me.missileIndex].update();
			    }
				me.echoesAircraft[me.currentIndexT].hide();
			}
			if(me.currentIndexT != 0) {
				me.track_index += 1;
				if (me.track_index == maxTracks) {
					me.track_index = -1;
				}
			}
			if (contact.get_model() == "missile_frigate" and me.threatIndex < maxThreats-1) {
				me.threatIndex += 1;
				me.threats[me.threatIndex].setTranslation(me.pos_xx, me.pos_yy);
				me.scale = 60*NM2M*M2TEX/100;
		      	me.threats[me.threatIndex].setStrokeLineWidth(w/me.scale);
		      	me.threats[me.threatIndex].setScale(me.scale);
				me.threats[me.threatIndex].show();
			} elsif (contact.get_model() == "buk-m2" and me.threatIndex < maxThreats-1) {
				me.threatIndex += 1;
				me.threats[me.threatIndex].setTranslation(me.pos_xx, me.pos_yy);
				me.scale = 20*NM2M*M2TEX/100;
		      	me.threats[me.threatIndex].setStrokeLineWidth(w/me.scale);
		      	me.threats[me.threatIndex].setScale(me.scale);
				me.threats[me.threatIndex].show();
			}
		}
	},

	showSelfVector: func {
		# length = time to travel in 60 seconds.
		var spd = getprop("velocities/airspeed-kt");# true airspeed so can be compared with other aircrats speed. (should really be ground speed)
		me.selfVector.setScale(1, clamp((spd/60)*NM2M*M2TEX, 1, 250*MM2TEX));
	},


	########################################################################################################
	########################################################################################################
	#
	#  buttons
	#
	#
	########################################################################################################
	########################################################################################################

	b1: func {
		if (me.off == TRUE) {
			me.off = !me.off;
			MI.mi.off = me.off;
		} elsif (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 9 and me.menuTrap == FALSE) {
				me.off = !me.off;
				MI.mi.off = me.off;
			}
		}
	},

	b2: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			
		}
	},

	b3: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			
			if (me.menuMain == 9 and me.menuTrap == TRUE) {
				# tact fire report
				me.trapFire = TRUE;
			}
		}
	},

	b4: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 10) {
				# place names on map
				me.mapPlaces = !me.mapPlaces;
				if (me.mapPlaces == PLACES) {
					type = "light_all";
					makePath = string.compileTemplate(maps_base ~ '/cartoLN/{z}/{x}/{y}.png');
				} else {
					type = "light_nolabels";
					makePath = string.compileTemplate(maps_base ~ '/cartoL/{z}/{x}/{y}.png');
				}
			}
		}
	},

	b5: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 13 and me.menuSvy == FALSE) {
				# side view
				me.menuSvy = TRUE;
			}
		}
	},

	b6: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 9 and me.menuTrap == FALSE) {
				# tactical report
				me.menuTrap = TRUE;
			}
			if (me.menuMain == 10) {
				# change zoom
				zoomIn();
			}
		}
	},

	b7: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			me.menuShowMain = FALSE;
			me.menuShowFast = FALSE;
			me.menuNoSub();
			me.menuTrap = TRUE;
			me.menuMain = 9;
		}
	},

	b8: func {
		# weapons
		if (me.menuShowMain == TRUE) {
			me.menuMain = 8;
			me.menuShowMain = FALSE;
			me.menuNoSub();
		} else {
			if (me.menuMain == 8) {
				me.input.station.setIntValue(5);
			} else {
				me.menuShowMain = !me.menuShowMain;
			}
		}
	},

	b9: func {
		# system
		if (me.menuShowMain == TRUE) {
			me.menuMain = 9;
			me.menuNoSub();
		} else {
			if (me.menuMain == 8) {
				me.input.station.setIntValue(1);
			} else {
				me.menuShowMain = !me.menuShowMain;
			}
		}
	},

	b10: func {
		# display
		if (me.menuShowMain == TRUE) {
			me.menuMain = 10;
			me.menuNoSub();
		} else {
			if (me.menuMain == 8) {
				me.input.station.setIntValue(2);
			} else {
				me.menuShowMain = !me.menuShowMain;
			}
		}
	},

	b11: func {
		# flight data
		if (me.menuShowMain == TRUE) {
			me.menuMain = 11;
			me.menuNoSub();
		} else {
			if (me.menuMain == 8) {
				me.input.station.setIntValue(4);
			} else {
				me.menuShowMain = !me.menuShowMain;
			}
		}
	},

	b12: func {
		# errors
		if (me.menuShowMain == TRUE) {
			me.menuMain = 12;
			me.menuNoSub();
		} else {
			if (me.menuMain == 8) {
				me.input.station.setIntValue(3);
			} else {
				me.menuShowMain = !me.menuShowMain;
			}
		}
	},

	b13: func {
		# configuration
		if (me.menuShowMain == TRUE) {
			me.menuMain = 13;
			me.menuNoSub();
		} else {
			if (me.menuMain == 8) {
				me.input.station.setIntValue(6);
			} else {
				me.menuShowMain = !me.menuShowMain;
			}
		}
	},

	b14: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 8) {
				me.input.station.setIntValue(0);
			}
			if (me.menuMain == 9 and me.menuTrap == TRUE) {
				# clear tact reports
				armament.fireLog = "\n      Fire log:";
			}
			if (me.menuMain == 13 and me.menuGPS == FALSE) {
				# GPS settings
				me.menuGPS = TRUE;
			}
		}
	},

	b15: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 8) {
				#clear weapon selection
			}
		}
	},

	b16: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 10) {
				me.displayTime = !me.displayTime;
			}
		}
	},

	b17: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if(me.menuMain == 10) {
				me.displayFlight += 1;
				if (me.displayFlight == 3) {
					me.displayFlight = 0;
				}
			}
		}
	},

	b18: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
		}
	},

	b19: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if(me.menuMain == 9 and me.menuTrap == TRUE and me.trapFire == TRUE) {
				me.logPage += 1;
			}
			if(me.menuMain == 11) {
				if (me.ownPosition < 0.25) {
					me.ownPosition = 0.25;
				} elsif (me.ownPosition < 0.50) {
					me.ownPosition = 0.50;
				} elsif (me.ownPosition < 0.75) {
					me.ownPosition = 0.75;
				} elsif (me.ownPosition < 1) {
					me.ownPosition = 1;
				} elsif (me.ownPosition = 1) {
					me.ownPosition = 0;
				}
			}
			if(me.menuMain == 12) {
				me.logPage += 1;
			}			
		}
	},

	b20: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if(me.menuMain == 9 and me.menuTrap == TRUE and me.trapFire == TRUE) {
				me.logPage -= 1;
				if (me.logPage < 0) {
					me.logPage = 0;
				}
			}
			if(me.menuMain == 12) {
				me.logPage -= 1;
				if (me.logPage < 0) {
					me.logPage = 0;
				}
			}
		}
	},

	########################################################################################################
	########################################################################################################
	#
	#  map
	#
	#
	########################################################################################################
	########################################################################################################


	setupMap: func {
		for(var x = 0; x < num_tiles[0]; x += 1) {
		  	tiles[x] = setsize([], num_tiles[1]);
		  	for(var y = 0; y < num_tiles[1]; y += 1)
		    	tiles[x][y] = me.mapFinal.createChild("image", "map-tile")
		    	.set("fill", "rgb(128,128,128)");
		}
	},

	updateMap: func {
		# update the map

		
		me.rootCenter.setTranslation(width/2, height*0.875-(height*0.875)*me.ownPosition);
		me.mapCentrum.setTranslation(width/2, height*0.875-(height*0.875)*me.ownPosition);
		
		  # get current position
		  var lat = getprop('/position/latitude-deg');
		  var lon = getprop('/position/longitude-deg');

		  var n = math.pow(2, zoom);
		  var offset = [
		    n * ((lon + 180) / 360) - center_tile_offset[0],
		    (1 - math.ln(math.tan(lat * math.pi/180) + 1 / math.cos(lat * math.pi/180)) / math.pi) / 2 * n - center_tile_offset[1]
		  ];
		  var tile_index = [int(offset[0]), int(offset[1])];

		  var ox = tile_index[0] - offset[0];
		  var oy = tile_index[1] - offset[1];

		  for(var x = 0; x < num_tiles[0]; x += 1) {
		    for(var y = 0; y < num_tiles[1]; y += 1) {
		      tiles[x][y].setTranslation(int((ox + x) * tile_size + 0.5), int((oy + y) * tile_size + 0.5));
		      #tiles[x][y].update();
		    }
		  }

		  if(tile_index[0] != last_tile[0] or tile_index[1] != last_tile[1] or type != last_type )  {
		    for(var x = 0; x < num_tiles[0]; x += 1) {
		      for(var y = 0; y < num_tiles[1]; y += 1) {
		        var pos = {
		          z: zoom,
		          x: int(offset[0] + x),
		          y: int(offset[1] + y),
		          type: type
		        };

		        (func {
			        var img_path = makePath(pos);
			        var tile = tiles[x][y];

			        if( io.stat(img_path) == nil ) { # image not found, save in $FG_HOME
			          var img_url = makeUrl(pos);
			          #print('requesting ' ~ img_url);
			          http.save(img_url, img_path)
			          		.done(func(r) {
			          	  		#print('received image ' ~ img_path~" " ~ r.status ~ " " ~ r.reason);
			          	  		tile.set("src", img_path);
			          	  	});
			              #.done(func {print('received image ' ~ img_path); tile.set("src", img_path);})
			              #.fail(func (r) print('Failed to get image ' ~ img_path ~ ' ' ~ r.status ~ ': ' ~ r.reason));
			        }
			        else {# cached image found, reusing
			          #print('loading ' ~ img_path);
			          tile.set("src", img_path);
			          tile.update();
			        }
		        })();
		      }
		    }

		    last_tile = tile_index;
		    last_type = type;
		  }

		  me.mapRot.setRotation(-getprop("orientation/heading-deg")*D2R);
	},

	displayGroundCollisionArrow: func () {
	    if (getprop("/instrumentation/terrain-warning") == TRUE) {
	      me.arrow_trans.setRotation(-getprop("orientation/roll-deg") * D2R);
	      me.arrow.show();
	    } else {
	      me.arrow.hide();
	    }
	},
};

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var ti = TI.new();
ti.loop();
ti.loopFast();
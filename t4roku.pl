#!/usr/bin/perl

########################################################################
# Tools4Roku   2008/08/04    Juergen Gluch      juergen.gluch@gmx.de
#
# Provides weather information on the Roku Soundbride display when in
# stand-by mode. Tested with the M1001 model. More detail in readme.txt
# 
# Based on "rokuweather.pl" from Michael Polymenakos 2007 mpoly@panix.com
# and the "services" from Adam Peller - peller@gnu.org
#
# for Terms of Use of Yahoo weather service see at:
# http://developer.yahoo.com/weather/
#
########################################################################

use strict;
use RokuUI;

our ($rokuIP, $displaytype, $modus, $alternate, $locationid, $unitsid, @direction, %dayname);
our (%monname, %condcode, $pleasewait, $getyahoodata, $wind, $menuweather, $menuserverdown);
our ($ilikeit, $notmytaste, $nosongtorate, $itsremotestream, $menustealarm, $menusetsleep, $digitemp, $feelstring, $humistring, $minstring, $maxstring, $outstring);
our ($threshhold, $similarartists1, $similarartists2, $lookforsimartist, $searchfor);
require "t4local";

my $display = RokuUI->new(host => $rokuIP, port => 4444);

my ($msgtext, $weatherdata, $condition, $currtemp, $atmosphere);
my ($humidity, $winddata, $windspeed, $winddirection, $feeltemp, $units, $unittemp, $unitspeed);
my ($to1day, $to1date, $to1low, $to1high, $to2day, $to2date, $to2low, $to2high);
my ($tomorrow1, $tomorrow2, $myouttemp);
my $to1code = 3200;
my $to2code = 3200;
my $wcode = 3200;
my $last_fetch = 0;

for my $int ('INT','QUIT','HUP','TRAP','ABRT','STOP') { 
   $SIG{$int} = 'interrupt';
}   

my $minitimeout = 3;
my $homecnt = 0;
my $standby = 0;
my $menu = 0;

if (($displaytype != 1) and ($displaytype != 2)) {
	print "This Tools4Roku version does only work with Small VFT displays.\n";
	exit; 
};

while (1) { 
	$display->open || die("Could not connect to Roku Soundbridge Port 4444: $!");
	$homecnt = 0;
   if ($display->ison()) {
		$display->cmd("irman echo");
		do {
			my ($p, $m ) = $display->{connection}->waitfor(Match => '/irman: .*/',
																										 Timeout => $minitimeout);
			if ($m) {
				$m =~ s/^irman: //;
				if ($m eq "CK_MENU") {
					$homecnt++ ;
				} else {
					$homecnt = 0;
					# next two lines are for rating
					if ($m eq "CK_EAST") { ratesong("1") };
					if ($m eq "CK_WEST") { ratesong("0") };
					# next three lines are are similar artist selection
					if ($m eq "CK_BRIGHTNESS") {
						$display->cmd("irman dispatch CK_EXIT"); 
						$display->cmd("irman dispatch CK_EXIT"); # Why two times?
						similarartists("0")
					};
					#
				};
				if ($homecnt == 3) {
				  $display->cmd("irman intercept");
				  $display->cmd("irman dispatch CK_EXIT");
					$menu = 1;
				};
			} else {
				# its a timeout
				$homecnt=0;
			};
		} until ( ($menu == 1) or ( not $display->ison() ) );
		if ($menu == 1 ) {
			showmenu("1");
			$menu = 0;
		};
   } else { 
		showweather("0");
	};
	$display->close();
};
$display->cmd("irman off");

sub interrupt {exit(@_)};

END {
  undef $display;  
}

###### subs 

sub similarartists {
	my @artists; # Our filtered array of artists
	my ($artist, $simartistsAS); # The data we recieve from Audioscrobbler.com

   # get the current artist
   #$display->clear();
	if ($displaytype == 1) {
		$display->msg(text => $similarartists1, clear=>1, duration=>0, font=>1, x=>0, y=>0, keygrab=>2);
		$display->msg(text => $similarartists2, clear=>0, duration=>0, font=>1, x=>0, y=>8, keygrab=>2);
  	} elsif ($displaytype == 2) {
		$display->msg(text => $similarartists1, clear=>1, duration=>0, font=>2, x=>0, y=>0, keygrab=>2);
		$display->msg(text => $similarartists2, clear=>0, duration=>0, font=>2, x=>0, y=>16, keygrab=>2);
   };
   $display->{connection}->print("rcp\n");
   $display->{connection}->print("GetCurrentSongInfo\n");
   my ($p, $m ) = $display->{connection}->waitfor(Match => '/^GenericError|GetCurrentSongInfo: artist: .+/', Timeout => 3);
   my ($q, $n ) = $display->{connection}->waitfor(Match => '/remoteStream/', Timeout => 3);
   $display->{connection}->print("exit\n");
   if ($m eq "GenericError") {
   	$display->msg(text => "Fehler", clear=>1, duration=>1, font => 2, x=>80, y=>0, keygrab=>2);
   } elsif ($n eq "remoteStream") {
   	$display->msg(text => "Radio", clear=>1, duration=>1, font => 2, x=>80, y=>0, keygrab=>2);
   } else {
      $m =~ s/^GetCurrentSongInfo: artist: //;
      if ($m eq '') {
	      # There is no Artist
      } else {
	if ($displaytype == 1) {
	 	$display->msg(text => $lookforsimartist.$m."? ".$pleasewait , clear=>1, duration=>0, font => 2, x=>0, y=>0, keygrab=>2);
      	} elsif ($displaytype == 2) {
	 	$display->msg(text => $lookforsimartist.$m."? ".$pleasewait, clear=>1, duration=>0, font => 2, x=>0, y=>8, keygrab=>2);
      	};
	# first put the current played Artist in the list
	push @artists, $m;
	# replace special character like space for URL use (source: http://glennf.com/writing/hexadecimal.url.encoding.html)
	$m =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
   # get a list of similar atrists from http://ws.audioscrobbler.com/1.0/artist/ArtistName/similar.txt
	$simartistsAS = `wget -q -O - "http://ws.audioscrobbler.com/1.0/artist/$m/similar.txt"`;
	if ( ($simartistsAS eq "") or (substr($simartistsAS, 0, 4) eq "wget") ) {
		# if its empty, then  something went wrong, e.g. no connection
	} else {
		# filter matching percentage AND artist names to an array
      for my $line ( split /\n/, $simartistsAS ) { 
    		my @data = split /,/, $line; 
			push @artists, $data[ 2 ] if $data[ 0 ] > $threshhold; 
		};
		# syncs RCP with currently playing Music Server (necessay to use same database)
		$display->{connection}->print("rcp\n");
		$display->{connection}->print("GetConnectedServer\n"); 
		my ($p, $m ) = $display->{connection}->waitfor(Match => '/^GenericError|GetConnectedServer: OK/', Timeout => 30);
      # clear the current Playlist (RCP)
      $display->{connection}->print("NowPlayingClear\n");
		my ($p, $m ) = $display->{connection}->waitfor(Match => '/^GenericError|NowPlayingClear: OK/', Timeout => 30);
		$display->{connection}->print("exit\n");
		$display->msg(encoding=>"utf8"); # because data is in utf8 not latin1
		foreach $artist (@artists) {
			if ($displaytype == 1) {
	 			$display->msg(text => $searchfor.$artist, clear=>1, duration=>0, font=>0, x=>2, y=>0, keygrab=>2);
      			} elsif ($displaytype == 2) {
	 			$display->msg(text => $searchfor.$artist, clear=>1, duration=>0, font=>0, x=>2, y=>8, keygrab=>2);
      	};
			$display->{connection}->print("rcp\n");
			# search for songs of found artists in the database 
			$display->{connection}->print("SetBrowseFilterArtist $artist\n");
			my ($p, $m ) = $display->{connection}->waitfor(Match => '/^GenericError|SetBrowseFilterArtist: OK/', Timeout => 30);
			$display->{connection}->print("ListSongs\n");
			my ($p, $m ) = $display->{connection}->waitfor(Match => '/^GenericError|ListSongs: TransactionComplete/', Timeout => 360);
			# push found songs into the Now Playing List 
			$display->{connection}->print("NowPlayingInsert all\n");
			my ($p, $m ) = $display->{connection}->waitfor(Match => '/^GenericError|NowPlayingInsert: OK/', Timeout => 3);
			$display->{connection}->print("exit\n");
		};
      $display->msg(encoding=>"latin1");
		# Play the Now Playing List in Shuffled order
		$display->{connection}->print("rcp\n");
      $display->{connection}->print("Shuffle on\n");
      $display->{connection}->print("Play\n");
	   $display->{connection}->print("exit\n");
		$display->cmd("sketch -c clear");
		$display->cmd("sketch -c exit");
	};
      };
   };	
};

sub ratesong {
	my $likeit = shift;
	my $data;	
	#uses print instead of cmd() because of timeout/ RCP has no prompt!
   $display->{connection}->print("rcp\n"); 
   $display->{connection}->print("GetCurrentSongInfo\n");	
   my ($p, $m ) = $display->{connection}->waitfor(Match => '/^GenericError|GetCurrentSongInfo: id: [0-9]+/',
																			  Timeout => 3);
   my ($q, $n ) = $display->{connection}->waitfor(Match => '/remoteStream/',
																			  Timeout => 3);
   $display->{connection}->print("exit\n");
   if ($m eq "GenericError") {
   	$display->msg(text => $nosongtorate, clear => 1, duration=>1, font => 2, x=>40, y=>0, keygrab=>2);
   } elsif ($n eq "remoteStream") {
   	$display->msg(text => $itsremotestream, clear => 1, duration=>1, font => 2, x=>40, y=>0, keygrab=>2);
   } else {
      $m =~ s/^GetCurrentSongInfo: id: //;
      if ($m eq '') {
	      # There is no Song to rate 
      } else {
      	if ( $likeit == 1 ) {
				$data = `sqlite /opt/var/mt-daapd/songs.db "SELECT rating FROM songs WHERE id = $m";`;
				$data = int(($data+100)/2+.5);	
      		if ($displaytype == 1) {
					$display->msg(text => $ilikeit." (".$data."%)", clear => 1, duration=>1, font => 2, x=>60, y=>0, keygrab=>2);
      		} elsif ($displaytype == 2) {
					$display->msg(text => $ilikeit." (".$data."%)", clear => 1, duration=>1, font => 2, x=>60, y=>8, keygrab=>2);
      		};
				$data = `sqlite /opt/var/mt-daapd/songs.db  "UPDATE songs SET rating = $data WHERE id = $m" `;
				## oder daten in File schreiben
      		#open FILE, ">>myratings.txt" or die $!;
				#print FILE $m;
				#print FILE ":1\n" ;
				#close FILE;
      	} else {
				$data = `sqlite /opt/var/mt-daapd/songs.db "SELECT rating FROM songs WHERE id = $m";`;
				$data = int(($data)/2+.5);	
      		if ($displaytype == 1) {
	      		$display->msg(text => $notmytaste." (".$data."%)", clear => 1, duration=>1, font => 2, x=>40, y=>0, keygrab=>2);
      		} elsif ($displaytype == 2) {
	      		$display->msg(text => $notmytaste." (".$data."%)", clear => 1, duration=>1, font => 2, x=>40, y=>8, keygrab=>2);
      		};
				$data = `sqlite /opt/var/mt-daapd/songs.db "UPDATE songs SET rating = $data WHERE id = $m" `;
      	};
      };
	};
   $display->cmd("sketch -c exit");
};

sub showmenu {

	my $from = shift;
	my $position = 0;
   my $myselection = -1;
	my $rc;
	my $myexit;
	my ($p, $m); 
	
	if ($menu == 1) {
		$display->clear();
		$position = 0;
		$myselection = -1;
    if ($displaytype == 1) {
  		$display->msg(text => $menuweather, font =>  1, x => 10, y => 0, duration => 0, keygrab => 0, clear => 1); 
  		$display->msg(text => $menusetsleep, x => 10, y =>8, duration => 0, keygrab => 0 ); 
  		$display->msg(text => $menustealarm, x => 150, y => 0, duration => 0, keygrab => 0 ); 
  		$display->msg(text => $menuserverdown, x => 150, y => 8, duration => 0, keygrab => 0); 
    } elsif ($displaytype == 2) {
  		$display->msg(text => $menuweather, font =>  1, x => 10, y => 0, duration => 0, keygrab => 0, clear => 1); 
  		$display->msg(text => $menusetsleep, x => 10, y =>8, duration => 0, keygrab => 0 ); 
  		$display->msg(text => $menustealarm, x => 10, y => 16, duration => 0, keygrab => 0 ); 
  		$display->msg(text => $menuserverdown, x => 10, y => 24, duration => 0, keygrab => 0); 
    };
		$display->msg(text => ">", x => 0, y =>  0, duration => 0, keygrab => 0);
		do {
			$rc = $display->msg(x => 279, y => 31, text => " ", duration => 6, keygrab => 1);
			if ($rc eq "CK_SELECT") {
				$myselection = $position;
				$myexit = 1;
			} elsif (($rc eq "timeout") or ($rc eq "CK_EXIT") ) {
				$myexit = 1;
			} elsif ($rc eq "CK_SOUTH") {
				$display->cmd("sketch -c color 0");
				$display->cmd("sketch -c rect 0 0 10 32");
				$display->cmd("sketch -c rect 140 0 10 32");
				$display->cmd("sketch -c color 1");
				$position++;
				if ($position > 3) {$position = 0};
        if ($displaytype == 1) {
        	if ($position < 2) {
        		$display->msg(text => ">", x => 0, y => $position*8, duration => 0, keygrab => 0);
        	} else {
        		$display->msg(text => ">", x => 140, y => ($position-2)*8, duration => 0, keygrab => 0);
        	};
        } elsif ($displaytype == 2) {
				  $display->msg(text => ">", x => 0, y => $position*8, duration => 0, keygrab => 0);
        };
			} elsif ($rc eq "CK_NORTH") {
				$display->cmd("sketch -c color 0");
				$display->cmd("sketch -c rect 0 0 10 32");
				$display->cmd("sketch -c rect 140 0 10 32");
				$display->cmd("sketch -c color 1");
				$position--;
				if ($position < 0) {$position = 3};
        if ($displaytype == 1) {
        	if ($position < 2) {
        		$display->msg(text => ">", x => 0, y => $position*8, duration => 0, keygrab => 0);
        	}	else {
        		$display->msg(text => ">", x => 140, y => ($position-2)*8, duration => 0, keygrab => 0);
        	};
        } elsif ($displaytype == 2) {
				  $display->msg(text => ">", x => 0, y => $position*8, duration => 0, keygrab => 0);
        };
			};
		} until ($myexit == 1);
		
		if ($myselection == 0) {
			showweather($from)
		} elsif ($myselection == 1) {
			$display->cmd("sketch -c clear"); 
			$display->cmd("sketch -c exit");
			$display->cmd("irman off");
			$display->cmd("irman intercept");
			$display->cmd("irman dispatch CK_SNOOZE");
			do { 
  			($p, $m ) = $display->{connection}->waitfor(Match => '/irman: .*/', Timeout => 60);
  			if ($m) {
  				$m =~ s/^irman: //;
  				if ($m eq "CK_SELECT") {
  					 $display->cmd("irman dispatch CK_SNOOZE");
  			  }
  			}
  		} until ( ($m eq "timeout") or ($m ne "CK_SELECT") );		
		} elsif ($myselection == 2) { 
			$display->cmd("sketch -c clear"); 
			$display->cmd("sketch -c exit");
			$display->cmd("irman dispatch CK_ALARM");
		} elsif ($myselection == 3) {
		   # test only
			$display->cmd("sketch -c clear"); 
		   $rc = `/usr/sbin/DO_Shutdown`;
			exit;
		};
		$myselection = -1;
		$myexit = 0;
		$menu = 0;
	};
};

# #######################################################
sub showweather {
 my $from = shift;
 my $myexit = 0;
 my $tempdata;
 
 do {
    $display->clear();
    if ($displaytype == 1) {
    	$display->msg(text => $pleasewait, duration=>0, font => 1, x=>90, y=>5, keygrab=>0);
    } elsif ($displaytype == 2) {
    	$display->msg(text => $pleasewait, duration=>0, font => 1, x=>90, y=>10, keygrab=>0);
    };
	 # get the outside temperature from digitemp

    if ((time()-$last_fetch) > (20 * 60)) {  #every 20 min fetch
    	$last_fetch = time();
    	
      # get the local weather information form the DigiTemp Sensors at home if available
	 		if ($digitemp == 1) {
	 		  if ($unitsid eq "c") {
	 		  	$tempdata = `digitemp -q -o2 -t1`;
	 			} else {
	 				$tempdata = `digitemp -q -o3 -t1`;
	 			};
	 			$tempdata =~ /\s([0-9]+\.[0-9]+)/ ;
	 			$myouttemp = sprintf ("%.0f", $1);
	 		};

      # get the weather information form the internet    
      $display->clear();
      if ($displaytype == 1) {
        $display->msg(text => $getyahoodata, duration=>0, font => 1, x=>25, y=>5, keygrab=>0);
      } elsif ($displaytype == 2) {
        $display->msg(text => $getyahoodata, duration=>0, font => 1, x=>25, y=>10, keygrab=>0);
      };

    	# get data from URL
    	$weatherdata = "";
    	$weatherdata = `wget -q -O - "http://xml.weather.yahoo.com/forecastrss?p=$locationid&u=$unitsid"`;
    	if ( ($weatherdata eq "") or (substr($weatherdata, 0, 4) eq "wget") ) {
    		# if its empty, then  something went wrong, e.g. no connection
    		$last_fetch = 0;
    		$currtemp = "";
    		$wcode = "3200";
    		$to1code = "3200";
    		$to2code = "3200";
    		$feeltemp = "-";
    		$currtemp = "-";
    		$unitspeed = ""; 
    		$humidity = "-";
    		$windspeed = "-";
    	} else {
			# read the units from feed data
			$weatherdata =~ /yweather:units ([^>]+)\/>/;
			$units = $1;
			$units =~ /temperature="([^"]+)"/;
			$unittemp = $1; # the unit for temperature    	
			$units =~ /speed="([^"]+)"/;
			$unitspeed = $1; # the unit for speed
			
			if ($unitspeed eq "kph" ) { # give it the propper SI unit :)
				 $unitspeed = "km/h"
			}; 
       
			# look for the local condition
			$weatherdata =~ /yweather:condition ([^>]+)\/>/;
			$condition = $1;
			$condition =~ /code="([^"]+)"/;
			$wcode = $1 + 0; # the weathercode    	
			$condition =~ /temp="([^"]+)"/;
			$currtemp = $1; # the current temperature

			# look for the atmosphere data
			$weatherdata =~ /yweather:atmosphere ([^>]+)\/>/;
			$atmosphere = $1;
			$atmosphere =~ /humidity="([^"]+)"/;
			$humidity = $1; # the relative air humidity    	

			# look for the atmosphere data
			$weatherdata =~ /yweather:wind ([^>]+)\/>/;
			$winddata = $1;
			$winddata =~ /speed="([^"]+)"/;
			$windspeed = $1; # the wind speed   	
			$winddata =~ /direction="([^"]+)"/;
			$winddirection = $direction[ int($1/(360/($#direction + 1))+.50) % ($#direction + 1) ]; # the wind direction 	
			$winddata =~ /chill="([^"]+)"/;
			$feeltemp = $1; # the felt temperature 	
  
			# look for forcast rest of the day
			$weatherdata =~ /yweather:forecast ([^>]+)\/>/o;
			$tomorrow1 = $1;
			$tomorrow1 =~ /day="([^"]+)"/;
			$to1day = $1; # 	
			$tomorrow1 =~ /date="([^"]+)"/;
			$to1date = substr($1, 0, 2).".".$monname{substr($1, 3, 3)}; # the date reformated: "dd mmm" to "dd.mm"	
			$tomorrow1 =~ /code="([^"]+)"/;
			$to1code = $1 + 0; # 	
			$tomorrow1 =~ /low="([^"]+)"/;
			$to1low = $1; # 	
			$tomorrow1 =~ /high="([^"]+)"/;
			$to1high = $1; # 	
			$weatherdata =~ s/yweather:forecast ([^>]+)\/>//o; # this overwrites the first forecast.

			# look for forcast of tomorrow
			$weatherdata =~ /yweather:forecast ([^>]+)\/>/o;
			$tomorrow2 = $1;
			$tomorrow2 =~ /day="([^"]+)"/;
			$to2day = $1;  # the weekday	
			$tomorrow2 =~ /date="([^"]+)"/;
			$to2date = substr($1, 0, 2).".".$monname{substr($1, 3, 3)}; # the date reformated: "dd mmm" to "dd.mm"	
			$tomorrow2 =~ /code="([^"]+)"/;
			$to2code = $1 + 0; # the weather code	
			$tomorrow2 =~ /low="([^"]+)"/;
			$to2low = $1; #  the low forecast	
			$tomorrow2 =~ /high="([^"]+)"/;
			$to2high = $1; # the high forecast	

			
			### uncomment next two lines for debug output on your console
			# print $condcode{$wcode+0}." bei ".$currtemp."C und ".$humidity."% Luftfeuchte \n";
			# print "Wind mit ".$windspeed.$unitspeed." aus Richtung ".$winddirection." ist wie ".$feeltemp."C \n";
      }
    }
    
    # push the info to the roku display
    
    ### Font List for costumization:
    #  1 - Fixed8
    #  2 - Fixed16 (UFT8 font with japanese charachters)
    #  3 - ZurichBold32
    #  10 - ZurichBold16
    #  11 - ZurichLite16
    #  12 - Fixed16
    #  14 - SansSerif16

    my $rc;
    $display->clear();
	  my $loop = 0;
	  if ($displaytype == 1) {
	  	if ($modus eq 0) {
        # Roku current weather to display
        $display->clear();
        $display->msg(text => $currtemp."°".$unittemp, duration=>0, font => 10, x=>34, y=>0, keygrab=>0);
        $display->msg(text => $condcode{$wcode}, duration=>0, font => 1, x=>80, y=>0,  keygrab=>0);
        $display->msg(text => $wind.": ".$winddirection." (".$windspeed.$unitspeed.")", duration=>0, font => 1, x=>80, y=>8,  keygrab=>0);
        drawIcon("pbm/s-".$wcode."\.pbm", 0, 0); # $display->cmd("sketch -c framerect 0 0 16 16");
      } elsif ($modus eq 1) {
        # Roku weather preview to display
        # rest of today
        $display->msg(text => $dayname{$to1day}, duration=>0, font => 1, x=>0, y=>0, keygrab=>0); # day
        $display->msg(text => $to1date, duration=>0, font => 1, x=>0, y=>8, keygrab=>0); # date
        $display->msg(text => $to1high."°".$unittemp, duration=>0, font => 1, x=>82, y=>0, keygrab=>0); # min temp
        $display->msg(text => $to1low."°".$unittemp, duration=>0, font => 1, x=>82, y=>8, keygrab=>0); # max temp
        # Clear second half and  draw border line
  	    $display->cmd("sketch -c color 0");
 	      $display->cmd("sketch -c rect 139 0 141 16");
  	    $display->cmd("sketch -c color 1");
 	      $display->cmd("sketch -c line 140 0 140 16");
        # tomorrow
        $display->msg(text => $dayname{$to2day}, duration=>0, font => 1, x=>145, y=>0, keygrab=>0); # day
        $display->msg(text => $to2date, duration=>0, font => 1, x=>145, y=>8, keygrab=>0); # date
        $display->msg(text => $to2high."°".$unittemp, duration=>0, font => 1, x=>147+80, y=>0, keygrab=>0); # min temp
        $display->msg(text => $to2low."°".$unittemp, duration=>0, font => 1, x=>147+80, y=>8, keygrab=>0); # max temp
        drawIcon("pbm/s-".$to1code."\.pbm", 47, 0); #$display->cmd("sketch -c framerect 47 0 16 16");
        drawIcon("pbm/s-".$to2code."\.pbm", 188, 0); # $display->cmd("sketch -c framerect 188 0 16 16");
      } else {  
        # dispaly only time at center
    	  $display->msg(text => substr(localtime(time), 11, 5), duration=>0, font => 10, x=>110, y=>0, keygrab=>0);
    	};
	  } elsif ($displaytype == 2) {
  	  if ($modus eq 0) {
         # Roku current weather to display
         $display->clear();
         if ($digitemp == 1) {
         	 $display->msg(text => $myouttemp."°".$unittemp, duration=>0, font => 3, x=>34, y=>0, keygrab=>0);
         } else {
         	 $display->msg(text => $currtemp."°".$unittemp, duration=>0, font => 3, x=>34, y=>0, keygrab=>0);
         };
         $display->msg(text => $condcode{$wcode}, duration=>0, font => 2, x=>90, y=>0,  keygrab=>0);
         $display->msg(text => $wind.": ".$winddirection." (".$windspeed.$unitspeed.")", duration=>0, font => 2, x=>90, y=>16,  keygrab=>0);
         drawIcon("pbm/".$wcode."\.pbm", 0, 0); # $display->cmd("sketch -c framerect 0 0 32 32");  
      } elsif ($modus eq 1) {
         # Roku weather preview to display
         # rest of today
         $display->msg(text => $dayname{$to1day}, duration=>0, font => 2, x=>0, y=>0, keygrab=>0); # day
         $display->msg(text => $to1date, duration=>0, font => 2, x=>0, y=>16, keygrab=>0); # date
         $display->msg(text => $to1high."°".$unittemp, duration=>0, font => 2, x=>84, y=>0, keygrab=>0); # min temp
         $display->msg(text => $to1low."°".$unittemp, duration=>0, font => 2, x=>84, y=>16, keygrab=>0); # max temp
         # Clear second half and  draw border line
  			 $display->cmd("sketch -c color 0");
  			 $display->cmd("sketch -c rect 139 0 141 32");
  			 $display->cmd("sketch -c color 1");
  			 $display->cmd("sketch -c line 140 0 140 31");
         # tomorrow
         $display->msg(text => $dayname{$to2day}, duration=>0, font => 2, x=>145, y=>0, keygrab=>0); # day
         $display->msg(text => $to2date, duration=>0, font => 2, x=>145, y=>16, keygrab=>0); # date
         $display->msg(text => $to2high."°".$unittemp, duration=>0, font => 2, x=>233, y=>0, keygrab=>0); # min temp
         $display->msg(text => $to2low."°".$unittemp, duration=>0, font => 2, x=>233, y=>16, keygrab=>0); # max temp
         drawIcon("pbm/".$to1code."\.pbm", 49, 0); #$display->cmd("sketch -c framerect 47 0 32 32");
         drawIcon("pbm/".$to2code."\.pbm", 194, 0); # $display->cmd("sketch -c framerect 188 0 32 32");
      } elsif ($modus eq 2) {
   		   # dispaly only time at center
  			 $display->msg(text => substr(localtime(time), 11, 5), duration=>0, font => 3, x=>110, y=>0, keygrab=>0);  		
 		  } else {
  	  	 # Roku compact all data view
  			 # now:
         if ($digitemp == 1) {
  		   	$display->msg(text => substr(localtime(time), 11, 5)." ".$outstring.$myouttemp."°".$unittemp." (".$currtemp."°".$unittemp.", ".$feelstring.":".$feeltemp."°".$unittemp.") ".$humistring.":".$humidity."% " , duration=>0, font => 1, x=>0, y=>0, keygrab=>0);
         } else {
  			 	$display->msg(text => substr(localtime(time), 11, 5)." ".$outstring.$currtemp."°".$unittemp.", ".$feelstring.":".$feeltemp."°".$unittemp." ".$humistring.":".$humidity."% " , duration=>0, font => 1, x=>0, y=>0, keygrab=>0);
         };
  			 $display->msg(text => $wind.":".$windspeed.$unitspeed." (".$winddirection.") ".$condcode{$wcode} , duration=>0, font => 1, x=>0, y=>8, keygrab=>0);
  			 # today
  			 $display->msg(text => $dayname{$to1day}." ".$to1date." ".$minstring.$to1low."°".$unittemp." ".$maxstring.$to1high."°".$unittemp.", ".$condcode{$to1code}, duration=>0, font => 1, x=>0, y=>17, keygrab=>0);
  			 # tomorrow
  			 $display->msg(text => $dayname{$to2day}." ".$to2date." ".$minstring.$to2low."°".$unittemp." ".$maxstring.$to2high."°".$unittemp.", ".$condcode{$to2code}, duration=>0, font => 1, x=>0, y=>25, keygrab=>0);
  		}; 
  		# end display modes
  	 };
	 do {
			$rc = $display->msg(text => " ", duration=>10, font => 32, x=>31, y=>279, keygrab=>1);
			$loop++;
    } until ((substr($rc,0,2) eq "CK") or ( $loop == $alternate ));
    if ($rc) { 
       if ($rc eq "CK_SOUTH") { $modus-- };
       if ($rc eq "CK_NORTH") { $modus++ };
       if ($rc eq "CK_POWER") { 
          # close the display, send the power command to the Roku and be quiet!
          $display->close;
          $display->cmd('irman dispatch CK_POWER'); 
          $display->cmd('irman dispatch CK_POWER'); 
			 # $display->cmd('irman dispatch CK_SPECIAL_POWER_STATE_CHANGED'); 
          sleep 15;
          $myexit = 1;
       };
       if ( $from eq "1") {
			 if ($rc eq "CK_MENU") { 
 	          $myexit = 1;
				 # $display->cmd('irman dispatch CK_POWER'); 
				 $display->cmd("sketch -c clear"); 
				 $display->cmd("sketch -c exit");
			 };
			 if ($rc eq "CK_EXIT") { 
  	          $myexit = 1;
				 # close the display, send the power command to the Roku and be quiet!
				 #$display->cmd('irman dispatch CK_POWER'); 
				 $display->cmd("sketch -c clear"); 
				 $display->cmd("sketch -c exit");
			 };
		 };
    };
    if (($alternate > 0) and ( $loop == $alternate )) {
 	  	$modus++;
 	  	if ($modus > 2) { $modus=0 }; # reset and skip views bigger 2 (e.g. compact view)
 	 };

    if ($modus > 3) { $modus = 0 };
    if ($modus < 0) { $modus = 3 }; 
  } until ($myexit == 1);
};

##############################################################################################

sub drawIcon {
   my $filename = shift;
   my $u = shift;
   my $v = shift;
   my $bits = "";
   my $x;
   my $y;
   my $i;
   my $j;
   my $s;
   my $t;

   open(iconfile, "<$filename") || die "Icon file ".$filename." not found!";
      my @icon = <iconfile>;
      my $cnt = 0;
      my $s2;
      my $help;
   close(iconfile);
   if ($icon[0] eq "P1\n" ) { # continue because its a PBM file
      # read the pbm dimensions
      $icon[2] =~ /^([0-9]+) ([0-9]+)/;
      $x = $1 ;
      $y = $2 ;
      # make a black box before drawing
      $display->cmd("sketch -c color 0");
      $display->cmd("sketch -c rect $u $v $x $y");
      $display->cmd("sketch -c color 1");
      
      foreach (@icon) {
        $bits = $bits.$_ ;
      };
      $bits =~ s/\n//;
      $bits =~ s/^.* $x $y//;
      for ($j = 0; $j < $y; $j++) {
      	for ($i = 0; $i < $x; $i++) {
          $cnt = 1; 
          $bits =~ s/([0|1]) //;
          if ($1 eq 1) {
            $s = $u+$i;
           	$t = $v+$j;
          	while ( ($1 == 1) and ($i < $x-1) ) {
            	$bits =~ s/([0|1]) //;
	            $i++;
            	if ($1 == 1) { 
               	$cnt++;
            	};
           	}
           	$s2 = $s + $cnt;
           	$display->cmd("sketch -c line $s $t $s2 $t"); # line x1 y1 x2 y2 		
          }
        }
      }
   }
}

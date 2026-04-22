$${\color{red}This \space repository \space archives \space an \space rather \space old \space code \space that \space used \space to \space run \space on \space my \space Pinnacle/Roku \space M1001 \space Soundbridges.}$$

# Tools4Roku   2008/08/04

Provides weather information on the Roku Soundbride display when in stand-by mode. Tested with the M1001 model.
Based on "rokuweather.pl" from _Michael Polymenakos_ (2007, mpoly@panix.com) and the "services" from _Adam Peller_ (peller@gnu.org)

For Terms of Use of Yahoo weather service see at: http://developer.yahoo.com/weather/

## Introduction and Features

Why put tons of gadgets on my shelf when I have a nice roku soundbrigde?
This display can show all the information I can think of (weather, song rating, mail, rss, phone calls ...).
But lets start simple :-)

This software allows you to: 
- show local measured temperature via digitemp one-wire sensor on the server 
- rate songs from the Roku remote
- make Roku "play similar artists" like current artist function
- use the Tool4Roku also when playing music
- use "sleep" function via remote control
- use "alarm" function via remote control
- shut down `mt-daapd server` from roku remotely

## Installation

My roku gets its music from Linksys NSLU running uNSLUng firmware and the mt-daapd music server (besides other services...).
To run perl sripts I had to install perl by
```
ipkg update
ipkg install perl
```
  
I was not successful to install CPAN as well, so I tried to avoid any additional perl packages. But the **Net::Telnet** was needed by Roku.pm

Download it from [http://search.cpan.org/CPAN/authors/id/J/JR/JROGERS/Net-Telnet-3.03.tar.gz]

Install the compiler
```
ipkg install make
```

Compile it:  
```
perl Makefile.PL 
make 
make test 
make install
```

Edit the Tools4Roku config file (`t4local`)  to suit your needs ( IP adress! )
T4Roku comes with an English and a German version.
Please send me the yours if you did translation to other languages.
 
Then you can start Tools4Roku by
```
perl t4roku.pl
```
  
enjoy :)

On Mac you must replace the term "wget -q -O -" by "curl --silent" as wget is not available by default. (Thanks elnjensen)

## Start T4Roku at NSLU-Boot and end it on shutdown

**uNSLUng** will start every Program in `/opt/etc/init.d` when it starts with *"S..."* at boot and when it starts with *"K..."* at shutdown.
So write two scripts named e.g. `S80t4roku`
```
cd /public/t4roku
perl t4roku.pl &
```
and `K80t4roku`
```
kill `pidof perl t4roku.pl`
cd /public/t4roku
perl cleanroku.pl
```

If the t4roku is killed only, it will leave your Roku unresponsible...
Make both files accessible with 
```
chmod 711 S80t4roku
chmod 711 K80t4roku
```

The script rokuclean.pl contains the following code
```
#!/usr/bin/perl
use strict;
use RokuUI;
my $display = RokuUI->new(host => '192.168.123.123', port => 4444);
for my $int ('INT','QUIT','HUP','TRAP','ABRT','STOP') { 
   $SIG{$int} = 'interrupt';
}
$display->open || die("Could not connect to Roku Soundbridge");  
$display->close;
sub interrupt {exit(@_)};
END {
  undef $display;  
}
```

## Digitemp - Fix the PL2303 driver

1. get the driver from [http://www.fh-furtwangen.de/~dersch/pl2303.o] (Thank you _Mr. Dersch_). 
2. find the current driver's location. You can do this using the command: `find / -name pl2302.o - print`
	(on my unslung it is at: `/lib/modules/2.4.22-xfs/kernel/drivers/usb/serial/pl2303.o`),
3. replace the current adapter at the above location,
4. unplug the USB to Serial Adapter,
5. rmmod pl2303,
6. insmod pl2303,
7. plug adapter back in.

Thanks _braydw_ for posting this on [http://www.nslu2-linux.org/wiki/Peripherals/USB2Serial]

## Use

### At stand-by

Tools4Roku starts to show weather information shortly after you switch to standby.
Information is updted every 30 minutes via RSS feed.
You can switch between 3 (or 4) modi by remote control (UP or DOWN key): Weather of today, weather for today and tomorrow, the time and a comapct view with all data on on screen (only tall screens).

### When the roku is on

Press the home button three times and the display will show the menu.
Use the Up and Down key to move the cursor and press Select to activate your selection.
Currently the menu lets you choose from
	a) show the weather data
	b) set the SB to sleep mode.
	c) set an alarm
	d) shut down the server (modify the comand in the script for your needs,
		 see line 252). Use with caution!
		 
### The Song Rating 

If music is playing, the songs can be rated with the remote.
The rating is updated in the mt-daapd database (tested with svn-1696, sqlite2).
The Rating is done from 0-100 (every 20 counts equals 1 star in iTunes).
Press the "right"-button if you like the current song, and press
the "left"-button on your remote if the song is not your taste.
The rating will be racalculated after the formula:

**Love = 100 if "Right", 0 if "Left" is pressed**
**New-Rating = ( Old-Rating + Love ) / 2**
	
So a multiple love will bring the rating closer to ultimate love score (100%), or the other way round.
The function is not symetric, so dislike a much beloved song once and it will drop below the 50 ;-)
You will see and responce on the Roku display.

**!! Caution so far t4roku does not recognise if you browse a menu or something similar.
So if you use the key during browsing a menu and having background playback, the current song will be rated !!**

### Play similar artists

If music is playing, the current playlist can be replaced by a playlist of all songs from similar artists in your collection. Simply press the brightnes button on your IR remote control. The generating may take some seconds.

Background: The current playing artist is read via RCP from your Soundbridge.
With the name a list of similar artist is requested at audioscrobbler.com
Based on  that list and the "similarity threshhold" your local collection of songs ist filtered with those artist names. The new generated playlist is played shuffled after the query is finished. 

## Icons

The weahther icons are in `/pbm`
If you not like the icons, then pixel it for yourself in your favorite application and save or convert to PBM format.
Be careful, the t4roku does not have much error handling!!
Size of my icons is 32 x 32 pixel.
Thanks _Marco Forschner_ for the 16 x 16 pixel icons.



## To do (will probably never be done...)

- error handling for incomplete rss feed ($1 clear ?)
- show mailbox status on roku display
- debug "similar artists" function
- make last.fm scrobbler function
- investigate server hang-up if roku is un-powered

## History

2008/08/04
 - working example of a "Play similar artists" implemented. The function is 
   mapped to the brightness button of the IR remote control. It asks for the 
   current artist, looks up similar artists at audioscrobbler.com and puts all
   tracks from local music server from listed artists into new playlist, which is
   then played in shuffled order

2008/06/23
 - localisation for rating, rating not possible for internet radio (remote stream)

2008/06/20
 - implmented a rating functionality, sqlite must be installed on the NSLU2

2008/05/24
 - got translated localisation files from Guillaume Membre (french),
   Pierre Bouchard (french too, Canada)
 - changed line 52 (now: $display->open || die("Could not connect to Roku Soundbridge: $!");)
   thanks Ed Outhwaite for the tip
 - M2000 version of t4roku by Steve Forster, this version has also command line support for
   display type, IP and location code

2008/03/01
 - made variables for all used strings (for easier localisation)
 - move icon drawing sub call to end of output, optical Roku looks more responsive
   Thanks to mic_hall for this idea
 - localisation file based on Michael Polymenakos perl scripts
 	 (this version comes with: EN and DE)
 - bug fixed the sleep mode, repeated pressing of Select increases time
 - I like the idea from Steve Forster to alternate view and put it
   in as well. On/off via config file.
 - merged small and tall display versions (switch in config file)
   Thanks Marco Forschner for the work to fit the small display

2008/01/28
 - bug fix the remote control exception handling (echo insted of intercept,
   result: smoother scrolling and volume control, just like without t4roku)
 - new menu function. The door is open to control anything on the server from SB
 - Sleep and Alarm acessible with the remote control via the menu

2008/01/20
 - additional view (modus 2) with all weather data in compact view
 - include digitemp temperature in modus 0 and 2

2008/01/16
 - changed the icon drawing procedure a little to improve the speed.
   it now draws successive white pixel as a line now. This improved speed
   on my roku by over 50%
 - corrected error in calculation of the wind direction

2008/01/12
 - the weather is now accessible also when soundbridge is switched on,
   simply press the Home butten three times
 - some bugfixes

2008/01/09
 - first release, shows weather on Roku display when in stand-by
 
## Thanks

Thanks to all who helped to improve this software.
Mainly members of the Roku Forum: _Michael Polymenakos_, _Haggis_, _Marco Forschner_, _mic_hall_, _Steve Forster_

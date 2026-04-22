#!/usr/bin/perl

########################################################################
# Tools4Roku-clean 2008/03/01  Juergen Gluch     juergen.gluch@gmx.de  #
########################################################################

use strict;
use RokuUI;

# adjust IP adress of your roku here
my $display = RokuUI->new(host => '192.168.1.13', port => 4444);

for my $int ('INT','QUIT','HUP','TRAP','ABRT','STOP') { 
   $SIG{$int} = 'interrupt';
}   

$display->open || die("Could not connect to Roku Soundbridge");  
$display->close;

sub interrupt {exit(@_)};

END {
  undef $display;  
}



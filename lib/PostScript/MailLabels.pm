package PostScript::MailLabels;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use PostScript::MailLabels::BasicData;

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( labelsetup labeldata averycode);

$VERSION = '2.00';

use Carp;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};

	$self->{SETUP} = {};
	$self->{COMPONENTS} = {};
	$self->{LABELDEF} = [];

	$self->{MAKEBOX} = ''; # ps code to draw a box
	$self->{MAKERULE} = ''; # ps code to make rulers
	$self->{PRTTEXT} = ''; # ps code to output the text
	$self->{PRTBAR} = ''; # ps code to output the barcode

	$self->{DATA} = {}; # pointer to various arrays & hashes of basic data.

    bless $self, $class;

	&initialize($self);

     return $self;
}

sub initialize {

	#		Initialize with some reasonable default values
	#	printable area : define width of borders
	#	printable_left, printable_right, printable_top, printable_bot

	#	output definition : define left and top offsets, width and
	#	height of a label
	#	output_left, output_top, output_width, output_height

	#	Other controls
	#	Postnet => 'yes' : print barcode on bottom for zip code
	#	Font => 'Helvetica'
	#	units => 'inches' or 'cm'
	#	

	my $self = shift;

	%{$self -> {SETUP}} = (

		#	paper size

		papersize		=> 'Letter',
			
		#	printable area on physical page

		printable_left		=> 0.0,
		printable_right		=> 0.0,
		printable_top		=> 0.0,
		printable_bot		=> 0.0,

		#	define where the labels live (ideally)

		output_top		=> 0.0, 
		output_left		=> 0.0, 
		output_width	=> 0.0, 
		output_height	=> 0.0, 
		x_gap			=> 0.0,
		y_gap			=> 0.0,
		number			=> 0,
		columns			=> 0,

		#	Adjustments for printer idiosyncracies

		x_adjust		=> 0.0,
		y_adjust		=> 0.0,

		#	Other controls

		postnet		=> 'yes',
		font		=> 'Helvetica',
		fontsize 	=> 12,
		units    	=> 'english',
		firstlabel	=> 1,

		#	Character encoding

		encoding    => 'StandardEncoding', # or ISOLatin1Encoding

		# set equal to the Avery(tm) product code, and the label description
		# will be updated from the database.
		avery		=> undef,

				   );
	
	#	Default (US-style) address components
	
	%{$self -> {COMPONENTS}} = (
		#	first name
		fname	=> { type => 'name', adj => 'yes', font => 'Helvetica', 'index' => 0 },
		#	last name
		lname	=> { type => 'name', adj => 'yes', font => 'Helvetica', 'index' => 1 },
		#	street address and street
		street	=> { type => 'road', adj => 'yes', font => 'Helvetica', 'index' => 2 },
		#	city
		city	=> { type => 'place', adj => 'yes', font => 'Helvetica', 'index' => 3 },
		#	state
		state	=> { type => 'place', adj => 'no', font => 'Helvetica', 'index' => 4 },
		#	country
		country	=> { type => 'place', adj => 'no', font => 'Helvetica', 'index' => 6 },
		#	zip
		zip	=> { type => 'place', adj => 'no', font => 'Helvetica', 'index' => 5 },
		#	postnet
		postnet	=> { type => 'bar', adj => 'no', font => 'PostNetJHC', 'index' => 5 },
				   );

	#	Default label definition

	@{$self -> {LABELDEF}} = (
		#	line 1
		[ 'fname', 'lname' ],
		#	line 2
		[ 'street', ],
		#	line 3
		[ 'city', 'state', 'zip' ],
		#	line 4
		[ 'postnet', ],
	   );

	
	#	Go get the basic data

	$self->{DATA} = new PostScript::MailLabels::BasicData;
}

##########################################################
## Add or Edit a component                              ##
##########################################################

#	editcomponent(name, type, adjust, index, font, )
#		where 
#			name = component name
#			type = name, road, place (controls trimming)
#			adjust = yes or no (can I shorten it?)
#			index = which element of input array?
#			font = which font to use
sub editcomponent {
	my $self = shift;
	my ($name, $type, $adj, $index, $font) = @_;

	if (!defined $name) {return [keys %{$self->{COMPONENTS}}];}

	if (!defined $type) {return [values %{$self->{COMPONENTS}{$name}}];}

	if (!defined $font) {$font = $self->{SETUP}{font};}
	if (!defined $adj) {$adj = 'no';}

	if (!defined $index && defined $self->{COMPONENTS}{$name}) {
		$index = $self->{COMPONENTS}{$name}->{'index'};
	}
	elsif (!defined $index) {
	}
	elsif ($index !~ /^\d+$/) {
	}

	if ($type ne 'name' && $type ne 'road' && $type ne 'place' && $type ne 'bar') {
		print STDERR "Invalid type $type, in editcomponent call\n";
		die;
	}
	if ($adj ne 'yes' && $adj ne 'no') {
		print STDERR "Invalid adjust $adj, in editcomponent call\n";
		die;
	}
	my @fonts = ListFonts($self); 
	my $okay=0;
	foreach (@fonts) {
		if ($font eq $_){
			$okay=1;
			last;
		}
	}
	if (!$okay) {
		print STDERR "Invalid font, $font, requested.\n",
					 "Available fonts are :\n",
					 join("\n",@fonts),"\n";
		die;
	}

	#	Whew! input verified, lets apply it...

	$self->{COMPONENTS}{$name} = { type => $type,
	                               adj => $adj,
	                               'index' => $index,
								   font => $font};
	return ;
}

##########################################################
## Label definition                                     ##
##########################################################

#	definelabel(line #, component, component, ...)

sub definelabel {
	my $self = shift;
	my $line = shift;
	my @comps;

	if (!defined $line) { return $self->{LABELDEF};}

	if ($line eq 'clear') { # clear old definition
		$self -> {LABELDEF} = ();
		return;
	}

	if ($#_<0) {return $self->{LABELDEF}[$line];}

	if ($line !~ /^\d+$/) {
		print STDERR "Invalid line number $line, in definelabel call\n";
		die;
	}

	#	verify components exist

	my $postnet=0;
	foreach (@_) {
		push @comps, $_; # take this opportunity to do a deep copy...
		if ($_ eq 'postnet') {$postnet=1;}
		if (!defined $self->{COMPONENTS}{$_}) {
			print STDERR "Invalid component $_, in definelabel call\n";
			die;
		}
	}

	#	Make certain that if barcode is requested, it is the only component
	#	on that line

	if ($postnet && $#comps > 0) {
		print STDERR "postnet (barcode) must be the only component on the line, in definelabel call\n";
		die;
	}
	
	$self -> {LABELDEF}[$line] = \@comps;

	return ;
}

##########################################################
## Set the settings                                     ##
##########################################################

sub labelsetup {
	my $self = shift;
	my %args = @_;

	my %params;
	@params{ qw / papersize printable_left printable_right printable_top printable_bot output_top
		output_left output_width output_height x_gap y_gap number x_adjust y_adjust
		postnet font fontsize units firstlabel avery columns encoding / } = (0..21);

	my @papers = qw / Letter Legal Ledger Tabloid A0 A1 A2 A3 A4 A5 A6 A7 A8
                 A9 B0 B1 B2 B3 B4 B5 B6 B7 B8 B9 Envelope10 EnvelopeC5 
                 EnvelopeDL Folio Executive / ;

	my @encodings = qw / ISOLatin1Encoding StandardEncoding / ;

	foreach (keys %args) 
		{ 
			if (!defined $params{lc($_)}) {
				print STDERR "Invalid setup parameter $_\n";
				die;
			}
			if ( lc($_) eq 'font') {
				my @fonts = ListFonts($self); 
				my $okay=0;
				foreach my $font (@fonts) {
					if ($font eq $args{$_}){
						$okay=1;
						last;
					}
				}
				if (!$okay) {
					print STDERR "Invalid font, $args{$_}, requested.\n",
					             "Available fonts are :\n",
								 join("\n",@fonts),"\n";
					die;
				}
				$self->{SETUP}{lc($_)} = $args{$_}; 
			}
			elsif (lc($_) eq 'encoding') {
				my $okay=0;
				foreach my $encoding (@encodings) {
					if ($encoding =~ /$args{$_}/i){
						$okay=1;
						$args{$_} = $encoding;
						last;
					}
				}
				if (!$okay) {
					print STDERR "Invalid encoding, $args{$_}, requested.\n",
					             "Available values are :\n",
								 join("\n",@encodings),"\n";
					die;
				}
				$self->{SETUP}{lc($_)} = $args{$_}; 
			}
			elsif (lc($_) eq 'papersize') {
				my $okay=0;
				foreach my $paper (@papers) {
					if ($paper =~ /$args{$_}/i){
						$okay=1;
						$args{$_} = $paper;
						last;
					}
				}
				if (!$okay) {
					print STDERR "Invalid papersize, $args{$_}, requested.\n",
					             "Available sizes are :\n",
								 join("\n",@papers),"\n";
					die;
				}
				$self->{SETUP}{lc($_)} = $args{$_}; 
			}
			else {
				$self->{SETUP}{lc($_)} = lc($args{$_}); 
				$args{lc($_)} = $args{$_};
			}
		}
	
	#	convert all parameters to points

	my $f = 72;
	if ($self->{SETUP}{units} eq 'metric') {$f = 28.3465;}

	foreach (qw/output_left output_top output_width output_height printable_left printable_right printable_top printable_bot x_gap y_gap x_adjust y_adjust/) {
		if (defined $args{$_}) {$self->{SETUP}{$_} *= $f;}
	}	


	############  Process and verify parameters

	#	If avery code is defined, use it.
 # layout=>[paper-size,[list of product codes], description,
 #          number per sheet, left-offset, top-offset, width, height]
 #			distances measured in points
if (defined $self->{SETUP}{avery} && $self->{SETUP}{avery} ne '') {
		my $code = $self->{SETUP}{avery};
		$self->{SETUP}{papersize} = $self->{DATA}{AVERY}{$code}->[0]; 
		$self->{SETUP}{number} = $self->{DATA}{AVERY}{$code}->[3]; 
		$self->{SETUP}{output_left} = $self->{DATA}{AVERY}{$code}->[4]; 
		$self->{SETUP}{output_top} = $self->{DATA}{AVERY}{$code}->[5]; 
		$self->{SETUP}{output_width} = $self->{DATA}{AVERY}{$code}->[6]; 
		$self->{SETUP}{output_height} = $self->{DATA}{AVERY}{$code}->[7]; 
	}

	#	Verify that measurements sum correctly...

	if ($self->{SETUP}{columns} > 0) {
		my $pwidth = $self->{SETUP}{output_width}*$self->{SETUP}{columns} 
					 + $self->{SETUP}{x_gap}*($self->{SETUP}{columns}-1)
					 + $self->{SETUP}{output_left}*2;
		if (abs($pwidth - papersize($self)->[0]) > $self->{SETUP}{output_width}/2) {
			print STDERR "Sum of label widths ($pwidth) differs from paper width (",
			              papersize($self)->[0],
			             ") by > ",$self->{SETUP}{output_width}/2," points\n";
			die;
		}
	}
	return $self->{SETUP};
}



# ****************************************************************

	#	printable area : define width of borders
	#	printable_left, printable_right, printable_top, printable_bot

	#	output definition : define left and top offsets, width and
	#	height of a label
	#	output_left, output_top, output_width, output_height

	#	Other controls
	#	Postnet => 'yes' : print barcode on bottom for zip code
	#	Font => 'Helvetica'
	#	

# ****************************************************************
sub labelcalibration {
    my $self = shift;

	#	Create a postscript file that will place centered axes on the page
	#	marked off in inches or centimeters, that will allow the user to
	#	actually see what the rprintable area of their printer is.

	#	Calculate the following quantites to place in the postscript file :
	#	x and y coordinates of page center in points
	#	inc = 0.1 inch or 0.1 cm depending on units, but expressed in points
	#	numx and numy : number of inches or cm on each axis, rounded up.
	
	my $paperwidth = papersize($self)->[0] ; # total width of paper
	my $paperheight = papersize($self)->[1] ; # total height of paper
	my $xcenter = papersize($self)->[0]/2;
	my $ycenter = papersize($self)->[1]/2;

	my $inc = 7.2;
	if ($self->{SETUP}{units} eq 'metric') {$inc = 2.83465;}

	my $numx = int((($xcenter*2)/($inc*10))+0.9);
	my $numy = int((($ycenter*2)/($inc*10))+0.9);

	my $postscript = $self->{DATA}{CALIBRATE};

	$postscript =~ s/%pagesize%/<< \/PageSize [$paperwidth $paperheight]>> setpagedevice/g;
	$postscript =~ s/%xcenter%/$xcenter/g;
	$postscript =~ s/%ycenter%/$ycenter/g;
	$postscript =~ s/%inc%/$inc/g;
	$postscript =~ s/%numx%/$numx/g;
	$postscript =~ s/%numy%/$numy/g;

     return $postscript;
}

# ****************************************************************
sub labeltest {
    my $self = shift;

	#	Create a postscript file to test the calibration

	my $postscript = $self->{DATA}{TESTPAGE};

	my $cols = int(papersize($self)->[0] / ($self->{SETUP}{x_gap} + $self->{SETUP}{output_width}));
	my $rows = $self->{SETUP}{number}/$cols;

	my $paperwidth = papersize($self)->[0] ; # total width of paper
	my $paperheight = papersize($self)->[1] ; # total height of paper

	$postscript =~ s/%pagesize%/<< \/PageSize [$paperwidth $paperheight]>> setpagedevice/g;
	$postscript =~ s/%paperwidth%/papersize($self)->[0]/e ; # total width of paper
	$postscript =~ s/%paperheight%/papersize($self)->[1]/e ; # total height of paper
	$postscript =~ s/%boxwidth%/$self->{SETUP}{output_width}/e ; # label width
	$postscript =~ s/%boxheight%/$self->{SETUP}{output_height}/e ; # label height
	$postscript =~ s/%xgap%/$self->{SETUP}{x_gap}/e ; # x gap between labels
	$postscript =~ s/%ygap%/$self->{SETUP}{y_gap}/e ; # y gap between labels
	$postscript =~ s/%rows%/$rows/ ; # rows of labels on each page
	$postscript =~ s/%cols%/$cols/ ; # columns of labels on each page
	$postscript =~ s/%by%/$self->{SETUP}{output_top}/e ; # gap between top of first label and top of page

	# adjustments
	$postscript =~ s/%xadjust%/$self->{SETUP}{x_adjust}/e ; # adjustment if paper not x centered 
	$postscript =~ s/%yadjust%/$self->{SETUP}{y_adjust}/e ; # adjustment if paper not y centered
	$postscript =~ s/%lbor%/$self->{SETUP}{printable_left}/e ; # left border
	$postscript =~ s/%rbor%/$self->{SETUP}{printable_right}/e ; # right border 
	$postscript =~ s/%tbor%/$self->{SETUP}{printable_top}/e ; # top border
	$postscript =~ s/%bbor%/$self->{SETUP}{printable_bot}/e ; # bottom border

    return $postscript;
}

# ****************************************************************
#	Make mailing labels

sub makelabels {
    my $self = shift;
	my $addrs = shift;

#---------- set up preamble
	my $postscript = <<'LABELS';
%!PS

% This code copyright 1999, Alan Jackson, alan@ajackson.org and is
% protected under the Open Source license. Code may be copied and
% modified so long as attribution to the original author is
% maintained.

% Notes : the -15 points for the barcode is to produce the legally required
%         13.5 point gap above the codes
%         The barcode font must be 12 point or greater

LABELS
#---------- end preamble
	my $paperwidth = papersize($self)->[0] ; # total width of paper
	my $paperheight = papersize($self)->[1] ; # total height of paper
	$postscript .= "%	set the page size\n" .
	               "<< /PageSize [$paperwidth $paperheight]>> setpagedevice\n";
	if ($self->{SETUP}{postnet} eq 'yes') {
		$postscript .= $self->{DATA}{POSTNET}; # add in barcode stuff
	}

	my $cols = int(papersize($self)->[0] / ($self->{SETUP}{x_gap} + $self->{SETUP}{output_width}));
	my $rows = $self->{SETUP}{number}/$cols;

	my $boxwidth = $self->{SETUP}{output_width} ; # label width
	my $boxheight = $self->{SETUP}{output_height} ; # label height
	my $xgap = $self->{SETUP}{x_gap} ; # x gap between labels
	my $ygap = $self->{SETUP}{y_gap} ; # y gap between labels
	my $by = $self->{SETUP}{output_top} ; # gap between top of first label and top of page

	# adjustments
	my $xadjust = $self->{SETUP}{x_adjust} ; # adjustment if paper not x centered 
	my $yadjust = $self->{SETUP}{y_adjust} ; # adjustment if paper not y centered
	my $lbor = $self->{SETUP}{printable_left} ; # left border
	my $rbor = $self->{SETUP}{printable_right} ; # right border 
	$rbor = $paperwidth - $rbor;
	my $tbor = $self->{SETUP}{printable_top} ; # top border
	my $bbor = $self->{SETUP}{printable_bot} ; # bottom border

	my $fontsize = $self->{SETUP}{fontsize};
	my $font = $self->{SETUP}{font};
	
	#	Can I fit all the rows desired onto the page?

	if (($rows*$boxheight + $by) > ($paperheight - $bbor)) {
		$rows--; # not enough room, drop the last row.
	}

#	Build arrays of sx, y, and width that define the locations and widths
#	of all the labels on a page. They are numbered starting at the top left,
#	going across and then down.
	
	my @y_arr = qw/0/;
	my @x_arr = qw/0/;
	my @w_arr = qw/0/;

	my ($sx,$ex); # start x, end x for each label
	my $bx = ($paperwidth - ($cols-1)*$xgap - $boxwidth*$cols)/2; # begin x
	my $y = $paperheight - $by - $yadjust; # initial y position
	for (my $r=1;$r<=$rows;$r++) {
		my $x = $bx;
		for (my $c=1;$c<=$cols;$c++) {
			if ($x < $lbor) { $sx = $lbor;} # adjust leftmost label
			else {$sx = $x;}
			$x += $boxwidth;
			if ( $x > $rbor) {$ex = $rbor} # adjust rightmost labelh
			else {$ex = $x;}
			$x += $xgap;
			my $width = $ex - $sx;
			$sx += $xadjust;
			push @y_arr,$y;
			push @x_arr,$sx+$xadjust+5;
			push @w_arr,$width-10; # leave 5 points slop on both ends.
		}
		$y = $y - $boxheight - $ygap;
	}

	#	set the desired font and size
	#The following lines have been modified to account for Portuguese characters
	# Nuno Faria, 2000/Mars/03
	$postscript .= "/$font findfont\n".
	               "dup length dict begin\n".
		           "{1 index /FID ne {def} {pop pop} ifelse} forall\n".
			   	   "/Encoding $self->{SETUP}{encoding} def\n".
			       "currentdict\n".
			       "end\n".
		           "/$font exch definefont pop\n";
	#End of modifications


	$postscript .= "/$font findfont $fontsize scalefont setfont\n".
	               "/fontsize $fontsize def\n";

	#	scroll through the address array, building the commands
	#	to print. Test each field to see if it will fit on the
	#	label. If it is too long, do some "intelligent" shortening.

	my $lab = $self->{SETUP}{firstlabel};
	foreach (@{$addrs}){
		my $linenum = 1;
		foreach my $line (@{$self->{LABELDEF}}) {
			my @text = prepare_text($self, $_, $line, $w_arr[$lab]);
			next if length(join('',@text)) == 0; # data-less line
			$postscript .= "/sx $x_arr[$lab] def /y $y_arr[$lab] def\n";
			$postscript .= "/cury y fontsize $linenum mul sub def\n";
			$postscript .= "sx cury moveto\n";
			foreach my $comp (@{$line}) {
				$postscript .= "/$self->{COMPONENTS}{$comp}->{font} findfont $fontsize scalefont setfont\n";
				my $text = shift @text;
				if ($self->{COMPONENTS}{$comp}->{'type'} eq 'bar') { # barcode
					#$postscript .= "gsave\n";
					$postscript .= "/fontsize 12 def\n";
					$postscript .= "/PostNetJHC findfont fontsize scalefont setfont\n";
					$postscript .= "/cury cury 15 sub def\n";
					$postscript .= "/cury y fontsize $linenum mul sub def\n";
					$postscript .= "sx cury moveto\n";
					$postscript .= "($text) show\n";
					$postscript .= "/$font findfont $fontsize scalefont setfont\n".
								   "/fontsize $fontsize def\n";
					#$postscript .= "grestore\n";
				}
				else { # not barcode
				$postscript .= "($text) show\n";
				}
			}
			$linenum++;
		}
		$lab++;
		if ($lab > $rows*$cols) { # end of page
			$postscript .= "showpage\n% ------- start new page\n\n";
			$lab = 1;
		}
	}
	$postscript .= "showpage\n% ------- end of data\n" unless $lab == 1;


	return $postscript;
}

sub prepare_text {
	my $self = shift;
	my $addrs = shift;
	my $line = shift;
	my $width = shift;

	my @text ; # array to be returned

	#	If barcode, handle and return

	if ($self->{COMPONENTS}{$line->[0]}->{'type'} eq 'bar') { # trim barcode
		my $text = $_->[$self->{COMPONENTS}{$line->[0]}->{'index'}]; 
		$text = trimbar($self,$text,
			$addrs->[$self->{COMPONENTS}{'street'}->{'index'}], $width);
		return $text;
	}

	#	If it's not Standard Encoding, then I don't know how to calculate
	#	the string length, so I can't do any trimming for you. Maybe later...

	if ($self->{SETUP}{encoding} ne 'StandardEncoding') {
		foreach my $comp (@{$line}) {
			my $text = $addrs->[$self->{COMPONENTS}{$comp}->{'index'}] . " "; 
			push @text, $text;
		}
		chop $text[-1];
		return @text;
	}

	#	Find longest adjustable string

	my $fontsize = $self->{SETUP}{fontsize};
	my ($type, $adjcomp, $maxlen, $totlen) = (0,0,0,0);
	my $strlen = $width;
	foreach my $comp (@{$line}) {
		my $text = $addrs->[$self->{COMPONENTS}{$comp}->{'index'}] . " "; 
		my $length = stringlen($self,"$text",$self->{COMPONENTS}{$comp}->{font}, $fontsize);
		$totlen += $length;
		if ($self->{COMPONENTS}{$comp}->{'adj'} eq 'yes') {
			if ($maxlen < $length) {
				$maxlen = $length;
				$adjcomp = $comp;
				$type = $self->{COMPONENTS}{$comp}->{'type'};
			}
		}
		push @text, $text;
	}

	#	trim back the longest adjustable string, if necessary

	if ($maxlen == 0 || $totlen <= $width) { # trimming not possible / needed
		chop $text[-1];
		return @text;
	}

	$strlen -= ($totlen - $maxlen); # how much space is left?
	if ($type eq 'name') {
		$addrs->[$self->{COMPONENTS}{$adjcomp}->{'index'}] = 
			trimname ($self,$addrs->[$self->{COMPONENTS}{$adjcomp}->{'index'}],$strlen);
	}
	elsif ($type eq 'road') {
		$addrs->[$self->{COMPONENTS}{$adjcomp}->{'index'}] = 
			trimaddr ($self,$addrs->[$self->{COMPONENTS}{$adjcomp}->{'index'}],$strlen);
	}
	elsif ($type eq 'place') {
		$addrs->[$self->{COMPONENTS}{$adjcomp}->{'index'}] = 
			trimcity ($self,$addrs->[$self->{COMPONENTS}{$adjcomp}->{'index'}],$strlen);
	}

	#	build output array
	@text = ();
	foreach my $comp (@{$line}) {
		my $text = $addrs->[$self->{COMPONENTS}{$comp}->{'index'}] . " "; 
		push @text, $text;
	}
	chop $text[-1];
	return @text;
}

# ****************************************************************
# Intelligently trim back name if needed
sub trimname {
	my $self = shift;
	my $name = shift;
	my $width = shift;

	$name =~ s/^\s*//;
	$name =~ s/\s*$//;

	my $strwidth = stringwidth($self,"$name");
	
	if ($strwidth > $width) {
		my $nchar = (($strwidth-$width)/$strwidth)*length($name); # approx # extra chars

		if ($name =~ / and / ) {
			$name =~ s/ and / & /;
			$nchar -= 2;
		}
		if ($nchar > 0) {
			#	Trim first names, leaving last name intact
			$name = substr($name,0,(length($name)-$nchar));
		}
		$strwidth = stringwidth($self,$name);
		if ($strwidth > $width) {chop $name;}
	}
	return $name;
}

# ****************************************************************
# Intelligently trim back street address if needed
sub trimaddr {
	my ($self, $addr, $width) = @_;

	$addr =~ s/^\s*//;
	$addr =~ s/\s*$//;

	my $strwidth = stringwidth($self,$addr);
	
	if ($strwidth > $width) {
		$addr =~ s/\.//g;
		$addr =~ s/\s*rd$//i;
		$addr =~ s/\s*ave$//i;
		$addr =~ s/\s*st$//i;
		$addr =~ s/\s*ln$//i;
		$strwidth = stringwidth($self,$addr);
		if ($strwidth > $width) {
			my $nchar = (($strwidth-$width)/$strwidth)*length($addr); # approx # extra chars
			$addr = substr($addr,0,(length($addr)-$nchar));
		}
	}
	return $addr;
}

# ****************************************************************
# Intelligently trim back city if needed
sub trimcity {
	my ($self, $city, $width) = @_;

	$city =~ s/^\s*//;
	$city =~ s/\s*$//;

	my $strwidth = stringwidth($self,$city);
	
	if ($strwidth > $width) {
		my $nchar = (($strwidth-$width)/$strwidth)*length($city); # approx # extra chars
		$city = substr($city,0,(length($city)-$nchar));
	}
	return $city;
}

# ****************************************************************
# Intelligently set up for barcode
sub trimbar {
	my ($self, $zip, $street, $width) = @_;

	if (!defined $zip || length($zip) < 5) {
		return ' ';
	}

	$zip =~ s/^\s*//;
	$zip =~ s/\s*$//;
	$street =~ s/^\s*//;
	$street =~ s/\s*$//;

	$zip =~ s/\-//;
	if ($zip =~ /[^0-9]/) {
		print STDERR "not a US zipcode : $zip\n";
		return ' ';
	}

	my $keepfont = $self->{SETUP}{font};
	my $keepfontsize = $self->{SETUP}{fontsize};
	$self->{SETUP}{font} = 'PostNetJHC';
	$self->{SETUP}{fontsize} = 12;

	my $zip5 = substr($zip,0,5);
	my $zipcode = 'I' . $zip5 . chksum($zip5) . "I";

	my $strwidth = stringwidth($self,$zipcode);
	if ($strwidth > $width) { # can't make it short enough
		$self->{SETUP}{font} = $keepfont;
		$self->{SETUP}{fontsize} = $keepfontsize;
		return ' ';
	}

	if (length($zip) == 5) {
		$self->{SETUP}{font} = $keepfont;
		$self->{SETUP}{fontsize} = $keepfontsize;
		return $zipcode;
	}

	if (length($zip) != 9) {
		print STDERR "error in zipcode $zip\n";
		$self->{SETUP}{font} = $keepfont;
		$self->{SETUP}{fontsize} = $keepfontsize;
		return $zipcode;
	}
	
	my $zip_plus = 'I' . $zip . chksum($zip) . "I";
	$strwidth = stringwidth($self,$zip_plus);
	$self->{SETUP}{font} = $keepfont;
	$self->{SETUP}{fontsize} = $keepfontsize;
	if ($strwidth > $width) { 
		return $zipcode;
	}
	return $zip_plus;
}

sub chksum {
	my $num = shift;
	return (10 - eval(join('+',(split(//,$num))))%10)%10;
}

# ****************************************************************
#	return label description : Output_Left Output_Top Output_Width Output_Height

sub labeldata {
    my $self = shift;

    return [ $self->{SETUP}{output_left},
             $self->{SETUP}{output_top},
             $self->{SETUP}{output_width},
             $self->{SETUP}{output_height},
	       ];
}

# ****************************************************************
#	return the avery layout code given a product code
sub averycode {
    my $self = shift;
	my $product = shift;

 # layout=>[paper-size,[list of product codes], description,
 #          number per sheet, left-offset, top-offset, width, height]
 #			distances measured in points

	foreach (keys %{$self->{DATA}{AVERY}}) {
		if (grep /$product/,@{$self->{DATA}{AVERY}{$_}->[1]}) {
			return $_;
		}
	}

    return 0;
}

# ****************************************************************
#	return the avery data
sub averydata {
    my $self = shift;

 # layout=>[paper-size,[list of product codes], description,
 #          number per sheet, left-offset, top-offset, width, height]
 #			distances measured in points

    return $self->{DATA}{AVERY};
}

# ****************************************************************
#		Return width & height of paper
sub papersize {
    my $self = shift;

    return [$self->{DATA}->{WIDTH}{$self->{SETUP}{papersize}},
	        $self->{DATA}->{HEIGHT}{$self->{SETUP}{papersize}},];
}

# ****************************************************************
#		Return paper names
sub papers {
    my $self = shift;

    return $self->{DATA}->{PAPER};
}


sub stringlen {
   my ($self,$string,$fontname,$fontsize) = @_;
   my $returnval = 0;
  
   foreach my $char (unpack("C*",$string)) {
       $returnval+=$self->{DATA}->{FONTS}{$fontname}->[$char-32];
   }
   return ($returnval*$fontsize/1000);

}

sub stringwidth {
   my ($self,$string,) = @_;
   my $returnval = 0;
   my $fontname = $self->{SETUP}{font};
   my $fontsize = $self->{SETUP}{fontsize};
  
   foreach my $char (unpack("C*",$string)) {
       $returnval+=$self->{DATA}->{FONTS}{$fontname}->[$char-32];
   }
   return ($returnval*$fontsize/1000);

}


sub ListFonts {
	my $self = shift;
    my @tmp = %{$self->{DATA}->{FONTS}};
    my @returnval =();
    while (@tmp) {
        push @returnval, shift(@tmp);   
	shift @tmp;
    }
    return sort( {$a cmp $b;} @returnval);
}

1;
__END__

=head1 NAME

PostScript::MailLabels - Modules for creating PostScript(tm) files of mailing address labels.

=head1 SYNOPSIS

Modules for creating PostScript(tm) files of mailing address labels, to be
printed on standard adhesive-backed mailing label stock.  Flexible enough to
tackle other printing tasks, basically anything requiring a set fields be
printed on a regular grid.  Also creates PostScript(tm) code for calibrating
and testing mailing label printing.


=head1 DESCRIPTION

The module has three distinct output modes. In my experience, printing
mailing labels is a matter of tweaking parameters to get them all to
fit properly on the page. This module is designed with this in mind.

The first output is the calibration sheet. This is a pair of annotated
axes, either in inches or centimeters, centered on the page and covering the
whole page in X and Y directions. The intent is for you to output this
page first, and simply read off the relevant page dimensions directly.

The second output is the label test. This output is a series of boxes drawn on
the page, meant to outline the edges of all the mailing labels.  Take this
sheet and line it up with a sheet of labels to see if they actually match
perfectly. If not, tweak the parameters until they do. Note that sometimes you
will get a message at the bottom of the sheet saying "Bottom gap too large,
last row cannot be printed". This means that the printable area of your printer
is too small to utilize the last row of labels. I have this problem. But I
handle it for you. Note also the arrows on the test sheet. As you hold the test
sheet over a sheet of labels, hold it up to the light and slide the test sheet
so that the boxes match the edges of the labels. If you slide in the arrow
direction, that is a positive adjustment. The other direction is negative. If
the edges of some boxes come out dashed, that means that the non-printing
border cuts off the end of the label, so I will adjust the printing area
appropriately. Don't try to line up the dashed lines with label edges - it
won't work. Just line up the solid lines.

The third output is the labels themselves. By default, I have set up a
US-centric address definition :

    firstname, lastname, street address, city, state, zipcode

But with version 2.0, you can now create your own definition. You can define
new fields, and you can define how those fields land on a label. You can also
control the fonts on a per-field basis. Not the size, yet - later pilgrim.

Parameters you can set :

Paper size, borders on the printable area (many printers will not print
right up to the edge of the paper), where the labels live on the page
and how big they are, overall x-y shift of page, whether or not to 
print PostNET barcode, font, fontsize, units (english or metric),
which Avery(tm) product code to use, and where the first label starts.

This last needs explanation. If you have a partially used sheet of labels,
you might want to use it up. So you count the missing labels, starting
at the upper left, and counting across, and then down. For example, if
I have 3 columns of labels, label five is the second label in the second
row.

The Avery(tm) label codes are woefully incomplete. I can't find the Avery(tm)
specs anywhere, so the ones that are in there are for products I personally
own.  I e-mailed Avery(tm) and they gave me a long distance phone number to
call.

If you have an Avery(tm) product that I haven't defined, send me the specs and 
I'll add it.

Also, if there is another brand of labels that you use, send me the relevant
data and I'll add that as well. I suspect that there must be some other vendor
in Europe, but I don't know who that would be.

When setting up the addresses, I check to see if they will fit on the label.
If not, I try to shorten them semi-intelligently until they fit. This part
could use quite a bit more work, if done right it probably merits a module all
it's own.

Briefly, for the name line, I start trimming the ends off the first name, and
leave the last name alone.

For the street, I look for things like Road or Avenue and nuke those first,
then I trim the street name from the right.

For the last line, I trim the city and leave the state and zip alone.

The barcode will be either a 5-digit zip or 9 digit zip-plus code. I could
also create the delivery point code, but since my mailing labels are not
even wide enough for the 9 digit zip-plus, I haven't bothered. I have read
the USPS spec on the barcode, and so far as I can tell, I meet the spec.

labelsetup :
    
All the distances are in units of inches or centimeters, depending on the Units flag.
A hash of the label definition will be returned.
	
    my $setup = $labels -> labelsetup( 

        #    paper size

        PaperSize        => 'Letter',
        options are : 
                    Letter Legal Ledger Tabloid A0 A1 A2 A3 A4 A5 A6 A7 A8
                    A9 B0 B1 B2 B3 B4 B5 B6 B7 B8 B9 Envelope10 EnvelopeC5 
                    EnvelopeDL Folio Executive 
            
        #   printable area on physical page - these numbers represent border widths
        #    typical values might be 0.25 inches

        Printable_Left   => 0.0,
        Printable_Right  => 0.0,
        Printable_Top    => 0.0,
        Printable_Bot    => 0.0,

        #    define where the labels live (ideally)

        Output_Top     => 1.0, where does the top of the first label sit?
        Output_Left    => 0.5, where is the left edge of the first label?
        Output_Width   => 3.0, how wide are the labels?
        Output_Height  => 2.0, how tall are the labels?
        X_Gap          => 0.1, what is the vertical gap between labels?
        Y_Gap          => 0.0, what is the horizontal gap between labels?
        Number         => 30,  how many labels per page?
        Columns        => 3,   how many columns per page? (optional)

        if the number of columns are given, I'll check your math to see if the page
        width approximately equals the sum of the label widths plus gaps etc.

        #    Adjustments for printer idiosyncracies

        X_Adjust       => 0.0, shift the whole thing over by this amount.
        Y_Adjust       => 0.0  shift the whole thing down by this amount.

        #    Other controls

        Postnet    => 'yes',  barcodes? yes or no
        Font       => 'Helvetica', which default font? see below for generating a list
        FontSize   => 12, how big are they?
        Units      => 'english', english or metric
        FirstLabel => 1, where is the first label (begins at 1).

        # set equal to the Avery(tm) product code, and the label description
        # will be updated from the database.
        Avery        => undef,
        );

        generate a PostScript(tm) file with rulers on it for making measurements
    $output = $labels->labelcalibration ;
        generate a PostScript(tm) file with boxes showing where the text will land
    $output = $labels->labeltest ;
        the main event - make me a label file
    $output = $labels->makelabels(\@addrs) ;

        translate an Avery(tm) product code into a template code.
    $templatecode = $labels->averycode($product_code) ;
        retrieve an array of the paper width, height (in points)
    @width_height = @{ $labels->papersize } ;
        get the length of a string in points using the current font
    $stringwidth = $labels->stringwidth("This is a string") ;
        get a list of the available fonts
    @fontname = $labels->ListFonts;

    Components:

    Each component has a name, and four attributes. The attributes are :
        type : must be name, road, place, or bar. This defines the trimming
               strategy. 
        adj : yes or no. Is trimming allowed?
        font : what font to use
        index : which entry in the input array will contain this component?

    Default components :
        #    first name
        fname    => { type => 'name', adj => 'yes', font => 'Helvetica', 'index' => 0 },
        #    last name
        lname    => { type => 'name', adj => 'yes', font => 'Helvetica', 'index' => 1 },
        #    street address and street
        street    => { type => 'road', adj => 'yes', font => 'Helvetica', 'index' => 2 },
        #    city
        city    => { type => 'place', adj => 'yes', font => 'Helvetica', 'index' => 3 },
        #    state
        state    => { type => 'place', adj => 'no', font => 'Helvetica', 'index' => 4 },
        #    country
        country    => { type => 'place', adj => 'no', font => 'Helvetica', 'index' => 6 },
        #    zip
        zip    => { type => 'place', adj => 'no', font => 'Helvetica', 'index' => 5 },
        #    postnet (bar code)
        postnet    => { type => 'bar', adj => 'no', font => 'PostNetJHC', 'index' => 5 },

    Editing components : with editcomponent

    #    What address components are available?
    print "components : ",join(' : ',@{$labels->editcomponent()}),"\n";

    #    Lets make the lname (lastname) bold-faced
    $labels->editcomponent('lname', 'name', 'no', 1, 'Times-Bold' );

    #    Lets create a new component
    $labels->editcomponent('company_name', 'name', 'yes', 7, 'Times-Bold');

    Label definition

    We define the label layout line by line, by describing for each line which
    components we want printed, and in what order.

    #    Default label definition
        #    line 1
        [ 'fname', 'lname' ],
        #    line 2
        [ 'street', ],
        #    line 3
        [ 'city', 'state', 'zip' ],
        #    line 4
        [ 'postnet', ],

    edit the label definition with definelabel :

    definelabel(line number, component, component, ...)

    #    first clear the old (default) definition
    $labels->definelabel('clear');
    #                   line number, component list
    $labels->definelabel(0,'pgm_name','version');
    $labels->definelabel(1,'blank',);
    $labels->definelabel(2,'author',);
    $labels->definelabel(3,'blank',);
    $labels->definelabel(4,'comments-1',);
    $labels->definelabel(5,'comments-2',);
    $labels->definelabel(6,'comments-3',);



=head1 EXAMPLE


    #!/usr/bin/perl -w

    #        This shows the capabilities of the program...

    use PostScript::MailLabels 2.0;

    $labels = PostScript::MailLabels->new;

    #####################################################################`
    #    Dumping information from the modules 
    #####################################################################`

    #    What address components are available?
    print "\n****** components ******\n";
    print join(' : ',@{$labels->editcomponent()}),"\n";

    #    What is the current label layout?
    print "\n****** layout ******\n";
    my @layout = @{$labels->definelabel()};
    foreach (@layout) {
        print join(' : ',@{$_}),"\n";
    }

    #    Here is how to list the available fonts
    print "\n****** fonts ******\n";
    @fonts = $labels->ListFonts;
    foreach (@fonts) {
        print "$_\n";
    }

    #    Here is how to list the available papers
    print "\n****** papers ******\n";
    print join(' : ',@{$labels->papers}),"\n";

    #    Here is how to list all th Avery data
     # layout=>[paper-size,[list of product codes], description,
     #          number per sheet, left-offset, top-offset, width, height]
     #            distances measured in points

    my %avery = %{$labels->averydata};
    print "\n****** Avery(tm) data ******\n";
    foreach (keys %avery) {
        print "$_ : $avery{$_}->[0] : ",
               join(', ',@{$avery{$_}->[1]})," : ",
               join(' : ',@{$avery{$_}}[2-7]),"\n";
    }


    #    Here are some more utilities

    print "\nString width of 'this is a test' = ", 
            $labels->stringwidth("this is a test",)/72," inches\n";

    my $setup = $labels -> labelsetup( Font => 'PostNetJHC');

    print "\nzip code tests, 6,9, and 12 digit lengths barcodes:  ", 
            $labels->stringwidth("123456",)/72," : ",
            $labels->stringwidth("123456789",)/72," : ",
            $labels->stringwidth("123456789012",)/72,
            " inches\n";

    print "\nPaper size Letter = ",($labels->papersize)->[0]," x ",
                                 ($labels->papersize)->[1]," in points\n";

    print "\nAvery(t) code for 8460 is >",$labels->averycode(8460),"<\n";

    #    Simple setup using predefined Avery label
    $labels -> labelsetup(
                Avery       => $labels->averycode(8460),
                PaperSize   => 'letter',
                Font        => 'Times-Roman',
                );

    print "\n                 num, left, top, width, height\n";
    print "label description : ", $setup->{number}, " : ",
                                  $setup->{output_left}, " : ",
                                  $setup->{output_top}, " : ",
                                  $setup->{output_width}, " : ",
                                  $setup->{output_height}, "\n";

    #    More hands-on setup defining everything. Note that Columns is optional
    $labels->labelsetup( 
                        Units           => 'English',
                        PaperSize       => 'A4',

                        Printable_Left  => 0.25,
                        Printable_Right => 0.25,
                        Printable_Top   => 0.0,
                        Printable_Bot   => 0.55,
                        
                        Output_Top      => 0.5, 
                        Output_Left     => 0.0,
                        Output_Width    => 2.625, 
                        Output_Height   => 1.0, 
                        X_Gap           => 0.16,
                        Y_Gap           => 0.0,
                        Number          => 30,
                        Columns         => 3,

                        #    Adjustments for printer idiosyncracies

                        X_Adjust   => 0.05,
                        Y_Adjust   => 0.05,

                        PostNet    => 'yes',
                        Font       => 'Helvetica',
                        FontSize   => 12,
                        FirstLabel => 1,
                       );

    #    We can fiddle the components...

    #    Lets make the lname (lastname) bold-faced
    print "\n******* make the lname field boldfaced *******\n";
    print "lname : ",join(' : ',@{$labels->editcomponent('lname')}),"\n";
    $labels->editcomponent('lname', 'name', 'no', 1, 'Times-Bold' );
    print "lname : ",join(' : ',@{$labels->editcomponent('lname')}),"\n";

    #    Lets switch the default ordering on the label from first-last to last-first
    print "\n******* swap order from first-last to last-first *******\n";
    print "Line 1 : ",join(' : ',@{$labels->definelabel(0)}),"\n";
    $labels->definelabel(0,'lname','fname');
    print "Line 1 : ",join(' : ',@{$labels->definelabel(0)}),"\n";

    #        print calibration sheet, in metric

    $labels->labelsetup( Units =>'metric');
    my $output = $labels->labelcalibration;
    open (FILE,"> calibration.ps") || warn "Can't open calibration.ps, $!\n";
    print FILE $output;
    close FILE;
    print "\n******* metric Letter sized calibration sheet in calibration.ps *******\n";

    #        adjust printable area and draw test boxes

    $output = $labels->labeltest;
    open (FILE,"> boxes.ps") || warn "Can't open boxes.ps, $!\n";
    print FILE $output;
    close FILE;
    print "\n******* Letter sized test boxes sheet in boxes.ps *******\n";

    #########################################################################
    #    Build a test address array
    # address array elements are : first,last,street_addr,city,state,zip
    my @addrs;
    my @address;
    my $indx = 0;
    foreach (<DATA>) {
        chomp;
        if ($indx%4 == 0) {
            @address = (split(':',$_));
        }
        elsif ($indx%4 == 1) {
            push @address,$_;
        }
        elsif ($indx%4 == 2) {
            push @address,(split(':',$_));
        }
        elsif ($indx%4 == 3) {
            push @addrs,[@address];
        }
        $indx++;
    }

    foreach (@addrs) {
        print "Address : $_->[0] $_->[1] $_->[2] $_->[3] $_->[4] $_->[5]\n";
    }

    #    Set up a few things...

    $setup = $labels -> labelsetup( Font         => 'Helvetica');
    $setup = $labels -> labelsetup( FirstLabel   => 25);
    $setup = $labels -> labelsetup( Output_Width => 2.625), 
    $setup = $labels -> labelsetup( Columns      => 3), 

    $output = $labels->makelabels(\@addrs);
    open (OUT,">labeltest.ps") || die "Can't open labeltest.ps, $!\n";
    print OUT $output;
    close OUT;
    print "\n******* label output in  labeltest.ps *******\n";

    1;

    __DATA__
    John and Jane:Doe
    1234 Robins Nest Sitting In a Tree Ave 
    Katy:Tx:77453

    William:Clinton
    1300 Pennsylvania Ave.
    Washington:DC:10000

    Shirley:Temple
    98765 Birch Point Drive 
    Houston:TX:78450

    Fred & June:Cleaver
    11221 Beaver Rd 
    Columbus:OH:07873-6305

    Ernest and Julio:Gallo
    1987 Chardonnay 
    San Jose:CA:80880

    Orville and Wilbur:Wright
    7715 Kitty Hawk Dr 
    Kitty Hawk:NC:87220

    Ulysses:Grant
    1856 Tomb Park Rd 
    Washington:DC:10012


=head1 BUGS AND TODO LIST

No bugs, that I am aware of.

To do list :

=over 4

=item +

Need to be able to get the length of a string in ISOLatin1

=item +

Add fontsize to each component

=item +

Account for label height - currently will run off bottom

=item +

Separate module for address compression/abbreviation

=item +

Add bitmaps or images?

=back

=head1 REVISION HISTORY

	Version 2.0 - December 2000
	Major revision. Added all of the component and label definition stuff. 
	Thanks to "Andrew Smith" <asmith at wpequity.com> for suggesting
	additional fields and inspiring the generalization.
	Thanks to Nuno Faria for assisting with the "Europeanization" of
	the code - it now works for Portuguese, and hopefully for other
	alphabets as well.
	Added pagesize so that various paper sizes are actually handled correctly.

	Version 1.0.1 - December 2000
	Bug reported by John Summerfield <summer at OS2.ami.com.au>
	Lowercase all SETUP parameters to avoid problems with mis-spellings.
	Do real parameter checks to check simple spelling errors.

	Bug reported by Nuno Faria <nfaria at fe.up.pt>
	Boxes plot did not work. Frankly I can't figure out how it ever did. Anyway
	it breaks on more modern versions of ghostscript, so I fixed it. Basically
	rewrote part of the PostScript(tm) code.

=head1 AUTHOR

    Alan Jackson
    October 1999
    alan@ajackson.org

    The PostNET font was gotten (under Gnu copyleft) from
    James H. Cloos, Jr. <cloos@jhcloos.com>

    The font metrics and paper sizes were pulled from the
    PostScript::Metrics module written by Shawn Wallace

=cut

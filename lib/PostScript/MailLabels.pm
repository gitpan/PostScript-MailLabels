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

$VERSION = '1.01';

use Carp;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};

	$self->{SETUP} = {};

	$self->{MAKEBOX} = ''; # ps code to draw a box
	$self->{MAKERULE} = ''; # ps code to make rulers
	$self->{PRTTEXT} = ''; # ps code to output the text
	$self->{PRTBAR} = ''; # ps code to outptu the barcode

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

		papersize		=> 'letter',
			
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

		#	Adjustments for printer idiosyncracies

		x_adjust		=> 0.0,
		y_adjust		=> 0.0,

		#	Other controls

		postnet		=> 'yes',
		font		=> 'Helvetica',
		fontsize 	=> 12,
		units    	=> 'english',
		firstlabel	=> 1,

		# set equal to the Avery(tm) product code, and the label description
		# will be updated from the database.
		avery		=> undef,

				   );
	
	#	Go get the basic data

	$self->{DATA} = new PostScript::MailLabels::BasicData;
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
		postnet font fontsize units firstlabel avery / } = (0..19);

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
			}
			$self->{SETUP}{lc($_)} = $args{$_}; 
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

	if (defined $self->{SETUP}{avery}) {
		my $code = $self->{SETUP}{avery};
		$self->{SETUP}{papersize} = $self->{DATA}{AVERY}{$code}->[0]; 
		$self->{SETUP}{number} = $self->{DATA}{AVERY}{$code}->[3]; 
		$self->{SETUP}{output_left} = $self->{DATA}{AVERY}{$code}->[4]; 
		$self->{SETUP}{output_top} = $self->{DATA}{AVERY}{$code}->[5]; 
		$self->{SETUP}{output_width} = $self->{DATA}{AVERY}{$code}->[6]; 
		$self->{SETUP}{output_height} = $self->{DATA}{AVERY}{$code}->[7]; 
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
	
	my $xcenter = papersize($self)->[0]/2;
	my $ycenter = papersize($self)->[1]/2;

	my $inc = 7.2;
	if ($self->{SETUP}{units} eq 'metric') {$inc = 2.83465;}

	my $numx = int((($xcenter*2)/($inc*10))+0.9);
	my $numy = int((($ycenter*2)/($inc*10))+0.9);

	my $postscript = $self->{DATA}{CALIBRATE};

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

/makelabel {
				/barcode exch def
				/city exch def
				/street exch def
				/name exch def
				sx y fontsize sub moveto
			    name show
				sx y fontsize 2 mul sub moveto
			    street show
				sx y fontsize 3 mul sub moveto
			    city show
				gsave
				/fontsize 12 def
				/PostNetJHC findfont fontsize scalefont setfont
				sx y 15 sub fontsize 4 mul sub moveto
			    barcode show
				grestore
           } def
%/ this just fools my editor into correct highlighting

LABELS
#---------- end preamble
	$postscript .= $self->{DATA}{POSTNET}; # add in barcode stuff

	my $cols = int(papersize($self)->[0] / ($self->{SETUP}{x_gap} + $self->{SETUP}{output_width}));
	my $rows = $self->{SETUP}{number}/$cols;

	my $paperwidth = papersize($self)->[0] ; # total width of paper
	my $paperheight = papersize($self)->[1] ; # total height of paper
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

	$postscript .= "/$font findfont $fontsize scalefont setfont\n".
	               "/fontsize $fontsize def\n";

	#	scroll through the address array, building the commands
	#	to print. Test each field to see if it will fit on the
	#	label. If it is too long, do some "intelligent" shortening.

	#	Addresses stored as [first, last, street, city, state, zip]

	my $lab = $self->{SETUP}{firstlabel};
	foreach (@{$addrs}){
		my $name = trimname($self,$_->[0],$_->[1], $w_arr[$lab]);
		my $street = trimaddr($self,$_->[2], $w_arr[$lab]);
		my $city = trimcity($self,$_->[3],$_->[4],$_->[5], $w_arr[$lab]);
		my $bar = trimbar($self,$_->[5],$_->[2], $w_arr[$lab]);
		if ($self->{SETUP}{postnet} ne 'yes') {$bar = '';}

		$postscript .= "/sx $x_arr[$lab] def /y $y_arr[$lab] def\n";
		$postscript .= "($name) ($street) ($city) ($bar) makelabel\n";

		$lab++;
		if ($lab > $rows*$cols) { # end of page
			$postscript .= "showpage\n% ------- start new page\n\n";
			$lab = 1;
		}
	}
	$postscript .= "showpage\n% ------- end of data\n" unless $lab == 1;


	return $postscript;
}

# ****************************************************************
# Intelligently trim back name if needed
sub trimname {
	my ($self, $fname, $lname, $width) = @_;

	$fname =~ s/^\s*//;
	$fname =~ s/\s*$//;
	$lname =~ s/^\s*//;
	$lname =~ s/\s*$//;

	my $name = $fname . " " . $lname;

	my $strwidth = stringwidth($self,"$name");
	
	if ($strwidth > $width) {
		my $nchar = (($strwidth-$width)/$strwidth)*length($name); # approx # extra chars

		if ($fname =~ / and / ) {
			$fname =~ s/ and / & /;
			$nchar -= 2;
		}
		if ($nchar > 0) {
			#	Trim first names, leaving last name intact
			$fname = substr($fname,0,(length($fname)-$nchar));
		}
		$name = $fname . " " . $lname;
		$strwidth = stringwidth($self,$name);
		if ($strwidth > $width) {chop $fname;}
	}
	$name = $fname . " " . $lname;
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
# Intelligently trim back city, state zip if needed
sub trimcity {
	my ($self, $city, $state, $zip, $width) = @_;

	$city =~ s/^\s*//;
	$city =~ s/\s*$//;
	$state =~ s/^\s*//;
	$state =~ s/\s*$//;
	$zip =~ s/^\s*//;
	$zip =~ s/\s*$//;

	my $citystate = $city.",".$state." ".$zip;

	my $strwidth = stringwidth($self,$citystate);
	
	if ($strwidth > $width) {
		my $nchar = (($strwidth-$width)/$strwidth)*length($citystate); # approx # extra chars
		$city = substr($city,0,(length($citystate)-$nchar));
	}
	$citystate = $city.",".$state." ".$zip;
	return $citystate;
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
#		Return width & height of paper
sub papersize {
    my $self = shift;

    return [$self->{DATA}->{WIDTH}{$self->{SETUP}{papersize}},
	        $self->{DATA}->{HEIGHT}{$self->{SETUP}{papersize}},];
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

PostScript::MailLabels - Modules for creating PostScript files of mailing
address labels, to be printed on standard adhesive-backed mailing label stock.

=head1 SYNOPSIS

Create PostScript(tm) code for calibrating and testing mailing label 
printing, and finally create the code for the labels themselves.


=head1 DESCRIPTION

The module has three distinct output modes. In my experience, printing
mailing labels is a matter of tweaking parameters to get them all to
fit properly on the page. This module is designed with this in mind.

The first output is the calibration sheet. This is a pair of annotated
axes, either in inches or centimeters, centered on the page and covering the
whole page in X and Y directions. The intent is for you to output this
page first, and simply read off the relevant page dimensions directly.

The second output is the label test. This output is a series of boxes
drawn on the page, meant to outline the edges of all the mailing labels.
Take this sheet and line it up with a sheet of labels to see if they actually 
match perfectly. If not, tweak the parameters until they do. Note that
sometimes you will get a message at the bottom of the sheet saying
"Bottom gap too large, last row cannot be printed". This means that the
printable area of your printer is too small to utilize the last row of
labels. I have this problem. But I handle it for you. Note also the arrows
on the test sheet. As you hold the test sheet over a sheet of labels, hold it
up to the light and slide the test sheet so that the boxes match the edges 
of the labels. If you slide in the arrow direction, that is a positive
adjustment. The other direction is negative. If the edges of some boxes 
come out dashed, that means that the non-printing border cuts off the
end of the label, so I will adjust the printing area appropriately. Don't
try to line up the dashed lines with label edges - it won't work. Just
line up the solid lines.

The third output is the labels themselves. The addresses must be given to
the program already broken up into :

    firstname, lastname, street address, city, state, zipcode

Yes, this is US-centric. If you would like to help me open this up to
print labels using non-US address standards, let me know. I'm happy to
do it, I just don't know what the standards ought to be.

Parameters you can set :

Paper size, borders on the printable area (many printers will not print
right up to the edge of the paper), where the labels live on the page
and how big they are, overall x-y shift of page, whether or not to 
print PostNET barcode, font, fontsize, units (english or metric),
which Avery (tm) product code to use, and where the first label starts.

This last needs explanation. If you have a partially used sheet of labels,
you might want to use it up. So you count the missing labels, starting
at the upper left, and counting across, and then down. For example, if
I have 3 columns of labels, label five is the second label in the second
row.

The Avery(tm) label codes are woefully incomplete. I can't find the Avery(tm) specs 
anywhere, so the ones that are in there are for products I personally own.
I e-mailed Avery(tm) and they gave me a long distance phone number to call.

If you have an Avery(tm) product that I haven't defined, send me the specs and 
I'll add it.

Also, if there is another brand of labels that you use, send me the relevant
data and I'll add that as well. I suspect that there must be some other
vendor in Europe, but I don't know who that would be.

When setting up the addresses, I check to see if they will fit on the label.
If not, I try to shorten them semi-intelligently until they fit. This part
could use quite a bit more work, if done right it probably merits a module
all it's own.

Briefly, for the name line, I start trimming the ends off the first name,
and leave the last name alone.

For the street, I look for things like Road or Avenue and nuke those first,
then I trim the street name from the right.

For the last line, I trim the city and leave the state and zip alone.

The barcode will be either a 5-digit zip or 9 digit zip-plus code. I could
also create the delivery point code, but since my mailing labels are not
even wide enough for the 9 digit zip-plus, I haven't bothered. I have read
the USPS spec on the barcode, and so far as I can tell, I meet the spec.

    labelsetup :
    
    my $setup = $labels -> labelsetup( 

        #    paper size

        PaperSize        => 'Letter',
            
        #    printable area on physical page

        Printable_Left        => 0.0,
        Printable_Right        => 0.0,
        Printable_Top        => 0.0,
        Printable_Bot        => 0.0,

        #    define where the labels live (ideally)

        Output_Top        => 0.0, 
        Output_Left        => 0.0, 
        Output_Width    => 0.0, 
        Output_Height    => 0.0, 
        X_Gap            => 0.0,
        Y_Gap            => 0.0,
        Number            => 0,

        #    Adjustments for printer idiosyncracies

        X_Adjust        => 0.0,
        Y_Adjust        => 0.0,

        #    Other controls

        Postnet        => 'yes',
        Font        => 'Helvetica',
        FontSize     => 12,
        Units        => 'english',
        FirstLabel    => 1,

        # set equal to the Avery(tm) product code, and the label description
        # will be updated from the database.
        Avery        => undef,
        );

    $output = $labels->labelcalibration ;
    $output = $labels->labeltest ;
    $output = $labels->makelabels(\@addrs) ;
    $templatecode = $labels->averycode($product_code) ;
    @width_height = @{ $labels->papersize } ;
    $stringwidth = $labels->stringwidth("This is a string") ;
    @fontname = $labels->ListFonts;


=head1 EXAMPLE

  require PostScript::MailLabels;

  $labels = PostScript::MailLabels->new;

  #    -------- first a few utility functions that are available
    
    #       List the available fonts

  @fonts = $labels->ListFonts;
  foreach (@fonts) {
    print "$_\n";
  }

  print "String width of this is a test = ", 
        $labels->stringwidth("this is a test",)/72,"\n";
    my $setup = $labels -> labelsetup( Font => 'PostNetJHC');
    print "zip code tests, 6,9, and 12 digit lengths barcodes:  ", 
        $labels->stringwidth("123456",)/72," : ",
        $labels->stringwidth("123456789",)/72," : ",
        $labels->stringwidth("123456789012",)/72,
        "\n";

    print "Paper size = ",($labels->papersize)->[0]," x ",
                      ($labels->papersize)->[1],"\n";


    # print the Avery(tm) template code for a given product code

  print "Avery(tm) code for 8196 is >",$labels->averycode(8196),"<\n";

      # set up the basic parameters for the labels

  $labels -> labelsetup(
                    Avery        => '5196',
                    PaperSize     => 'A4',
                    Font        => 'Times-Roman',
                    );

    #--------- okay, let's get serious now and create some test sheets


    #    paper and label description so far
  $labels -> labelsetup(
                Units => 'english',
                PaperSize => 'letter',
                Avery => undef, # turn off previous definition
  );

    # create a calibration sheet
  my $output = $labels->labelcalibration;
  `lpr < $output`;

    # create a test sheet

  $labels -> labelsetup( 
          # page setup - where is printing allowed? (border widths)
        Printable_Left   => 0.25,
        Printable_Right  => 0.25,
        Printable_Top    => 0.05,
        Printable_Bot    => 0.6,

        # Label description

            # top of first label is 0.5 inches from top of page
        Output_Top      => 0.5, 
            # each label is 2.625 inches wide
        Output_Width    => 2.625, 
            # each label is 1.0 inches high
        Output_Height   => 1.0, 
            # there is a 0.16 inch gap between labels in the X direction
        X_Gap           => 0.16,
            # there is no gap between labels in the Y direction
        Y_Gap           => 0.0,
            # there are 30 labels on a page
        Number           => 30,

        #    Adjustments for printer idiosyncracies

            # shift the whole page 0.05 inches right
        X_Adjust        => 0.05,
            # shift the whole page 0.05 inches down
        Y_Adjust        => 0.05,

                       );
    #    Create and print a label test sheet

  $output = $labels->labeltest;
  `lpr < $output`;

      #    Everything looks good, let's print some labels!

    @addresses = magic; # I magically populate my address array. 8-)

    #    each element of the array is an array of 
    #   first,last,street_addr,city,state,zip

    $labels -> (  Font       => 'Helvetica',
                  FontSize   => 12,
                  FirstLabel => 7,
                  Postnet    => 'yes',
               );
    
    $output = $labels->makelabels(\@addresses);
    `lpr < $output`;

=head1 REVISION HISTORY

	Version 1.0.1 - December 2000
	Bug reported by John Summerfield <summer@OS2.ami.com.au>
	Lowercase all SETUP parameters to avoid problems with mis-spellings.
	Do real parameter checks to check simple spelling errors.

	Bug reported by Nuno Faria <nfaria@fe.up.pt>
	Boxes plot did not work. Frankly I can't figure out how it ever did. Anyway
	it breaks on more modern versions of ghostscript, so I fixed it. Basically
	rewrote part of the PostScript code.

=head1 AUTHOR

    Alan Jackson
    October 1999
    alan@ajackson.org

    The PostNET font was gotten (under Gnu copyleft) from
    James H. Cloos, Jr. <cloos@jhcloos.com>

    The font metrics and paper sizes were pulled from the
    PostScript::Metrics module written by Shawn Wallace

=cut

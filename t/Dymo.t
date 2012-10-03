#!/usr/bin/perl 

#no warnings;

use Test::More tests => 6;

use_ok( 'PostScript::MailLabels' );

my $labels = PostScript::MailLabels->new;
isa_ok( $labels, 'PostScript::MailLabels' );

can_ok( $labels, 'dymocode' );

$labels->labelsetup(
					Dymo		=> $labels->dymocode(30252),
					PaperSize 	=> 'letter',
					Font		=> 'Times-Roman',
					);

#		print calibration sheet

	$labels->labelsetup( Units =>'metric');
  my $output = $labels->labelcalibration;
  open (VIEW,"> dymo-calibration.ps") || warn "Can't write file dymo-calibration.ps, $!\n";
  print VIEW $output;
  close VIEW;
  pass();

#		adjust printable area and draw test boxes

	$labels->labelsetup( Units => 'english',
						Printable_Left		=> 0,
						Printable_Right		=> 0,
						Printable_Top		=> 0,
						Printable_Bot		=> 0,
						
						Output_Top		=> 0, 
						Output_Width	=> 79 / 72, 
						Output_Height	=> 3.5, 
						X_Gap			=> 0,
						Y_Gap			=> 0,
						Number			=> 1,

						#	Adjustments for printer idiosyncracies

						X_Adjust		=> 0,
						Y_Adjust		=> 0,						
	                   );

	$output = $labels->labeltest;
  open (VIEW,"> dymo-testboxes.ps") || warn "Can't write file dymo-testboxes.ps, $!\n";
  print VIEW $output;
  close VIEW;
  pass();
  
	# address array elements are : first,last,street_addr,city,state,zip
{
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
	print "Address : $_->[0] $_->[1] $_->[2] $_->[3] $_->[4]\n";
	}

$labels->labelsetup( Font => 'Helvetica');

$output = $labels->makelabels(\@addrs);
open (VIEW,"> dymo-labelsheet.ps") || warn "Can't write file labelsheet.ps, $!\n";
print VIEW $output;
close VIEW;
pass();
}

  print STDERR "\n\n","-"x30,"\n",
               "There are 3 files that have been created, calibration.ps, testboxes.ps, and labelsheet.ps\n",
               "Please view them with ghostview, ghostscript, or try printing them.\n";


1;

__DATA__
John and Jane (esq):Doe
1234 Robin Ave 
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


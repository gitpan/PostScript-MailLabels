#!/usr/bin/perl

use Data::Dumper;

my $dir = '/Users/brian/Desktop/Labels/dymo-cups-drivers-1.0.1/ppd';

chdir $dir or die "Could not change to $dir! $!\n";

my %Labels;

{
local @ARGV = glob( "lw*.ppd" );
print "Files are @ARGV\n";

while( <> )
	{
	next unless /^\*(PageSize|PageRegion|ImageableArea|PaperDimension)\s/;
	
	my( $directive, $dimension, $product_desc, $cups ) =
		/^
			\*
			(\S+)
			\s
			(.+?)
			\/
			(.+?)
			:
			\s
			"(.+)"
		/xg;
			
	my( $w, $h ) = $dimension =~ /w(\d+)h(\d+)/g;
	
	next unless $product_desc =~ m/(\d{3,5})\s(.*)/;
	
	my( $product_code, $description ) = ( $1, $2 );
	
	
	$Labels{ $product_code } =
		{
		paper_size_name  => $product_code,
		product_codes    => [ $product_code ],
		description      => $description,
		number_per_sheet => 1,
		left_offset      => 0,
		top_offset       => 0,
		width            => $w,
		height           => $h,
		x_gap            => 0,
		y_gap            => 0,
		};
		
	}


}

print "Hello!\n";

$" = ", ";

# flip height and width in output for PostScript::MailLabels because
# the Dymo printer takes care of the rest/
foreach my $code ( sort { $a <=> $b } keys %Labels )
	{
	my $h = $Labels{$code};

	print <<"HERE";
			'$code' => [ 'Dymo-$code', [qw/$code/], '$h->{description}', $h->{number_per_sheet},
					@{ $h }{ qw(left_offset top_offset height width x_gap y_gap ) }
					],
HERE

	}


#print Dumper( \%Labels );

__END__
*PageSize w18h252/06 mm (1/4") Label: "<</PageSize[18 252]/ImagingBBox null/cupsMediaType 0>>setpagedevice"

*PageRegion w18h252/06 mm (1/4") Label: "<</PageSize[18 252]/ImagingBBox null/cupsMediaType 0>>setpagedevice"

*ImageableArea w35h252/1/3 File: "9.20 30.00 25.20 222.00"

*PaperDimension w55h252/19 mm (3/4") Label: "54.40 252.00"


*PageSize w79h252/30252 Address: "<</PageSize[79 252]/ImagingBBox null>>setpagedevice"

*PageRegion w79h252/30252 Address: "<</PageSize[79 252]/ImagingBBox null>>setpagedevice"

*ImageableArea w79h252/30252 Address: "4.32 4.32 76.08 235.44"

*PaperDimension w79h252/30252 Address: "78.96 252.00"

 # layout=>[paper-size,[list of product codes], description,
 #          number per sheet, left-offset, top-offset, width, height,
 #			x_gap, y_gap ]
 #			distances measured in points


	%{$self->{AVERY}} = (
			'5096' => ['Letter',[qw/5096/], 'diskette', 9,
					9, 36, 198, 198, 0, 18,
			],

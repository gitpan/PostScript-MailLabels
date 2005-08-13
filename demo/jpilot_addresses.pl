#!/bin/perl -w

#	This makes use of the palm pilot address database
#	and reads it with the CPAN module Palm::PDB

#	Open addressbook, select subset, and print

use PostScript::MailLabels 2.0;
use Palm::PDB;

$labels = PostScript::MailLabels->new;

#	Open address book and select addresses to print

my $pdb = new Palm::PDB;
use Palm::Address;
$pdb->Load("AddressDB.pdb");

#	I store keywords in the 'custom2' field for subsetting addresses
#my $data = getaddresses($pdb, 'custom2', [qw/ xmas x2000 /]);
my $data = getaddresses($pdb, 'custom2', [qw/ grad /]);

#-------------------------------------------------------------------
#	Prepare mailing labels (assume you've already calibrated them)
#-------------------------------------------------------------------

	$labels->labelsetup( Units => 'english',
	                    Font => 'Helvetica',
						Printable_Left		=> 0.25,
						Printable_Right		=> 0.25,
						Printable_Top		=> 0.0,
						Printable_Bot		=> 0.55,
						
						Output_Top		=> 0.5, 
						Output_Width	=> 2.625, 
						Output_Height	=> 1.0, 
						X_Gap			=> 0.16,
						Y_Gap			=> 0.0,
						Number			=> 30,

						#	Adjustments for printer idiosyncracies

						X_Adjust		=> 0.05,
						Y_Adjust		=> 0.05,

	                   );

#-------------------------------------------------------------------
#	Create labels
#-------------------------------------------------------------------

my $output = $labels->makelabels($data);

open (UT,">labels_out.ps") || die "Warning, cannot write labels_out.ps, $!\n";
print UT $output;
close UT;

print "\n******** View labels_out.ps with ghostscript ********\n";

#-------------------------------------------------------------------
#	do the hard work of extracting the addresses
#-------------------------------------------------------------------
sub getaddresses {
	# database object, field in database where flag lives, flags to test for
	my $pdb = shift;
	my $field = shift; 
	my $tests = shift;
	my @output;

	# output first, last, street_addr, city, state, zip, country

	foreach (my $i=0; defined $pdb->{records}[$i]; $i++) {
		my @rec;
		my $record = $pdb->{records}[$i];
		my $flags = lc $record->{fields}{$field} || 'none';
		if ($tests && !find($tests,$flags)) {next;} # loop if not selected

		#	look for mail-label first names
		if ($record->{fields}{custom1}) {
			push @rec, (split(/,/,$record->{fields}{"custom1"}))[0];
		}
		else {
			push @rec, $record->{fields}{"firstName"};
		}

		#	add in last name
		push @rec, $record->{fields}{"name"};

		#	add street address - check for PO box
		my $addr = $record->{fields}{"address"};
		if (!defined $addr) {
			print STDERR "Address undefined for ",$record->{fields}{"firstName"}," ",$record->{fields}{"name"},"\n";
			$addr = "No Address in Database";
		}
		$addr =~ s/\n/ /;
		$addr =~ s/^.*P\.?O\.?/PO/;
		push @rec, $addr;

		#	add city, state, zip, country
		push @rec, $record->{fields}{"city"};
		my $country = ' ';
		if ($record->{fields}{"country"} && $record->{fields}{"country"} ne 'USA') {
			$country .= $record->{fields}{"country"};
		}
		if ($record->{fields}{"state"}) {
			push @rec, $record->{fields}{"state"}.$country;
		}
		else {
			push @rec, $country;
		}
		if ($record->{fields}{"zipCode"}) {
			push @rec, (split(/[^-\w]/,$record->{fields}{"zipCode"}))[-1];
		}
		else {
			push @rec, ' ';
		}
		push @output, \@rec;
	}
	return \@output;
}

sub find {
	# look for a member of the array $tests in the string $flags
	my $tests = shift;
	my $flags = shift;
	return 0 if index($flags, 'bad address')>=0;
	foreach (@$tests) {
		return 1 if index($flags, $_)>=0;
	}
	return 0;
}

=head1
By convention,

custom2 = flags to select entries on, comma delimited
custom1 = first names for addressing and childrens names. Like :
	John and Jane, Joyce, Jill, and Joe
	will print
	John and Jane

If I have both a street address and a PO box, I put the street address first
in the database, followed by PO xxxxx. If I have both, then the zip codes
end up in the same sort of order.
=cut

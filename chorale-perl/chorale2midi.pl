#!/usr/bin/perl -w

# ./chorale2midi.pl FILENAME
#
# Reads in chorale data from FILENAME, and writes to $outputfile in MIDI
# format.


my $outputfile = "/tmp/output.mid";

use Chorale;

use MIDI::Simple;

use strict;

my $filename = $ARGV[0];
my $fh;
open $fh, "< $filename" or die "can't open file: $!";

my $transpose = 0;
my $toppart = 0;
if (defined($ARGV[1]) and $ARGV[1] eq "-transpose" or $ARGV[0] =~ m:results/bch:)
{
	$transpose = 1;
	print "(transposing to original key)\n";
}
if (defined($ARGV[1]) and $ARGV[1] eq "-no-melody")
{
	print "(not playing melody)\n";
	$toppart = 1;
}

my $obj = MIDI::Simple::new_score();

for (my $i = 1; $i < 16; $i++)
{
	$MIDI::Simple::Length{$i/4} = $i/4;
}

my ($choralname, $stimmen, $tonart, $takt, $tempo, $message) = Chorale::readheaders($fh);

my $keypitch = 0; # so we don't transpose by default

if ($transpose)
{
	$keypitch = - Chorale::key2pitch($tonart); # 'inverse' of key transposition
}

text_event "$choralname";

set_tempo 600000;

#my $patch = 7; # harpsichord
my $patch = 74; # flute

my $stressbar = 0; # should beginning of bar be louder?

patch_change 0, $patch;
patch_change 1, $patch;
patch_change 2, $patch;
patch_change 3, $patch;

my @started = (0,0,0,0);
my @current = ("","","","");
my @newbar = ("","","","");

my $beat = -1/16;
do {
	my $line = <$fh>;
	chomp $line;

	$beat += 1/16;

	if ($line =~ /\S/)
	{
		my ($phrase, $takt, $sopran, $alt, $tenor, $bass, $harmonik) = Chorale::transposerow ($keypitch, Chorale::splitcolumns($line));
		my @newnotes = ($sopran, $alt, $tenor, $bass);
		for (my $i = $toppart; $i < 4; $i++)
		{
			if (defined($newnotes[$i]) and $newnotes[$i] ne "" and $newnotes[$i] !~ /^-/)
			{
				my $duration = $beat - $started[$i];
#				print $started[$i]*4, "\t$current[$i]\t", $duration*4, "\t[$i]\n" if $current[$i];
				add_note ($started[$i]*4, $current[$i], $duration*4, $newbar[$i], $i) if ($current[$i] and $current[$i] ne "");
				$current[$i] = $newnotes[$i];
				$started[$i] = $beat;
				if ($takt =~ /^\d*$/ or $takt =~ m:1/:)
				{
					$newbar[$i] = 1;
				}
				else
				{
					$newbar[$i] = 0;
				}
			}
		}
	}

} until (eof);

$beat += 1/16;
for (my $i = 0; $i < 4; $i++)
{
	my $duration = $beat - $started[$i];
#	print $started[$i]*4, "\t$current[$i]\t", $duration*4, "\t[$i]\n" if $current[$i];
	add_note ($started[$i]*4, $current[$i], $duration*4, $newbar[$i], $i) if defined($current[$i] and $current[$i] ne "");
}

write_score "$outputfile";

print "Output written to file '$outputfile'.\n";

sub add_note
{
	my ($start, $note, $duration, $newbar, $channel) = @_;
	if ($note eq "P" or $note eq "")
	{
		return 1;
	}
#	print "$start $note $duration $channel: \n\n";

	my $volume = 80;
	if ($newbar and $stressbar)
	{
		$volume = 96;
#		print "(new bar)\n";
	}

	push @{$obj->{Score}},
		['note',
		$start*96,		# Time
		$duration*96,		# Duration
		$channel,		# Channel
		Chorale::notepitch ($note), # Note
		$volume,		# Volume
		];

	return 0;
}



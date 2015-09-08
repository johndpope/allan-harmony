#!/usr/bin/perl -w

# ./chorale2lilypond.pl FILENAME
#
# Reads in chorale data from FILENAME, and writes to $outputfile as a
# Lilypond music notation source file.
#
# The Lilypond format has changed over time; to update the file to work with
# current versions of Lilypond, use e.g. 
#  convert-ly -f 1.4.12 output.ly > output-new.ly


my $outputfile = "/tmp/output.ly";

use Chorale;

use MIDI::Simple;

use strict;

my $melodyonly = 0;
my $harmonicsymbols = 0;

my $debug = 0;

my $filename = $ARGV[0];

my $transpose = 0;
if (defined($ARGV[1]) and $ARGV[1] eq "-transpose" or $ARGV[0] =~ m:results/bch:)
{
	$transpose = 1;
	print "(transposing to original key)\n";
}
#$transpose = 0;

open OUT, "> $outputfile";

my ($headers, @lines) = Chorale::readchorale ($filename, "notranspose");
# Chorale::writechorale ("/tmp/tempchorale", $headers, \@lines);
my ($choralname, $stimmen, $tonart, $takt, $tempo, $message) = @{$headers};

if (!defined(${$lines[0]}[3]) or ${$lines[0]}[3] !~ /\w/)
{
    print "(assuming only melody present)\n";
    $melodyonly = 1;
    print "(printing harmonic symbols)\n";
    $harmonicsymbols = 1;
}

my $voices = 4;
if ($melodyonly)
{
    $voices = 1;
}

my $keypitch = 0;
if ($transpose)
{
	$keypitch = - Chorale::key2pitch($tonart); # 'inverse' of key transposition
}

my @started = (0,0,0,0);
my @current = ("","","","");
my @newbar = ("","","","");
my @barposstarted = (0,0,0,0);

my $composer = "Johann Sebastian Bach";

if ($filename =~ m:/tmp/music:)
{
    $composer = "";
}

$choralname =~ s/bch(\d*)/$1*1/e;

# \header {
# title = "Chorale no. ', $choralname, '"
# composer = "', $composer, '"
# }

print OUT '\include "paper16.ly"

\header {
tagline = ""
}

\score {
\notes
<
';

for (my $i = 0; $i < $voices; $i++)
{

	my $clef = ('treble', 'treble', '"treble_8"', "bass")[$i];
	
	if ($harmonicsymbols and $i == 0)
	{
	    print OUT '\context Lyrics = symbols {  }
\context Staff = staffS {  }
\addlyrics', "\n";
	}
	print OUT '\context Staff = staff', ("S", "A", "T", "B")[$i], ' {', "\n";
	print OUT '\clef ', $clef, "\n";
	print OUT '\time ', $takt, "\n";
	print OUT '\property Staff.instrument = "', ("Soprano", "Alto", "Tenor", "Bass")[$i], '"', "\n";
	print OUT '\property Staff.instr = "', ("S", "A", "T", "B")[$i], '"', "\n";

	my ($beats) = $takt =~ m:(\d*)/:;
	$beats = $beats / 4;

	my ($keynote, $keytype) = $tonart =~ m/([^-]*)-([^-]*)/;
$keynote = convertnote ($keynote);
if ($keytype =~ /dur/i)
{
    $keytype = '\major';
}
elsif ($keytype =~ /moll/i)
{
    $keytype = '\minor';
}

print OUT '\key ', $keynote, ' ', $keytype, "\n";

if (${$lines[0]}[1] !~ /1/)
{
    print OUT '\partial 4', "\n";
}

my $beat = -1/16;
my $barpos = -1/16 - 1/4;
foreach my $line (@lines) {
	$beat += 1/16;
	$barpos += 1/16;

	my ($phrase, $takt, $sopran, $alt, $tenor, $bass, $harmonik) = Chorale::transposerow ($keypitch, @{$line});
	my @newnotes = ($sopran, $alt, $tenor, $bass);
	if ($takt =~ m:^1/: or $barpos >= $beats)
	{
	    print "new bar: ($beats long; $barpos) - $takt\n" if $debug;
	    $newbar[$i] = 1;
	    $barpos = 0;
	}
	else
	{
	    print $barpos*4, ": " if $debug;
	    $newbar[$i] = 0;
	}
	if (defined($newnotes[$i]) and $newnotes[$i] ne "" and $newnotes[$i] !~ /^-/)
	{
		my $duration = $beat - $started[$i];
#		print $started[$i]*4, "\t$current[$i]\t", $duration*4, "\t[$i]\n" if $current[$i];
		add_note ($started[$i]*4, $current[$i], $duration, $newbar[$i], $i, $barposstarted[$i], $beats) if ($current[$i] and $current[$i] ne "");
		$current[$i] = $newnotes[$i];
		$started[$i] = $beat;
		$barposstarted[$i] = $barpos;
	}
}

$beat += 1/16;
$barpos += 1/16;
my $duration = $beat - $started[$i];
# print $started[$i]*4, "\t$current[$i]\t", $duration*4, "\t[$i]\n" if $current[$i];
add_note ($started[$i]*4, $current[$i], $duration, $newbar[$i], $i, $barposstarted[$i], $beats) if defined($current[$i] and $current[$i] ne "");

print OUT '}', "\n";
if ($harmonicsymbols and $i == 0)
{
    print OUT '\context Lyrics = symbols \lyrics { ';
    my @nextsymbols = ();
    my @symbols = ();
    my $first = 1;
    for (my $i = 0; $i <= $#lines; $i++)
    {
	my @row = @{$lines[$i]};
	if (defined($row[2]) and $row[2] ne "" and $row[2] !~ /^-/)
	{
	    if (!$first)
	    {
		if ($#symbols >= 0)
		{
		    print OUT '"', join (" ", @symbols), '" ';
		    @symbols = ();
		}
		else
		{
		    print OUT '"" ';
		}
	    }
	    $first = 0;
	}
	if (defined($row[6]) and $row[6] ne "" and $row[6] !~ /^-/)
	{
	    $row[6] =~ s/_/ /g;
	    $row[6] =~ s/%/\\%/g;
	    push @symbols, $row[6];
	}
    }
    print OUT '"', join (" ", @symbols), '" ';
    print OUT '}', "\n";
}
}

print OUT '
>
\paper { linewidth = 13.5\cm }
}
';

print "Output written to file '$outputfile'.\n";

sub add_note
{
	my ($start, $note, $duration, $newbar, $channel, $barposstarted, $beats) = @_;

	my $maxduration = $beats - $barposstarted;

	if ($maxduration == 0)
	{
	    print "warning: maximum note duration is currently zero ($note / $duration)\n";
	    $maxduration = 1;
	}

	$note = convertnote ($note);

#	print "$start $note $duration $channel: \n\n";

	my %durationcode = (1 => 1, 0.875 => "2..", 0.75 => "2.", 0.5 => 2, 0.375 => "4.", 0.25 => 4, 0.1875 => 8., 0.125 => 8, 0.0625 => 16);

	print $note, $duration, " -> " if $debug;
	if ($duration > $maxduration and $maxduration > 0)
	{
		while ($duration > $maxduration)
		{
			print OUT $note;
			print OUT $durationcode{$maxduration}, " ";
			print OUT "~ " if $note !~ /^r/;
			$duration -= $maxduration;
			print " $note, ", $durationcode{$maxduration}, "; " if $debug;
			$maxduration = $beats;
		}
	}

	if (!defined($durationcode{$duration}))
	{
		die "undefined duration: $duration";
	}

	$duration = $durationcode{$duration};

	print OUT $note, $duration, " ";
	print " $note, ", $duration, "\n" if $debug;
	return 0;
}

sub convertnote
{
    my $note = $_[0];
	if ($note eq "P" or $note eq "" or !defined($note))
	{
		$note = "r";
	}
	else
	{
		my ($octave, $octavesymbol, $note2);
		($note2, $octave) = $note =~ m/([^ \-\d]*) *(-*\d*)/;
		if (defined ($note2))
		{
		    $note = $note2;
		}
		$note =~ s/\#/is/;
		$note =~ s/b/es/;		
		$note =~ s/B/Bes/;
		$note =~ s/H/B/;
		$note =~ s/esis//;
		$note =~ s/ises//;
		$note =~ tr/A-Z/a-z/;
		if (defined ($octave) and $octave ne "")
		{
		    $octavesymbol = "";
		    if ($octave <= 0)
		    {
			foreach (1 ... -$octave)
			{
			    $octavesymbol .= ",";
			}
		    }
		    if ($octave >= 0)
		    {
			foreach (1 ... $octave)
			{
			    $octavesymbol .= "'";
			}
		    }
		    $note .= $octavesymbol;
		}
	}
	return $note;
}

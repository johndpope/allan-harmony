#!/usr/bin/perl -w

# ./hmm-annotate.pl FILE ANNOTATIONFILE OUTPUTFILE
#
# Reads in chorale data from $input, adds on each beat an annotation from a
# line in $annotationfile, and writes the data to $output.

use Chorale;

if ($#ARGV != 2)
{
        die "syntax: hmm-annotate.pl FILE ANNOTATIONFILE OUTPUTFILE";
}

$input = $ARGV[0]; # $choraledir."music/bch009.txt";
$annotationfile = $ARGV[1]; # "/tmp/probs";
$output = $ARGV[2]; # "bch009.annotated";

$choraledir = $ENV{HARMONYDIR};
$modeldir = $ENV{HARMONYOUTPUTDIR};
$dir = $modeldir."model-hmm01c/";

foreach $filename (($input))
{
	my ($headers, @lines) = Chorale::readchorale ($filename);
#	my @linesB = Chorale::beatrows (@lines);
#	push @linesB, [ @Chorale::AFTER ];

	my @linesC = ();

	print "${filename}\n";

	open FILE, $annotationfile;

	my @annotations;
	foreach $line (<FILE>)
	{
		chomp $line;
		($hidden, $annotation) = split (/[\t ]+/, $line);
		push @annotations, $annotation;
	}
	close FILE;

	if ($#output != ($#lines / 4))
	{
		print "output file lines: ", $#output, "\n";
		print "chorale file beats: ", ($#lines / 4), "\n";
		if (($#output - ($#lines / 4)) < 3)
		{
			print STDERR "ignoring last ", $#output - ($#lines/4), " lines of output/${filename}\n";
		}
		else
		{
			die "line counts don't match";
		}
	}

	for ($i = 0; $i <= $#lines; $i+=4)
	{
		my (@row, @row1, @row2, @row3);
		@row = @{$lines[$i]};
		@row1 = @{$lines[$i+1]};
		@row2 = @{$lines[$i+2]};
		@row3 = @{$lines[$i+3]};
		print join (" ", @row), "\n";

		$row[6] = $annotations[$i/4];

#		print $row[6], " ";
		print "@row\n";
#		print "@row1\n";
#		print "@row2\n";
#		print "@row3\n";
		push @linesC, [ @row ];
		push @linesC, [ @row1 ];
		push @linesC, [ @row2 ];
		push @linesC, [ @row3 ];
	}

#	Chorale::unpackchordsymbols (\@linesC);
#	@lines_generated = @linesC;
#	my @lines_generated = Chorale::insertrows (\@linesB);
	Chorale::tidychorale (\@linesC);
	Chorale::writechorale ($output, $headers, \@linesC);
}

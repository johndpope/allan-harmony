#!/usr/bin/perl -w

# ./hmm-output-expand.pl MODELNAME OUTPUTNAME
#
# Expand numerical HMM output into full chorale files.
#
# MODELNAME: Model name (i.e. model directory is 'model-NAME').
# OUTPUTNAME: Name of subdirectory containing HMM output (e.g. 'viterbi').

use Chorale;

if ($#ARGV != 1)
{
	die "syntax: hmm-output-expand.pl MODELNAME OUTPUTNAME";
}

$name = $ARGV[0];
$outputname = $ARGV[1];

$choraledir = $ENV{HARMONYDIR};
$modeldir = $ENV{HARMONYOUTPUTDIR};
$dir = $modeldir."/model-".$name."/";
$prevstagedir = $choraledir."/music/";

$outputdir = $outputname;
$resultdir = $outputname."-results";

mkdir ($dir.$resultdir);

open FILE, $dir."SYMBOLS-HIDDEN";
foreach $line (<FILE>)
{
	chomp $line;
	push @hiddensymbols, $line;
}
close FILE;

opendir DIR, $dir . $outputdir;

@files = ();

foreach $file (readdir(DIR))
{
	push @files, $file if $file =~ /bch.*txt/;
}

close DIR;

foreach $filename (@files)
{
	my ($headers, @lines) = Chorale::readchorale ($prevstagedir.$filename);
#	my @linesB = Chorale::beatrows (@lines);
	push @lines, [ @Chorale::AFTER ];

	my @linesC = ();

	print "Reading from ${dir}${outputdir}/${filename}\n";

	open FILE, $dir.$outputdir."/".$filename or die "can't open ${dir}${outputdir}/${filename}";

	my @output;
	foreach $line (<FILE>)
	{
		chomp $line;
		($hidden) = split (" ", $line);
		push @output, $hidden;
	}
	close FILE;

	if ($#output != ($#lines / 4))
	{
		print "output file lines: ", $#output, "\n";
		print "chorale file beats: ", ($#lines / 4), "\n";
		if (($#output - ($#lines / 4)) < 3)
		{
			print STDERR "ignoring last ", $#output - ($#lines/4), " lines of ${filename}\n";
		}
		else
		{
			die "line counts don't match";
		}
	}

	pop @lines;

	for ($i = 0; $i <= $#lines; $i+=4)
	{
		my (@row, @row1, @row2, @row3);
		@row = (${$lines[$i]}[0], ${$lines[$i]}[1], ${$lines[$i]}[2]);
		@row1 = (${$lines[$i+1]}[0], ${$lines[$i+1]}[1], ${$lines[$i+1]}[2]);
		@row2 = (${$lines[$i+2]}[0], ${$lines[$i+2]}[1], ${$lines[$i+2]}[2]);
		@row3 = (${$lines[$i+3]}[0], ${$lines[$i+3]}[1], ${$lines[$i+3]}[2]);
#		print join (" ", @row), "\n";

		$row[6] = $hiddensymbols[$output[$i/4]];
		if ($row[6] =~ m:/:)
		{
			$row[6] =~ s:/.*::;
		}

#		print $row[6], " ";
#		print "@row\n";
#		print "@row1\n";
#		print "@row2\n";
#		print "@row3\n";
		push @linesC, [ @row ];
		push @linesC, [ @row1 ];
		push @linesC, [ @row2 ];
		push @linesC, [ @row3 ];
	}

	Chorale::unpackchordsymbols (\@linesC);
#	@lines_generated = @linesC;
#	my @lines_generated = Chorale::insertrows (\@linesB);
	Chorale::tidychorale (\@linesC);
	Chorale::writechorale ($dir.$resultdir."/".$filename, $headers, \@linesC);
}

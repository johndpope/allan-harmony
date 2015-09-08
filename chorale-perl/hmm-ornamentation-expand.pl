#!/usr/bin/perl -w

# ./hmm-output-expand.pl MODELNAME PREVMODELNAME OUTPUTNAME PREVOUTPUTNAME
#
# Expand numerical HMM output into full chorale files.
#
# MODELNAME: Model name (i.e. model directory is 'model-NAME').
# PREVMODELNAME: Identifier used for the chord model (e.g. 'chords').
# OUTPUTNAME: Name of subdirectory containing HMM output (e.g. 'viterbi').
# PREVOUTPUTNAME: Name of subdirectory containing HMM output for chord model.

use Chorale;

$name = $ARGV[0];
$prevstage = $ARGV[1];
$outputname = $ARGV[2];
$prevoutputname = $ARGV[3];

$modeldir = $ENV{HARMONYOUTPUTDIR};
$dir = $modeldir."/model-".$name."/";
$prevstagedir = $modeldir."/model-".$prevstage."/".$prevoutputname."-results/";

mkdir ($dir.$outputname."-results");

open FILE, $dir."SYMBOLS-HIDDEN";
foreach $line (<FILE>)
{
	chomp $line;
	push @hiddensymbols, $line;
}
close FILE;

opendir DIR, $dir . $outputname;

@files = ();

foreach $file (readdir(DIR))
{
	push @files, $file if $file =~ /bch.*txt/;
#	print $file, "\n";
}

close DIR;

foreach $filename (@files)
{
	my ($headers, @lines) = Chorale::readchorale ($prevstagedir.$filename, "notranspose");
#	my @linesB = Chorale::beatrows (@lines);
	push @lines, [ @Chorale::AFTER ];

	my @linesC = ();

	print "Reading from ${dir}${outputname}/${filename}\n";

	open FILE, $dir.$outputname."/".$filename or die "can't open ${dir}${outputname}/${filename}";

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
			print STDERR "ignoring last ", $#output - ($#lines/4), " lines of output/${filename}\n";
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
		@row = @{$lines[$i]};
		@row1 = (${$lines[$i+1]}[0], ${$lines[$i+1]}[1], ${$lines[$i+1]}[2]);
		@row2 = (${$lines[$i+2]}[0], ${$lines[$i+2]}[1], ${$lines[$i+2]}[2]);
		@row3 = (${$lines[$i+3]}[0], ${$lines[$i+3]}[1], ${$lines[$i+3]}[2]);
		$row[6] = $hiddensymbols[$output[$i/4]];
#		print join (" ", @row), "\n";
		my @pitch = (Chorale::notepitch($row[3]),
			  Chorale::notepitch($row[4]),
			  Chorale::notepitch($row[5]));
		my @motion = split ("/", $hiddensymbols[$output[$i/4]]);
#		print $hiddensymbols[$output[$i]], "\n";
		for ($j = 0; $j < 3; $j++)
		{
		    my @m = split (",", $motion[$j]);
		    shift @m; # the first entry is always 0
		    $row1[$j+3] = "";
		    $row2[$j+3] = "";
		    $row3[$j+3] = "";
		    if ($m[0] != 0)
		    {
			$row1[$j+3] = Chorale::notesymbol ($pitch[$j] + $m[0]);
		    }
		    if ($m[1] != $m[0])
		    {
			$row2[$j+3] = Chorale::notesymbol ($pitch[$j] + $m[1]);
		    }
		    if ($m[2] != $m[1])
		    {
			$row3[$j+3] = Chorale::notesymbol ($pitch[$j] + $m[2]);
		    }
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

#	@lines_generated = @linesC;
#	my @lines_generated = Chorale::insertrows (\@linesB);
	Chorale::tidychorale (\@linesC);
	Chorale::writechorale ($dir.$outputname."-results/".$filename, $headers, \@linesC);
}

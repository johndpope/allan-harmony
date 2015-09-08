#!/usr/bin/perl -w

# ./hmm-ornamentation-data.pl MODELNAME PREVMODELNAME PREVOUTPUTNAME TRAIN TEST
#
# Create data files for ornamentation HMM, using original harmonisations
# together with the output from the chord HMM.
#
# MODELNAME: Identifier for this representation of the chorale data.
# PREVMODELNAME: Identifier used for the chord model (e.g. 'chords').
# PREVOUTPUTNAME: Name of subdirectory containing HMM output (e.g. 'viterbi').
# TRAIN: Training data set (e.g. 'train_dur').
# TEST: Test data set (e.g. 'test_dur').

use Chorale;
use File::Basename;

$name = $ARGV[0];
$prevstage = $ARGV[1];
$prevoutputname = $ARGV[2];
$train = $ARGV[3];
$test = $ARGV[4];

$harmonydir = $ENV{HARMONYDIR};
$modeldir = $ENV{HARMONYOUTPUTDIR};

$datasetdir = $harmonydir."datasets/";

$dir = $modeldir."/model-".$name."/";
$prevstagedir = $modeldir."/model-".$prevstage."/".$prevoutputname."-results/";
mkdir ($dir);
mkdir ($dir."input");
mkdir ($dir."input-test");
mkdir ($dir."viterbi");
mkdir ($dir."sampled");

@hiddensymbols = ();
%hiddensymbolseen = ();
@visiblesymbols = ();
%visiblesymbolseen = ();

@trainfiles = readentries ($train);
@testfiles = readentries ($test);

@files = ();

foreach $file (@trainfiles, @testfiles)
{
	push @files, $ENV{"HARMONYDIR"}."/music/".$file if $file =~ /bch.*txt/;
}

foreach $file (@testfiles)
{
	push @files, $prevstagedir.$file if $file =~ /bch.*txt/;
}

foreach $filename (@files)
{
	my ($headers, @lines) = Chorale::readchorale ($filename);
#	@linesB = Chorale::beatrows (@lines);
	push @lines, [ @Chorale::AFTER ], [ @Chorale::AFTER ], [ @Chorale::AFTER ], [ @Chorale::AFTER ];

	if ($filename =~ /$prevstagedir/)
	{
		open OUTFILE, ">".$dir."input-test/".basename($filename) or die "can't open ${dir}input-test/".basename($filename)." for writing";
		print "writing to input-test/\n";
	}
	else
	{
		open OUTFILE, ">".$dir."input/".basename($filename) or die "can't open ${dir}input/".basename($filename)." for writing";
		print "writing to input/\n";
	}

	for ($i = 0; $i <= $#lines; $i += 4)
	{
		my @c = @{$lines[$i]};
		my @c1 = @{$lines[$i+1]};
		my @c2 = @{$lines[$i+2]};
		my @c3 = @{$lines[$i+3]};
		my @c4;
		if ($i <= ($#lines-4))
		{
			@c4 = @{$lines[$i+4]};
		}
		else
		{
			@c4 = @c;
		}
		my @h = (), @v = (0);
#		push @v, Chorale::notepitch($c[2]);
# Chorale::notepitch($c4[2])-Chorale::notepitch($c[2]). ";".
#		    (Chorale::notepitch($c1[2])-Chorale::notepitch($c[2])).",".
#		    (Chorale::notepitch($c2[2])-Chorale::notepitch($c[2])).",".
#		    (Chorale::notepitch($c3[2])-Chorale::notepitch($c[2]));
		for ($j = 3; $j < 6; $j++)
		{
			push @h,"0,".(Chorale::notepitch($c1[$j])-Chorale::notepitch($c[$j])).",".
				(Chorale::notepitch($c2[$j])-Chorale::notepitch($c[$j])).",".
				(Chorale::notepitch($c3[$j])-Chorale::notepitch($c[$j]));
			push @v, Chorale::notepitch($c4[$j])-Chorale::notepitch($c[$j]);
		}
		$hiddensymbol = join ("/", @h);
		$visiblesymbol = join ("/", @v);
#		print $hiddensymbol, " ", $visiblesymbol, "\n";
		if (!defined($hiddensymbolseen{$hiddensymbol}))
		{
			push @hiddensymbols, $hiddensymbol;
			$hiddensymbolseen{$hiddensymbol} = $#hiddensymbols;
		}
		if (!defined($visiblesymbolseen{$visiblesymbol}))
		{
			push @visiblesymbols, $visiblesymbol;
			$visiblesymbolseen{$visiblesymbol} = $#visiblesymbols;
		}
		print OUTFILE $hiddensymbolseen{$hiddensymbol}, "\t", $visiblesymbolseen{$visiblesymbol}, "\n";
	}

	close OUTFILE;
}

open FILE, ">".$dir."SYMBOLS-HIDDEN";
print FILE join("\n", @hiddensymbols), "\n";
close FILE;

open FILE, ">".$dir."SYMBOLS-VISIBLE";
print FILE join("\n", @visiblesymbols), "\n";
close FILE;

open FILE, ">".$dir."PARAMETERS" or die "can't open PARAMETERS file ${dir}PARAMETERS";

print FILE "Name: ", $name, "\n";
print FILE "Hidden: Ornamented notes\n";
print FILE "Visible: Part intervals\n\n";
print FILE "Hidden states: ", $#hiddensymbols+1, "\n";
print FILE "Visible states: ", $#visiblesymbols+1, "\n";
print FILE "Training data: ", $train, "\n";
print FILE "Test data: ", $test, "\n";

close FILE;

sub internal 
{
	$_ = $_[0];
	s/PHRASE/\$column[0]/;
	s/TAKT/\$column[1]/;
	s/SOPRAN/\$column[2]/;
	s/ALT/\$column[3]/;
	s/TENOR/\$column[4]/;
	s/BASS/\$column[5]/;
	s/HARMONIK/\$column[6]/;
	s/chordtransposed/\$column[9]/;
	return $_;
}

sub readentries
{
    my $filename = $_[0];
    my @entries;
    open FILE, ($datasetdir.$filename) or die "can't read from $datasetdir$filename";
    foreach $entry (<FILE>)
    {
        chomp $entry;
        $entry = sprintf ("bch%03d.txt", $entry);
        push @entries, $entry;
#       print "$entry\n";
    }
    close FILE;
    return @entries;
}

#!/usr/bin/perl -w

# ./hmm-data.pl MODELNAME HIDDEN VISIBLE TRAIN TEST
#
# Create HMM data files from original harmonisations.
#
# MODELNAME: Identifier for this representation of the chorale data.
# HIDDEN: Representation to use as hidden symbols.
# VISIBLE: Representation to use as visible symbols.
# TRAIN: Training data set (e.g. 'train_dur').
# TEST: Test data set (e.g. 'test_dur').

use Chorale;

if ($#ARGV != 4)
{
	die "syntax: hmm-data.pl MODELNAME HIDDEN VISIBLE TRAIN TEST";
}

my $choraledir = $ENV{HARMONYDIR};
my $modeldir = $ENV{HARMONYOUTPUTDIR};
if (!defined($choraledir) or !defined($modeldir))
{
	die "\$HARMONYDIR and \$HARMONYOUTPUTDIR must be set";
}
$inputdir = $choraledir."music/";
$datasetdir = $choraledir."datasets/";

$name = $ARGV[0];
$hidden = internal("\"$ARGV[1]\"");
$visible = internal("\"$ARGV[2]\"");
$train = $ARGV[3];
$test = $ARGV[4];

$dir = $modeldir."model-".$name."/";
mkdir ($dir);
mkdir ($dir."input");
mkdir ($dir."viterbi");
mkdir ($dir."sampled");

$unseenmarker = "(unknown)";
@hiddensymbols = ($unseenmarker);
%hiddensymbolseen = ($unseenmarker=>0);
@visiblesymbols = ($unseenmarker);
%visiblesymbolseen = ($unseenmarker=>0);

@trainfiles = readentries ($train);
@testfiles = readentries ($test);

foreach $filename (@trainfiles, @testfiles)
{
	my ($headers, @lines) = Chorale::readchorale ($inputdir.$filename);
	@linesB = Chorale::beatrows (@lines);
	push @linesB, [ @Chorale::AFTER ];

	open OUTFILE, ">".$dir."input/".$filename or die "can't open ${dir}input/${filename} for writing";

	foreach $line (@linesB)
	{
		my @column = @{$line};
		@column = @column;
		$hiddensymbol = eval($hidden);
		$visiblesymbol = eval($visible);
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

foreach $filename (())
{
	my ($headers, @lines) = Chorale::readchorale ($inputdir.$filename);
	@linesB = Chorale::beatrows (@lines);
	push @linesB, [ @Chorale::AFTER ];

	open OUTFILE, ">".$dir."input/".$filename or die "can't open ${dir}input/${filename} for writing";

	foreach $line (@linesB)
	{
		my @column = @{$line};
		@column = @column;
		$hiddensymbol = eval($hidden);
		$visiblesymbol = eval($visible);
		if (!defined($hiddensymbolseen{$hiddensymbol}))
		{
		    $hiddensymbol = $unseenmarker;
		}
		if (!defined($visiblesymbolseen{$visiblesymbol}))
		{
		    $visiblesymbol = $unseenmarker;
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
print FILE "Hidden: ", $ARGV[1], "\n";
print FILE "Visible: ", $ARGV[2], "\n\n";
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
#	print "$entry\n";
    }
    close FILE;
    return @entries;
}

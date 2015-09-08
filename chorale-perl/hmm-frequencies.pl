#!/usr/bin/perl -w

# cat INPUTFILENAMES | ./hmm-frequencies.pl
#
# Given chorale data converted to HMM input files, prints relative frequencies
# of HMM hidden state to output event emissions to STDOUT.

use strict;

my @frequency;

my $maxcol = 0;
my $maxrow = 0;

foreach my $line (<>)
{
	chomp $line;

	my ($a, $b) = split (/[\t ]+/, $line);

	if (!defined($frequency[$b][$a]))
	{
		$frequency[$b][$a] = 1;
	}
	else
	{
		$frequency[$b][$a]++;
	}

	if ($b > $maxcol)
	{
		$maxcol = $b;
	}
	if ($a > $maxrow)
	{
		$maxrow = $a;
	}
}

print "rows: $maxrow   cols: $maxcol\n";

my @total;

my ($i, $j);

for ($i = 0; $i <= $maxcol; $i++)
{
	$total[$i] = 0;

	for ($j = 0; $j <= $maxrow; $j++)
	{
		if (defined($frequency[$i][$j]))
		{
			$total[$i] += $frequency[$i][$j];
		}
		else
		{
			$frequency[$i][$j] = 0;
		}
	}
	for ($j = 0; $j <= $maxrow; $j++)
	{
		$frequency[$i][$j] = ($frequency[$i][$j]) / $total[$i];
	}
}

for ($j = 0; $j <= $maxrow; $j++)
{
	for ($i = 0; $i <= $maxcol; $i++)
	{
		if ($i > 0)
		{
			print "\t";
		}
		printf "%.04f", $frequency[$i][$j];
	}
	print "\n";
}

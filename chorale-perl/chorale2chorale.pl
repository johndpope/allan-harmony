#!/usr/bin/perl -w

# ./chorale2chorale.pl < INPUT > OUTPUT
#
# Reads chorale data from STDIN and outputs to STDOUT.
#
# The output is not necessarily identical to the input -- for example, spaces
# separating fields in the input are replaced with tabs.


use Chorale;

my ($choralname, $stimmen, $tonart, $takt, $tempo, $message) = Chorale::readheaders();

Chorale::writeheaders($choralname, $stimmen, $tonart, $takt, $tempo, $message);

$beat = -1/16;
do {
	$line = <>;
	chomp $line;

	$beat += 1/16;

	if ($line !~ /\S/)
	{
		print "\n";
	}
	else
	{
		print join ("\t", Chorale::splitcolumns($line)), "\n";
	}
} until (eof);

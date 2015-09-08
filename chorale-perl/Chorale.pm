package Chorale;
require Exporter;

use strict;

# @ISA = qw (Exporter);
# @EXPORT = qw ();

$Chorale::tabbeddata = 1;
$Chorale::columnheadings = join("\t", ("PHRASE", "TAKT", "SOPRAN", "ALT", "TENOR", "BASS", "HARMONIK"));
$Chorale::columns = 1;
@Chorale::columnbreaks = ();

%Chorale::notepitches = (
	'C'  =>  0,
	'C#' =>  1, 'Db' =>  1, 'Csharp' =>  1, 'Dflat' =>  1,
	'D'  =>  2,
	'D#' =>  3, 'Eb' =>  3, 'Dsharp' =>  3, 'Eflat' =>  3,
	'E'  =>  4,
	'F'  =>  5, 'E#' => 5,
	'F#' =>  6, 'Gb' =>  6, 'Fsharp' =>  6, 'Gflat' =>  6,
	'G'  =>  7,
	'G#' =>  8, 'Ab' =>  8, 'Gsharp' =>  8, 'Aflat' =>  8,
	'A'  =>  9,
	'A#' =>  10, 'B' => 10, 'Hb' => 10,
	'H'  => 11, 'B#' =>  11,
	'H#' => 12,
);

@Chorale::notesymbols = ('C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'B', 'H', 'P');

@Chorale::BEFORE = ("0", "0", "P", "P", "P", "P", "0", "P,P,P,P", "0", "P:P:P:P", "P;P;P;P", "P,P,P,P", "P,P,P,P", "P,P,P,P", "P,P,P,P");

@Chorale::AFTER = ("0", "0", "END", "END", "END", "END", "0", "P,P,P,P", "0", "P:P:P:P", "P;P;P;P", "P,P,P,P", "P,P,P,P", "P,P,P,P", "P,P,P,P");

1;

sub writeheaders # write out the header lines of a chorale data file
{
	my ($choralname, $stimmen, $tonart, $takt, $tempo, $message) = @_;

	print "Choralname = $choralname\n";
	print "Anzahl Stimmen = $stimmen\n";
	print "Tonart = $tonart\n";
	print "Takt = $takt\n";
	print "Tempo = $tempo\n";
	print "$message\n";

	print "$Chorale::columnheadings\n\n";
}

sub readheaders # read in the header lines of a chorale data file
{
	my ($fh) = @_;

	if (!defined($fh) or $fh eq "")
	{
		$fh = "STDIN";
	}

	my ($choralname, $stimmen, $tonart, $takt, $tempo, $message);
	do
	{	
		$_ = <$fh>;

		chomp;

		if (/ = /)
		{
			my ($value) = m/= (.*)$/;
			if (/Choralname/i)
			{
				$choralname = $value;
			}
			if (/Stimmen/i)
			{
				$stimmen = $value;
			}
			if (/Tonart/i)
			{
				$tonart = $value;
			}
			if (/Takt/i)
			{
				$takt = $value;
			}
			if (/Tempo/i)
			{
				$tempo = $value;
			}
		}
		else
		{
			if (defined($message))
			{
				$message = join("\n", $message, $_);
			}
			else
			{
				$message = $_;
			}
		}
	} until ($_ eq "" or eof);

	my $headings = "";
	while ($headings eq "")
	{
		$headings = <$fh>;
		chomp $headings;
	}
	my $blankline = <$fh>;
	chomp $blankline;
	if ($blankline ne "")
	{
		die "no blank line after headings!";
	}
	
	if ($headings =~ /\t/)
	{
		$Chorale::tabbeddata = 1;
	}
	else
	{
		$Chorale::tabbeddata = 0;
		# find gaps between columns in headings line
		my @a = split(//, $headings);
		push @Chorale::columnbreaks, 0;
		$Chorale::columns = 1;
		for (my $i = 0; $i <= $#a; $i++)
		{
			if ($a[$i] eq " " and $a[$i+1] ne " ")
			{
				push (@Chorale::columnbreaks, $i);
				$Chorale::columns++;
			}
		}
		push @Chorale::columnbreaks, $#a;
	}

	my @fields = splitcolumns($headings);
#	my ($phrase, $takt, $sopran, $alt, $tenor, $bass, $harmonik) = @fields;

	$Chorale::columnheadings = join("\t", @fields);

	return ($choralname, $stimmen, $tonart, $takt, $tempo, $message);
}

sub splitcolumns
# split a line from a chorale data file into its constituent fields
# - would be trivial, except the upstream files use spaces rather than tabs
{
	my @out;
	if ($Chorale::tabbeddata)
	{
		@out = split(/\t/, $_[0]);
	}
	else
	{
		my @a = split(//, $_[0]);
		@out = ();
		{
			for (my $column = 0; $column < $Chorale::columns; $column++)
			{
				my $text = "";
				foreach my $i ($Chorale::columnbreaks[$column] ... $Chorale::columnbreaks[$column+1])
				{
					if (defined($a[$i]))
					{
						$text .= $a[$i];
					}
				}
				$text =~ s/^ +//;
				$text =~ s/ +$//;
				push @out, $text;
			}
		}
	}
	return (@out);
}

sub notepitch # convert a note representation into a numerical value
{
	if (!defined($_[0]))
	{
		return -1;
	}
	if ($_[0] =~ /-*P/)
	{
		return -1;
	}
        my ($symbol, $octave) = $_[0] =~ m/^\-*([ABCDEFGH#b]+)[ _]*([-\d]+)/;
	my $noteval;
        if (defined($symbol) && defined($Chorale::notepitches{$symbol}))
	{
		$noteval = $Chorale::notepitches{$symbol};
	}
	else
        {
#               print STDERR "Unrecognised note symbol: '$_[0]' [$symbol/$octave]!\n";
		return -1;
        }
	return $noteval + ($octave + 4) * 12
}

sub notesymbol # convert a numerical note value to a textual representation
{
	my $noteval = $_[0] % 12;
	my $octave = (($_[0] - $noteval) / 12) - 4;
	my $symbol = $Chorale::notesymbols[$noteval];
	if (length($symbol) == 1)
	{
		$symbol .= " ";
	}
	$symbol .= $octave;
	return $symbol;
}

sub finalnote # returns final note of a note sequence
{
	if (!defined($_[0]))
	{
		return "P";
	}
	my @s = split(",", $_[0]);
	for (my $i = $#s; $i >= 0 ; $i--)
	{
		if (defined($s[$i]) and $s[$i] ne "")
		{
			return $s[$i];
		}
	}
	return "P";
}

sub interval # finds interval between two notes / note sequences' final notes
{
	my $note1 = finalnote ($_[0]);
	my $note2 = finalnote ($_[1]);
	if ($note1 eq "B" or $note2 eq "B") # before start of actual chorale!
	{
		return 0;
	}
	return (notepitch ($note1) - notepitch ($note2));
}

sub key2pitch # find a numerical note value for transposing to/from a key
{
	my ($tonart) = @_;
	$tonart =~ s/-.*//;
	$tonart .= " -4";
	return notepitch($tonart);
}

sub transposerow # transpose a line from a data file according to the key
{
	my ($keypitch, @row) = @_;
	for (my $i = 2; $i < 6; $i++)
	{
#		print "real: ", $row[$i], "(", notepitch($row[$i]), ") key: ", notesymbol($keypitch), "(", $keypitch, ") transposed: ", notesymbol(notepitch($row[$i]) - $keypitch), "\n" if (defined($row[$i]) and $row[$i] ne "");
		if (defined($row[$i]) and $row[$i] ne "" and $row[$i] !~ /-*P/)
		{
			my $continuation = $row[$i] =~ m/^-/;
			$row[$i] = ($continuation ? "-" : "").notesymbol(notepitch($row[$i]) - $keypitch);
		}
	}
	return (@row);
}

sub writechorale # write out a chorale data file
{
    my ($filename, $headers, $lines) = @_;
    open my $outputfile, "> $filename" or die "can't write to $filename: $!";

    print STDERR "Writing to '$filename'...\n";

    my ($choralname, $stimmen, $tonart, $takt, $tempo, $message) = @{$headers};

    print $outputfile "Choralname = $choralname\n";
    print $outputfile "Anzahl Stimmen = $stimmen\n";
    print $outputfile "Tonart = $tonart\n";
    print $outputfile "Takt = $takt\n";
    print $outputfile "Tempo = $tempo\n";
    print $outputfile "$message\n";
    print $outputfile "$Chorale::columnheadings\n\n";

    for (my $i = 0; $i <= $#$lines; $i++)
    {
	if (defined($$lines[$i]))
	{
	    my @row = @{$$lines[$i]};
	    for (my $j = 0; $j <= 9; $j++)
	    {
	        if (!defined($row[$j]))
		{
		    $row[$j] = "";
		}
	    }
	    print $outputfile join ("\t", @row), "\n";
	}
	else
	{
	    print join ("\t", ("","","","","","","")), "\n";
	}
    }

    close $outputfile;
}

sub readchorale # read in a chorale data file
{
    my ($filename, $notranspose) = @_;

        my @lines;

        print STDERR "Processing '$filename'...\n";
    my $trainfile;
        open $trainfile, "< $filename" or die "can't read from $filename: $!";

        my @headers = Chorale::readheaders ($trainfile);

    my ($choralname, $stimmen, $tonart, $takt, $tempo, $message) = @headers;


        my $keypitch = Chorale::key2pitch ($tonart);

        my @within = @Chorale::BEFORE;       # event we're 'in' (so nothing to start with)
        foreach my $line (<$trainfile>) {
                chomp $line;                                    # read line of file

                my @row = Chorale::splitcolumns($line);
		if (!defined($notranspose) or $notranspose ne "notranspose")
		{
                	@row = Chorale::transposerow($keypitch, @row);  # transpose to C major/C minor
		}
                for (my $i = 0; $i < 7; $i++)
                {
                        if (!defined($row[$i]) or $row[$i] eq "")
                        {
                                $row[$i] = "-".$within[$i];
				# instead of just spaces we have -TOKEN for continuation
                        }
                        else
                        {
                                $row[$i] =~ s/ /_/g;             # replace any spaces in tokens with underscores
                                $within[$i] = $row[$i];
                        }
                }

		my @intervals = ();
		my $bass;
		for (my $i = 5; $i >= 2; $i--)
		{
			if (defined($row[$i]) and $row[$i] ne "")
			{
				if ($row[$i] =~ "-*P" or $row[$i] eq "END")
				{
					$intervals[$i-2] = $row[$i];
				}
				else
				{
					if (!defined($bass))
					{
						$bass = Chorale::notepitch($row[$i]);
					}
					$intervals[$i-2] = Chorale::notepitch($row[$i])-$bass;
					if ($row[$i] =~ /^-/)
					{
						$intervals[$i-2] = "-".$intervals[$i-2];
					}
				}
			}
		}
		$row[9] = join(":", @intervals);
					# , $row[6]);

                push @lines, [ @row ];
        };

    close $trainfile;

    if (${$lines[0]}[1] !~ m:/:) # convert beat numbers if not already done
    {
	my $maxbeat = 0;
	my $beat = -1;
	for (my $i = 0; $i <= $#lines; $i++)
	{
	    my @row = @{$lines[$i]};
	    if ($i % 4 == 0)
	    {
		$beat++;
	    }
	    if (defined($row[1]) and $row[1] !~ /^-/ and $row[1] ne "0")
	    {
		$beat = 1;
	    }
	    $row[1] = $i % 4 ? "-".$beat : $beat;
	    if ($beat > $maxbeat)
	    {
		$maxbeat = $beat;
	    }
	    $lines[$i] = [ @row ];
	}
	for (my $i = 0; $i <= $#lines; $i++)
	{
	    my @row = @{$lines[$i]};
	    $row[1] .= "/".$maxbeat;
	    $lines[$i] = [ @row ];
	}
    }

    return ([@headers], @lines);
}

sub chorale_get_line # preferably avoid, since have to pass large array
{
    my ($lineno, @lines) = @_;

    if ($lineno < 0)
    {
	return @Chorale::BEFORE;
    }
    elsif ($lineno > $#lines)
    {
	return @Chorale::AFTER;
    }
    return @{$lines[$lineno]};
}

sub clearchorale # clear a harmonisation's lower parts, leaving the melody
{
    my ($lines) = @_;
    for (my $i = 0; $i <= $#$lines; $i++)
    {
	my @row = @{$lines->[$i]};
	for (my $j = 3; $j < 7; $j++)
	{
		$row[$j] = "";
	}
	$$lines[$i] = [@row];
    }
}

sub tidychorale # convert note data to nice version for writing out
{
    my ($lines) = @_;
    my @row = ("","","","","","","");
    my @ev = @row;
    for (my $i = 0; $i <= $#$lines; $i++)
    {
	my @row = @{$lines->[$i]};
	for (my $j = $#row; $j >= 8; $j--)
	{
	    if (defined($row[$j]))
	    {
		$row[$j] = "";
	    }
	}
	for (my $j = 0; $j < 7; $j++)
	{
	    if (defined($row[$j]) and $row[$j] =~ /^-/)
	    {
#		$row[$j] =~ s/^-//;
#	        if ($row[$j] eq $ev[$j])
#		{
		    $row[$j] = "";
#		}
#	        else
#		{
#		    $ev[$j] = $row[$j];
#		}
	    }
	    else
	    {
		$ev[$j] = $row[$j];
	    }
	    if (defined ($row[$j]))
	    {
        	$row[$j] =~ s/_/ /g; # replace any underscores in tokens with spaces
	    }
	}
	$row[7] = "";
	$$lines[$i] = [@row];
    }
}

sub beatrows # get the notes from a chorale which occur on the beat
{
    my @linesB;
    for (my $i = 0; $i <= $#_; $i += 4)
    {
	my @row = @{$_[$i]};
	my @ornamentation;
	my @tornamentation; # transposed relative to initial notes
	for (my $j = 0; $j < 4; $j++)
	{
	    my (@sequence, @tsequence);
	    @sequence = ($row[$j+2], ${$_[$i+1]}[$j+2], ${$_[$i+2]}[$j+2], ${$_[$i+3]}[$j+2]);
	    $ornamentation[$j] = join (",", @sequence);

	    my $firstnote;
	    foreach my $note (@sequence)
	    {
		if (defined ($note) and (!defined($firstnote)))
		{
		    $firstnote = notepitch($note);
		}
		if (defined($note) and $note !~ /^-/ and $note !~ /^-*P/ and $note ne "" and $note ne "END")
		{
		    push @tsequence, notepitch($note) - $firstnote;
		}
		else
		{
		    push @tsequence, "-";
		}
	    }
	    $tornamentation[$j] = join (",", @tsequence);
#	    print "$ornamentation[$j], $tornamentation[$j]\n";
	}
	$row[8] = join ("/", @ornamentation); # ornamented versions of all parts
	$row[10] = join (";", @tornamentation); # ornamented versions (transposed)
	$row[11] = $ornamentation[0]; # ornamented version of soprano part
	$row[12] = $tornamentation[1]; # note: [12][13][14] *t*ornamentation
	$row[13] = $tornamentation[2];
	$row[14] = $tornamentation[3];

	if (($i+4) > $#_)
	{
	    $row[7] = "END,END,END,END";
	}
	else
	{
	    my @nextbeatrow = @{$_[$i+4]};
	    my @intervals; # to next notes
	    for (my $j = 0; $j < 4; $j++)
	    {
		if ($nextbeatrow[$j+2] !~ /-*P/ and $row[$j+2] !~ /-*P/)
		{
	 	    $intervals[$j] = notepitch($nextbeatrow[$j+2]) - notepitch($row[$j+2]).">".(notepitch($row[$j+2]) % 12);
		}
		else
		{
		    $intervals[$j] = "P";
		}
	    }
	    $row[7] = join (",", @intervals); # intervals to next beat's notes
	}

	push @linesB, [ @row ];
    }
    return @linesB;
}

sub contsymbol # add continuation marker to a note symbol
{
    my $symbol = $_[0];
    if ($symbol !~ /^-/)
    {
	$symbol = "-". $symbol;
    }
    print "cont ";
    return $symbol;
}

sub insertrows # add back off-the-beat lines to chorale data
{
    my $linesB = $_[0];
    my @lines;
    for (my $i = 0; $i <= $#$linesB; $i++)
    {
	my @line1 = @{$$linesB[$i]};
	my (@line2, @line3, @line4);
	@line2 = @line3 = @line4 = ("","","","","","","");
	if ($line1[6] =~ m:/:)
	{
#	    print "matched on /\n";
	    my @parts = split ("/", $line1[6]);
	    for (my $i = 0; $i < 4; $i++)
	    {
		($line1[$i+2], $line2[$i+2], $line3[$i+2], $line4[$i+2]) = split (",", $parts[$i]);
	    }
#	    $line1[6] = "";
#	    $line1[11] = "";
	    $line1[8] = "";
	}
	elsif ($line1[6] =~ m/;/)
	{
#	    print "matched on ;\n";
	    my @ornamentation = split (";", $line1[6]);
	    for (my $i = 1; $i < 4; $i++) # skip soprano
	    {
		if (defined ($line1[$i+2]) and $line1[$i+2] !~ /-*P/)
		{
		    my @noteornamentation = split (",", $ornamentation[$i]);
		    my $firstnote = notepitch ($line1[$i+2]);
		    if (defined ($noteornamentation[1]) and $noteornamentation[1] ne "-")
		    {
			if ($noteornamentation[1] eq "P")
			{
				$line2[$i+2] = "P";
			}
			elsif ($noteornamentation[1] eq "-")
			{
			    $line2[$i+2] = contsymbol ($line1[$i+2]);
			}
			else
			{
				$line2[$i+2] = notesymbol ($firstnote + $noteornamentation[1]);
			}
		    }
		    if (defined ($noteornamentation[2]) and $noteornamentation[2] ne "-")
		    {
			if ($noteornamentation[2] eq "P")
			{
				$line3[$i+2] = "P";
			}
			elsif ($noteornamentation[2] eq "-")
			{
			    $line3[$i+2] = contsymbol ($line2[$i+2]);
			}
			else
			{
				$line3[$i+2] = notesymbol ($firstnote + $noteornamentation[2]);
			}
		    }
		    if (defined ($noteornamentation[3]) and $noteornamentation[3] ne "-")
		    {
			if ($noteornamentation[3] eq "P")
			{
				$line4[$i+2] = "P";
			}
			elsif ($noteornamentation[3] eq "-")
			{
			    $line4[$i+2] = contsymbol ($line3[$i+2]);
			}
			else
			{
			 	$line4[$i+2] = notesymbol ($firstnote + $noteornamentation[3]);
			}
		    }
		}
	    }
##	    $line1[6] = "";
#	    $line1[11] = "";
	    $line1[8] = "";
	    $line1[9] = "";
	    $line1[10] = "";
	    $line1[7] = "";
	}
	if ($line1[11] =~ m:,:) # restore melody
	{
#	    print "matched on ,\n";
	    ($line1[2], $line2[2], $line3[2], $line4[2]) = split (",", $line1[11]);
	    $line1[7] = "";
	    $line1[8] = "";
	}
	# fixme: insert decoding for other parts here!
	# fixme: and make *relative*?

#	print join "\t", @line1, "\n";

	push @lines, ([@line1], [@line2], [@line3], [@line4]);
    }
    return @lines;
}

sub unpackchordsymbols # convert chord symbols back to individual notes
{
    my ($lines) = @_;
    for (my $i = 0; $i <= $#$lines; $i++)
    {
	my @row = @{$$lines[$i]};
	if (defined($row[6]) and $row[6] =~ m:/:)
	{
		my $soprano;
		($soprano, $row[3], $row[4], $row[5]) = split("/", $row[6]);
	}
	elsif (defined($row[6]) and $row[6] =~ m/:/)
	{
		my @intervals = split(":", $row[6]);
		if (defined($row[2]) and $row[2] ne "")
		{
			my $soprano = notepitch($row[2]);
			$intervals[0] =~ s/^-//;
			for (my $i = 3; $i < 6; $i++)
			{
				if ($intervals[$i-2] !~ /\d/)
				{
					$row[$i] = $intervals[$i-2];
				}
				else
				{
					my $prefix = "";
					if ($intervals[$i-2] =~ /^-/)
					{
						$prefix = "-";
						$intervals[$i-2] =~ s/^-//;
					}
					$row[$i] = $prefix . notesymbol($soprano-($intervals[0]-$intervals[$i-2]));
				}
			}
		}
		else
		{
			print STDERR "Warning: skipping unpacking these intervals: ";
			print STDERR $row[6];
			print STDERR "\n";
		}
	}
	elsif (defined($row[6]))
	{
		print "not unpacking: $row[6]\n";
	}
	$$lines[$i] = [ @ row ];
    }
}

sub chordsymbol # convert set of notes to a chord symbol
{
    my @chord = ();
    for (my $i = 2; $i < 6; $i++)
    {
	push @chord, $_[$i];
    }
    return join ("/", @chord);
}

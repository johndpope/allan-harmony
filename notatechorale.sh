#!/bin/sh

# ./notatechorale.sh FILENAME
# 
# Typesets a chorale data file in music notation, using the lilypond music
# notation program.


FILE=$1

set -e

if [ ! -f $FILE ]; then
FILE=`printf "%03d" $FILE`
FILE=./music/bch$FILE.txt
fi

perl -I./chorale-perl ./chorale-perl/chorale2lilypond.pl $FILE
# add this flag to force transposition back to original key - normally detected automatically
#  -transpose

# for old lilypond versions use this code:
#  (cd /tmp; ly2dvi -P /tmp/output.ly)
#  echo Saved PostScript output to \'/tmp/output.ps\'.
#  gv /tmp/output.ps &

if which lilypond > /dev/null; then
  # for newer lilypond versions, first update the old-format file:
  (cd /tmp; convert-ly -f 1.4.12 output.ly > output-new.ly ; lilypond --pdf output-new.ly)
  echo Saved PDF output to \'/tmp/output-new.pdf\'.
  if which evince > /dev/null; then
    evince /tmp/output-new.pdf &
  fi
else
  echo Cannot find lilypond in \$PATH, is it installed\? >&2
fi

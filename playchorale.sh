#!/bin/sh

# playchorale.sh FILENAME
# 
# Plays back a chorale data file, using the timidity MIDI synthesiser.

FILE=$1
FLAG=$2

set -e

if [ ! -f $FILE ]; then
FILE=`printf "%03d" $FILE`
FILE=./music/bch$FILE.txt
fi

perl -I./chorale-perl ./chorale-perl/chorale2midi.pl $FILE $FLAG
if which timidity > /dev/null; then
  timidity /tmp/output.mid >/dev/null &
else
  echo Please install timidity MIDI player for automatic playback.
fi

#!/bin/bash

set -e

# This script will only work properly if you have already successfully run
# harmonise.sh

# HARMONYDIR is the directory containing the scripts and original data
# edit to set HARMONYDIR to the correct directory when the script is run
#[ -d $HARMONYDIR/music/ ] || HARMONYDIR=$HOME/work/harmony-new/
[ -d $HARMONYDIR/music/ ] || HARMONYDIR=./
[ -d $HARMONYDIR/music/ ] || ( echo Unable to find files, please set HARMONYDIR to the install directory. ; exit 1 )

# HARMONYOUTPUTDIR is the directory where the models should be saved
# edit to set HARMONYOUTPUTDIR to the correct directory when the script is run
[ -n $HARMONYOUTPUTDIR ] || HARMONYOUTPUTDIR=$HARMONYDIR
mkdir -p $HARMONYOUTPUTDIR
[ -w $HARMONYOUTPUTDIR ] || ( echo Unable to write to ${HARMONYDIR}, will use /tmp/ instead. ; HARMONYOUTPUTDIR=/tmp/ )

echo Using data/programs in \'$HARMONYDIR\'.
echo Writing output to \'$HARMONYOUTPUTDIR\'.
echo

for DATASET in dur moll; do
  TRAIN=train_$DATASET
  TEST=test_$DATASET
  STAGE1=chords-$DATASET
  STAGE2=ornamentation-$DATASET
  SEED=4
  $HARMONYDIR/chorale-c/prob $STAGE1 sample seed=$SEED
  perl -I$HARMONYDIR/chorale-perl $HARMONYDIR/chorale-perl/hmm-output-expand.pl $STAGE1 sampled
  perl -I$HARMONYDIR/chorale-perl $HARMONYDIR/chorale-perl/hmm-ornamentation-data.pl $STAGE2 $STAGE1 sampled $TRAIN $TEST
  $HARMONYDIR/chorale-c/prob $STAGE2 viterbi-test
  perl -I$HARMONYDIR/chorale-perl $HARMONYDIR/chorale-perl/hmm-ornamentation-expand.pl $STAGE2 $STAGE1 viterbi sampled

  echo
  echo Output files are in $HARMONYOUTPUTDIR/model-$STAGE2/viterbi-results/
  echo
  echo If you have timidity installed then you can use playchorale.sh to play them back.
done

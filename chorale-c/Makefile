all: prob

prob: prob.c hmm.c mm.c prob.h hmm.h mm.h
	gcc -g -Wall -O2 -std=c99 -DHAVE_INLINE -DHARMONYDIR="\"${HARMONYDIR}\"" -DMODELDIR="\"${MODELDIR}\"" -Wall hmm.c mm.c prob.c -o prob -lgsl -lblas -lm
# -lefence

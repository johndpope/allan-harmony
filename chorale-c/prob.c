#include <gsl/gsl_errno.h>
#include <gsl/gsl_nan.h>
#include <gsl/gsl_machine.h>
#include <gsl/gsl_blas.h>
#include <gsl/gsl_sf_log.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <errno.h>

#include "prob.h"
#include "mm.h"
#include "hmm.h"

model_parameters *parameters_read (char *model_name)
{
  model_parameters *p = malloc (sizeof(model_parameters));
  p->hiddenstates = 0;
  p->visiblestates = 0;
  p->train = NULL;
  p->test = NULL;

  char *parameters_filename = malloc (strlen (PARAMETERS_FORMAT) + strlen (model_name));
  sprintf (parameters_filename, PARAMETERS_FORMAT, model_name);

  FILE *parameters_file = fopen (parameters_filename, "r");
  if (!parameters_file)
    {
      perror("parameters_read(parameters_file)");
      exit (errno);
    }

  while (!feof (parameters_file))
    {
      char buffer[1024];
      if (fgets (buffer, 1024, parameters_file))
	{
	  if (!strncmp (buffer, "Hidden states: ", 15))
	    {
	      sscanf (buffer, "Hidden states: %d", &(p->hiddenstates));
	    }
	  else if (!strncmp (buffer, "Visible states: ", 16))
	    {
	      sscanf (buffer, "Visible states: %d", &(p->visiblestates));
	    }
	  else if (!strncmp (buffer, "Training data: ", 15))
	    {
	      p->train = malloc (strlen(buffer) - 15 + 1);
	      sscanf (buffer, "Training data: %s", p->train);
	    }
	  else if (!strncmp (buffer, "Test data: ", 11))
	    {
	      p->test = malloc (strlen(buffer) - 11 + 1);
	      sscanf (buffer, "Test data: %s", p->test);
	    }
	}
    }

  fclose (parameters_file);
  free (parameters_filename);

  if (!(p->hiddenstates) || !(p->visiblestates))
    {
      fprintf (stderr, "Can't find numbers of states in PARAMETERS file\n");
      exit (1);
    }
  if ((p->train == NULL) || (p->test == NULL))
    {
      fprintf (stderr, "Can't find data sets in PARAMETERS file\n");
      exit (1);
    }

  return p;
}

void parameters_free (model_parameters *p)
{
  free (p);
}

double *goodturing (int *freqfreq, int maxfreq)
{
  const int gt_debug = 0;

  double *rstar = malloc (sizeof(double) * (maxfreq+2));
  int foundzero = 0;
  for (int r = 0; r <= maxfreq; r++)
    {
      if ((!foundzero) && (freqfreq[r+1] > 0))
	{
	  rstar[r] = ((double) (r+1)) * ((double) freqfreq[r+1]) / ((double) freqfreq[r]);
	  if (gt_debug)
	    printf ("*");
	}
      else
	{
	  foundzero = 1;
	  rstar[r] = r;
	  if (gt_debug)
	    printf (".");
	}
    }
  if (gt_debug)
    printf ("\n");

  if (rstar[0] == 0)
    {
      double initialmass = 0;
      for (int r = 0; r <= maxfreq; r++)
	{
	  initialmass += ((double) freqfreq[r]) * r;
	}
      // here we can't use Good-Turing to estimate the probability of
      // unseen events

      // for now, imagine we'll see one of the unseen events at the next
      // event (gives them too much weight really)

      rstar[0] = 1./((double) freqfreq[0]);

      if (gt_debug)
	printf ("guessing r*[0]\n");
    }

  if (gt_debug)
    {
      double initialmass = 0;
      double mass = 0;
      for (int r = 0; r <= maxfreq; r++)
	{
	  initialmass += ((double) freqfreq[r]) * r;
	  mass += ((double) freqfreq[r]) * rstar[r];
	}
      printf ("initial mass: %f\tfinal mass: %f\n", initialmass, mass);
      printf ("r\tN_r\tr*\t\tr x N_r / N\tr* x N_r / N*\n");
      for (int r = 0; r <= maxfreq; r++)
	{
	  printf ("%d\t%d\t%f\t%f\t%f\n", r, freqfreq[r], rstar[r], freqfreq[r]*r/((double) initialmass), freqfreq[r]*rstar[r]/((double) mass));
	}
      printf ("\n");
    }

  return rstar;
}

void matrix_smooth_normalise_log (gsl_matrix *m, gsl_matrix *logm)
{
  // normalise for P(b_t = j | a_t = i)

#ifdef GOODTURING
  // estimate frequency of unseens

  gsl_vector *p_output = gsl_vector_calloc (m->size1);
  gsl_vector *p_transition = gsl_vector_calloc (m->size1 * m->size2);

  for (int output = 0; output < m->size1; output++)
    {
      double seen = 0;
      for (int input = 0; input < m->size2; input++)
	{
	  double n = gsl_matrix_get (m, output, input);
	  seen += n;
	  gsl_vector_set (p_transition, output * m->size2 + input, n);
	}
      gsl_vector_set (p_output, output, seen);
    }
  vector_smooth_normalise_log (p_output, NULL);
  vector_smooth_normalise_log (p_transition, NULL);

  double probunseen = gsl_vector_get (p_output, 0);
  printf (" prob(unseen) approx. %f\n", probunseen);
  double probunseentransition = gsl_vector_get (p_transition, 0);
  printf (" prob(unseentransition) approx. %f\n", probunseentransition);

  gsl_vector_free (p_output);

  // Good-Turing smoothing variant

  for (int input = 0; input < m->size2; input++)
    {
      // before just added K_SMOOTHING_MATRIX to each frequency
      // (including in calculating mass above)

      int maxfreq = 0;
      for (int output = 0; output < m->size1; output++)
	{
	  int freq = gsl_matrix_get (m, output, input);
	  if (freq > maxfreq)
	    maxfreq = freq;
	}
      if (maxfreq == 0)
	{
	  // assume uniform distribution

	  for (int output = 0; output < m->size1; output++)
	    {
	      gsl_matrix_set (m, output, input, 1);
	    }
	}
      else
	{
	  int *freqfreq = malloc (sizeof(int) * (maxfreq+2));
	  for (int i = 0; i < (maxfreq+2); i++)
	    freqfreq[i] = 0.;
	  for (int output = 0; output < m->size1; output++)
	    {
	      int freq = gsl_matrix_get (m, output, input);
	      freqfreq[freq]++;
	    }	

	  double *rstar = goodturing (freqfreq, maxfreq);

	  free (freqfreq);

	  for (int output = 0; output < m->size1; output++)
	    {
	      double r = gsl_matrix_get (m, output, input);
	      gsl_matrix_set (m, output, input, rstar[(int) r]);
	    }

	  free (rstar);
	}

      // before just added K_SMOOTHING_MATRIX to each frequency

      double mass = 0;
      for (int output = 0; output < m->size1; output++)
	{
	  double n = gsl_matrix_get (m, output, input);
	  mass += n;
	}
      for (int output = 0; output < m->size1; output++)
	{
	  double n = gsl_matrix_get (m, output, input) / mass;
	  gsl_matrix_set (m, output, input, n);
	  if (logm != NULL)
	    gsl_matrix_set (logm, output, input, gsl_sf_log (n));
	}
    }
#else
  for (int input = 0; input < m->size2; input++)
    {
      double mass = 0;
      for (int output = 0; output < m->size1; output++)
	{
	  double n = gsl_matrix_get (m, output, input) + K_SMOOTHING_MATRIX;
	  mass += n;
	}
      for (int output = 0; output < m->size1; output++)
	{
	  double n = (gsl_matrix_get (m, output, input) + K_SMOOTHING_MATRIX) / mass;
	  gsl_matrix_set (m, output, input, n);
	  if (logm != NULL)
	    gsl_matrix_set (logm, output, input, gsl_sf_log (n));
	}
    }
#endif
}

void vector_smooth_normalise_log (gsl_vector *v, gsl_vector *logv)
{
#ifdef GOODTURING
  // normalise for P(b_t = i)

  // before just added K_SMOOTHING_VECTOR to each frequency

  int maxfreq = 0;
  for (int output = 0; output < v->size; output++)
    {
      int freq = gsl_vector_get (v, output);
      if (freq > maxfreq)
	maxfreq = freq;
    }

  if (maxfreq == 0)
    {
      // assume uniform distribution
      
      for (int output = 0; output < v->size; output++)
	gsl_vector_set (v, output, 1);
    }
  else
    {
      int *freqfreq = malloc (sizeof(int) * (maxfreq+2));
      for (int i = 0; i < (maxfreq+2); i++)
	freqfreq[i] = 0.;
      for (int output = 0; output < v->size; output++)
	{
	  int freq = gsl_vector_get (v, output);
	  freqfreq[freq]++;
	}

      double *rstar = goodturing (freqfreq, maxfreq);

      free (freqfreq);

      for (int output = 0; output < v->size; output++)
	{
	  double r = gsl_vector_get (v, output);
	  gsl_vector_set (v, output, rstar[(int) r]);
	}

      free (rstar);
    }

  // before just added K_SMOOTHING_VECTOR to each frequency

  double mass = 0;
  for (int output = 0; output < v->size; output++)
    {
      double n = gsl_vector_get (v, output);
      mass += n;
    }
  for (int output = 0; output < v->size; output++)
    {
      double n = gsl_vector_get (v, output) / mass;
      gsl_vector_set (v, output, n);
      if (logv != NULL)
	gsl_vector_set (logv, output, gsl_sf_log (n));
    }
#else
  double mass = 0;

  for (int output = 0; output < v->size; output++)
    {
      double n = gsl_vector_get (v, output) + K_SMOOTHING_VECTOR;
      mass += n;
    }
  for (int output = 0; output < v->size; output++)
    {
      double n = (gsl_vector_get (v, output) + K_SMOOTHING_VECTOR) / mass;
      gsl_vector_set (v, output, n);
      if (logv != NULL)
	gsl_vector_set (logv, output, gsl_sf_log (n));
    }
#endif
}

void sequence_write (sequence_data *s, char *model_name, char *format, int filename)
{
  FILE *output_file = fopen_data (model_name, format, filename, "w");
  
  if (!output_file)
    {
      perror("sequence_write(output_file)");
      exit (errno);
    }
  
  for (int t = 0; t < s->sequencelength; t++)
    {
      fprintf (output_file, "%d %d\n", s->hidden[t], s->visible[t]);
    }
  
  fclose (output_file);
}

sequence_data *sequence_read (char *model_name, char *format, int filename)
{
      int sequencelength = 0;

      FILE *test_file = fopen_data (model_name, format, filename, "r");

      if (!test_file)
	{
	  perror("sequence_read(datafile)");

	  exit (errno);
	}

#ifdef DEBUG
      fflush (stdout);
#endif

      while (!feof (test_file))
	{
	  int hiddenstate, visiblestate;

	  int r = fscanf (test_file, "%d %d", &hiddenstate, &visiblestate);
	  if (r == 2)
	    {
	      sequencelength++;
	    }
	  else if (r != EOF)
	    {
	      fprintf (stderr, "badly formed input file line! %d\n", r);
	      exit(1);
	    }
	}

      rewind (test_file);

      int *hidden = malloc (sequencelength * sizeof (int));
      int *visible = malloc (sequencelength * sizeof (int));

      for (int i = 0; !feof (test_file); i++)
	{
	  int r = fscanf (test_file, "%d %d", &(hidden[i]), &(visible[i]));
	  if (r == 2)
	    {
	      // correctly-formed input line
	    }
	  else if (r != EOF)
	    {
	      fprintf (stderr, "badly formed input file line! %d\n", r);
	      exit(1);
	    }
	}

      fclose (test_file);

      sequence_data *s = malloc (sizeof(sequence_data));

      s->sequencelength = sequencelength;
      s->hidden = hidden;
      s->visible = visible;

      return s;
}

void sequence_free (sequence_data *s)
{
  if (s->hidden)
    free (s->hidden);
  if (s->visible)
    free (s->visible);
  free (s);
}

FILE *fopen_data (char *model_name, char *format, int filename, const char *mode)
{
  char *filename_full = malloc (strlen (format) + strlen (model_name));
  sprintf (filename_full, format, model_name, filename);
  FILE *file = fopen (filename_full, mode);
#ifdef DEBUG
  printf ("Opening %s\n", filename_full);
#endif
  free (filename_full);

  return file;
}

dataset *dataset_read (char *dataset_filename)
{
  char *dataset_filename_full = malloc (strlen (dataset_filename) + strlen(DATASETS_DIR) + 1);
  sprintf (dataset_filename_full, "%s%s", DATASETS_DIR, dataset_filename);
  
  FILE *dataset_file = fopen (dataset_filename_full, "r");
  if (!dataset_file)
    {
      perror("dataset_read(dataset_file)");
      exit (errno);
    }

  int files = 0;

  while (!feof (dataset_file))
    {
      char buffer[1024];

      if (fgets (buffer, 1024, dataset_file) && (buffer[0] != '#'))
	{
	  char test_filename[4];
	  int test_filename_number;
	  bzero (test_filename, 4);
	  strncpy (test_filename, buffer, 3);
	  if (sscanf (test_filename, "%d", &test_filename_number) == 1)
	  files++;
	}
    }

  rewind (dataset_file);
  printf ("Reading dataset index %s - %d entries\n", dataset_filename, files);

  int *filenames = malloc (sizeof(int) * files);

  for (int i = 0; (!feof (dataset_file)) && (i < files); i++)
    {
      char buffer[1024];

      if (fgets (buffer, 1024, dataset_file) && (buffer[0] != '#'))
	{
	  char test_filename[4];
	  int test_filename_number;
	  bzero (test_filename, 4);
	  strncpy (test_filename, buffer, 3);
	  if (sscanf (test_filename, "%d", &test_filename_number) == 1)
	    {
	      filenames[i] = test_filename_number;
	    }
	}
    }

  fclose (dataset_file);

  free (dataset_filename_full);

  dataset *d = malloc (sizeof(dataset));
  d->name = malloc (strlen(dataset_filename)+1);
  strcpy (d->name, dataset_filename);
  d->entries = files;
  d->filenames = filenames;

  return d;
}

void dataset_free (dataset *d)
{
  if (d->name)
    free (d->name);
  if (d->filenames)
    free (d->filenames);
  free (d);
}

int main (int argc, char *argv[])
{
  if (argc < 3)
    {
      fprintf (stderr, "Syntax: hmm MODELNAME OPERATIONS\n");
      exit (1);
    }

  char *model_name = argv[1];

  int evaluate = 0;
  int viterbi = 0;
  int viterbitest = 0;
  int sample = 0;
  unsigned long int rngseed = 3;

  for (int i = 2; i < argc; i++)
    {
      if (!strcmp (argv[i], "evaluate"))
        evaluate = 1;
      else if (!strcmp (argv[i], "viterbi"))
        viterbi = 1;
      else if (!strcmp (argv[i], "viterbi-test"))
        viterbitest = 1;
      else if (!strcmp (argv[i], "sample"))
        sample = 1;
      else if (!strncmp (argv[i], "seed=", 5))
        {
	  sscanf (argv[i], "seed=%ld", &rngseed);
	}
      else
        {
          fprintf (stderr, "Unknown operation '%s'.\n", argv[i]);
	  exit (1);
        }
    }

  model_parameters *parameters = parameters_read (model_name);

  printf ("Model '%s', with training data '%s' and test data '%s':\n", model_name, parameters->train, parameters->test);

  dataset *train = dataset_read(parameters->train);
  dataset *test = dataset_read(parameters->test);

  parameters_free (parameters);

  printf ("\n");

  // To harmonise an additional data set, use e.g.
  // dataset *ocanada = dataset_read("test_ocanada");
  // hmm_viterbi (hmm1, DATAFILE_FORMAT, ocanada);

  // To look at how likely stuff in a particular sequence is, use e.g.
  // hmm_sequence_probs (hmm1, DATAFILE_FORMAT, 9);

  if (evaluate)
    {
      // mm_model *mm1 = mm_train (model_name, train, 1);
      // mm_model *mmoz1 = mm_orderzero_train (model_name, train, 1);

      printf ("\t\t\t%s\t%s\n", train->name, test->name);
      mm_model *mmcond = mm_train (model_name, train, -1);
      printf ("log P(c_t|y_t)/N:\t%f\t%f\n", mm_logprob (mmcond, DATAFILE_FORMAT, train), mm_logprob (mmcond, DATAFILE_FORMAT, test));
      mm_free (mmcond);

      mm_model *mm0 = mm_train (model_name, train, 0);
      printf ("log P(c_t|c_{t-1})/N:\t%f\t%f\n", mm_logprob (mm0, DATAFILE_FORMAT, train), mm_logprob (mm0, DATAFILE_FORMAT, test));
      mm_free (mm0);

      mm_model *mmoz0 = mm_orderzero_train (model_name, train, 0);
      printf ("log P(c_t)/N:\t\t%f\t%f\n", mm_orderzero_logprob (mmoz0, DATAFILE_FORMAT, train), mm_orderzero_logprob (mmoz0, DATAFILE_FORMAT, test));
      mm_free (mmoz0);
    }

  hmm_model *hmm1 = hmm_train (model_name, train);

  if (evaluate)
    {
      printf ("\t\t\t%s\t%s\n", train->name, test->name);
      double logjointp = hmm_logjointprob (hmm1, DATAFILE_FORMAT, train);
      double logjointpT = hmm_logjointprob (hmm1, DATAFILE_FORMAT, test);
      printf ("log P(C*,Y*)/N:\t\t%f\t%f\n", logjointp, logjointpT);

      double logoutputp = hmm_logoutputprob (hmm1, DATAFILE_FORMAT, train);
      double logoutputpT = hmm_logoutputprob (hmm1, DATAFILE_FORMAT, test);
      printf ("log P(Y*)/N:\t\t%f\t%f\n", logoutputp, logoutputpT);
      printf (" -> log P(C*|Y*)/N:\t%f\t%f\n\n", (logjointp - logoutputp), (logjointpT - logoutputpT));
    }

/* if want to compare joint probs
  printf ("\t\t\t %s\t%s\n", test->name, testM->name);
  logjointp = hmm_logjointprob (hmm1, DATAFILE_FORMAT, test);
  hmm_viterbi (hmm1, DATAFILE_FORMAT, test);
  printf ("\t\t\t %s\t%s (viterbi)\n", test->name, testM->name);
  logjointp = hmm_logjointprob (hmm1, VITERBIFILE_FORMAT, test);
*/

  // find the viterbi path for each test file (most probable sequence)

  if (viterbi)
    hmm_viterbi (hmm1, DATAFILE_FORMAT, test);
    // run viterbi using observed events from original data

  if (viterbitest)
    hmm_viterbi (hmm1, TESTFILE_FORMAT, test);
    // run viterbi using observed events from test data (from previous stage)

  if (sample)
    {
      hmm_sample (hmm1, DATAFILE_FORMAT, test, rngseed);
    }

  hmm_free (hmm1);

  dataset_free (train);
  dataset_free (test);

  return 0;
}

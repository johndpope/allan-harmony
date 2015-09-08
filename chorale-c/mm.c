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

double mm_logprob (mm_model *mm, char *format, dataset *d)
{
  // printf ("Calculating MM probability on test files (%s): ", dataset_filename);

  double logprob = 0;
  int outputsymbols = 0;

  for (int entry = 0; entry < d->entries; entry++)
    {
      // printf ("%d ", test_filename_number);

      sequence_data *s = sequence_read (mm->model_name, format, d->filenames[entry]);

      /* calculate cross-entropy over file */

      int *state = NULL;
      if (mm->model_column == 0)
	{
	  state = s->hidden;
	}
      else if (mm->model_column == 1)
	{
	  state = s->visible;
	}

      if (mm->model_column >= 0)
	{
	  double logp_initial = gsl_vector_get (mm->logp_initial, state[0]);
	  logprob += logp_initial;
	}
      else
	{
	  logprob += gsl_matrix_get (mm->logp_transition, s->hidden[0], s->visible[0]);
	}

      for (int t = 1; t < s->sequencelength; t++)
	{
	  double logp_transition;
	  if (mm->model_column >= 0)
	    {
	      logp_transition = gsl_matrix_get (mm->logp_transition, state[t], state[t-1]);
	    }
	  else
	    {
	      logp_transition = gsl_matrix_get (mm->logp_transition, s->hidden[0], s->visible[0]);
	    }
	  logprob += logp_transition;
	}

      outputsymbols += s->sequencelength;

      sequence_free (s);
    }

  // printf ("%f %d\n", logprob, outputsymbols);

  return logprob / outputsymbols;
}

double mm_orderzero_logprob (mm_model *mm, char *format, dataset *d)
{
  // printf ("Calculating zero-order MM probability on test files (%s): ", dataset_filename);

  double logprob = 0;
  int outputsymbols = 0;

  for (int entry = 0; entry < d->entries; entry++)
    {
      // printf ("%d ", test_filename_number);

      sequence_data *s = sequence_read (mm->model_name, DATAFILE_FORMAT, d->filenames[entry]);

      int *state;
      if (mm->model_column == 0)
	{
	  state = s->hidden;
	}
      else
	{
	  state = s->visible;
	}

      /* calculate cross-entropy over file */

      for (int t = 0; t < s->sequencelength; t++)
	{
	  double logp = gsl_vector_get (mm->logp_initial, state[t]);
	  outputsymbols++;
	  logprob += logp;
	}

      sequence_free (s);
    }

  // printf ("%f %d\n", logprob, outputsymbols);

  return logprob / outputsymbols;
}

mm_model *mm_new (char *model_name, int model_column)
{
  mm_model *mm = malloc (sizeof (mm_model));

  mm->model_name = malloc (strlen (model_name) + 1);
  strcpy (mm->model_name, model_name);

  mm->inputstates = 0;
  mm->outputstates = 0;
  mm->normalised_flag = 0;

  mm->model_column = model_column;

  /* read in model parameters */

  model_parameters *p = parameters_read (model_name);

  if (model_column == 0)
    {
      mm->inputstates = p->hiddenstates;
      mm->outputstates = p->hiddenstates;
    }
  else if (model_column == 1)
    {
      mm->inputstates = p->visiblestates;
      mm->outputstates = p->visiblestates;
    }
  else
    {
      mm->inputstates = p->visiblestates;
      mm->outputstates = p->hiddenstates;
    }

  parameters_free (p);

  mm->p_initial = 0;
  mm->logp_initial = 0;
  mm->p_transition = 0;
  mm->logp_transition = 0;

  return mm;
}

mm_model *mm_train (char *model_name, dataset *d, int model_column)
{
  mm_model *mm = mm_new (model_name, model_column);

  /* initialise GSL probability matrices of these sizes */

  mm->p_initial = gsl_vector_calloc (mm->inputstates);
  mm->logp_initial = gsl_vector_calloc (mm->inputstates);
  mm->p_transition = gsl_matrix_calloc (mm->outputstates, mm->inputstates);
  mm->logp_transition = gsl_matrix_calloc (mm->outputstates, mm->inputstates);

  /* loop through files in dataset */

  // printf ("Training MM from input files: ");

  for (int entry = 0; entry < d->entries; entry++)
    {
      // printf ("%d ", training_filename_number);

      sequence_data *s = sequence_read (model_name, DATAFILE_FORMAT, d->filenames[entry]);

      /* train probability matrices */

      // t = 0;

      int *state = NULL;
      if (model_column == 0)
	{
	  state = s->hidden;
	}
      else if (model_column == 1)
	{
	  state = s->visible;
	}

      if (model_column >= 0)
	{
	  double n;
	  n = gsl_vector_get (mm->p_initial, state[0]) + 1.;
	  gsl_vector_set (mm->p_initial, state[0], n);
	}
      else
	{
	  double n = gsl_matrix_get (mm->p_transition, s->hidden[0], s->visible[0]) + 1.;
	  gsl_matrix_set (mm->p_transition, s->hidden[0], s->visible[0], n);
	}

      for(int t = 1; t < s->sequencelength; t++)
	{
	  if (model_column >= 0)
	    {
	      double n = gsl_matrix_get (mm->p_transition, state[t], state[t-1]) + 1.;
	      gsl_matrix_set (mm->p_transition, state[t], state[t-1], n);
	    }
	  else
	    {
	      double n = gsl_matrix_get (mm->p_transition, s->hidden[t], s->visible[t]) + 1.;
	      gsl_matrix_set (mm->p_transition, s->hidden[t], s->visible[t], n);
	    }
	}

      sequence_free(s);
    }

  // printf ("\n\n");

  /* smooth (add-k), normalize, precalculate logs */

  vector_smooth_normalise_log (mm->p_initial, mm->logp_initial);
  // printf ("mm p_transition:\n");
  matrix_smooth_normalise_log (mm->p_transition, mm->logp_transition);

  mm->normalised_flag = 1;

  return mm;
}

mm_model *mm_orderzero_train (char *model_name, dataset *d, int model_column)
{
  mm_model *mm = mm_new (model_name, model_column);

  /* initialise GSL probability matrices of these sizes */

  mm->p_initial = gsl_vector_calloc (mm->inputstates);
  mm->logp_initial = gsl_vector_calloc (mm->inputstates);
  mm->p_transition = 0;
  mm->logp_transition = 0;

  /* loop through files in dataset */

  // printf ("Training MM from input files: ");

  for (int entry = 0; entry < d->entries; entry++)
    {
      // printf ("%d ", training_filename_number);

      sequence_data *s = sequence_read (model_name, DATAFILE_FORMAT, d->filenames[entry]);

      int *state;
      if (model_column == 0)
	{
	  state = s->hidden;
	}
      else
	{
	  state = s->visible;
	}

      /* train probability matrices */

      for (int t = 0; t < s->sequencelength; t++)
      {
	double n = gsl_vector_get (mm->p_initial, state[t]) + 1.;
	gsl_vector_set (mm->p_initial, state[t], n);
      }

      sequence_free (s);
    }

  // printf ("\n\n");

  /* smooth (add-k), normalise, precalculate logs */

  vector_smooth_normalise_log (mm->p_initial, mm->logp_initial);

  mm->normalised_flag = 1;

  return mm;
}

void mm_free (mm_model *mm)
{
  if (mm->model_name)
    free (mm->model_name);
  if (mm->p_initial)
    gsl_vector_free (mm->p_initial);
  if (mm->logp_initial)
    gsl_vector_free (mm->logp_initial);
  if (mm->p_transition)
    gsl_matrix_free (mm->p_transition);
  if (mm->logp_transition)
    gsl_matrix_free (mm->logp_transition);
  free (mm);
}

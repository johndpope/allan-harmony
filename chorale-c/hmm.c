#include <gsl/gsl_errno.h>
#include <gsl/gsl_nan.h>
#include <gsl/gsl_machine.h>
#include <gsl/gsl_blas.h>
#include <gsl/gsl_sf_log.h>
#include <gsl/gsl_rng.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <errno.h>

#include "prob.h"
#include "hmm.h"

void hmm_sequence_probs (hmm_model *hmm, char *format, int filename)
{
  printf ("Probabilities for steps in sequence %d:\n", filename);

  sequence_data *s = sequence_read (hmm->model_name, format, filename);

  /* forward probabilities */

  hmm_alpha *f = hmm_forwardprobs (hmm, s->hidden, s->visible, s->sequencelength);

  gsl_vector *statemass = gsl_vector_calloc (hmm->hiddenstates);

  for (int t = 1; t < s->sequencelength; t++)
    {
      double mass = 0.0;

      for (int j = 0; j < hmm->hiddenstates; j++)
	{
	  double n = gsl_matrix_get (f->alphahat, t - 1, j) * gsl_matrix_get (hmm->p_transition, s->hidden[t], j);
	  mass += n;
	  gsl_vector_set (statemass, j, n);
	}

      double logprob = gsl_sf_log (gsl_vector_get (statemass, s->hidden[t-1]) / mass);

      printf ("%d\t%.02f\n", s->hidden[t-1], -logprob /* (gsl_vector_get (statemass, s->hidden[t-1]) / mass)*5046, gsl_matrix_get (hmm->p_transition, s->hidden[t], s->hidden[t-1])*5046 */);
    }

  double mass = 0.0;

  for (int j = 0; j < hmm->hiddenstates; j++)
    {
      double n = gsl_matrix_get (f->alphahat, s->sequencelength - 1, j);
      mass += n;
      gsl_vector_set (statemass, j, n);
    }

  double logprob = gsl_sf_log (gsl_vector_get (statemass, s->hidden[s->sequencelength-1]) / mass);

  printf ("%d\t%.02f\n", s->hidden[s->sequencelength-1], -logprob);

  gsl_vector_free (statemass);

  hmm_forwardprobs_free (f);

  sequence_free (s);
}

void hmm_sample_sequence (hmm_model *hmm, char *format, int filename, unsigned long int seed)
{
  sequence_data *s = sequence_read (hmm->model_name, format, filename);

  /* forward probabilities */

  hmm_alpha *f = hmm_forwardprobs (hmm, s->hidden, s->visible, s->sequencelength);

  gsl_rng *r = gsl_rng_alloc (gsl_rng_taus2);
  gsl_rng_set (r, seed);

  gsl_vector *statemass = gsl_vector_calloc (hmm->hiddenstates);
  double mass = 0.0;

  for (int j = 0; j < hmm->hiddenstates; j++)
    {
      double n = gsl_matrix_get (f->alpha, s->sequencelength - 1, j);
      mass += n;
      gsl_vector_set (statemass, j, n);
    }

  double sample = gsl_rng_uniform (r); // value in [0,1)

  for (int j = 0; (j < hmm->hiddenstates) && (sample > 0); j++)
    {
      double n = gsl_vector_get (statemass, j) / mass;
      sample -= n;

      if (sample < 0)
	{
	  s->hidden[s->sequencelength - 1] = j;
	}
    }

  printf ("sample  p(c)    c\n");

  for (int t = s->sequencelength - 1; t > 0; t--)
    {
      double mass = 0.0;

      for (int j = 0; j < hmm->hiddenstates; j++)
	{
	  double n = gsl_matrix_get (f->alpha, t - 1, j) * gsl_matrix_get (hmm->p_transition, s->hidden[t], j);
	  mass += n;
	  gsl_vector_set (statemass, j, n);
	}

      double sample = gsl_rng_uniform (r); // value in [0,1);

      printf ("%.04f  ", sample);

      for (int j = 0; (j < hmm->hiddenstates) && (sample > 0); j++)
	{
	  double n = gsl_vector_get (statemass, j) / mass;
	  sample -= n;
	  
	  if (sample < 0)
	    {
	      s->hidden[t - 1] = j;

	      printf ("%.04f  %d\n", n, j);
	    }
	}
    }

  // now have sampled path in hidden[]

  gsl_vector_free (statemass);

  gsl_rng_free (r);

  hmm_forwardprobs_free (f);

  sequence_write (s, hmm->model_name, SAMPLEDFILE_FORMAT, filename);

  sequence_free (s);
}

void hmm_sample (hmm_model *hmm, char *format, dataset *d, unsigned long int seed)
{
  printf ("Sampling hidden sequences for test files (%s), with RNG seed %ld:\n", d->name, seed);

  gsl_rng *r = gsl_rng_alloc (gsl_rng_taus2);
  gsl_rng_set (r, seed);

  for (int entry = 0; entry < d->entries; entry++)
    {
      unsigned long int seed = gsl_rng_uniform (r) * 10000000;

      printf ("sampling for %03d (seed %ld)\n", d->filenames[entry], seed);

      hmm_sample_sequence (hmm, format, d->filenames[entry], seed);
    }

  gsl_rng_free (r);
}

double hmm_viterbi (hmm_model *hmm, char *format, dataset *d)
{
  printf ("Calculating Viterbi alignments for test files (%s): ", d->name);

  double negloglikelihood = 0;
  int outputsymbols = 0;

  for (int entry = 0; entry < d->entries; entry++)
    {

      sequence_data *s = sequence_read (hmm->model_name, format, d->filenames[entry]);

      printf ("%d ", d->filenames[entry]);
      fflush (stdout);

      /* calculate viterbi alignment over file */

      gsl_matrix *delta = gsl_matrix_calloc (s->sequencelength, hmm->hiddenstates);
      gsl_matrix *psi = gsl_matrix_calloc (s->sequencelength, hmm->hiddenstates);

      // should re-do in terms of matrix operations if possible

      for (int j = 0; j < hmm->hiddenstates; j++)
	{
	  double logp_initial = gsl_vector_get (hmm->logp_initial, j);
	  double logp_emission = gsl_matrix_get (hmm->logp_emission, s->visible[0], j);
	  gsl_matrix_set (delta, 0, j, logp_initial + logp_emission);
	  gsl_matrix_set (psi, 0, j, 0.);
	}

      gsl_vector *logprob = gsl_vector_calloc (hmm->hiddenstates);
      
      for (int t = 1; t < s->sequencelength; t++)
	{
	  for (int j = 0; j < hmm->hiddenstates; j++)
	    {
	      int argmax = -1;;
	      double max = 0;
	      
	      for (int k = 0; k < hmm->hiddenstates; k++)
		{
		  double logprobk = gsl_matrix_get (delta, t - 1, k) + gsl_matrix_get (hmm->logp_transition, j, k);
		  gsl_vector_set (logprob, k, logprobk);
		  if ((argmax == -1) || (logprobk > max))
		    {
		      argmax = k;
		      max = logprobk;
		    }
		}
	      
	      gsl_matrix_set (psi, t, j, argmax);
	      gsl_matrix_set (delta, t, j, max + gsl_matrix_get (hmm->logp_emission, s->visible[t], j));
	    }
	}

      gsl_vector_free (logprob);

      int argmax = -1;
      double max = 0;
	  
      for (int j = 0; j < hmm->hiddenstates; j++)
	{
	  double logprobj = gsl_matrix_get (delta, s->sequencelength - 1, j);
	  if ((argmax == -1) || (logprobj > max))
	    {
	      argmax = j;
	      max = logprobj;
	    }
	}
      
      s->hidden[s->sequencelength - 1] = argmax;
      
      for (int t = s->sequencelength - 2; t >= 0; t--)
	{
	  s->hidden[t] = gsl_matrix_get (psi, t + 1, s->hidden[t + 1]);
	}

      outputsymbols += s->sequencelength;

      sequence_write (s, hmm->model_name, VITERBIFILE_FORMAT, d->filenames[entry]);
      sequence_free (s);
    }

  printf ("\n\n");

  // printf ("%f %d\n", negloglikelihood, outputsymbols);

  return negloglikelihood / ((double) outputsymbols);
}

hmm_alpha *hmm_forwardprobs (hmm_model *hmm, int *hidden, int *visible, int sequencelength)
{
#if 1
      // A. method without scaling

      gsl_matrix *alpha = gsl_matrix_calloc (sequencelength, hmm->hiddenstates);

      // should re-do in terms of matrix operations if possible

      for (int j = 0; j < hmm->hiddenstates; j++)
	{
	  double p_initial = gsl_vector_get (hmm->p_initial, j);
	  double p_emission = gsl_matrix_get (hmm->p_emission, visible[0], j);

	  gsl_matrix_set (alpha, 0, j, p_initial * p_emission);
	}

      for (int t = 1; t < sequencelength; t++)
	{
	  for (int j = 0; j < hmm->hiddenstates; j++)
	    {
	      double sum = 0.0;
	      for (int k = 0; k < hmm->hiddenstates; k++)
		{
		  sum += gsl_matrix_get (alpha, t - 1, k) * gsl_matrix_get (hmm->p_transition, j, k);
		}

	      //		  printf ("%d %e\n", t, sum);

	      gsl_matrix_set (alpha, t, j, sum * gsl_matrix_get (hmm->p_emission, visible[t], j));
	    }
	}
#endif

      // B. method with scaling

      gsl_matrix *alphahat = gsl_matrix_calloc (sequencelength, hmm->hiddenstates);
      if (alphahat == NULL)
	{
	  printf ("foo!\n");
	}
      gsl_vector *c = gsl_vector_calloc (sequencelength);

      // should re-do in terms of matrix operations if possible

      double summedalphahats = 0.0;

      for (int j = 0; j < hmm->hiddenstates; j++)
	{
	  double p_initial = gsl_vector_get (hmm->p_initial, j);
	  double p_emission = gsl_matrix_get (hmm->p_emission, visible[0], j);

	  gsl_matrix_set (alphahat, 0, j, p_initial * p_emission);
	  summedalphahats += p_initial * p_emission;
	}
      gsl_vector_set (c, 0, 1/summedalphahats);
      /*	  for (int j = 0; j < hmm->hiddenstates; j++)
		  {
		  double n = gsl_matrix_get (alphahat, 0, j);
		  gsl_matrix_set (alphahat, 0, j, n / summedalphahats);
		  }
      */
	  
      double prevsummedalphahats = summedalphahats;

      for (int t = 1; t < sequencelength; t++)
	{
	  double summedalphahats = 0.0;

	  for (int j = 0; j < hmm->hiddenstates; j++)
	    {
	      double sum = 0.0;
	      for (int k = 0; k < hmm->hiddenstates; k++)
		{
		  sum += gsl_matrix_get (alphahat, t - 1, k) * gsl_matrix_get (hmm->p_transition, j, k) / prevsummedalphahats;
		}

	      double alphahat_t_j = sum * gsl_matrix_get (hmm->p_emission, visible[t], j);
	      summedalphahats += alphahat_t_j;

	      gsl_matrix_set (alphahat, t, j, alphahat_t_j);
	    }

	  gsl_vector_set (c, t, 1 / summedalphahats);

	  /*	      for (int j = 0; j < hmm->hiddenstates; j++)
		      {
		      double n = gsl_matrix_get (alphahat, t, j);
		      gsl_matrix_set (alphahat, t, j, n / summedalphahats);
		      }
	  */

	  prevsummedalphahats = summedalphahats;
	}
  hmm_alpha *forwardprobs = malloc(sizeof(hmm_alpha));
#if 1
  forwardprobs->alpha = alpha;
#else
  forwardprobs->alpha = NULL;
#endif
  forwardprobs->alphahat = alphahat;
  forwardprobs->c = c;

  return forwardprobs;
}

void hmm_forwardprobs_free (hmm_alpha *f)
{
  if (f->alpha)
    gsl_matrix_free (f->alpha);
  if (f->alphahat)
    gsl_matrix_free (f->alphahat);
  if (f->c)
    gsl_vector_free (f->c);
  free (f);
}

// hmm_logoutputprob : log (P(y)) / N

double hmm_logoutputprob (hmm_model *hmm, char *format, dataset *d)
{
  //  printf ("Calculating log probabilities for test files (%s): ", d->name);

  double logprob = 0;
  int outputsymbols = 0;

  for (int entry = 0; entry < d->entries; entry++)
    {
      fprintf (stdout, "%d ", d->filenames[entry]);
      fflush (stdout);

      sequence_data *s = sequence_read (hmm->model_name, format, d->filenames[entry]);

      /* forward probabilities */

      hmm_alpha *f = hmm_forwardprobs (hmm, s->hidden, s->visible, s->sequencelength);

#if 0
      double sequenceprob = 0.0;
      for (int j = 0; j < hmm->hiddenstates; j++)
	{
	  sequenceprob += gsl_matrix_get (f->alpha, s->sequencelength - 1, j);
	}
#endif

      double logsequenceprob = 0.0;

      for (int t = 0; t < s->sequencelength; t++)
	{
	  double n = gsl_vector_get (f->c, t);
	  // printf ("%d %f %e\n", t, n, n);
	  logsequenceprob -= gsl_sf_log (n);
	}

      hmm_forwardprobs_free (f);

#if 0
      // sanity check: 2004-01-14, was giving same answer:
      if (sequenceprob != 0.0)
	{
	  printf ("%d: %f %f\n", d->filenames[entry], gsl_sf_log (sequenceprob), logsequenceprob);
	}
      else
	{
	  printf ("%d: - %f\n", d->filenames[entry], logsequenceprob);
	}
#endif

      outputsymbols += s->sequencelength;
      logprob += logsequenceprob;

      //      printf ("%d\t%f\n", d->filenames[entry], logsequenceprob/((double)s->sequencelength));

      sequence_free (s);
    }

  printf ("\n\n");

  return logprob / ((double) outputsymbols);
}

// hmm_logjointprob : log (P(x*, y)) / N

double hmm_logjointprob (hmm_model *hmm, char *format, dataset *d)
{
  // printf ("Calculating HMM probability on test files (%s): ", d->name);

  double logprob = 0;
  int outputsymbols = 0;

  for (int entry = 0; entry < d->entries; entry++)
    {
      // printf ("%d ", test_filename_number);
      
      sequence_data *s = sequence_read (hmm->model_name, format, d->filenames[entry]);

      double logsequenceprob = 0.;

      /* sum log joint probability over file */

      double logp_initial = gsl_vector_get (hmm->logp_initial, s->hidden[0]);

      double logp_emission = gsl_matrix_get (hmm->logp_emission, s->visible[0], s->hidden[0]);
      logsequenceprob += logp_initial + logp_emission;

      for (int t = 1; t < s->sequencelength; t++)
	{
	  double logp_transition = gsl_matrix_get (hmm->logp_transition, s->hidden[t], s->hidden[t-1]);
	  double logp_emission = gsl_matrix_get (hmm->logp_emission, s->visible[t], s->hidden[t]);
	  logsequenceprob += logp_transition + logp_emission;
	}

#ifdef DEBUG
      printf ("%d\t%f\n", d->filenames[entry], logsequenceprob/((double)s->sequencelength));
#endif

      outputsymbols += s->sequencelength;
      logprob += logsequenceprob;

      sequence_free (s);
    }

  // printf ("%f %d\n", logprob, outputsymbols);

  return logprob / ((double) outputsymbols);
}

hmm_model *hmm_new (char *model_name)
{
  hmm_model *hmm = malloc (sizeof (hmm_model));

  hmm->model_name = malloc (strlen (model_name) + 1);
  strcpy (hmm->model_name, model_name);

  hmm->hiddenstates = 0;
  hmm->visiblestates = 0;
  hmm->normalised_flag = 0;

  /* read in model parameters */

  model_parameters *p = parameters_read (model_name);

  hmm->hiddenstates = p->hiddenstates;
  hmm->visiblestates = p->visiblestates;

  parameters_free (p);

  printf ("Model '%s':\nHidden states: %d\nVisible states: %d\n\n", model_name, hmm->hiddenstates, hmm->visiblestates);

  return hmm;
}

hmm_model *hmm_train (char *model_name, dataset *d)
{
  hmm_model *hmm = hmm_new (model_name);

  /* initialise GSL probability matrices */

  hmm->p_initial = gsl_vector_calloc (hmm->hiddenstates);
  hmm->logp_initial = gsl_vector_calloc (hmm->hiddenstates);
  hmm->p_transition = gsl_matrix_calloc (hmm->hiddenstates, hmm->hiddenstates);
  hmm->logp_transition = gsl_matrix_calloc (hmm->hiddenstates, hmm->hiddenstates);
  hmm->p_emission = gsl_matrix_calloc (hmm->visiblestates, hmm->hiddenstates);
  hmm->logp_emission = gsl_matrix_calloc (hmm->visiblestates, hmm->hiddenstates);

  /* loop through files in requested dataset */

  // printf ("Training HMM from input files: ");

  for (int entry = 0; entry < d->entries; entry++)
    {
      
#ifdef DEBUG
      printf ("%d ", d->filenames[entry]);
#endif

      sequence_data *s = sequence_read (hmm->model_name, DATAFILE_FORMAT, d->filenames[entry]);

      /* train probability matrices */

      for (int t = 0; t < s->sequencelength; t++)
	{
	  double n;

	  if (t == 0)
	    {
	      n = gsl_vector_get (hmm->p_initial, s->hidden[0]) + 1.;
	      gsl_vector_set (hmm->p_initial, s->hidden[0], n);
	    }
	  else
	    {
	      n = gsl_matrix_get (hmm->p_transition, s->hidden[t], s->hidden[t-1]) + 1.;
	      gsl_matrix_set (hmm->p_transition, s->hidden[t], s->hidden[t-1], n);
	    }

	  n = gsl_matrix_get (hmm->p_emission, s->visible[t], s->hidden[t]) + 1.;
	  gsl_matrix_set (hmm->p_emission, s->visible[t], s->hidden[t], n);

	}

      sequence_free (s);
    }

  // printf ("\n\n");

  /* smooth (add-k), normalise, and precalculate logs */

  vector_smooth_normalise_log (hmm->p_initial, hmm->logp_initial);
  // printf ("hmm p_transition:\n");
  matrix_smooth_normalise_log (hmm->p_transition, hmm->logp_transition);
  // printf ("hmm p_emission:\n");
  matrix_smooth_normalise_log (hmm->p_emission, hmm->logp_emission);

  hmm->normalised_flag = 1;

#if 1
  FILE *f = fopen ("/tmp/p_initial", "w");
  for (int output = 0; output < hmm->hiddenstates; output++)
    {
      fprintf (f, "%.05f\n", gsl_vector_get (hmm->p_initial, output));
    }
  fclose (f);

  f = fopen ("/tmp/p_transition", "w");
  for (int output = 0; output < hmm->hiddenstates; output++)
    {
      for (int input = 0; input < hmm->hiddenstates; input++)
	fprintf (f, "%.05f\t", gsl_matrix_get (hmm->p_transition, output, input));
      fprintf (f, "\n");
    }
  fclose (f);

  f = fopen ("/tmp/p_emission", "w");
  for (int output = 0; output < hmm->visiblestates; output++)
    {
      for (int input = 0; input < hmm->hiddenstates; input++)
	fprintf (f, "%.05f\t", gsl_matrix_get (hmm->p_emission, output, input));
      fprintf (f, "\n");
    }
  fclose (f);
#endif

  return hmm;
}

void hmm_free (hmm_model *hmm)
{
  if (hmm->model_name)
    free (hmm->model_name);
  if (hmm->p_initial)
    gsl_vector_free (hmm->p_initial);
  if (hmm->logp_initial)
    gsl_vector_free (hmm->logp_initial);
  if (hmm->p_transition)
    gsl_matrix_free (hmm->p_transition);
  if (hmm->logp_transition)
    gsl_matrix_free (hmm->logp_transition);
  if (hmm->p_emission)
    gsl_matrix_free (hmm->p_emission);
  if (hmm->logp_emission)
    gsl_matrix_free (hmm->logp_emission);
  free (hmm);
}


typedef struct {
  char *model_name;
  int hiddenstates;
  int visiblestates;
  int normalised_flag;
  gsl_vector *p_initial; /* initial hidden state probabilities */
  gsl_vector *logp_initial;
  gsl_matrix *p_transition; /* hidden state transition probabilities */
  gsl_matrix *logp_transition;
  gsl_matrix *p_emission; /* output probabilities */
  gsl_matrix *logp_emission;
} hmm_model;

typedef struct {
  gsl_matrix *alpha;
  gsl_matrix *alphahat;
  gsl_vector *c;
} hmm_alpha;

hmm_model *hmm_new (char *model_name);
hmm_model *hmm_train(char *model_name, dataset *d);
void hmm_free (hmm_model *hmm);

hmm_alpha *hmm_forwardprobs (hmm_model *hmm, int *hidden, int *visible, int sequencelength);
void hmm_forwardprobs_free (hmm_alpha *f);
double hmm_logoutputprob (hmm_model *hmm, char *format, dataset *d);
double hmm_logjointprob (hmm_model *hmm, char *format, dataset *d);

double hmm_viterbi (hmm_model *hmm, char *format, dataset *d);
void hmm_sample (hmm_model *hmm, char *format, dataset *d, unsigned long int seed);
void hmm_sequence_probs (hmm_model *hmm, char *format, int filename);

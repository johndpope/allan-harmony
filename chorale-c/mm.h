typedef struct {
  char *model_name;
  int model_column; /* in our files, 0: hidden; 1: visible */
  int inputstates;
  int outputstates;
  int normalised_flag;
  gsl_vector *p_initial; /* initial (visible) state probabilities */
  gsl_vector *logp_initial;
  gsl_matrix *p_transition; /* (visible) state transition probabilities */
  gsl_matrix *logp_transition;
} mm_model;

mm_model *mm_new (char *model_name, int model_column);
mm_model *mm_train (char *model_name, dataset *d, int model_column);
mm_model *mm_orderzero_train (char *model_name, dataset *d, int model_column);
void mm_free (mm_model *mm);

double mm_logprob (mm_model *mm, char *format, dataset *d);
double mm_orderzero_logprob (mm_model *mm, char *format, dataset *d);

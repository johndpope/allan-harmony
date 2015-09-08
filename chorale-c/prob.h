#ifndef HARMONYDIR
#define HARMONYDIR "./"
#endif

#ifndef MODELDIR
#define MODELDIR "./"
#endif

#define DATASETS_DIR HARMONYDIR "datasets/"
#define DATAFILE_FORMAT MODELDIR "model-%s/input/bch%03d.txt"
#define TESTFILE_FORMAT MODELDIR "model-%s/input-test/bch%03d.txt"
#define VITERBIFILE_FORMAT MODELDIR "model-%s/viterbi/bch%03d.txt"
#define SAMPLEDFILE_FORMAT MODELDIR "model-%s/sampled/bch%03d.txt"
#define PARAMETERS_FORMAT MODELDIR "model-%s/PARAMETERS"

#define K_SMOOTHING_MATRIX 0.01
#define K_SMOOTHING_VECTOR 0.01
// were 0.1 / 0.01

typedef struct {
  int hiddenstates;
  int visiblestates;
  char *train;
  char *test;
} model_parameters;

typedef struct {
  char *name;
  int entries;
  int *filenames;
} dataset;

typedef struct {
  int sequencelength;
  int *hidden;
  int *visible;
} sequence_data;

model_parameters *parameters_read (char *model_name);
void parameters_free (model_parameters *p);
void matrix_smooth_normalise_log (gsl_matrix *m, gsl_matrix *logm);
void vector_smooth_normalise_log (gsl_vector *v, gsl_vector *logv);
void sequence_write (sequence_data *s, char *model_name, char *format, int filename);
sequence_data *sequence_read (char *model_name, char *format, int filename);
void sequence_free (sequence_data *s);
FILE *fopen_data (char *model_name, char *format, int file, const char *mode);
dataset *dataset_read (char *dataset_filename);
void dataset_free (dataset *d);

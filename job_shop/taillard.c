/*
  This code comes from the OR-Library:
  http://people.brunel.ac.uk/~mastjjb/jeb/orlib/files/jobshop2.txt
 */

/*
 Program to generate the 80 job shop instances proposed by
 Taillard, E. D.: "Benchmarks for basic scheduling problems",
 EJOR vol. 64, pp. 278-285, 1993

 Originaly written by Taillard in PASCAL, re-written in C by
 Dirk C. Mattfeld, University of Bremen <dirk@uni-bremen.de> and
 Rob J.M. Vaessens, Eindhoven University of Technology <robv@win.tue.nl>.
 Last update : 2/7/1996.

 UNIX compile: cc -o jsp_gen jsp_gen.c -lm

 Tested on the machines/systems/compilers listed below.
 DEC 5000    Ultrix 4.2    cc
 SUN 10      Solaris 2     cc
 IBM 6000    AIX 3.x       xlc
 Atari ST    TOS           pure c
 IBM-PC      DOS 6.2       MS-C
 IBM-PC      Linux         gcc

 Care should be taken on 64 bit machines (e.g. Cray). There,
 'long' and 'double' contain 128 bit. In this case replace all
 'long' and 'double' with the appropriate 64 bit type.

     Verification file 'ta01' (if VERIFY == 1 and FIRMACIND == 1)
        4 4
        3 54 1 34 4 61 2 2
        4 9 1 15 2 89 3 70
        1 38 2 19 3 28 4 87
        1 95 3 34 2 7 4 29
*/

#define ANSI_C 0     /* 0:   K&R function style convention */
#define VERIFY 0     /* 1:   produce the verification file */
#define FIRMACIND 0  /* 0,1: first machine index           */

#include <stdio.h>
#include <math.h>

struct problem {
  long rand_time;     /* random seed for jobs */
  long rand_mach;     /* random seed for mach */
  short num_jobs;     /* number of jobs */
  short num_mach;     /* number of machines */
};

#if VERIFY == 1

struct problem S[] = {
  {         0,         0, 0, 0},
  {1166510396, 164000672, 4, 4},
  {         0,         0, 0, 0}};

#else /* VERIFY */

struct problem S[] = {
{          0,           0,    0,    0}, /* 15 jobs  15 machines */
{   840612802,  398197754,   15,  15 },
{  1314640371,  386720536,   15,  15 },
{  1227221349,  316176388,   15,  15 },
{   342269428, 1806358582,   15,  15 },
{  1603221416, 1501949241,   15,  15 },
{  1357584978, 1734077082,   15,  15 },
{    44531661, 1374316395,   15,  15 },
{   302545136, 2092186050,   15,  15 },
{  1153780144, 1393392374,   15,  15 },
{    73896786, 1544979948,   15,  15 },
                                        /* 20 jobs  15 machines */
{   533484900,  317419073,   20,  15 },
{  1894307698, 1474268163,   20,  15 },
{   874340513,  509669280,   20,  15 },
{  1124986343, 1209573668,   20,  15 },
{  1463788335,  529048107,   20,  15 },
{  1056908795,   25321885,   20,  15 },
{   195672285, 1717580117,   20,  15 },
{   961965583, 1353003786,   20,  15 },
{  1610169733, 1734469503,   20,  15 },
{   532794656,  998486810,   20,  15 },
                                        /* 20 jobs  20 machines */
{  1035939303,  773961798,   20,  20 },
{     5997802, 1872541150,   20,  20 },
{  1357503601,  722225039,   20,  20 },
{   806159563, 1166962073,   20,  20 },
{  1902815253, 1879990068,   20,  20 },
{  1503184031, 1850351876,   20,  20 },
{  1032645967,   99711329,   20,  20 },
{   229894219, 1158117804,   20,  20 },
{   823349822,  108033225,   20,  20 },
{  1297900341,  489486403,   20,  20 },
                                        /* 30 jobs  15 machines */
{    98640593, 1981283465,   30,  15 },
{  1839268120,  248890888,   30,  15 },
{   573875290, 2081512253,   30,  15 },
{  1670898570,  788294565,   30,  15 },
{  1118914567, 1074349202,   30,  15 },
{   178750207,  294279708,   30,  15 },
{  1549372605,  596993084,   30,  15 },
{   798174738,  151685779,   30,  15 },
{   553410952, 1329272528,   30,  15 },
{  1661531649, 1173386294,   30,  15 },
                                        /* 30 jobs  20 machines */
{  1841414609, 1357882888,   30,  20 },
{  2116959593, 1546338557,   30,  20 },
{   796392706, 1230864158,   30,  20 },
{   532496463,  254174057,   30,  20 },
{  2020525633,  978943053,   30,  20 },
{   524444252,  185526083,   30,  20 },
{  1569394691,  487269855,   30,  20 },
{  1460267840, 1631446539,   30,  20 },
{   198324822, 1937476577,   30,  20 },
{    38071822, 1541985579,   30,  20 },
                                        /* 50 jobs  15 machines */
{       17271,     718939,   50,  15 },
{   660481279,  449650254,   50,  15 },
{   352229765,  949737911,   50,  15 },
{  1197518780,  166840558,   50,  15 },
{  1376020303,  483922052,   50,  15 },
{  2106639239,  955932362,   50,  15 },
{  1765352082, 1209982549,   50,  15 },
{  1105092880, 1349003108,   50,  15 },
{   907248070,  919544535,   50,  15 },
{  2011630757, 1845447001,   50,  15 },
                                        /* 50 jobs  20 machines */
{    8493988,    2738939,    50,  20 },
{  1991925010,  709517751,   50,  20 },
{   342093237,  786960785,   50,  20 },
{  1634043183,  973178279,   50,  20 },
{   341706507,  286513148,   50,  20 },
{   320167954, 1411193018,   50,  20 },
{  1089696753,  298068750,   50,  20 },
{   433032965, 1589656152,   50,  20 },
{   615974477,  331205412,   50,  20 },
{   236150141,  592292984,   50,  20 },
                                        /* 100 jobs  20 machines */
{   302034063, 1203569070,  100,  20 },
{  1437643198, 1692025209,  100,  20 },
{  1792475497, 1039908559,  100,  20 },
{  1647273132, 1012841433,  100,  20 },
{   696480901, 1689682358,  100,  20 },
{  1785569423, 1092647459,  100,  20 },
{   117806902,  739059626,  100,  20 },
{  1639154709, 1319962509,  100,  20 },
{  2007423389,  749368241,  100,  20 },
{   682761130,  262763021,  100,  20 },
{           0,          0,    0,   0 }};
#endif /* VERIFY */

/* generate a random number uniformly between low and high */

#if ANSI_C == 1
short unif (long *seed, short low, short high)
#else
short unif (seed, low, high)
long *seed; short low, high;
#endif
{
  static long m = 2147483647, a = 16807, b = 127773, c = 2836;
  double  value_0_1;

  long k = *seed / b;
  *seed = a * (*seed % b) - k * c;
  if(*seed < 0) *seed = *seed + m;
  value_0_1 =  *seed / (double) m;

  return low + floor(value_0_1 * (high - low + 1));
}

/* Maximal 100 jobs and 20 machines are provided. */
/* For larger problems extend array sizes.        */

short d[101][21];                        /* duration */
short M[101][21];                        /* machine  */


#if ANSI_C == 1
void generate_job_shop(short p)          /* Fill d and M according to S[p] */
#else
void generate_job_shop(p)
short p;
#endif
{
  short i, j;
  long time_seed = S[p].rand_time;
  long machine_seed = S[p].rand_mach;

  for(i = 0; i < S[p].num_jobs; ++i)      /* determine a random duration */
    for (j = 0; j < S[p].num_mach; ++j)   /* for all operations */
      d[i][j] = unif(&time_seed, 1, 99);  /* 99 = max. duration of op. */

  for(i = 0; i < S[p].num_jobs; ++i)      /* determine a machine */
    for (j = 0; j < S[p].num_mach; ++j)   /* for all operations */
      M[i][j] = j;                        /* assign the machine j */


  for(i = 0; i < S[p].num_jobs; ++i) {    /* for all jobs */
    for (j = 0; j < S[p].num_mach; ++j) { /* for all machines*/
      int k = unif(&machine_seed, j, S[p].num_mach-1);  /* get rand index */

      short t = M[i][j];                  /* swap positions j and k */
      M[i][j] = M[i][k];
      M[i][k] = t;
    }
  }
}

#if ANSI_C == 1
void write_problem(short p)  /* write out problem */
#else
void write_problem(p)
short p;
#endif
{
  short i, j;
  FILE *f = NULL;
  char name[5];

  sprintf(name,"ta%02d", p);                 /* file name construction */
  if(!(f = fopen(name,"w"))) {               /* open file for writing  */
    fprintf(stderr,"file %s error\n", name);
    return;
  }
  fprintf(f,"%d %d\n", S[p].num_jobs, S[p].num_mach);   /* write header line */

  for(i = 0; i < S[p].num_jobs; ++i) {
    for(j = 0; j < S[p].num_mach; ++j) {
      fprintf(f,"%2d %2d ", M[i][j]+FIRMACIND, d[i][j]); /* write machine and job */
    }
    fprintf(f,"\n");                         /* newline == End of job */
  }
  fclose(f);                                 /* close file */
}


int main()
{
  short i = 1;
  while(S[i].rand_time) {                    /* for i == 1 up to NULL entry */
    generate_job_shop(i);                    /* generate problem i  */
    write_problem(i);                        /* write out problem i */
    ++i;                                     /* increment i */
  }
  return 0;
}

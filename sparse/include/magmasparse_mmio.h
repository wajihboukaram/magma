/*
*   Matrix Market I/O library for ANSI C
*
*   See http://math.nist.gov/MatrixMarket for details.
*
*
*/
#include <stdio.h>

#include "magma_v2.h"
#include "magmasparse.h"

#ifndef MM_IO_H
#define MM_IO_H

#define MM_MAX_LINE_LENGTH 1025
#define MatrixMarketBanner "%%MatrixMarket"
#define MM_MAX_TOKEN_LENGTH 64

typedef char MM_typecode[4];

void mm_snprintf_typecode( char *buffer, size_t buflen, MM_typecode matcode );

int mm_read_banner(FILE *f, MM_typecode *matcode);
int mm_read_mtx_crd_size(FILE *f, magma_index_t *M, magma_index_t *N,
                                                    magma_index_t *nz);
int mm_read_mtx_array_size(FILE *f, magma_index_t *M, magma_index_t *N);

int mm_write_banner(FILE *f, MM_typecode matcode);
int mm_write_mtx_crd_size(FILE *f, magma_index_t M, magma_index_t N,
                                                    magma_index_t nz);
int mm_write_mtx_array_size(FILE *f, magma_index_t M, magma_index_t N);


/********************* MM_typecode query fucntions ***************************/

#define mm_is_matrix(typecode)  ((typecode)[0]=='M')

#define mm_is_sparse(typecode)  ((typecode)[1]=='C')
#define mm_is_coordinate(typecode)((typecode)[1]=='C')
#define mm_is_dense(typecode)  ((typecode)[1]=='A')
#define mm_is_array(typecode)  ((typecode)[1]=='A')

#define mm_is_complex(typecode)  ((typecode)[2]=='C')
#define mm_is_real(typecode)    ((typecode)[2]=='R')
#define mm_is_pattern(typecode)  ((typecode)[2]=='P')
#define mm_is_integer(typecode) ((typecode)[2]=='I')

#define mm_is_symmetric(typecode)((typecode)[3]=='S')
#define mm_is_general(typecode)  ((typecode)[3]=='G')
#define mm_is_skew(typecode)  ((typecode)[3]=='K')
#define mm_is_hermitian(typecode)((typecode)[3]=='H')

int mm_is_valid(MM_typecode matcode);    /* too complex for a macro */


/********************* MM_typecode modify fucntions ***************************/

#define mm_set_matrix(typecode)  ((*typecode)[0]='M')
#define mm_set_coordinate(typecode)  ((*typecode)[1]='C')
#define mm_set_array(typecode)  ((*typecode)[1]='A')
#define mm_set_dense(typecode)  mm_set_array(typecode)
#define mm_set_sparse(typecode)  mm_set_coordinate(typecode)

#define mm_set_complex(typecode)((*typecode)[2]='C')
#define mm_set_real(typecode)  ((*typecode)[2]='R')
#define mm_set_pattern(typecode)((*typecode)[2]='P')
#define mm_set_integer(typecode)((*typecode)[2]='I')


#define mm_set_symmetric(typecode)((*typecode)[3]='S')
#define mm_set_general(typecode)((*typecode)[3]='G')
#define mm_set_skew(typecode)  ((*typecode)[3]='K')
#define mm_set_hermitian(typecode)((*typecode)[3]='H')

#define mm_clear_typecode(typecode) ((*typecode)[0]=(*typecode)[1]= \
                  (*typecode)[2]=' ',(*typecode)[3]='G')

#define mm_initialize_typecode(typecode) mm_clear_typecode(typecode)


/********************* Matrix Market error codes ***************************/


#define MM_COULD_NOT_READ_FILE  11
#define MM_PREMATURE_EOF    12
#define MM_NOT_MTX        13
#define MM_NO_HEADER      14
#define MM_UNSUPPORTED_TYPE    15
#define MM_LINE_TOO_LONG    16
#define MM_COULD_NOT_WRITE_FILE  17


/******************** Matrix Market internal definitions ********************

   MM_matrix_typecode: 4-character sequence

                     object     sparse/      data         storage
                                dense        type         scheme

   string position:  [0]        [1]          [2]          [3]

   Matrix typecode:  M(atrix)   C(oord)      R(eal)       G(eneral)
                                A(array)     C(omplex)    H(ermitian)
                                             P(attern)    S(ymmetric)
                                             I(nteger)    K(skew)

 ***********************************************************************/

#define MM_UNKNOWN        "unknown"

#define MM_MTX_STR        "matrix"

#define MM_ARRAY_STR      "array"
#define MM_DENSE_STR      "array"
#define MM_COORDINATE_STR "coordinate"
#define MM_SPARSE_STR     "coordinate"

#define MM_COMPLEX_STR    "complex"
#define MM_REAL_STR       "real"
#define MM_INT_STR        "integer"
#define MM_PATTERN_STR    "pattern"

#define MM_GENERAL_STR    "general"
#define MM_SYMM_STR       "symmetric"
#define MM_HERM_STR       "hermitian"
#define MM_SKEW_STR       "skew-symmetric"


/*  high level routines */

/// @deprecated
/// @ingroup magma_deprecated_sparse
MAGMA_DEPRECATE("mm_write_mtx_crd is deprecated and will be removed in the next release")
int mm_write_mtx_crd(char fname[], magma_index_t M, magma_index_t N, magma_index_t nz,
      magma_index_t I[], magma_index_t J[], double val[], MM_typecode matcode);

/// @deprecated
/// @ingroup magma_deprecated_sparse
MAGMA_DEPRECATE("mm_read_mtx_crd_data is deprecated and will be removed in the next release")
int mm_read_mtx_crd_data(FILE *f, magma_index_t M, magma_index_t N, magma_index_t nz,
      magma_index_t I[], magma_index_t J[], double val[], MM_typecode matcode);

/// @deprecated
/// @ingroup magma_deprecated_sparse
MAGMA_DEPRECATE("mm_read_mtx_crd_entry is deprecated and will be removed in the next release")
int mm_read_mtx_crd_entry(FILE *f, magma_index_t *I, magma_index_t *J,
        double *real, double *img, MM_typecode matcode);

/// @deprecated
/// @ingroup magma_deprecated_sparse
MAGMA_DEPRECATE("mm_read_unsymmetric_sparse is deprecated and will be removed in the next release")
int mm_read_unsymmetric_sparse(const char *fname, magma_index_t *M_,
        magma_index_t *N_, magma_index_t *nz_,
        double **val_, magma_index_t **I_, magma_index_t **J_);



#endif

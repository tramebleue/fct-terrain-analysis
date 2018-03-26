# coding: utf-8

import numpy as np
import array

cimport numpy as np
cimport cython
from cpython cimport array

#                                    0   1   2   3   4   5   6   7
#                                    N  NE   E  SE   S  SW   W  NW
cdef int[8] ci = array.array('i', [ -1, -1,  0,  1,  1,  1,  0, -1 ])
cdef int[8] cj = array.array('i', [  0,  1,  1,  1,  0, -1, -1, -1 ])

@cython.boundscheck(False)
@cython.wraparound(False)
def flowdir(np.ndarray[float, ndim=2] data, np.ndarray[unsigned char, ndim=2] out, np.ndarray[double, ndim=2] distance_2d, double nodata):

    cdef long rows, cols
    cdef long i, j
    cdef int x, minx
    cdef float z, zx, sx, mins

    with nogil:

        rows = out.shape[0]
        cols = out.shape[1]

        for i in range(rows):
            for j in range(cols):
                
                z = data[i+1, j+1]
                if z == nodata:
                    # out[x, y] = nodata
                    continue

                mins = 0.0
                minx = 0

                for x in range(8):

                    zx = data[ i+ci[x]+1, j+cj[x]+1 ]
                    sx = (zx - z) / distance_2d[ ci[x]+1, cj[x]+1 ]

                    if sx < mins:

                        mins = sx
                        minx = x

                out[i, j] = 1 << minx

# coding: utf-8


@cython.boundscheck(False)
@cython.wraparound(False)
def flowdir(
        np.ndarray[float, ndim=2] data,
        np.ndarray[unsigned char, ndim=2] out,
        np.ndarray[double, ndim=2] distance_2d,
        double nodata):

    cdef long rows, cols
    cdef long i, j
    cdef int x, minx, maxx
    cdef float z, zx, sx, mins, maxs

    with nogil:

        rows = out.shape[0]
        cols = out.shape[1]

        for i in range(rows):
            for j in range(cols):
                
                z = data[i+1, j+1]
                if z == nodata:
                    # out[x, y] = nodata
                    continue

                mins = maxs = 0.0
                minx = maxx = 0

                for x in range(8):

                    zx = data[ i+ci[x]+1, j+cj[x]+1 ]

                    if zx == nodata:
                        continue

                    sx = (zx - z) / distance_2d[ ci[x]+1, cj[x]+1 ]

                    if sx < mins:

                        mins = sx
                        minx = x

                    elif sx > maxs:

                        maxs = sx
                        maxx = x

                if mins < 0.0:

                    out[i, j] = 1 << minx

                elif maxs > 0.0:

                    if maxx > 3:

                        out[ i, j ] = 1 << (maxx - 4)

                    else:

                        out[ i, j ] = 1 << (maxx + 4)

                else:

                    out[ i, j ] = 1

# coding: utf-8


@cython.boundscheck(False)
@cython.wraparound(False)
def strahler(
        float[:,:] elevations,
        unsigned char[:,:] flowdir,
        unsigned char[:,:] out,
        float flowdir_nodata):

    cdef long height, width, k, x
    cdef np.ndarray[long] idx
    cdef np.ndarray[unsigned char, ndim=2] count
    cdef long i, j, ix, jx, dx
    cdef float z

    cdef CppTermProgress progress

    height = elevations.shape[0]
    width = elevations.shape[1]

    progress = CppTermProgress(height*width)

    progress.write('Sorting input by z ...')

    idx = elevations.reshape(height*width).argsort(kind='mergesort')
    count = np.zeros((height, width), dtype=np.uint8)

    progress.write('Compute strahler order ...')
    x = idx[height*width-1]
    msg  = 'Start from z = %.3f' % elevations[ x // width, x % width ]
    progress.write(msg)

    with nogil:

        for k in range(height*width-1, -1, -1):

            x = idx[k]
            i = x // width
            j = x  % width

            dx = flowdir[ i, j ]

            if dx == flowdir_nodata:

                out[ i, j ] = 0
                progress.update(1)
                continue

            if out[ i, j ] == 0: out[ i, j ] = 1

            if count[ i, j ] > 1:

                out[ i, j ] = out[ i, j ] + 1

            if dx > 0:

                dx = ilog2(dx)
                ix = i + ci[dx]
                jx = j + cj[dx]

                if ingrid(height, width, ix, jx):

                    if out[ i, j ] > out[ ix, jx ]:

                        # At junction (i, j)

                        out[ ix, jx ] = out[ i, j ]
                        count[ ix, jx ] = 1

                    elif out[ i, j ] == out[ ix, jx ]:

                        # At junction (ix, jx),
                        # counting number of upstream cells with same order

                        count[ ix, jx ] = count[ i, j ] + 1

            progress.update(1)

    progress.close()
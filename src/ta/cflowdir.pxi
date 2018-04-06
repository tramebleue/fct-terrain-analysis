# coding: utf-8


@cython.boundscheck(False)
@cython.wraparound(False)
def flowdir(
        float[:,:] data,
        float rx,
        float ry,
        double nodata,
        unsigned char[:,:] out):
    """
    flowdir(data, rx, ry, nodata, out)

    Compute the D8 flow direction,
    ie. the direction of the neighbor cell having the maximum z gradient (slope).

    Directions are numbered clockwise starting form North (N = 0)
    and are coded as power of 2 (N = 2^0 = 1) in the output.

    NW=128 |   N=1   |  NE=2
    -------------------------
     W=64  |   i,j   |  E=4
    -------------------------
    SW=32  |  S=16   |  SE=8

    Parameters
    ----------

    elevations: array-like, dtype float
        z values from digital elevation model (DEM),
        1-pixel padded with nodata with respect to `out`'s shape

    rx: float
        Cell resolution in x direction

    ry: float
        Cell resolution in x direction

    nodata: float
        No-data value in the raster elevation input

    out: array-like
        Output raster, dtype uint8, initialized to 0
    """

    cdef long rows, cols
    cdef long i, j
    cdef int x, minx, maxx
    cdef float z, zx, sx, mins, maxs
    cdef double[:,:] d2d = distance_2d(rx, ry)

    rows = out.shape[0]
    cols = out.shape[1]

    with nogil:

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

                    sx = (zx - z) / d2d[ ci[x]+1, cj[x]+1 ]

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

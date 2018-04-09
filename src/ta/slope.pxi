# coding: utf-8

@cython.boundscheck(False)
@cython.wraparound(False)
def max_slope(
        float[:, :] elevations,
        float[:, :] out,
        float rx,
        float ry,
        float nodata):
    """
    max_slope(elevations, rx, ry, nodata, out)

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
        Output raster, dtype uint8, initialized to nodata

    """

    cdef long rows, cols
    cdef long i, j
    cdef int x, minx, maxx
    cdef float z, zx, sx, mins, maxs
    cdef double[:, :] d2d

    rows = out.shape[0]
    cols = out.shape[1]

    d2d = distance_2d(rx, ry)

    with nogil:

        for i in range(rows):
            for j in range(cols):

                z = elevations[i+1, j+1]
                if z == nodata:
                    # out[ i, j ] = nodata
                    continue

                mins = 0.0

                for x in range(8):

                    zx = elevations[ i+ci[x]+1, j+cj[x]+1 ]

                    if zx == nodata:
                        continue

                    sx = (zx - z) / d2d[ ci[x]+1, cj[x]+1 ]

                    if sx < mins:

                        mins = sx

                out[ i, j ] = -mins

    return out

@cython.boundscheck(False)
@cython.wraparound(False)
cdef Gradient local_gradient(float[:, :] elevations, float rx, float ry, float nodata, long i, long j) nogil:

    cdef float dzx, dzy, r1, r0
    cdef Gradient gradient

    dzx = dzy = 0.0
    gradient.slope = 0.0
    gradient.aspect = -1.0

    r0 = elevations[ i+1, j ]
    r1 = elevations[ i+1, j+2 ]
    if r0 != nodata and r1 != nodata:
        dzx = (r1 - r0) / (2 * rx)

    r0 = elevations[ i+2, j+1 ]
    r1 = elevations[ i,   j+1 ]    
    if r0 != nodata and r1 != nodata:
        dzy = (r1 - r0) / (2 * ry)

    if not (dzx == 0.0 and dzy == 0.0):

        gradient.slope = sqrt(dzx*dzx + dzy*dzy)

        # Aspect is zero for the North direction and increases clockwise.

        # if dzy == 0.0:
        #     if dzx > 0.0:
        #         gradient.aspect = 1.5*pi
        #     elif dzx < 0.0:
        #         gradient.aspect = 0.5*pi
        # else:
        
        gradient.aspect = pi + atan2(dzx, dzy)

    return gradient


@cython.boundscheck(False)
@cython.wraparound(False)
def gradient(
        float[:, :] elevations,
        float rx,
        float ry,
        float nodata,
        float[:, :] out_slope,
        float[:, :] out_aspect):
    """
    gradient(elevations, rx, ry, nodata, out)

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
        Output raster, dtype uint8, initialized to nodata

    """

    cdef long rows, cols
    cdef long i, j
    cdef int x, nx, ny
    cdef float z, dzx, dzy, r1, r0
    cdef Gradient gradient

    assert(out_slope.shape[0] == out_aspect.shape[0] and out_slope.shape[1] == out_aspect.shape[1])

    with nogil:

        rows = out_slope.shape[0]
        cols = out_slope.shape[1]

        for i in range(rows):
            for j in range(cols):

                if not ingrid3x3(rows, cols, i, j):
                    continue

                z = elevations[i+1, j+1]
                if z == nodata:
                    # out[ i, j ] = nodata
                    continue

                gradient = local_gradient(elevations, rx, ry, nodata, i, j)
                out_slope[ i, j ] = gradient.slope
                out_aspect[ i, j] = gradient.aspect

# coding: utf-8

@cython.boundscheck(False)
@cython.wraparound(False)
def hillshade(
        float[:,:] elevations,
        float rx,
        float ry,
        float nodata,
        float azimuth,
        float declination,
        float zscale,
        float[:,:] out):
    """
    hillshade(elevations, nodata, rx, ry, azimuth, declination, zscale, out)

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

    azimuth: float
        Direction of the light source, measured in degree clockwise from the North direction.

    declination: float
        Height of the light source, measured in degree above the horizon.

    out: array-like
        Output raster, dtype uint8, initialized to nodata
    """

    cdef long rows, cols
    cdef long i, j
    cdef float z, angle
    cdef Gradient gradient

    with nogil:

        rows = out.shape[0]
        cols = out.shape[1]

        azimuth = deg2rad(azimuth)
        declination = deg2rad(declination)

        for i in range(rows):
            for j in range(cols):

                if not ingrid3x3(rows, cols, i, j):
                    continue

                z = elevations[ i+1, j+1 ]
                if z == nodata:
                    continue

                gradient = local_gradient(elevations, rx, ry, nodata, i, j)

                # surface normal angle with z-axis
                angle = 0.5*pi - atan(zscale * gradient.slope)

                # light angle with surface normal
                angle = acos( sin(angle)*sin(declination) + cos(angle)*cos(declination)*cos(gradient.aspect - azimuth) )

                # if angle > pi:
                #     angle = pi

                # if combined:
                #   angle = angle * gradient.slope / pi

                out[ i, j ] = angle
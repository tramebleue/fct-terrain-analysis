# coding: utf-8


@cython.boundscheck(False)
@cython.wraparound(False)
def fillsinks(
        float[:,:] data,
        src,
        float minslope,
        float[:,:] out = None):
    """
    fillsinks(elevations, src, minslope, out=None)

    Fill sinks of digital elevation model (DEM),
    based on the algorithm of Wang & Liu (2006).

    Parameters
    ----------

    elevations: array-like
        Digital elevation model (DEM) raster (ndim=2)

    src: rasterio dataset descriptor

    out: array-like
        Same shape and dtype as elevations, initialized to nodata

    minslope: float
        Minimum slope to preserve between cells
        when filling up sinks.

    Returns
    -------

    Filled raster.

    Notes
    -----

    [1] Wang, L. & H. Liu (2006)
        An efficient method for identifying and filling surface depressions
        in digital elevation models.
        International Journal of Geographical Information Science,
        Vol. 20, No. 2: 193-213.

    [2] SAGA C++ Implementation
        https://github.com/saga-gis/saga-gis/blob/1b54363/saga-gis/src/tools/terrain_analysis/ta_preprocessor/FillSinks_WL_XXL.cpp
        GPL Licensed
    """

    cdef long width, height
    cdef float dx, dy, nodata

    cdef long i, j, x, ix, jx
    cdef float z, zx
    cdef Cell ij
    cdef QueueEntry entry
    cdef CellQueue queue

    cdef np.ndarray[double, ndim=2] w
    cdef np.ndarray[float] mindiff
    cdef CppTermProgress progress

    height = data.shape[0]
    width = data.shape[1]
    
    nodata = src.nodata
    dx = src.transform.a
    dy = -src.transform.e

    w = np.array([ ci, cj ]).T * (dx, dy)
    mindiff = np.float32(minslope*np.sqrt(np.sum(w*w, axis=1)))

    if out is None:
        out = np.full((height, width), nodata, dtype=np.float32)
    
    progress = CppTermProgress(2*width*height)
    msg = 'Input is %d x %d' % (width, height)
    progress.write(msg)
    msg = 'Find boundary cells ...'
    progress.write(msg)

    with nogil:

        for i in range(height):
            for j in range(width):

                z = data[ i, j ]
                
                if z != nodata:
                    
                    for x in range(8):
                    
                        ix = i + ci[x]
                        jx = j + cj[x]
                    
                        if not ingrid(height, width, ix, jx) or (data[ ix, jx ] == nodata):
                            
                            # heapq.heappush(queue, (-z, x, y))
                            entry = QueueEntry(-z, Cell(i, j))
                            queue.push(entry)
                            out[ i, j ] = z

                            break

                progress.update(1)

    msg = 'Fill depressions from bottom to top ...'
    progress.write(msg)

    entry = queue.top()
    z = -entry.first
    
    msg = f'Starting from z = {z:.3f}'
    progress.write(msg)

    with nogil:
        
        while not queue.empty():

            # z, x, y = heapq.heappop(queue)
            # z = out[x, y]
            entry = queue.top()
            queue.pop()

            # z = -entry.first
            ij = entry.second
            i = ij.first
            j = ij.second
            z = out[ i, j ]

            for x in range(8):
                
                ix = i + ci[x]
                jx = j + cj[x]
                zx = data[ ix, jx ]
                
                if ingrid(height, width, ix, jx) and (zx != nodata) and (out[ ix, jx ] == nodata):

                    if zx < (z + mindiff[x]):
                        zx = z + mindiff[x]

                    out[ ix, jx ] = zx

                    # heapq.heappush(queue, (-iz, ix, iy))
                    entry = QueueEntry(-zx, Cell(ix, jx))
                    queue.push(entry)

            progress.update(1)

    msg = 'Done.'
    progress.write(msg)
    progress.close()

    return np.asarray(out)
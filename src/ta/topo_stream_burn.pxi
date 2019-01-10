ctypedef pair[unsigned char, float] TopoKey
ctypedef pair[TopoKey, Cell] TopoQueueEntry
ctypedef priority_queue[TopoQueueEntry] TopoQueue

cdef inline unsigned char reverse_direction(unsigned char x) nogil:
    """ Return D8 inverse search directions
    """

    return (x + 4) % 8

@cython.boundscheck(False)
@cython.wraparound(False)
def topo_stream_burn(
    float[:,:] elevations,
    float[:,:] streams,
    src,
    float minslope=1e-3,
    short[:,:] out=None,):
    """ Fill sinks of digital elevation model (DEM),
        based on the algorithm of Wang & Liu (2006).

    Parameters
    ----------

    elevations: array-like
        Digital elevation model (DEM) raster (ndim=2)

    streams: array-like
        Digital elevation model (DEM) raster (ndim=2)

    src: rasterio dataset descriptor

    out: array-like
        Same shape and dtype as elevations, initialized to nodata

    minslope: float
        Minimum slope to preserve between cells
        when filling up sinks.

    Returns
    -------

    D8 Flow Direction raster

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
    cdef float dx, dy, nodata, z, zx
    cdef np.ndarray[double, ndim=2] w
    cdef np.ndarray[float] mindiff
    cdef long i, j, ix, jx, x, ncells
    cdef unsigned char instream, instreamx

    cdef Cell cell
    cdef TopoKey key
    cdef TopoQueueEntry entry
    cdef TopoQueue queue

    cdef CppTermProgress progress

    height = elevations.shape[0]
    width = elevations.shape[1]

    nodata = src.nodata
    dx = src.transform.a
    dy = -src.transform.e

    w = np.array([ ci, cj ]).T * (dx, dy)
    mindiff = np.float32(minslope*np.sqrt(np.sum(w*w, axis=1)))

    if out is None:
        out = np.full((height, width), -1, dtype=np.int16)

    # progress = TermProgressBar(2*width*height)
    # progress.write('Input is %d x %d' % (width, height))

    progress = CppTermProgress(width*height)
    progress.write('Find boundary cells ...')

    with nogil:

        for i in range(height):
            for j in range(width):

                z = elevations[i, j]
                instream = 1 if streams[i, j] > 0 else 0

                if z != nodata:

                    ncells += 1

                    for x in range(8):

                        ix = i + ci[x]
                        jx = j + cj[x]

                        if not ingrid(height, width, ix, jx) or (elevations[ix, jx] == nodata):

                            # out[ i, j ] = z
                            # heappush(queue, (instream, z, i, j))
                            cell = Cell(i, j)
                            key = TopoKey(instream, -z)
                            entry = TopoQueueEntry(key, cell)
                            queue.push(entry)

                            break

                progress.update(1)

        progress.write('')
        progress = CppTermProgress(ncells)
        progress.write('Fill depressions from bottom to top ...')

        while not queue.empty():

            # instream, z, i, j = heappop(queue)
            entry = queue.top()
            queue.pop()
            key = entry.first
            cell = entry.second
            instream = key.first
            z = -key.second
            i = cell.first
            j = cell.second

            if out[i, j] == -1:
                out[i, j] = 0

            for x in range(8):

                ix = i + ci[x]
                jx = j + cj[x]

                if ingrid(height, width, ix, jx):

                    zx = elevations[ix, jx]
                    instreamx = 1 if streams[ix, jx] > 0 else 0

                    if (zx != nodata) and (out[ix, jx] == -1):

                        if zx < (z + mindiff[x]):
                            zx = z + mindiff[x]

                        out[ix, jx] = pow2(reverse_direction(x))
                        # heappush(queue, (instreamx, zx, ix, jx))
                        cell = Cell(ix, jx)
                        key = TopoKey(instreamx, -zx)
                        entry = TopoQueueEntry(key, cell)
                        queue.push(entry)

            progress.update(1)

    return out

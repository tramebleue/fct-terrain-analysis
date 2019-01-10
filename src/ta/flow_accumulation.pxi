@cython.boundscheck(False)
@cython.wraparound(False)
def flow_accumulation(short[:,:] flow, int[:,:] out=None):
    """ Fill sinks of digital elevation model (DEM),
        based on the algorithm of Wang & Liu (2006).

    Parameters
    ----------

    flow: array-like
        D8 Flow direction raster (ndim=2)

    out: array-like
        Same shape and dtype as elevations, initialized to nodata

    Returns
    -------

    Flow accumulation raster
    """

    cdef long width, height
    cdef float nodata
    cdef long i, j, ix, jx
    cdef int x
    cdef signed char[:,:] inflow
    cdef signed char inflowij
    cdef short direction
    cdef long ncells = 0
    cdef Cell cell
    cdef CellStack stack

    cdef CppTermProgress progress

    height = flow.shape[0]
    width = flow.shape[1]
    nodata = -1

    if out is None:
        out = np.full((height, width), -1, dtype=np.int32)

    inflow = np.full((height, width), -1, dtype=np.int8)

    # progress = TermProgressBar(2*width*height)
    # progress.write('Input is %d x %d' % (width, height))
    # feedback.setProgressText('Find source cells ...')
    progress = CppTermProgress(height*width)
    progress.write('Find source cells ...')

    with nogil:

        for i in range(height):
            for j in range(width):

                direction = flow[i, j]

                if direction != nodata:

                    out[i, j] = 1
                    inflowij = 0

                    for x in range(8):

                        ix = i + ci[x]
                        jx = j + cj[x]

                        if ingrid(height, width, ix, jx) and (flow[ix, jx] == upward[x]):
                            inflowij += 1

                    if inflowij == 0:
                        cell = Cell(i, j)
                        stack.push(cell)

                    inflow[i, j] = inflowij
                    ncells += 1

                progress.update(1)

        progress = CppTermProgress(ncells)
        progress.write('Accumulate ...')

        while not stack.empty():

            cell = stack.top()
            stack.pop()
            i = cell.first
            j = cell.second

            inflow[i, j] = -1

            direction = flow[i, j]
            if direction == 0:
                progress.update(1)
                continue

            x = ilog2(direction)
            ix = i + ci[x]
            jx = j + cj[x]

            while ingrid(height, width, ix, jx) and inflow[ix, jx] > 0:

                out[ix, jx] = out[ix, jx] + out[i, j]
                inflow[ix, jx] = inflow[ix, jx] - 1

                # check if we reached a confluence cell

                if inflow[ix, jx] > 0:
                    break

                # otherwise accumulate downward

                direction = flow[ix, jx]
                if direction == 0:
                    progress.update(1)
                    break

                inflow[ix, jx] = -1
                i = ix
                j = jx
                x = ilog2(direction)
                ix = i + ci[x]
                jx = j + cj[x]

                progress.update(1)

    return out


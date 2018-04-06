from libcpp.vector cimport vector

ctypedef vector[Cell] CellList
ctypedef vector[CellList] SegmentList

@cython.boundscheck(False)
@cython.wraparound(False)
cdef int indegree(
        unsigned char[:,:] flow,
        unsigned char[:,:] channels,
        long i,
        long j) nogil:
    """
    Compute in-degree of channel node.
    If not a channel node, return 0
    """

    cdef long height, width, ik, jk
    cdef int k, indeg = 0

    height = flow.shape[0]
    width = flow.shape[1]

    for k in range(8):

        ik = i + ci[k]
        jk = j + cj[k]

        if ingrid(height, width, ik, jk):

            if channels[ ik, jk ] > 0 and flow[ ik, jk ] == upward[k]:
                indeg += 1

    return indeg

@cython.boundscheck(False)
@cython.wraparound(False)
def channels(
        unsigned char[:,:] flow,
        unsigned char[:,:] channels,
        size_t min_length):
    """
    channels(flow, channels, min_length)

    Vectorize channel network.

    Parameters
    ----------

    flow : array_like
        D8 flow direction raster NxM, uint8

    channels : array_like
        channel network raster NxM, uint8
        (0 if not a channel, > 0 if a channel)

    min_length : int
        minimum length in pixels of segments to be output
        (apply only to head basin segments)

    Returns
    -------

    outlets : list of coordinate pairs
        coordinate pair as (row, column)

    confluences : list of coordinate pairs

    segments : list of segments
        ie. list of list of coordinate pairs

    Example
    -------

    >>> flow = ta.flowdir(dem, dem_nodata)
    >>> strahler = ta.strahler(dem, flowdir)
    >>> channels = np.uint8(strahler >= 6)
    >>> outlets, confluences, segments = ta.channels(flow, channels, 100)
    """

    cdef long height, width, i, j
    cdef long channels_count = 0, sources_count = 0
    cdef unsigned char direction, deg
    cdef bint from_source

    cdef Cell c
    cdef CellStack stack
    cdef CellList confluences
    cdef CellList outlets
    cdef CellList segment
    cdef SegmentList segments

    cdef unsigned char[:,:] seen_nodes
    cdef CppTermProgress progress

    height = flow.shape[0]
    width = flow.shape[1]
    seen_nodes = np.zeros((height, width), dtype=np.uint8)

    progress = CppTermProgress(height*width)
    progress.write('Find sources ...')

    # Pass 1 : Sequential scan
    #          Find source nodes, ie. pixels having in-degree = 0

    with nogil:

        for i in range(height):
            for j in range(width):

                if channels[ i, j ] > 0:

                    channels_count += 1

                    if indegree(flow, channels, i, j) == 0:

                        c = Cell(i, j)
                        stack.push(c)
                        sources_count += 1

                progress.update(1)

    progress.write('Found %d sources out of %d channel pixels' % (sources_count, channels_count))
    progress.close()

    progress = CppTermProgress(channels_count)
    progress.write('Walk downstream from sources ...')

    # confluences = list()
    # segments = list()

    # Pass 2 : Graph walk, from sources to outlets,
    #          breaking segments at confluences (junctions)

    with nogil:

        while not stack.empty():

            c = stack.top()
            stack.pop()

            i = c.first
            j = c.second

            segment = CellList()
            segment.push_back(c)

            from_source = (seen_nodes[ i,j ] == 0)

            direction = ilog2(flow[ i, j ])
            i = i + ci[direction]
            j = j + cj[direction]

            while ingrid(height, width, i, j) and flow[ i, j ] > 0:

                deg = indegree(flow, channels, i, j)

                # Visit simple nodes only once
                if deg < 2 and seen_nodes[ i, j ] > 0:
                    break

                # Append next point to current segment
                c = Cell(i, j)
                segment.push_back(c)

                # progress.write('On (%d, %d, deg=%d, count=%d)' % (i , j, deg, seen_nodes[ i, j ]))

                # At confluence
                if deg >= 2:

                    # if we pass through this junction for the first time,
                    # walk forward downstream from this junction
                    if seen_nodes[i, j] == 0:

                        c = Cell(i, j)
                        stack.push(c)
                        confluences.push_back(c)

                    # record number of times
                    # we've been through this junction
                    seen_nodes[i , j] += 1

                    break

                # record number of times
                # we've been through this node,
                # so we can exit loops
                seen_nodes[ i, j ] += 1

                # walk downstream
                direction = ilog2(flow[ i, j ])
                i = i + ci[direction]
                j = j + cj[direction]

                progress.update(1)

            if segment.size() > 1 and (not from_source or segment.size() > min_length):
                
                segments.push_back(segment)

                # Finally, output final outlet
                if indegree(flow, channels, i, j) == 1:

                    c = Cell(i, j)
                    outlets.push_back(c)

    progress.write('Done.')
    progress.close()

    # Cython's magic
    # c++ vectors are automagically converted to python lists,
    # and c++ pairs to python tuples

    return outlets, confluences, segments





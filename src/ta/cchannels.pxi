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
        int min_length):

    cdef long height, width, i, j, segment_id, confluence_id, channels_count = 0
    cdef int seg_size
    cdef unsigned char direction
    cdef Cell c
    cdef CellStack stack
    # cdef CellList confluences
    # cdef CellList segment
    # cdef SegmentList segments
    cdef unsigned char[:,:] seen_nodes
    cdef CppTermProgress progress

    height = flow.shape[0]
    width = flow.shape[1]
    seen_nodes = np.zeros((height, width), dtype=np.uint8)

    # with nogil:

    progress = CppTermProgress(height*width)
    progress.write('Find sources ...')

    for i in range(height):
        for j in range(width):

            if channels[ i, j ] > 0:

                channels_count += 1

                if indegree(flow, channels, i, j) == 0:

                    c = Cell(i, j)
                    stack.push(c)

            progress.update(1)

    progress.write('Found %d channel pixels' % channels_count)
    progress.close()

    progress = CppTermProgress(channels_count)
    progress.write('Walk downstream from sources ...')

    segment_id = 0
    confluence_id = 0
    confluences = list()
    segments = list()
    # confluences = CellList(channels_count)

    while not stack.empty():

        # segment = CellList()
        segment = list()
        seg_size = 0

        c = stack.top()
        stack.pop()

        i = c.first
        j = c.second

        while ingrid(height, width, i, j) and seen_nodes[ i, j ] == 0:

            # c = Cell(i, j)
            # segment.push_back(c)
            # progress.write('On (%d, %d)' % (i , j))
            segment.append((i, j))
            seg_size += 1
            seen_nodes[ i, j ] = 1

            if indegree(flow, channels, i, j) > 1:

                confluences.append((i, j))
                confluence_id += 1
                
                if seg_size >= min_length:
                    # segments.push_back(segment)
                    segments.append(segment)
                    segment_id += 1

                c = Cell(i, j)
                stack.push(c)
                break

            direction = ilog2(flow[ i, j ])
            i = i + ci[direction]
            j = j + cj[direction]

            progress.update(1)

    progress.write('Done.')
    progress.close()

    confluences_list = list()

    # for i in range(confluences.size()):
    #     c = confluences[i]
    #     confluences_list.append((c.first, c.second))

    # segments_list = list()

    # for i in range(segments.size()):

    #     segment = segments[i]
    #     segment_list = list()
        
    #     for j in range(segment.size()):
    #         c = segment[j]
    #         segment_list.append(c)
            
    #         segments_list.append(segment_list)

    return confluences, segments





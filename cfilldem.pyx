# coding: utf-8
# cython: c_string_type=str, c_string_encoding=ascii

import numpy as np
# from progress import TermProgress
# from tqdm import tqdm

cimport numpy as np
cimport cython
from libcpp.queue cimport priority_queue
from libcpp.pair cimport pair
# cimport progress

from CppTermProgress cimport CppTermProgress

ctypedef pair[long, long] Cell
ctypedef pair[float, Cell] Entry
ctypedef priority_queue[Entry] Queue

from common cimport ci, cj, ingrid


@cython.boundscheck(False)
@cython.wraparound(False)
def fillnd(
        np.ndarray[float, ndim=2] data,
        np.ndarray[float, ndim=2] filled,
        src,
        float minslope):

    cdef long width, height
    cdef float dx, dy, nodata

    cdef long i, j, x, ix, jx
    cdef float z, zx
    cdef Cell ij
    cdef Entry entry
    cdef Queue queue

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

    # queue = list()
    queue = Queue()

    # progress = tqdm(total=2*width*height)
    progress = CppTermProgress(2*width*height)
    msg = 'Input is %d x %d' % (width, height)
    progress.write(msg)
    msg = 'Mindiff = ' + str(mindiff)
    progress.write(msg)
    msg = 'Find boundary cells ...'
    progress.write(msg)

    for i in range(height):
        for j in range(width):

            z = data[ i, j ]
            
            if z != nodata:
                
                for x in range(8):
                
                    ix = i + ci[x]
                    jx = j + cj[x]
                
                    if not ingrid(height, width, ix, jx) or (data[ ix, jx ] == nodata):
                        
                        # heapq.heappush(queue, (-z, x, y))
                        entry = Entry(-z, Cell(i, j))
                        queue.push(entry)
                        filled[ i, j ] = z

                        break

            progress.update(1)

    msg = 'Fill depressions from bottom to top ...'
    progress.write(msg)

    entry = queue.top()
    z = -entry.first
    
    msg = f'Starting from Z = {z:.3f}'
    progress.write(msg)

    while not queue.empty():

        # z, x, y = heapq.heappop(queue)
        # z = filled[x, y]
        entry = queue.top()
        queue.pop()

        # z = -entry.first
        ij = entry.second
        i = ij.first
        j = ij.second
        z = filled[ i, j ]

        for x in range(8):
            
            ix = i + ci[x]
            jx = j + cj[x]
            zx = data[ ix, jx ]
            
            if ingrid(height, width, ix, jx) and (zx != nodata) and (filled[ ix, jx ] == nodata):

                if zx < (z + mindiff[x]):
                    zx = z + mindiff[x]

                filled[ ix, jx ] = zx

                # heapq.heappush(queue, (-iz, ix, iy))
                entry = Entry(-zx, Cell(ix, jx))
                queue.push(entry)

        progress.update(1)

    msg = 'Done.'
    progress.write(msg)
    progress.close()
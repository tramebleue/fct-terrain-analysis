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

ctypedef pair[int, int] Cell
ctypedef pair[float, Cell] Entry
ctypedef priority_queue[Entry] Queue

@cython.boundscheck(False)
@cython.wraparound(False)
def fillnd(np.ndarray[float, ndim=2] data, src, float minslope):

    cdef int width
    cdef int height
    cdef float nodata
    cdef float dx
    cdef float dy

    cdef int x
    cdef int y
    cdef float z
    cdef int i
    cdef int ix
    cdef int iy
    cdef float iz
    cdef Cell xy
    cdef Entry entry
    cdef Queue queue

    cdef np.ndarray[int, ndim=2] c
    cdef np.ndarray[double, ndim=2] w
    cdef np.ndarray[float] mindiff
    cdef np.ndarray[float, ndim=2] filled
    cdef CppTermProgress progress

    width = src.width
    height = src.height
    nodata = src.nodata
    dx = src.transform.a
    dy = -src.transform.e

    c = np.array([[  1,  0 ],
                  [  1, -1 ],
                  [  0, -1 ],
                  [ -1, -1 ],
                  [ -1,  0 ],
                  [ -1,  1 ],
                  [  0,  1 ],
                  [  1,  1 ]], dtype=np.int32)

    w = c * (dx, dy)
    mindiff = np.float32(minslope*np.sqrt(np.sum(w*w, axis=1)))

    # queue = list()
    queue = Queue()

    it = np.nditer(data,
        flags=[ 'multi_index', 'buffered' ],
        op_flags=[ 'readonly' ],
        op_dtypes=[ 'float32' ])

    filled = np.full((data.shape[0], data.shape[1]), nodata, dtype=np.float32)

    # progress = tqdm(total=2*width*height)
    progress = CppTermProgress(2*width*height)
    msg = 'Input is %d x %d' % (width, height)
    progress.write(msg)
    msg = 'Find boundary cells ...'
    progress.write(msg)

    for z in it:
        
        x, y = it.multi_index
        
        if z != nodata:
            
            for i in range(8):
            
                ix = x + c[i, 0]
                iy = y + c[i, 1]
            
                if not (ix >= 0 and ix < width and iy >= 0 and iy < height) or (data[ix, iy] == nodata):
                    
                    # heapq.heappush(queue, (-z, x, y))
                    entry = Entry(-z, Cell(x, y))
                    queue.push(entry)
                    filled[x, y] = z

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

        z = -entry.first
        xy = entry.second
        x = xy.first
        y = xy.second

        for i in range(8):
            
            ix = x + c[i, 0]
            iy = y + c[i, 1]
            iz = data[ix, iy]
            
            if (ix >= 0 and ix < width and iy >= 0 and iy < height) \
                and (iz != nodata) \
                and (filled[ix, iy] == nodata):

                if iz < (z + mindiff[i]):
                    iz = iz + mindiff[i]

                filled[ix, iy] = iz
                # heapq.heappush(queue, (-iz, ix, iy))
                entry = Entry(-iz, Cell(ix, iy))
                queue.push(entry)

        progress.update(1)

    msg = 'Done.'
    progress.write(msg)
    progress.close()

    return filled
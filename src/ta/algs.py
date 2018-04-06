# coding: utf-8
""" Pure python implementation of some SAGA algorithms
    useful to extract water basins and river channels from DEM rasters.
"""

import numpy as np
from heapq import heapify, heappop, heappush
from progress import ProgressBar, TermProgressBar

# D8 directions in 3x3 neighborhood

d8_directions = np.power(2, np.array([ 7, 0, 1, 6, 0, 2, 5, 4, 3 ], dtype=np.uint8))

# D8 search directions, clockwise starting from North
#       0   1   2   3   4   5   6   7
#       N  NE   E  SE   S  SW   W  NW

ci = [ -1, -1,  0,  1,  1,  1,  0, -1 ]
cj = [  0,  1,  1,  1,  0, -1, -1, -1 ]

# Flow direction value of upward cells
# in each search direction,
# e.g. cell north (search index 0) of cell x is connected to cell x
#      if its flow direction is 2^4 (southward)    

upward = np.power(2, np.array([ 4,  5,  6,  7,  0,  1,  2,  3 ], dtype=np.uint8))

def distance_2d(rx, ry):
    """
    Returns a 3x3 matrix of 2D distances between cells in each D8 direction,
    given cell resolutions in x and y direction.

    Parameters
    ----------

    rx: float
        Cell resolution in x direction

    ry: float
        Cell resolution in x direction

    Returns
    -------

    3x3 matrix, dtype float
    """

    dx = np.array([1, 0, 1] * 3).reshape(3, 3)   * rx
    dy = np.array([1, 0, 1] * 3).reshape(3, 3).T * ry
    
    return np.sqrt(dx**2 + dy**2)

def flowdir(elevations, rx, ry, nodata, out=None):
    """
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
        z values from digital elevation model (DEM)

    rx: float
        Cell resolution in x direction

    ry: float
        Cell resolution in x direction

    nodata: float
        No-data value in the raster elevation input

    out: array-like
        Output raster, dtype uint8, initialized to 0

    Returns
    -------

    D8 flow direction raster, given as power of 2, with no-data = 0
    N = 2^0 = 1, NE = 2^1 = 2, ..., NW = 2^7 = 128
    """

    rows = elevations.shape[0]
    cols = elevations.shape[1]
    d2d = distance_2d(rx, ry)

    if out is None:

        out = np.zeros(elevations.shape, dtype=np.uint8)

    for i in range(rows):
        for j in range(cols):
            
            z = elevations[i+1, j+1]
            if z == nodata:
                # out[i, j] = 0
                continue

            dz = elevations[ i:i+3, j:j+3 ] - z
            s = np.argmin(dz / d2d)

            out[i, j] = d8_directions[s]

    return out

def ingrid(data, i, j):
    """ Tests if cell (i, j) is within the range of data

    Parameters
    ----------

    data: array-like, ndim=2
        Input raster

    i: int
        Row index

    j: int
        Column index

    Returns
    -------

    True if coordinates (i, j) fall within data, False otherwise.
    """

    height = data.shape[0]
    width  = data.shape[1]

    return (i >= 0) and (i < height) and (j >= 0) and (j < width)

def upcells(flowdir, i, j):
    """ Find all upward cells connected to cell (i, j)
    in the up-down direction given by flowdir.

    Parameters
    ----------

    flowdir: array-like
        Flow direction raster

    i: int
        Row index of cell (i, j)

    j: int
        Column index of cell (i, j)

    Returns
    -------

    Generator object returning (row, col) coordinate tuples of upward cells.
    """

    for k in range(8):

        ni = i + ci[k]
        nj = j + cj[k]

        if ingrid(flowdir, ni, nj) and flowdir[ni,nj] == upward[k]:
            yield (ni, nj)

def strahler(elevations, flowdir, nodata, out=None):
    """
    Strahler order,
    assuming connection between cells in the up-down direction
    given by flowdir.

    The elevation data is used to sort the input cells,
    so as to process cells from top to down.

    Parameters
    ----------

    elevations: array-like
        Digital elevation model (DEM) raster (ndim=2)

    flowdir: array-like
        Same shape as elevations

    nodata: float
        No-data value of elevations

    out: array-like
        Output raster, dtype uint8,
        same shape as elevations,
        initialized to 1

    Returns
    -------

    Strahler order raster, no-data = 0
    """

    height = elevations.shape[0]
    width = elevations.shape[1]

    if out is None:
        out = np.ones(elevations.shape, dtype=np.uint8)

    idx = elevations.reshape(height*width).argsort(kind='mergesort')
    count = np.zeros(elevations.shape, dtype=np.uint8)

    for k in xrange(height*width-1, -1, -1):

        x = idx[k]
        i = x  % height
        j = x // height

        z = elevations[ i, j ]

        if z == nodata:
            continue

        if count[ i, j ] > 1:

            out[ i, j ] = out[ i, j ] + 1

        dx = flowdir[ i, j ]

        if dx > 0:

            dx = int(np.log2(dx))
            ix = i + ci[dx]
            jx = j + cj[dx]

            if ingrid(elevations, ix, jx):

                if out[ i, j ] > out[ ix, jx ]:

                    out[ ix, jx ] = out[ i, j ]
                    count[ ix, jx ] = 1

                elif out[ i, j ] == out[ ix, jx ]:

                    count[ ix, jx ] = count[ i, j ] + 1

    return out

def fillsinks(elevations, nodata, rx, ry, out=None, minslope=1e-3):
    """ Fill sinks of digital elevation model (DEM),
        based on the algorithm of Wang & Liu (2006).

    Parameters
    ----------

    elevations: array-like
        Digital elevation model (DEM) raster (ndim=2)

    nodata: float
        No-data value in elevations

    rx: float
        Cell resolution in x direction

    ry: float
        Cell resolution in y direction

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

    height = elevations.shape[0]
    width = elevations.shape[1]

    w = np.array([ ci, cj ]).T * (rx, ry)
    mindiff = np.float32(minslope*np.sqrt(np.sum(w*w, axis=1)))

    if out is None:
        out = np.full(elevations.shape, nodata, dtype=elevations.dtype)

    progress = TermProgressBar(2*width*height)
    progress.write('Input is %d x %d' % (width, height))
    
    progress.write('Find boundary cells ...')

    # We use a heap queue to sort cells
    # from lower z to higher z.
    # Remember python's heapq is a min-heap.
    queue = list()

    for i in range(height):
        for j in range(width):

            z = elevations[ i, j ]
            
            if z != nodata:
                
                for x in range(8):
                
                    ix = i + ci[x]
                    jx = j + cj[x]
                
                    if not ingrid(elevations, ix, jx) or (elevations[ ix, jx ] == nodata):
                        
                        out[ i, j ] = z
                        heappush(queue, (z, x, y))

                        break

            progress.update(1)

    progress.write('Fill depressions from bottom to top ...')

    z, i, j = queue[0]
    progress.write('Starting from z = %f' % z)
        
    while queue:

        z, i, j = heappop(queue)
        z = out[ i, j ]

        for x in range(8):
            
            ix = i + ci[x]
            jx = j + cj[x]
            zx = data[ ix, jx ]
            
            if ingrid(elevations, ix, jx) and (zx != nodata) and (out[ ix, jx ] == nodata):

                if zx < (z + mindiff[x]):
                    zx = z + mindiff[x]

                out[ ix, jx ] = zx
                heappush(queue, (iz, ix, iy))

        progress.update(1)

    progress.write('Done.')
    progress.close()

    return out

def upslope(flowdir, i0, j0, watershed_id, out=None):
    """ Delineate water basin upslope of cell (i0, j0).

    Parameters
    ----------

    flowdir: array-like, ndim=2, dtype=uint8
        Flow direction raster

    i0: int
        Row index of outlet cell

    j0: int
        Column index of outlet cell

    watershed_id: int
        Value to assign to cells of `out` found in the upslope basin of (i0, j0)

    out: array-like, ndim=2, dtype=int32
        Output raster, same shape as `flowdir`.
        This raster stores the id of the water basin to which each cell belongs.


    Returns
    -------

    out: array-like
        Output raster with cells in basin of cell (i0, j0)
        having value watershed_id.

    count: int
        Size in cells of cell (i0, j0) basin.
    """

    height = flowdir.shape[0]
    width  = flowdir.shape[1]

    if out is None:
        out = np.zeros(flowdir.shape, dtype=np.int32)

    stack = [ (i0, j0) ]
    count = 0

    while stack:

        i, j = stack.pop()

        if flowdir[ i, j ] == 0:
            continue

        out[ i, j ] = watershed_id
        count += 1

        for x in range(8):

            ni = i + ci[x]
            nj = j + cj[x]

            if not ingrid(flowdir, ni, nj):
                continue

            w = out[ ni, nj ]
            if (flowdir[ ni, nj ] == upward[x]) and (w == 0 or w == -1):

                stack.append(( ni, nj ))

    return out, count

def watershed(flowdir, i0, j0, watershed_id, out=None):
    """ Delineate water basin containing cell (i0, j0).

    First, find the outlet cell connected to cell (i0, j0)
    and then, delineate the upslope basin of that cell.

    Parameters
    ----------

    flowdir: array-like, ndim=2, dtype=uint8
        Flow direction raster

    i0: int
        Row index of origin cell

    j0: int
        Column index of origin cell

    watershed_id: int
        Value to assign to cells of `out` contained in the basin of cell (i0, j0)

    out: array-like, ndim=2, dtype=int32
        Output raster, having same shape as `flowdir`.
        This raster stores the id of the water basin to which each cell belongs.

    Returns
    -------

    out: numpy-array, ndim=2, dtype=int32
        Output raster, having same shape as `flowdir`.
        This raster stores the id of the water basin to which each cell belongs.

    """

    si = i = i0
    sj = j = j0

    if out is None:
        out = np.zeros(flowdir.shape, dtype=np.int32)

    while ingrid(flowdir, i, j) and out[i, j] == 0:

        out[ i, j ] = -1

        si = i
        sj = j

        down_x = int(np.log2(flowdir[ i, j ]))
        i = i + ci[down_x]
        j = j + cj[down_x]

    upslope(flowdir, si, sj, watershed_id, out)

    return out
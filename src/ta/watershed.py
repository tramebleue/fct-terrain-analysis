# coding: utf-8

import numpy as np
import rasterio as rio
import concurrent.futures
import multiprocessing as mp
from rasterio.windows import Window
from TermProgress import TermProgress

#       0   1   2   3   4   5   6   7
#       N  NE   E  SE   S  SW   W  NW
ci = [ -1, -1,  0,  1,  1,  1,  0, -1 ]
cj = [  0,  1,  1,  1,  0, -1, -1, -1 ]

upward = np.power(2, np.array([ 4,  5,  6,  7,  0,  1,  2,  3 ], dtype=np.uint8))

def ingrid(data, i, j):

    height = data.shape[0]
    width  = data.shape[1]
    return (i >= 0) and (i < height) and (j >= 0) and (j < width)

try:

    from cwatershed import upslope
    from cwatershed import watershed
    from cwatershed import all_watersheds as find_all_watersheds

except ImportError:

    def upslope(data, out, i0, j0, nodata, watershed_id):

        height = data.shape[0]
        width  = data.shape[1]
        stack = [ (i0, j0) ]

        progress = TermProgress(height*width)

        while stack:

            i, j = stack.pop()
            progress.update()

            if data[ i, j ] == nodata:
                continue

            out[ i, j ] = watershed_id

            for x in range(8):

                ni = i + ci[x]
                nj = j + cj[x]

                if not ingrid(data, ni, nj):
                    # print 'not in grid (%d, %d)' % (ni, nj)
                    continue

                if data[ ni, nj ] == upward[x] and (out[ ni, nj ] == 0 or out[ ni, nj ] == -1):

                    # print "(%d, %d) -> (%d, %d)" % (i, j, ni, nj)
                    stack.append((ni, nj))


    def watershed(data, out, i0, j0, nodata, watershed_id):

        height = data.shape[0]
        width  = data.shape[1]

        i, j = i0, j0

        while ingrid(data, i, j) and out[i, j] == 0:

            out[ i, j ] = -1

            si = i
            sj = j

            down_x = int(np.log2(data[ i, j ]))
            i = i + ci[down_x]
            j = j + cj[down_x]

            print "(%d, %d) -> (%d, %d)" % (si, sj, i, j)

        upslope(data, out, si, sj, nodata, watershed_id)


def main(src_file, dst_file, x, y):

    with rio.open(src_file) as src:

        i, j = src.index(x, y)
        data = src.read(1)
        out  = np.zeros(data.shape, dtype=np.int32)

        watershed(data, out, int(i), int(j), src.nodata, 128)

        meta = src.meta
        meta.update(nodata=0, dtype=np.int32, blockxsize=256, blockysize= 256, tiled='yes', compress='deflate')

        with rio.open(dst_file, 'w', **meta) as dst:
            dst.write(out, 1)

def all_watersheds(elevation_file, flow_file, dst_file):

    with rio.open(elevation_file) as elevation:

        print 'Reading elevation file ...'
        zdata = elevation.read(1)

        with rio.open(flow_file) as src:

            print 'Reading flow direction file ...'
            data = src.read(1)
            out  = np.zeros(data.shape, dtype=np.int32)
            
            find_all_watersheds(zdata, data, out, elevation.nodata)

            meta = src.meta
            meta.update(nodata=0, dtype=np.int32, blockxsize=256, blockysize= 256, tiled='yes', compress='deflate')

            with rio.open(dst_file, 'w', **meta) as dst:

                dst.write(out, 1)
                print 'Finish writing destination file'








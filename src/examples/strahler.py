import numpy as np
import rasterio as rio


try:

    from cstrahler import strahler

except ImportError:

    #       0   1   2   3   4   5   6   7
    #       N  NE   E  SE   S  SW   W  NW
    ci = [ -1, -1,  0,  1,  1,  1,  0, -1 ]
    cj = [  0,  1,  1,  1,  0, -1, -1, -1 ]

    def strahler(elevations, flowdir, out, nodata):

        height = elevations.shape[0]
        width = elevations.shape[1]

        idx = elevations.reshape(height*width).argsort(kind='heapsort')
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

            dx = int(np.log2(flowdir[ i, j ]))
            ix = i + ci[dx]
            jx = j + cj[dx]

            if out[ i, j ] > out[ ix, jx ]:

                out[ ix, jx ] = out[ i, j ]
                count[ ix, jx ] = 1

            elif out[ i, j ] == out[ ix, jx ]:

                count[ ix, jx ] = count[ i, j ] + 1
   

def main(elevation_file, flow_file, dst_file):

    with rio.open(elevation_file) as elevation:

        print 'Reading elevation file ...'
        zdata = elevation.read(1)

        with rio.open(flow_file) as flow:

            print 'Reading flow file ...'
            flowdata = flow.read(1)

            result = np.ones(elevation.shape, dtype=np.uint8)

            ta.strahler(zdata, flowdata, result, flow.nodata)

            meta = elevation.meta
            meta.update(nodata=0, blockxsize=256, blockysize=256, dtype=np.uint8, tiled='yes', compress='deflate')

            with rio.open(dst_file, 'w', **meta) as dst:
                dst.write(result, 1)
                print 'Finish writing output file ...'

            print 'Done.'


def filter_sup(src_file, dst_file, threshold):

    with rio.open(src_file) as src:

        width = src.width
        height = src.height
        meta = src.meta
        meta.update(nodata=0, dtype=np.uint8, blockxsize=256, blockysize= 256, tiled='yes', compress='deflate')

        progress = TermProgress((width // 256 + 1) * (height // 256 + 1))
        progress.write(u'Input is %d x %d' % (width, height))

        with rio.open(dst_file, 'w', **meta) as dst:

            for ij, window in dst.block_windows():

                data = src.read(1, window=window)
                
                result = np.zeros(data.shape, dtype=np.uint8)
                result[(data != src.nodata) & (data >= threshold)] = 1
                
                dst.write(result, 1, window=window)
                progress.update()

            progress.write(u'Finish to write destination file')
            progress.close()

        print u'Done.'

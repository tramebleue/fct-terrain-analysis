# coding: utf-8

import numpy as np
import rasterio as rio
import concurrent.futures
import multiprocessing as mp
from rasterio.windows import Window
from TermProgress import TermProgress

try:
    
    from cflowdir import flowdir

except ImportError:

    directions = np.power(2, np.array([ 7, 0, 1, 6, 0, 2, 5, 4, 3 ], dtype=np.uint8))

    def flowdir(data, out, distance_2d, nodata):

        rows = out.shape[0]
        cols = out.shape[1]

        for i in range(rows):
            for j in range(cols):
                
                z = data[i+1, j+1]
                if z == nodata:
                    # out[i, j] = 0
                    continue

                dz = data[ i:i+3, j:j+3 ] - z
                s = np.argmin(dz / distance_2d)

                out[i, j] = directions[s]

def distance_2d(tx, ty):

    dx = np.array([-1, 0, 1] * 3).reshape(3, 3)   * tx
    dy = np.array([-1, 0, 1] * 3).reshape(3, 3).T * ty
    
    return np.sqrt(dx**2 + dy**2)

def main(src_file, dst_file):

    with rio.open(src_file) as src:

        width = src.width
        height = src.height
        nodata = src.nodata
        meta = src.meta
        meta.update(nodata=0, dtype=np.uint8, blockxsize=256, blockysize= 256, tiled='yes', compress='deflate')

        d2d = distance_2d(src.transform.a, src.transform.e)
        d2d[1,1] = 1.0

        progress = TermProgress((width // 256 + 1) * (height // 256 + 1))
        progress.write(u'Input is %d x %d' % (width, height))

        with rio.open(dst_file, 'w', **meta) as dst:

            for ij, window in dst.block_windows():

                read_window = Window(window.col_off - 1, window.row_off -1, window.width + 2, window.height + 2)
                data = src.read(1, window=read_window)

                pn = (window.row_off == 0) and 1 or 0
                pw = (window.col_off == 0) and 1 or 0
                ps = (window.row_off+window.height == height) and 1 or 0
                pe = (window.col_off+window.width == width) and 1 or 0

                if any([ pn, pw, ps, pe ]):
                    data = np.pad(data, [[ pn, ps ], [ pw, pe ]], 'constant', constant_values=np.nan)
                
                result = np.zeros((window.height, window.width), dtype=np.uint8)
                flowdir(data, result, d2d, nodata)
                
                dst.write(result, 1, window=window)
                progress.update()

            progress.write(u'Finish to write destination file')
            progress.clear_progress()

        progress.write(u'Done.')
        progress.close()

def main_concurrent(src_file, dst_file, workers=mp.cpu_count()):

    with rio.open(src_file) as src:

        width = src.width
        height = src.height
        nodata = src.nodata
        meta = src.meta
        meta.update(nodata=0, dtype=np.uint8, blockxsize=256, blockysize= 256, tiled='yes', compress='deflate')

        d2d = distance_2d(src.transform.a, src.transform.e)
        d2d[1,1] = 1.0

        progress = TermProgress(2 * (width // 256 + 1) * (height // 256 + 1))
        progress.write(u'Input is %d x %d' % (width, height))

        with rio.open(dst_file, 'w', **meta) as dst:

            def tasks():

                for ij, window in dst.block_windows():

                    read_window = Window(window.col_off - 1, window.row_off -1, window.width + 2, window.height + 2)
                    data = src.read(1, window=read_window)

                    pn = (window.row_off == 0) and 1 or 0
                    pw = (window.col_off == 0) and 1 or 0
                    ps = (window.row_off+window.height == height) and 1 or 0
                    pe = (window.col_off+window.width == width) and 1 or 0

                    if any([ pn, pw, ps, pe ]):
                        data = np.pad(data, [[ pn, ps ], [ pw, pe ]], 'constant', constant_values=np.nan)
                    
                    result = np.zeros((window.height, window.width), dtype=np.uint8)
                    progress.update()

                    yield data, result, window

            with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:

                progress.write(u'Read input file')

                futures = { executor.submit(flowdir, data, result, d2d, nodata) : (result, window)
                            for data, result, window in tasks() }

                progress.write(u'Process blocks concurrently with %d workers' % workers)

                for future in concurrent.futures.as_completed(futures):

                    result, window = futures[future]
                    dst.write(result, 1, window=window)
                    progress.update()

            progress.write(u'Finish to write destination file')

        progress.write(u'Done.')
        progress.close()

# coding: utf-8

import numpy as np
import rasterio as rio
from cfilldem import fillnd

def fill_dem(src_file, dst_file, minslope=1e-3):

    with rio.open(src_file) as src:

        data = src.read(1)
        filled = np.full(data.shape, src.nodata, dtype=data.dtype)
        ta.filldem(data, filled, src, minslope)

        meta = src.meta
        meta.update(blockxsize=256, blockysize= 256, tiled='yes', compress='deflate')

        with rio.open(dst_file, 'w', **meta) as dst:
            dst.write(filled, 1)


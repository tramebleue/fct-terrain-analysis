# coding: utf-8

import numpy as np
import rasterio as rio
import terrain_analysis as ta
from math import radians, tan

def fillsinks(src_file, dst_file, minslope=0.01, unit='degree'):

    if unit == 'degree':
        minslope = tan(radians(minslope))

    with rio.open(src_file) as src:

        data = src.read(1)
        filled = np.full(data.shape, src.nodata, dtype=data.dtype)
        ta.fillsinks(data, src, np.float32(minslope), filled)

        meta = src.meta
        meta.update(blockxsize=256, blockysize= 256, tiled='yes', compress='deflate')

        with rio.open(dst_file, 'w', **meta) as dst:
            dst.write(filled, 1)


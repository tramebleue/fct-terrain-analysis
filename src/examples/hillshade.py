import terrain_analysis as ta
import rasterio as rio
import numpy as np

info_dem = rio.open('RGEALTI_5M.tif')
dem = info_dem.read(1)
dem[dem == 0] = -1

hs = np.full(dem.shape, -1, dtype=np.float32)

print 'Computing analytical hillshading ...'
print 'Input file is %d x %d' % dem.shape

rx = info_dem.transform.a
ry = -info_dem.transform.e
ta.hillshade(np.pad(dem, 1, 'constant', constant_values=-1), rx, ry, -1, 135, 30, 4, hs)

meta = info_dem.meta
meta.update({ 'nodata': -1, 'blockxsize': 256, 'blockysize': 256, 'tiled':'yes', 'compress':'deflate', 'dtype': np.float32 })

with rio.open('HILLSHADE.tif', 'w', **meta) as f:
    f.write(hs, 1)
    print 'Finish writing output file ...'

print 'Done.'

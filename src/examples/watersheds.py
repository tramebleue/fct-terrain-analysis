import numpy as np
import fiona
import rasterio as rio
import terrain_analysis as ta
import shapely.geometry
from functools import partial

with fiona.open('BV_OUTLETS.shp') as din:
    outlets = [ shapely.geometry.asShape(f['geometry']) for f in din ]

with rio.open('FILLED.tif') as dem:

    dem_data = dem.read(1)
    def z(p):
        i, j = dem.index(p.x, p.y)
        return dem_data[int(i), int(j)]

    points = [ shapely.geometry.Point(p.x, p.y, z(p)) for p in outlets ]

del dem_data
del outlets

points.sort(key=lambda x: -x.z)

flow = rio.open('FLOW.tif')
flow_data = flow.read(1)

channels = rio.open('CHANNELS_S7.tif')
channels_data = channels.read(1)
channels_data[ 5274, 7113 ] = 0

#       0   1   2   3   4   5   6   7
#       N  NE   E  SE   S  SW   W  NW
ci = [ -1, -1,  0,  1,  1,  1,  0, -1 ]
cj = [  0,  1,  1,  1,  0, -1, -1, -1 ]

upward = np.power(2, np.array([ 4,  5,  6,  7,  0,  1,  2,  3 ], dtype=np.uint8))

def ingrid(data, i, j):

    height = data.shape[0]
    width  = data.shape[1]
    return (i >= 0) and (i < height) and (j >= 0) and (j < width)

def upcells(flow, i, j):
    for k in range(8):
        ni = i + ci[k]
        nj = j + cj[k]
        if ingrid(flow, ni, nj) and flow[ni,nj] == upward[k]:
            yield (ni, nj)

def inchannel(channels, x):
    i, j = x
    return channels[i, j] > 0

out  = np.zeros(flow.shape, dtype=np.int32)
wid = 0
junctions = list()

for p in points:

    i, j = map(int, flow.index(p.x, p.y)) 
    up = filter(partial(inchannel, channels_data), [ c for c in upcells(flow_data, i, j) ])

    for iu, ju in up:

        wid += 1
        ta.upslope(flow_data, out, iu, ju, flow.nodata, wid)
        junctions.append([ (iu, ju), (i, j), wid ])

for junction in junctions:

    i, j = junction[1]
    junction.append(out[ i, j ])

junction_index = { basin: to_basin for a,b,basin,to_basin in junctions }

from rasterio import features
import fiona.crs

out = features.sieve(out, 400)
t = flow.transform * flow.transform.translation(.5, .5)
basins = features.shapes(out, mask=(out > 0), transform=t)

with fiona.open('BASINS.shp', 'w',
        driver='ESRI Shapefile',
        crs=fiona.crs.from_epsg(2154),
        schema={ 'geometry': 'Polygon', 'properties': [ ('basin', 'int'), ('to_basin', 'int') ] }) as dout:

    for basin, wid in basins:
        to_wid = junction_index[wid]
        dout.write({ 'geometry': basin, 'properties': { 'basin': wid, 'to_basin': int(to_wid) }})


meta = flow.meta
meta.update(nodata=0, dtype=np.int32, blockxsize=256, blockysize= 256, tiled='yes', compress='deflate')

with rio.open('WATERSHEDS.tif', 'w', **meta) as dst:
    dst.write(out, 1)
import numpy as np
import rasterio as rio
import terrain_analysis as ta
from shapely.geometry import Point, LineString
import fiona
import fiona.crs

flow = rio.open('TEST/FLOW.tif')
channels = rio.open('TEST/CHANNELS_S7.tif')
flowd = flow.read(1)
channelsd = channels.read(1)

outlets, confluences, segments = ta.channels(flowd, channelsd, 100)

t = channels.transform * channels.transform.translation(.5, .5)

with fiona.open('TEST/CONFLUENCES.shp', 'w',
    driver='ESRI Shapefile',
    crs=fiona.crs.from_epsg(2154),
    schema={'geometry': 'Point', 'properties': [ ('gid','int') ] }) as ds:

    for i, pt in enumerate(confluences):
        y, x = pt
        p = Point(t*(x, y))
        ds.write({ 'geometry': p.__geo_interface__, 'properties': { 'gid': i }})

with fiona.open('TEST/OUTLETS.shp', 'w',
    driver='ESRI Shapefile',
    crs=fiona.crs.from_epsg(2154),
    schema={'geometry': 'Point', 'properties': [ ('gid','int') ] }) as ds:

    for i, pt in enumerate(outlets):
        y, x = pt
        p = Point(t*(x, y))
        ds.write({ 'geometry': p.__geo_interface__, 'properties': { 'gid': i }})

with fiona.open('TEST/CHANNELS.shp', 'w',
        driver='ESRI Shapefile',
        crs=fiona.crs.from_epsg(2154),
        schema={ 'geometry': 'LineString', 'properties': [ ('gid','int') ] }) as ds:

    for i, segment in enumerate(segments):
        ls = LineString([ t*(x, y) for y, x in segment ])
        ds.write({ 'geometry': ls.__geo_interface__, 'properties': { 'gid': i }})

flow.close()
channels.close()
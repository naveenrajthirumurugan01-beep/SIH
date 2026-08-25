"""Terrain feature extraction from DEM/GIS sources using GeoPandas + Rasterio.

TODO: implement slope, aspect, and elevation extraction from a DEM raster
(e.g. SRTM/Bhuvan tiles for the NER region) and join against district/village
boundary shapefiles.
"""

import geopandas as gpd
import rasterio


def load_dem(path: str):
    """Open a DEM raster and return the rasterio dataset handle."""
    return rasterio.open(path)


def compute_slope_degrees(dem_path: str):
    """TODO: compute slope raster (degrees) from a DEM using a gradient method
    (e.g. richdem, or numpy.gradient on the elevation array with cell size)."""
    raise NotImplementedError


def load_district_boundaries(shapefile_path: str) -> gpd.GeoDataFrame:
    """TODO: load NER district boundary shapefile for spatial joins."""
    return gpd.read_file(shapefile_path)


def zonal_stats_by_district(dem_path: str, boundaries: gpd.GeoDataFrame):
    """TODO: aggregate slope/elevation stats per district polygon
    (e.g. via rasterstats.zonal_stats)."""
    raise NotImplementedError

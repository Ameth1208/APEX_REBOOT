"""Read only the route's WorldCover COG window; emit a compact offline JSON grid.

Run with: uv run --with rasterio python tools/prepare_landcover.py
No game files or preferences are written by this tool.
"""
import json
import math
from pathlib import Path
from datetime import datetime, timezone

import numpy as np
import rasterio
from rasterio.windows import from_bounds

route = json.loads(Path("data/tracks/polonuevo_baranoa.json").read_text(encoding="utf-8"))
points = route["control_route"]
west = min(p["lon"] for p in points) - 0.004
east = max(p["lon"] for p in points) + 0.004
south = min(p["lat"] for p in points) - 0.004
north = max(p["lat"] for p in points) + 0.004
url = "https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_N09W075_Map.tif"
with rasterio.Env(GDAL_HTTP_TIMEOUT=30, GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR", CPL_VSIL_CURL_ALLOWED_EXTENSIONS=".tif"):
    with rasterio.open(url) as dataset:
        window = from_bounds(west, south, east, north, dataset.transform).round_offsets().round_lengths()
        data = dataset.read(1, window=window)
        west, south, east, north = rasterio.windows.bounds(window, dataset.transform)

# Preserve fractions of the original 10 m classes in each 4x4 cell (~40 m).
nx = math.ceil(data.shape[1] / 4)
nz = math.ceil(data.shape[0] / 4)
fractions = {"tree_cover": [], "built_cover": [], "water_cover": []}
for z in range(nz):
    for x in range(nx):
        block = data[z * 4:min((z + 1) * 4, data.shape[0]), x * 4:min((x + 1) * 4, data.shape[1])]
        for name, code in [("tree_cover", 10), ("built_cover", 50), ("water_cover", 80)]:
            fractions[name].append(round(float(np.mean(block == code)) * 100))

print(json.dumps({
    "source": "ESA WorldCover 2021 v200", "source_url": url,
    "source_file_sha256": route["geo"]["source_file_sha256"],
    "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
    "source_resolution_m": 10, "aggregation_pixels": 4,
    "west": west, "north": north,
    "cell_lon_deg": (east - west) * 4 / data.shape[1],
    "cell_lat_deg": (north - south) * 4 / data.shape[0],
    "nx": nx, "nz": nz,
    "attribution": "© ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium",
    "license": "CC-BY-4.0", "citation": "https://doi.org/10.5281/zenodo.7254221",
    **fractions,
}, separators=(",", ":")))

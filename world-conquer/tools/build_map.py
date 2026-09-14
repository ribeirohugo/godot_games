"""Builds data/map.json for World Conquer from Natural Earth country borders.

Natural Earth data is public domain: https://www.naturalearthdata.com/
Download ne_50m_admin_0_countries.geojson (for example from
https://github.com/nvkelso/natural-earth-vector/tree/master/geojson) and run:

    python tools/build_map.py path/to/ne_50m_admin_0_countries.geojson

Needs the `shapely` package. Countries are merged into game regions, big countries are
split with longitude/latitude boxes, and neighbours are found from shared borders plus a
hand-made list of sea routes.
"""

import json
import math
import os
import sys

from shapely.geometry import MultiPolygon, Polygon, box, shape
from shapely.ops import polylabel, transform, unary_union

MAP_WIDTH = 2000.0  # pixels; height follows from the projection
SIMPLIFY = 0.6  # pixels
MIN_PART_AREA = 8.0  # square pixels; smaller islands are dropped (the biggest part is always kept)
TOUCH = 1.2  # pixels; borders closer than this count as shared

CONTINENTS = {
    "NA": {"name": "América do Norte", "bonus": 5, "color": "#e8c170"},
    "SA": {"name": "América do Sul", "bonus": 3, "color": "#d98b6a"},
    "EU": {"name": "Europa", "bonus": 5, "color": "#7fa6d9"},
    "AF": {"name": "África", "bonus": 4, "color": "#c9a45c"},
    "AS": {"name": "Ásia", "bonus": 8, "color": "#8fbf7a"},
    "OC": {"name": "Oceânia", "bonus": 3, "color": "#b58fcf"},
}

# (id, name, continent, members). A member is a country code (Natural Earth ADM0_A3),
# optionally with a (lon_min, lon_max, lat_min, lat_max) box that keeps only that part.
REGIONS = [
    ("na_alaska", "Alasca", "NA", [("USA", (-180, -129, 50, 72))]),
    ("na_west_canada", "Canadá Ocidental", "NA", [("CAN", (-141, -102, 40, 90))]),
    ("na_east_canada", "Canadá Oriental", "NA", [("CAN", (-102, -50, 40, 90))]),
    ("na_greenland", "Gronelândia", "NA", ["GRL"]),
    ("na_west_usa", "EUA Ocidental", "NA", [("USA", (-125, -97, 24, 50))]),
    ("na_east_usa", "EUA Oriental", "NA", [("USA", (-97, -66, 24, 50))]),
    ("na_mexico", "México", "NA", ["MEX"]),
    ("na_central", "América Central", "NA", ["GTM", "BLZ", "HND", "SLV", "NIC", "CRI", "PAN"]),
    ("na_caribbean", "Caraíbas", "NA", ["CUB", "JAM", "HTI", "DOM", "BHS", "PRI"]),

    ("sa_north", "Colômbia e Venezuela", "SA", ["COL", "VEN", "GUY", "SUR", ("FRA", (-56, -50, 1, 7))]),
    ("sa_andes", "Peru e Equador", "SA", ["PER", ("ECU", (-82, -74, -6, 2))]),
    ("sa_bolivia", "Bolívia e Paraguai", "SA", ["BOL", "PRY"]),
    ("sa_north_brazil", "Brasil Norte", "SA", [("BRA", (-75, -30, -11, 6))]),
    ("sa_south_brazil", "Brasil Sul", "SA", [("BRA", (-60, -30, -35, -11)), "URY"]),
    ("sa_south", "Argentina e Chile", "SA", ["ARG", ("CHL", (-80, -60, -60, -15)), "FLK"]),

    ("eu_iceland", "Islândia", "EU", ["ISL"]),
    ("eu_britain", "Ilhas Britânicas", "EU", ["GBR", "IRL", "IMN"]),
    ("eu_iberia", "Península Ibérica", "EU", [("ESP", (-10, 5, 35, 44)), ("PRT", (-10, -6, 36, 43)), "AND"]),
    ("eu_france", "França e Benelux", "EU", [("FRA", (-6, 10, 41, 52)), "BEL", ("NLD", (3, 8, 50, 54)), "LUX", "MCO"]),
    ("eu_central", "Europa Central", "EU", ["DEU", "AUT", "CHE", "LIE", "CZE", "SVK", "HUN"]),
    ("eu_scandinavia", "Escandinávia", "EU", [("NOR", (4, 32, 57, 72)), "SWE", "FIN", ("DNK", (8, 16, 54, 58)), "ALD"]),
    ("eu_italy", "Itália e Balcãs", "EU", ["ITA", "SMR", "VAT", "MLT", "SVN", "HRV", "BIH", "SRB", "MNE", "KOS", "ALB", "MKD", "GRC"]),
    ("eu_baltic", "Polónia e Bálticos", "EU", ["POL", "LTU", "LVA", "EST", "BLR"]),
    ("eu_ukraine", "Ucrânia e Roménia", "EU", ["UKR", "MDA", "ROU", "BGR"]),
    ("eu_russia", "Rússia Europeia", "EU", [("RUS", (19, 60, 40, 82))]),

    ("af_maghreb", "Magrebe", "AF", ["MAR", "SAH", "DZA", "TUN", "LBY"]),
    ("af_egypt", "Egito e Sudão", "AF", ["EGY", "SDN", "SDS"]),
    ("af_west", "África Ocidental", "AF", ["MRT", "SEN", "GMB", "GNB", "GIN", "SLE", "LBR", "CIV", "MLI", "BFA", "GHA", "TGO", "BEN"]),
    ("af_nigeria", "Nigéria e Chade", "AF", ["NGA", "NER", "TCD", "CMR"]),
    ("af_congo", "Congo", "AF", ["COD", "COG", "GAB", "GNQ", "CAF"]),
    ("af_horn", "Corno de África", "AF", ["ETH", "ERI", "DJI", "SOM", "SOL"]),
    ("af_east", "África Oriental", "AF", ["KEN", "UGA", "RWA", "BDI", "TZA"]),
    ("af_south", "África Austral", "AF", ["AGO", "ZMB", "NAM", "BWA", "ZWE", "MOZ", "MWI", ("ZAF", (15, 35, -35, -22)), "LSO", "SWZ"]),
    ("af_madagascar", "Madagáscar", "AF", ["MDG"]),

    ("as_middle_east", "Médio Oriente", "AS", ["TUR", "SYR", "LBN", "ISR", "PSX", "JOR", "IRQ", "CYP", "CYN"]),
    ("as_arabia", "Arábia", "AS", ["SAU", "YEM", "OMN", "ARE", "QAT", "BHR", "KWT"]),
    ("as_iran", "Irão e Cáucaso", "AS", ["IRN", "GEO", "ARM", "AZE"]),
    ("as_central", "Ásia Central", "AS", ["KAZ", "UZB", "TKM", "KGZ", "TJK"]),
    ("as_afghanistan", "Afeganistão e Paquistão", "AS", ["AFG", "PAK"]),
    ("as_india", "Índia", "AS", ["IND", "NPL", "BTN", "BGD", "LKA", "KAS"]),
    ("as_west_siberia", "Sibéria Ocidental", "AS", [("RUS", (60, 100, 40, 82))]),
    ("as_east_siberia", "Sibéria Oriental", "AS", [("RUS", (100, 140, 40, 82))]),
    ("as_far_east", "Extremo Oriente Russo", "AS", [("RUS", (140, 200, 40, 82))]),
    ("as_mongolia", "Mongólia", "AS", ["MNG"]),
    ("as_west_china", "China Ocidental", "AS", [("CHN", (73, 100, 17, 50))]),
    ("as_east_china", "China Oriental", "AS", [("CHN", (100, 135, 17, 54)), "TWN", "HKG", "MAC"]),
    ("as_korea", "Coreia", "AS", ["KOR", "PRK"]),
    ("as_japan", "Japão", "AS", ["JPN"]),
    ("as_southeast", "Sudeste Asiático", "AS", ["MMR", "THA", "LAO", "KHM", "VNM", "MYS", "SGP"]),

    ("oc_indonesia", "Indonésia", "OC", [("IDN", (94, 132, -11, 6)), "BRN", "TLS"]),
    ("oc_philippines", "Filipinas", "OC", ["PHL"]),
    ("oc_new_guinea", "Nova Guiné", "OC", [("PNG", (140, 156, -12, 0)), ("IDN", (132, 142, -10, 0))]),
    ("oc_west_australia", "Austrália Ocidental", "OC", [("AUS", (112, 135, -40, -10))]),
    ("oc_east_australia", "Austrália Oriental", "OC", [("AUS", (135, 154, -44, -10))]),
    ("oc_new_zealand", "Nova Zelândia", "OC", [("NZL", (165, 179, -48, -34))]),
]

# Neighbours across water, added on top of the shared land borders.
SEA_ROUTES = [
    ("na_alaska", "as_far_east"),
    ("na_greenland", "eu_iceland"),
    ("na_greenland", "na_east_canada"),
    ("na_caribbean", "na_east_usa"),
    ("na_caribbean", "na_mexico"),
    ("na_caribbean", "sa_north"),
    ("sa_north_brazil", "af_west"),
    ("eu_iceland", "eu_britain"),
    ("eu_iceland", "eu_scandinavia"),
    ("eu_britain", "eu_france"),
    ("eu_britain", "eu_scandinavia"),
    ("eu_iberia", "af_maghreb"),
    ("eu_italy", "af_maghreb"),
    ("eu_scandinavia", "eu_baltic"),
    ("eu_scandinavia", "eu_central"),
    ("as_arabia", "af_horn"),
    ("af_madagascar", "af_south"),
    ("af_madagascar", "af_east"),
    ("as_japan", "as_korea"),
    ("as_japan", "as_far_east"),
    ("oc_philippines", "as_east_china"),
    ("oc_philippines", "as_southeast"),
    ("oc_philippines", "oc_indonesia"),
    ("oc_indonesia", "oc_west_australia"),
    ("oc_new_guinea", "oc_east_australia"),
    ("oc_new_zealand", "oc_east_australia"),
]


def natural_earth_projection(lon, lat):
    """Natural Earth projection (Savric, Jenny, Patterson, Petrovic, Hurni, 2011)."""
    lam = math.radians(lon)
    phi = math.radians(lat)
    p2 = phi * phi
    p4 = p2 * p2
    x = lam * (0.870700 - 0.131979 * p2 + p4 * (-0.013791 + p4 * (0.003971 * p2 - 0.001529 * p4)))
    y = phi * (1.007226 + p2 * (0.015085 + p4 * (-0.044475 + 0.028874 * p2 - 0.005916 * p4)))
    return x, y


def main(source):
    with open(source, encoding="utf-8") as f:
        features = json.load(f)["features"]
    countries = {}
    for feature in features:
        code = feature["properties"]["ADM0_A3"]
        geom = shape(feature["geometry"])
        if code == "RUS":
            geom = _unwrap_dateline(geom)
        countries[code] = geom.buffer(0)

    used = set()
    raw = {}
    for region_id, _, _, members in REGIONS:
        parts = []
        for member in members:
            code, bounds = (member, None) if isinstance(member, str) else member
            if code not in countries:
                sys.exit("Unknown country code %s in %s" % (code, region_id))
            used.add(code)
            geom = countries[code]
            if bounds:
                geom = geom.intersection(box(bounds[0], bounds[2], bounds[1], bounds[3]))
            parts.append(geom)
        raw[region_id] = unary_union(parts)

    # Project to pixels. Latitude is limited to the inhabited range so the map stays compact.
    top = natural_earth_projection(0, 84)[1]
    bottom = natural_earth_projection(0, -56)[1]
    left = natural_earth_projection(-170, 0)[0]
    right = natural_earth_projection(192, 0)[0]
    scale = MAP_WIDTH / (right - left)
    height = (top - bottom) * scale

    def to_pixels(lon, lat, z=None):
        x, y = natural_earth_projection(lon, lat)
        return (x - left) * scale, (top - y) * scale

    projected = {}
    for region_id, geom in raw.items():
        geom = transform(lambda xs, ys, zs=None: _map_coords(to_pixels, xs, ys), geom)
        projected[region_id] = geom.buffer(0)

    neighbours = set()
    ids = [r[0] for r in REGIONS]
    grown = {rid: projected[rid].buffer(TOUCH / 2) for rid in ids}
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            if grown[a].intersects(grown[b]) and grown[a].intersection(grown[b]).area > 1.0:
                neighbours.add((a, b, False))
    for a, b in SEA_ROUTES:
        if (a, b, False) not in neighbours and (b, a, False) not in neighbours:
            neighbours.add((a, b, True))

    regions = []
    for region_id, name, continent, _ in REGIONS:
        geom = projected[region_id].simplify(SIMPLIFY, preserve_topology=True)
        polys = sorted(_polygons(geom), key=lambda p: p.area, reverse=True)
        kept = [p for i, p in enumerate(polys) if i == 0 or p.area >= MIN_PART_AREA]
        label = polylabel(kept[0], tolerance=0.5)
        regions.append({
            "id": region_id,
            "name": name,
            "continent": continent,
            "label": [round(label.x, 1), round(label.y, 1)],
            "polygons": [_flat(p) for p in kept],
        })

    links = [{"a": a, "b": b, "sea": sea} for a, b, sea in sorted(neighbours)]
    _check_connected(ids, links)

    out = {
        "size": [MAP_WIDTH, round(height, 1)],
        "continents": CONTINENTS,
        "regions": regions,
        "links": links,
        "source": "Natural Earth 1:50m admin 0 countries (public domain)",
    }
    target = os.path.join(os.path.dirname(__file__), "..", "data", "map.json")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

    points = sum(len(p) // 2 for r in regions for p in r["polygons"])
    print("regions: %d, links: %d (%d by sea), points: %d, size: %dx%d" % (
        len(regions), len(links), sum(1 for l in links if l["sea"]), points, MAP_WIDTH, height))
    unused = sorted(set(countries) - used)
    print("countries left out: %s" % " ".join(unused))
    for region_id in ids:
        near = sorted({l["b"] if l["a"] == region_id else l["a"] for l in links if region_id in (l["a"], l["b"])})
        print("  %-18s %s" % (region_id, ", ".join(near)))


def _unwrap_dateline(geom):
    """Moves Russia's easternmost parts (west of -160) past 180 so the country stays in one piece."""
    def shift(xs, ys, zs=None):
        return [x + 360 if x < -160 else x for x in xs], list(ys)
    return transform(shift, geom)


def _map_coords(fn, xs, ys):
    pairs = [fn(x, y) for x, y in zip(xs, ys)]
    return [p[0] for p in pairs], [p[1] for p in pairs]


def _polygons(geom):
    if isinstance(geom, Polygon):
        return [geom]
    if isinstance(geom, MultiPolygon):
        return list(geom.geoms)
    return [g for g in getattr(geom, "geoms", []) if isinstance(g, Polygon)]


def _flat(poly):
    coords = list(poly.exterior.coords)[:-1]
    return [round(v, 1) for xy in coords for v in xy]


def _check_connected(ids, links):
    adjacency = {rid: set() for rid in ids}
    for link in links:
        adjacency[link["a"]].add(link["b"])
        adjacency[link["b"]].add(link["a"])
    seen = {ids[0]}
    stack = [ids[0]]
    while stack:
        for n in adjacency[stack.pop()]:
            if n not in seen:
                seen.add(n)
                stack.append(n)
    missing = set(ids) - seen
    if missing:
        sys.exit("Regions not reachable: %s" % ", ".join(sorted(missing)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "ne_50m_admin_0_countries.geojson")

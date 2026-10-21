"""build_simulator.py -- assemble the self-contained peer-comparison simulator.
Author: Eric Booth.
Injects the real county data (CSV) and the fonts (base64) into the HTML
template and writes peer_simulator.html, a single file that opens from any
folder with no server.
Run from anywhere:  python3 simulator/build_simulator.py
Fonts: Open Sans (Apache License 2.0) and EB Garamond (SIL Open Font License),
copied from the TeX Live distribution into simulator/fonts.
"""
import base64
import csv
import json
from pathlib import Path

SIM = Path(__file__).resolve().parent

# ---- real county data (ACS 2019-23, PLACES 2023 release, RUCC 2023) ---------
rows = []
with open(SIM / "county_data.csv", newline="") as f:
    for r in csv.DictReader(f):
        rec = {"id": r["fips5"], "name": r["county_name"]}
        for k in ["unins", "unins_lo", "unins_hi", "lpop", "pop", "pov", "hisp", "medage",
                  "pct65", "bach", "unemp", "rucc", "metro", "border", "acs_unins"]:
            v = r[k]
            rec[k] = None if v in ("", ".") else round(float(v), 3)
        rows.append(rec)
county_json = json.dumps(rows, separators=(",", ":"))

# ---- fonts -----------------------------------------------------------------------
def b64(path):
    return base64.b64encode((SIM / "fonts" / path).read_bytes()).decode()

fonts_css = f"""
@font-face {{ font-family: 'Open Sans'; font-weight: 400; src: url(data:font/ttf;base64,{b64('OpenSans-Regular.ttf')}) format('truetype'); }}
@font-face {{ font-family: 'Open Sans'; font-weight: 600; src: url(data:font/ttf;base64,{b64('OpenSans-SemiBold.ttf')}) format('truetype'); }}
@font-face {{ font-family: 'EB Garamond'; font-weight: 600; src: url(data:font/otf;base64,{b64('EBGaramond-SemiBold.otf')}) format('opentype'); }}
"""

template = (SIM / "peer_simulator_template.html").read_text()
assert "/*__FONTS__*/" in template and "/*__COUNTY_DATA__*/" in template
out = template.replace("/*__FONTS__*/", fonts_css).replace("/*__COUNTY_DATA__*/", county_json)
(SIM / "peer_simulator.html").write_text(out)
print("wrote", SIM / "peer_simulator.html", f"{len(out)/1e6:.2f} MB", f"{len(rows)} counties")

#!/usr/bin/env python
# coding: utf-8
"""CLI wrapper around EvapotranspirationCulture.EvapotranspirationCulture, for
Octave (which has no MATLAB-style `py.*` interop) to call via `system()` —
same JSON-file-in/JSON-file-out convention as the Octave engine itself uses
towards the FastAPI backend (see engine_runner.py).

Usage: python3 evapotranspiration_culture_cli.py <input.json> <output.json>

<input.json>: {"lat": float, "lon": float, "date_semence": "YYYY-MM-DD", "t_croissance": int}
<output.json>: {"eto": [float, ...]}  (length t_croissance)

Does not change the underlying logic in EvapotranspirationCulture.py at all —
this only adapts its calling convention.
"""
import json
import sys

from EvapotranspirationCulture import EvapotranspirationCulture


def main():
    if len(sys.argv) != 3:
        print("usage: evapotranspiration_culture_cli.py <input.json> <output.json>", file=sys.stderr)
        sys.exit(2)
    input_path, output_path = sys.argv[1], sys.argv[2]

    with open(input_path) as f:
        params = json.load(f)

    eto = EvapotranspirationCulture(
        params["lat"], params["lon"], params["date_semence"], params["t_croissance"]
    )

    with open(output_path, "w") as f:
        json.dump({"eto": list(eto)}, f)


if __name__ == "__main__":
    main()

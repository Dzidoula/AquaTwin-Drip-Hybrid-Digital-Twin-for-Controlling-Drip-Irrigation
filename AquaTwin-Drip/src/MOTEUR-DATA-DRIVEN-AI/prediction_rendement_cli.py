#!/usr/bin/env python
# coding: utf-8
"""CLI wrapper around PredictionRendementTest.PredictionRendementTest, for
Octave to call via `system()` instead of MATLAB's `py.*` interop — same
JSON-file-in/JSON-file-out convention as evapotranspiration_culture_cli.py.

Usage: python3 prediction_rendement_cli.py <input.json> <output.json>

<input.json>: {"eto": [float, ...], "rendement": [float, ...], "v_a_predire": [float, ...]}
  (eto and rendement must be the same length — one value per growth-cycle day)
<output.json>: {"yield_predicted": [float, ...]}  (same length as v_a_predire)

Does not change the underlying logic in PredictionRendementTest.py at all —
this only adapts its calling convention.
"""
import json
import sys

from PredictionRendementTest import PredictionRendementTest


def _as_list(value):
    """Octave's jsonencode serializes a 1-element numeric vector as a bare
    JSON scalar, not a single-element array (the same quirk documented on
    the app side, see WettingBulbAnimation._numList) — v_a_predire is
    exactly 1 element whenever only one day is tested in the Prévisions
    screen. PredictionRendementTest then iterates over it (`for x in
    V_a_predire`), which raises on a plain int/float. Normalize here
    rather than in PredictionRendementTest.py itself (Alex's file)."""
    return value if isinstance(value, list) else [value]


def main():
    if len(sys.argv) != 3:
        print("usage: prediction_rendement_cli.py <input.json> <output.json>", file=sys.stderr)
        sys.exit(2)
    input_path, output_path = sys.argv[1], sys.argv[2]

    with open(input_path) as f:
        params = json.load(f)

    predicted = PredictionRendementTest(
        _as_list(params["eto"]), _as_list(params["rendement"]), _as_list(params["v_a_predire"])
    )

    with open(output_path, "w") as f:
        json.dump({"yield_predicted": [float(v) for v in predicted]}, f)


if __name__ == "__main__":
    main()

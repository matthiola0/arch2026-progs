#!/usr/bin/env python3
"""Check every target path and summarize the exact counter measurements."""

import argparse
import json
import re
from pathlib import Path

from generate_rubik_tables import SOURCE, TWIST


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--states", type=Path, required=True)
    args = parser.parse_args()
    expected = {}
    for line in args.states.read_text().splitlines():
        parts = line.split(",")
        if re.fullmatch(r"[1-7]{7}[1-3]{7}", parts[0]):
            expected[parts[0]] = int(parts[1]) if len(parts) > 1 else 11
    assert expected
    records = {}
    pattern = re.compile(r"@@probe state=(\d+) impl=(c|asm) length=(\d+) "
                         r"instructions=(\d+) moves=(.*)")
    for line in args.log.read_text().splitlines():
        match = pattern.fullmatch(line)
        if not match:
            continue
        state, impl, length, instructions, moves = match.groups()
        length, instructions = int(length), int(instructions)
        assert state in expected and length == expected[state]
        assert (state, impl) not in records
        assert instructions <= (7500000 if impl == "asm" else 50000000)
        p = [int(x) - 1 for x in state[:7]]
        o = [int(x) - 1 for x in state[7:]]
        tokens = moves.split(" ") if moves else []
        assert len(tokens) == length
        for token in tokens:
            assert token in ("R", "R2", "R'", "B", "B2", "B'", "D", "D2", "D'")
            face = "RBD".index(token[0])
            turns = 1 if len(token) == 1 else 2 if token[1] == "2" else 3
            for _ in range(turns):
                p = [p[k] for k in SOURCE[face]]
                o = [(o[k] + t) % 3 for k, t in zip(SOURCE[face], TWIST[face])]
        assert p == list(range(7)) and o == [0] * 7
        records[state, impl] = instructions
    assert set(records) == {(state, impl) for state in expected for impl in ("c", "asm")}
    summary = {"states_checked": len(expected), "paths_checked": len(records),
               "budget_failures": 0, "path_failures": 0}
    for impl in ("c", "asm"):
        entries = [(n, s) for (s, v), n in records.items() if v == impl]
        worst, state = max(entries)
        summary[impl] = {"maximum_instructions": worst, "worst_state": state,
                         "mean_instructions": sum(n for n, _ in entries) / len(entries)}
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()

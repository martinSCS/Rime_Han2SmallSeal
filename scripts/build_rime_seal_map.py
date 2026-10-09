#!/usr/bin/env python3
"""Build a Rime Lua filter mapping from SealSources.txt.

The output is a UTF-8 TSV file:

    modern_cjk<TAB>small_seal_unicode_variant_1<TAB>small_seal_unicode_variant_2...

When several small-seal code points share the same modern CJK equivalent, all
variants are kept in SealSources order. The Lua filter uses the first variant as
the phrase default and expands single-character candidates into variant choices.
"""

from __future__ import annotations

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "SealSources.txt"
DEFAULT_OUTPUT = ROOT / "rime" / "seal_map.tsv"


def build(source: Path, output: Path) -> None:
    pairs: dict[str, list[str]] = {}

    for raw_line in source.read_text(encoding="utf-8").splitlines():
        if not raw_line or raw_line.startswith("#"):
            continue

        fields = raw_line.split("\t")
        if len(fields) != 3:
            continue

        seal_cp_text, key, value = fields
        if key != "kSEAL_MCJK":
            continue

        small_seal_cp = int(seal_cp_text.removeprefix("U+"), 16)
        modern = chr(int(value, 16))
        small_seal = chr(small_seal_cp)
        variants = pairs.setdefault(modern, [])
        if small_seal not in variants:
            variants.append(small_seal)

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write("# modern_cjk\tsmall_seal_variants...\n")
        for modern in sorted(pairs):
            handle.write(f"{modern}\t{'\t'.join(pairs[modern])}\n")

    print(f"Wrote {output}")
    print(f"Modern entries: {len(pairs)}")
    print(f"Small-seal variants: {sum(len(variants) for variants in pairs.values())}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--input",
        type=Path,
        default=DEFAULT_SOURCE,
        help="Path to Unicode SealSources.txt.",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="Output path for the generated Rime seal_map.tsv.",
    )
    args = parser.parse_args()
    build(args.input, args.output)


if __name__ == "__main__":
    main()

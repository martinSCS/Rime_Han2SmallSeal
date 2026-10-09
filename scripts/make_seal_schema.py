#!/usr/bin/env python3
"""Create an independent Rime schema derived for small-seal output.

This is a lightweight text transformer for ordinary Rime schema YAML files. It
keeps the original processors, segmentors, translators, dictionaries, and other
schema settings, then inserts the small-seal filters and configuration.
"""

from __future__ import annotations

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def top_level(line: str) -> bool:
    return line and not line.startswith((" ", "\t")) and ":" in line


def find_section_end(lines: list[str], start: int) -> int:
    for index in range(start + 1, len(lines)):
        if top_level(lines[index]):
            return index
    return len(lines)


def replace_schema_fields(lines: list[str], schema_id: str, name: str) -> list[str]:
    out = lines[:]
    in_schema = False
    schema_indent = ""
    replaced_id = False
    replaced_name = False

    for index, line in enumerate(out):
        if line.startswith("schema:"):
            in_schema = True
            schema_indent = ""
            continue
        if in_schema and top_level(line):
            break
        if not in_schema:
            continue

        stripped = line.strip()
        indent = line[: len(line) - len(line.lstrip())]
        if stripped.startswith("schema_id:"):
            out[index] = f"{indent}schema_id: {schema_id}"
            replaced_id = True
        elif stripped.startswith("name:"):
            out[index] = f'{indent}name: "{name}"'
            replaced_name = True

    if not replaced_id or not replaced_name:
        raise SystemExit("Could not find schema/schema_id and schema/name in the source schema.")
    return out


def replace_translator_prism(lines: list[str], schema_id: str) -> list[str]:
    out = lines[:]
    for index, line in enumerate(out):
        if line.startswith("translator:"):
            end = find_section_end(out, index)
            dictionary_index = None
            prism_index = None
            indent = "  "
            for item_index in range(index + 1, end):
                stripped = out[item_index].strip()
                item_indent = out[item_index][: len(out[item_index]) - len(out[item_index].lstrip())]
                if stripped.startswith("dictionary:"):
                    dictionary_index = item_index
                    indent = item_indent
                elif stripped.startswith("prism:"):
                    prism_index = item_index
                    indent = item_indent

            if prism_index is not None:
                out[prism_index] = f"{indent}prism: {schema_id}"
            elif dictionary_index is not None:
                out.insert(dictionary_index + 1, f"{indent}prism: {schema_id}")
            else:
                raise SystemExit("Could not find translator/dictionary in the source schema.")
            return out

    raise SystemExit("Could not find translator in the source schema.")


def insert_filters(lines: list[str]) -> list[str]:
    for index, line in enumerate(lines):
        if line.strip() == "filters:":
            end = find_section_end(lines, index)
            block = [
                item
                for item in lines[index + 1 : end]
                if item.strip() != ""
                and "single_char_filter" not in item
                and "lua_filter@*seal_filter" not in item
            ]
            block.append("    - lua_filter@*seal_filter")
            return lines[: index + 1] + block + lines[end:]

    raise SystemExit("Could not find engine/filters in the source schema.")


def append_config(lines: list[str]) -> list[str]:
    if any(line.startswith("seal_filter:") for line in lines):
        return lines

    block = [
        "",
        "seal_filter:",
        "  map_file: seal_map.tsv",
        "  liding_map_file: opencc/SealVariants.txt",
        "  extra_liding_map_file: custom_liding.tsv",
        "  single_char_variants: true",
        "  max_variants: 9",
    ]
    return lines + block


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", type=Path, required=True, help="Source schema YAML.")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Generated seal schema YAML.")
    parser.add_argument("--schema-id", help="Generated schema id. Defaults to <source_schema_id>_seal.")
    parser.add_argument("--name", help="Generated schema name. Defaults to '<source name>・小篆'.")
    args = parser.parse_args()

    source_lines = args.input.read_text(encoding="utf-8").splitlines()
    source_id = None
    source_name = None
    in_schema = False
    for line in source_lines:
        if line.startswith("schema:"):
            in_schema = True
            continue
        if in_schema and top_level(line):
            break
        if in_schema and line.strip().startswith("schema_id:"):
            source_id = line.split(":", 1)[1].strip().strip('"')
        if in_schema and line.strip().startswith("name:"):
            source_name = line.split(":", 1)[1].strip().strip('"')

    if not source_id or not source_name:
        raise SystemExit("Could not read source schema id/name.")

    schema_id = args.schema_id or f"{source_id}_seal"
    name = args.name or f"{source_name}・小篆"

    lines = replace_schema_fields(source_lines, schema_id, name)
    lines = replace_translator_prism(lines, schema_id)
    lines = insert_filters(lines)
    lines = append_config(lines)

    header = [
        f"# Generated from {args.input.name} by scripts/make_seal_schema.py.",
        "# Switch back to the original schema for the unmodified input method.",
        "",
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(header + lines) + "\n", encoding="utf-8")
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()

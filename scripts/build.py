#!/usr/bin/env python3
"""Generate Mihomo rulesets from JSON sources."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parent.parent
SOURCE_ROOT = ROOT / "sources"
OUTPUT_ROOT = ROOT / "output"


def ensure_directory(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_lines(path: Path, lines: Iterable[str]) -> None:
    ensure_directory(path.parent)
    content = "\n".join(lines) + "\n"
    path.write_text(content, encoding="utf-8")


def normalize_domain(value: str) -> str:
    return value.strip().lstrip(".").lower()


def normalize_keyword(value: str) -> str:
    return value.strip().lower()


def convert_mrs(behavior: str, input_format: str, source_path: Path, mrs_path: Path) -> None:
    try:
        subprocess.run(
            [
                "mihomo",
                "convert-ruleset",
                behavior,
                input_format,
                str(source_path),
                str(mrs_path),
            ],
            check=True,
        )
    except FileNotFoundError as err:
        raise SystemExit("mihomo не найден в PATH. Установите бинарник перед сборкой.") from err
    except subprocess.CalledProcessError as err:
        raise SystemExit(f"mihomo convert-ruleset завершился с ошибкой: {err}") from err


def process_domain_sources() -> None:
    domain_dir = SOURCE_ROOT / "domain"
    output_dir = OUTPUT_ROOT / "domain"
    ensure_directory(output_dir)

    for source in sorted(domain_dir.glob("*.json")):
        data = json.loads(source.read_text(encoding="utf-8"))
        payload_entries: list[str] = []
        list_entries: list[str] = []

        seen_suffix: set[str] = set()
        seen_exact: set[str] = set()

        for rule in data.get("rules", []):
            for raw_value in rule.get("domain_suffix", []) or []:
                value = normalize_domain(raw_value)
                if not value or value in seen_suffix:
                    continue
                seen_suffix.add(value)
                payload_entries.append(f"+.{value}")
                list_entries.append(f"+.{value}")
            for raw_value in rule.get("domain", []) or []:
                value = normalize_domain(raw_value)
                if not value or value in seen_exact:
                    continue
                seen_exact.add(value)
                payload_entries.append(value)
                list_entries.append(value)

        if not payload_entries:
            print(f"Пропускаю {source.name}: нет доменных записей", file=sys.stderr)
            continue

        name = source.stem
        yaml_path = output_dir / f"{name}.yaml"
        list_path = output_dir / f"{name}.list"
        mrs_path = output_dir / f"{name}.mrs"

        yaml_lines = ["payload:"] + [f"  - '+.{entry[2:]}'" if entry.startswith("+.") else f"  - '{entry}'" for entry in payload_entries]
        # Отдельно формируем список, чтобы сохранять исходный порядок элементов
        list_lines = list_entries

        write_lines(yaml_path, yaml_lines)
        write_lines(list_path, list_lines)
        convert_mrs("domain", "yaml", yaml_path, mrs_path)
        print(f"Собран доменный ruleset: {name}")


CLASSICAL_KEY_PREFIX = {
    "domain_suffix": "DOMAIN-SUFFIX",
    "domain": "DOMAIN",
    "domain_keyword": "DOMAIN-KEYWORD",
    "domain_regex": "DOMAIN-REGEX",
    "domain_keyword_regex": "DOMAIN-KEYWORD-REGEX",
    "ip_cidr": "IP-CIDR",
    "ip_cidr6": "IP-CIDR6",
    "process_name": "PROCESS-NAME",
    "process_name_regex": "PROCESS-NAME-REGEX",
    "payload": None,  # уже строка целиком
}


def process_classical_sources() -> None:
    classical_dir = SOURCE_ROOT / "classical"
    output_dir = OUTPUT_ROOT / "classical"
    ensure_directory(output_dir)

    for source in sorted(classical_dir.glob("*.json")):
        data = json.loads(source.read_text(encoding="utf-8"))
        payload_entries: list[str] = []

        seen_entries: set[str] = set()

        for rule in data.get("rules", []):
            for key, prefix in CLASSICAL_KEY_PREFIX.items():
                values = rule.get(key)
                if not values:
                    continue
                if key == "payload":
                    iterable = values if isinstance(values, list) else [values]
                    for item in iterable:
                        entry = item.strip()
                        if not entry or entry in seen_entries:
                            continue
                        seen_entries.add(entry)
                        payload_entries.append(entry)
                    continue

                iterable = values if isinstance(values, list) else [values]
                for raw_value in iterable:
                    value = raw_value.strip()
                    if not value:
                        continue
                    if key in {"domain_suffix", "domain"}:
                        value = normalize_domain(value)
                    elif key in {"domain_keyword"}:
                        value = normalize_keyword(value)
                    if key in {"domain_suffix", "domain"} and not value:
                        continue
                    entry = f"{prefix},{value}"
                    if entry in seen_entries:
                        continue
                    seen_entries.add(entry)
                    payload_entries.append(entry)

        if not payload_entries:
            print(f"Пропускаю {source.name}: нет записей payload", file=sys.stderr)
            continue

        name = source.stem
        yaml_path = output_dir / f"{name}.yaml"
        text_path = output_dir / f"{name}.txt"
        mrs_path = output_dir / f"{name}.mrs"
        yaml_lines = ["payload:"] + [f"  - {entry}" for entry in payload_entries]
        text_lines = payload_entries

        write_lines(yaml_path, yaml_lines)
        write_lines(text_path, text_lines)
        convert_mrs("classical", "text", text_path, mrs_path)
        print(f"Собран classical ruleset: {name}")


def main() -> None:
    ensure_directory(OUTPUT_ROOT)
    process_domain_sources()
    process_classical_sources()


if __name__ == "__main__":
    main()

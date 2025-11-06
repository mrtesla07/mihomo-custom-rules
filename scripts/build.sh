#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/output"

LIST_PATH="${ROOT_DIR}/domains/common.txt"
OUTPUT_NAME="my-domains"
MIHOMO_BIN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--list)
      LIST_PATH="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_NAME="$2"
      shift 2
      ;;
    -m|--mihomo)
      MIHOMO_BIN="$2"
      shift 2
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$LIST_PATH" ]]; then
  echo "Файл не найден: $LIST_PATH" >&2
  exit 1
fi

mapfile -t RAW_LINES < "$LIST_PATH"
DOMAINS=()
for line in "${RAW_LINES[@]}"; do
  clean="$(echo "$line" | tr -d '\r' | xargs)"
  clean="${clean#$'\ufeff'}"
  if [[ -z "$clean" ]]; then
    continue
  fi
  if [[ "$clean" == \#* ]]; then
    continue
  fi
  clean_lower="$(echo "$clean" | tr '[:upper:]' '[:lower:]')"
  DOMAINS+=("$clean_lower")
done

if [[ ${#DOMAINS[@]} -eq 0 ]]; then
  echo "Файл $LIST_PATH не содержит доменов" >&2
  exit 1
fi

# Удаляем дубликаты, сохраняя порядок
TMP_DOMAINS=()
for domain in "${DOMAINS[@]}"; do
  skip=false
  for added in "${TMP_DOMAINS[@]}"; do
    if [[ "$domain" == "$added" ]]; then
      skip=true
      break
    fi
  done
  if ! $skip; then
    TMP_DOMAINS+=("$domain")
  fi
done
DOMAINS=("${TMP_DOMAINS[@]}")

mkdir -p "$OUTPUT_DIR"

YAML_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}.yaml"
LIST_OUT="${OUTPUT_DIR}/${OUTPUT_NAME}.list"
MRS_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}.mrs"

printf 'payload:\n' > "$YAML_PATH"
: > "$LIST_OUT"
for domain in "${DOMAINS[@]}"; do
  printf "  - '+.%s'\n" "$domain" >> "$YAML_PATH"
  printf '+.%s\n' "$domain" >> "$LIST_OUT"
done

echo "YAML:  $YAML_PATH"
echo "LIST:  $LIST_OUT"

if [[ -n "$MIHOMO_BIN" ]]; then
  if [[ ! -x "$MIHOMO_BIN" ]]; then
    echo "Бинарник mihomo недоступен для выполнения: $MIHOMO_BIN" >&2
    exit 1
  fi
elif command -v mihomo >/dev/null 2>&1; then
  MIHOMO_BIN="$(command -v mihomo)"
elif command -v mihomo.exe >/dev/null 2>&1; then
  MIHOMO_BIN="$(command -v mihomo.exe)"
else
  MIHOMO_BIN=""
fi

if [[ -n "$MIHOMO_BIN" ]]; then
  if "$MIHOMO_BIN" convert-ruleset domain yaml "$YAML_PATH" "$MRS_PATH"; then
    echo "MRS:   $MRS_PATH"
  else
    echo "Не удалось собрать .mrs через $MIHOMO_BIN" >&2
  fi
else
  echo "mihomo не найден, генерация .mrs пропущена" >&2
fi

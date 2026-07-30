#!/usr/bin/env bash
set -euo pipefail

TNOODLE_VERSION="1.2.3"
TNOODLE_SHA256="e9ff6a164effee8a7ecdcc5c18111d4aa09d1de471b71de224889a1282d98cd5"
TNOODLE_RELEASE_URL="https://github.com/thewca/tnoodle/releases/download/v${TNOODLE_VERSION}/TNoodle-WCA-${TNOODLE_VERSION}.jar"
COUNT="${COUNT:-32768}"
BATCH_SIZE="${BATCH_SIZE:-256}"
WORKERS="${WORKERS:-16}"
PORT="${PORT:-28114}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-${ROOT_DIR}/Sources/CubeCoachCore/Resources/Scrambles}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cubecoach-tnoodle.XXXXXX")"
JAR_PATH="${WORK_DIR}/TNoodle-WCA-${TNOODLE_VERSION}.jar"
SERVER_LOG="${WORK_DIR}/tnoodle.log"
RAW_PATH="${WORK_DIR}/scrambles.txt"
JSONL_PATH="${OUT_DIR}/tnoodle-${TNOODLE_VERSION}-333.jsonl"
MANIFEST_PATH="${OUT_DIR}/tnoodle-${TNOODLE_VERSION}-333.manifest.json"
SERVER_PID=""

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT INT TERM

for command in curl java jq python3 shasum; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Required command not found: ${command}" >&2
    exit 1
  }
done

if (( COUNT < 32768 )); then
  echo "COUNT must be at least 32768 (requested: ${COUNT})" >&2
  exit 1
fi
if (( BATCH_SIZE < 1 || BATCH_SIZE > 1000 )); then
  echo "BATCH_SIZE must be between 1 and 1000" >&2
  exit 1
fi
if (( WORKERS < 1 || WORKERS > 32 )); then
  echo "WORKERS must be between 1 and 32" >&2
  exit 1
fi

echo "Downloading signed TNoodle-WCA ${TNOODLE_VERSION} release…"
curl -fL --retry 3 --retry-delay 2 -o "${JAR_PATH}" "${TNOODLE_RELEASE_URL}"
printf '%s  %s\n' "${TNOODLE_SHA256}" "${JAR_PATH}" | shasum -a 256 -c -

echo "Starting TNoodle on localhost:${PORT}…"
java -jar "${JAR_PATH}" -n -b -u --noReexec -p "${PORT}" >"${SERVER_LOG}" 2>&1 &
SERVER_PID="$!"

VERSION_JSON=""
for _ in $(seq 1 180); do
  if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
    echo "TNoodle exited before becoming ready:" >&2
    cat "${SERVER_LOG}" >&2
    exit 1
  fi
  VERSION_JSON="$(curl -fsS --max-time 2 "http://127.0.0.1:${PORT}/version" 2>/dev/null || true)"
  if [[ -n "${VERSION_JSON}" ]]; then break; fi
  sleep 1
done

if [[ -z "${VERSION_JSON}" ]]; then
  echo "TNoodle did not become ready within 180 seconds" >&2
  cat "${SERVER_LOG}" >&2
  exit 1
fi

jq -e \
  --arg version "${TNOODLE_VERSION}" \
  '.projectName == "TNoodle-WCA" and .projectVersion == $version and .signedBuild == true' \
  <<<"${VERSION_JSON}" >/dev/null || {
    echo "Unexpected /version response: ${VERSION_JSON}" >&2
    exit 1
  }
echo "Verified /version: projectName=TNoodle-WCA projectVersion=${TNOODLE_VERSION} signedBuild=true"

: >"${RAW_PATH}"
generated=0
batch_number=0
while (( generated < COUNT )); do
  pids=()
  part_paths=()
  part_counts=()
  for _ in $(seq 1 "${WORKERS}"); do
    if (( generated >= COUNT )); then break; fi
    remaining=$((COUNT - generated))
    request_count="${BATCH_SIZE}"
    if (( remaining < request_count )); then request_count="${remaining}"; fi
    part_path="${WORK_DIR}/batch-$(printf '%06d' "${batch_number}").txt"
    (
      curl -fsS --retry 3 --retry-delay 1 --max-time 300 \
        "http://127.0.0.1:${PORT}/api/v0/scramble/333/raw?numScrambles=${request_count}" \
        | tr -d '\r' >"${part_path}"
    ) &
    pids+=("$!")
    part_paths+=("${part_path}")
    part_counts+=("${request_count}")
    generated=$((generated + request_count))
    batch_number=$((batch_number + 1))
  done

  for pid in "${pids[@]}"; do wait "${pid}"; done
  for index in "${!part_paths[@]}"; do
    actual_count="$(awk 'NF { count += 1 } END { print count + 0 }' "${part_paths[$index]}")"
    if [[ "${actual_count}" != "${part_counts[$index]}" ]]; then
      echo "Batch returned ${actual_count} lines; expected ${part_counts[$index]}" >&2
      exit 1
    fi
    cat "${part_paths[$index]}" >>"${RAW_PATH}"
    # The raw endpoint does not guarantee a trailing newline. Always add one
    # between response bodies so adjacent scrambles cannot be concatenated.
    printf '\n' >>"${RAW_PATH}"
  done
  printf '\rGenerated %d/%d' "${generated}" "${COUNT}"
done
printf '\n'

mkdir -p "${OUT_DIR}"
python3 - "${RAW_PATH}" "${JSONL_PATH}.tmp" "${COUNT}" <<'PY'
import json
import re
import sys

source, destination, expected_text = sys.argv[1:]
expected = int(expected_text)
token = re.compile(r"^[RLUDFB](?:2|')?$")

with open(source, encoding="utf-8") as handle:
    scrambles = [line.strip() for line in handle if line.strip()]

if len(scrambles) != expected:
    raise SystemExit(f"TNoodle returned {len(scrambles)} non-empty lines; expected {expected}")
if len(set(scrambles)) != expected:
    raise SystemExit(f"Catalog contains {expected - len(set(scrambles))} duplicate scrambles")

for line_number, scramble in enumerate(scrambles, 1):
    moves = scramble.split()
    if not moves or any(token.fullmatch(move) is None for move in moves):
        raise SystemExit(f"Invalid 3x3 notation at line {line_number}: {scramble!r}")

with open(destination, "w", encoding="utf-8", newline="\n") as handle:
    for scramble in scrambles:
        handle.write(json.dumps(scramble, ensure_ascii=False, separators=(",", ":")) + "\n")
PY

mv "${JSONL_PATH}.tmp" "${JSONL_PATH}"
POOL_SHA256="$(shasum -a 256 "${JSONL_PATH}" | awk '{print $1}')"

jq -n \
  --argjson schemaVersion 1 \
  --arg event "333" \
  --arg generator "TNoodle-WCA" \
  --arg generatorVersion "${TNOODLE_VERSION}" \
  --arg officialReleaseURL "https://github.com/thewca/tnoodle/releases/tag/v${TNOODLE_VERSION}" \
  --arg generatorSHA256 "${TNOODLE_SHA256}" \
  --argjson signedBuild true \
  --argjson count "${COUNT}" \
  --arg poolSHA256 "${POOL_SHA256}" \
  --arg claim "tnoodleGeneratedPractice" \
  '{
    schemaVersion: $schemaVersion,
    event: $event,
    generator: $generator,
    generatorVersion: $generatorVersion,
    officialReleaseURL: $officialReleaseURL,
    generatorSHA256: $generatorSHA256,
    signedBuild: $signedBuild,
    count: $count,
    poolSHA256: $poolSHA256,
    claim: $claim
  }' >"${MANIFEST_PATH}.tmp"
mv "${MANIFEST_PATH}.tmp" "${MANIFEST_PATH}"

echo "Catalog: ${JSONL_PATH}"
echo "Manifest: ${MANIFEST_PATH}"
echo "Count: ${COUNT}"
echo "Pool SHA-256: ${POOL_SHA256}"
echo "The committed app resources contain generated text and provenance only; the JAR is deleted on exit."

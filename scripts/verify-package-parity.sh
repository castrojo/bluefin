#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <candidate-image-ref> <reference-image-ref>"
    exit 2
fi

CANDIDATE_IMAGE="$1"
REFERENCE_IMAGE="$2"

WORKDIR_CREATED=0
if [[ -n "${WORKDIR:-}" ]]; then
    WORKDIR="${WORKDIR}"
    mkdir -p "${WORKDIR}"
else
    WORKDIR="$(mktemp -d)"
    WORKDIR_CREATED=1
fi

if [[ -z "${KEEP_WORKDIR:-}" && "${WORKDIR_CREATED}" -eq 1 ]]; then
    trap 'rm -rf "$WORKDIR"' EXIT
elif [[ -n "${KEEP_WORKDIR:-}" ]]; then
    echo "Keeping reports in ${WORKDIR}"
fi

CANDIDATE_MANIFEST="$WORKDIR/candidate.txt"
REFERENCE_MANIFEST="$WORKDIR/reference.txt"
MISSING_REPORT="$WORKDIR/missing.txt"
NEW_REPORT="$WORKDIR/new.txt"
UNEXPECTED_MISSING_REPORT="$WORKDIR/unexpected-missing.txt"

ALLOWLIST_MISSING=(
    ublue-os-luks
    ublue-os-just
    ublue-os-udev-rules
    ublue-os-signing
    ublue-os-update-services
)

NEGATIVO_PACKAGES=(
    mesa-va-drivers
    libheif
    ffmpeg
    ffmpeg-libs
    libfdk-aac
)

extract_manifest() {
    local image_ref="$1"
    local output_file="$2"

    podman run --rm --entrypoint /usr/bin/rpm "${image_ref}" -qa --qf '%{NAME}\n' \
        | LC_ALL=C sort -u >"${output_file}"
}

contains_allowlisted_missing() {
    local pkg="$1"
    local allowed
    for allowed in "${ALLOWLIST_MISSING[@]}"; do
        if [[ "${pkg}" == "${allowed}" ]]; then
            return 0
        fi
    done
    return 1
}

echo "Extracting package manifest from candidate: ${CANDIDATE_IMAGE}"
extract_manifest "${CANDIDATE_IMAGE}" "${CANDIDATE_MANIFEST}"

echo "Extracting package manifest from reference: ${REFERENCE_IMAGE}"
extract_manifest "${REFERENCE_IMAGE}" "${REFERENCE_MANIFEST}"

comm -23 "${REFERENCE_MANIFEST}" "${CANDIDATE_MANIFEST}" >"${MISSING_REPORT}"
comm -13 "${REFERENCE_MANIFEST}" "${CANDIDATE_MANIFEST}" >"${NEW_REPORT}"

echo "Missing packages report: ${MISSING_REPORT}"
echo "New packages report: ${NEW_REPORT}"

: >"${UNEXPECTED_MISSING_REPORT}"
while IFS= read -r pkg; do
    [[ -z "${pkg}" ]] && continue
    if ! contains_allowlisted_missing "${pkg}"; then
        printf '%s\n' "${pkg}" >>"${UNEXPECTED_MISSING_REPORT}"
    fi
done <"${MISSING_REPORT}"

vendor_fail=0
vendor_info="$(podman run --rm --entrypoint /usr/bin/rpm "${CANDIDATE_IMAGE}" -q --qf '%{NAME} %{VENDOR}\n' "${NEGATIVO_PACKAGES[@]}" 2>/dev/null || true)"
for package in "${NEGATIVO_PACKAGES[@]}"; do
    if ! grep -i -E "^${package}[[:space:]]+.*negativo17" <<<"${vendor_info}" >/dev/null; then
        echo "FAIL: NEGATIVO vendor mismatch for ${package}"
        vendor_fail=1
    fi
done

unexpected_missing_count="$(wc -l <"${UNEXPECTED_MISSING_REPORT}")"
vendor_fail_count="${vendor_fail}"

if [[ "${unexpected_missing_count}" -eq 0 && "${vendor_fail_count}" -eq 0 ]]; then
    echo "PASS: package parity checks succeeded"
    echo "  Candidate: ${CANDIDATE_IMAGE}"
    echo "  Reference: ${REFERENCE_IMAGE}"
    echo "  Missing report: ${MISSING_REPORT}"
    echo "  New report: ${NEW_REPORT}"
    exit 0
fi

echo "FAIL: package parity checks failed"
if [[ "${unexpected_missing_count}" -gt 0 ]]; then
    echo "  Unexpected missing packages (${unexpected_missing_count}):"
    cat "${UNEXPECTED_MISSING_REPORT}"
fi
if [[ "${vendor_fail_count}" -ne 0 ]]; then
    echo "  One or more NEGATIVO vendor checks failed"
fi
echo "  Missing report: ${MISSING_REPORT}"
echo "  New report: ${NEW_REPORT}"

exit 1

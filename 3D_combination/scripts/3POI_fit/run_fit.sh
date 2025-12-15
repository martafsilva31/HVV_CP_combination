#!/usr/bin/env bash
# =============================================================================
# run_fit.sh - 3POI fit runner
# =============================================================================
# Runs a maximum likelihood fit floating all three Wilson coefficients.
#
# Usage:
#   ./run_fit.sh --workspace linear_obs --backend local --hesse
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../configs/hvv_cp_combination.yaml"

WORKSPACE=""
BACKEND="local"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/3POI_fits"
TAG=""
QUEUE="medium"
HESSE=true

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run 3POI maximum likelihood fit.

Required:
  --workspace <label>   Workspace label (linear_obs, linear_asimov, quad_obs, quad_asimov)

Optional:
  --backend <backend>   local|condor (default: local)
  --output-dir <dir>    Output directory
  --tag <tag>           Tag for output naming
  --queue <queue>       Condor queue (default: medium)
  --no-hesse            Skip Hesse error calculation
  --config <file>       Config file
  -h, --help            Show this help message

Examples:
  # Local fit with Hesse
  $(basename "$0") --workspace linear_obs --backend local

  # Condor fit without Hesse
  $(basename "$0") --workspace quad_obs --backend condor --no-hesse

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace) WORKSPACE="$2"; shift 2;;
        --backend) BACKEND="$2"; shift 2;;
        --output-dir) OUTPUT_DIR="$2"; shift 2;;
        --tag) TAG="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --no-hesse) HESSE=false; shift;;
        --hesse) HESSE=true; shift;;
        --config) CONFIG="$2"; shift 2;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

if [[ -z "$WORKSPACE" ]]; then
    echo "Error: --workspace is required"
    usage
fi

mkdir -p "$OUTPUT_DIR"

if [[ -z "$TAG" ]]; then
    TAG="${WORKSPACE}_3POI_fit"
fi

echo "=============================================="
echo "3POI Maximum Likelihood Fit"
echo "=============================================="
echo "  Workspace: $WORKSPACE"
echo "  Backend:   $BACKEND"
echo "  Hesse:     $HESSE"
echo "  Output:    $OUTPUT_DIR"
echo "  Tag:       $TAG"
echo "=============================================="
echo

cd "$SCRIPT_DIR/.."

HESSE_FLAG=""
if $HESSE; then
    HESSE_FLAG="--hesse"
fi

python3 -m quickfit.runner \
    --config "$CONFIG" \
    --scan-type fit \
    --workspace "$WORKSPACE" \
    --backend "$BACKEND" \
    --output-dir "$OUTPUT_DIR" \
    --tag "$TAG" \
    --queue "$QUEUE" \
    $HESSE_FLAG

echo
echo "Done! Result in: $OUTPUT_DIR/${TAG}.root"

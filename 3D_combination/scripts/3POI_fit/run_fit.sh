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
SYSTEMATICS="full_syst"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/3POI_fits"
TAG=""
QUEUE="medium"
HESSE=true
MINOS=false

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run 3POI maximum likelihood fit.

Required:
  --workspace <label>   Workspace label (linear_obs, linear_asimov, quad_obs, quad_asimov)

Optional:
  --backend <backend>   local|condor (default: local)
  --systematics <sys>   full_syst|stat_only (default: full_syst)
  --output-dir <dir>    Output directory
  --tag <tag>           Tag for output naming
  --queue <queue>       Condor queue (default: medium)
  --hesse               Run Hesse error calculation (default: true)
  --no-hesse            Skip Hesse error calculation
  --minos               Run MINOS error calculation
  --no-minos            Skip MINOS error calculation (default)
  --config <file>       Config file
  -h, --help            Show this help message

Examples:
  # Local fit with Hesse
  $(basename "$0") --workspace linear_obs --backend local

  # Condor fit with MINOS, no Hesse
  $(basename "$0") --workspace quad_obs --backend condor --no-hesse --minos

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace) WORKSPACE="$2"; shift 2;;
        --backend) BACKEND="$2"; shift 2;;
        --systematics) SYSTEMATICS="$2"; shift 2;;
        --output-dir) OUTPUT_DIR="$2"; shift 2;;
        --tag) TAG="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --no-hesse) HESSE=false; shift;;
        --hesse) HESSE=true; shift;;
        --minos) MINOS=true; shift;;
        --no-minos) MINOS=false; shift;;
        --config) CONFIG="$2"; shift 2;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

if [[ -z "$WORKSPACE" ]]; then
    echo "Error: --workspace is required"
    usage
fi

# Convert OUTPUT_DIR to absolute path if relative
if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$(pwd)/$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"

if [[ -z "$TAG" ]]; then
    TAG="${WORKSPACE}_3POI_fit"
fi

echo "=============================================="
echo "3POI Maximum Likelihood Fit"
echo "=============================================="
echo "  Workspace:  $WORKSPACE"
echo "  Backend:    $BACKEND"
echo "  Systematics: $SYSTEMATICS"
echo "  Hesse:      $HESSE"
echo "  MINOS:      $MINOS"
echo "  Output:     $OUTPUT_DIR"
echo "  Tag:        $TAG"
echo "=============================================="
echo

cd "$SCRIPT_DIR/.."

HESSE_FLAG=""
if $HESSE; then
    HESSE_FLAG="--hesse"
fi

MINOS_VAL=0
if $MINOS; then
    MINOS_VAL=1
fi

python3 -m quickfit.runner \
    --config "$CONFIG" \
    --scan-type fit \
    --workspace "$WORKSPACE" \
    --backend "$BACKEND" \
    --systematics "$SYSTEMATICS" \
    --output-dir "$OUTPUT_DIR" \
    --tag "$TAG" \
    --queue "$QUEUE" \
    --minos "$MINOS_VAL" \
    $HESSE_FLAG

echo
echo "Done! Result in: $OUTPUT_DIR/${TAG}.root"

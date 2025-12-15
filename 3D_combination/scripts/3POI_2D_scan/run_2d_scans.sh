#!/usr/bin/env bash
# =============================================================================
# run_2d_scans.sh - User-friendly 2D scan runner
# =============================================================================
# This script provides a simple interface for running 2D likelihood scans
# using the quickfit module.
#
# Usage:
#   ./run_2d_scans.sh --workspace linear_obs \
#                     --poi1 cHWtil_combine --min1 -1 --max1 1 --n1 21 \
#                     --poi2 cHBtil_combine --min2 -1.5 --max2 1.5 --n2 21 \
#                     --mode parallel --backend condor
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../configs/hvv_cp_combination.yaml"

# Default values
WORKSPACE=""
POI1=""
MIN1=""
MAX1=""
N1=21
POI2=""
MIN2=""
MAX2=""
N2=21
MODE="parallel"
BACKEND="local"
SYSTEMATICS="full_syst"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/2D_scans"
TAG=""
QUEUE="short"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run 2D likelihood scans using quickFit.

Required:
  --workspace <label>   Workspace label (linear_obs, linear_asimov, quad_obs, quad_asimov)
  --poi1 <name>        First POI to scan
  --min1 <value>       Minimum for POI1
  --max1 <value>       Maximum for POI1
  --poi2 <name>        Second POI to scan
  --min2 <value>       Minimum for POI2
  --max2 <value>       Maximum for POI2

Optional:
  --n1 <N>             Points for POI1 (default: 21)
  --n2 <N>             Points for POI2 (default: 21)
  --mode <mode>        parallel|sequential (default: parallel)
  --backend <backend>  local|condor (default: local)
  --systematics <sys>  full_syst|stat_only (default: full_syst)
  --output-dir <dir>   Output directory
  --tag <tag>          Tag for output naming
  --queue <queue>      Condor queue (default: short)
  --config <file>      Config file
  -h, --help           Show this help message

Examples:
  # Condor parallel 2D scan
  $(basename "$0") --workspace linear_obs \\
                   --poi1 cHWtil_combine --min1 -1 --max1 1 --n1 21 \\
                   --poi2 cHBtil_combine --min2 -1.5 --max2 1.5 --n2 21 \\
                   --mode parallel --backend condor

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace) WORKSPACE="$2"; shift 2;;
        --poi1) POI1="$2"; shift 2;;
        --min1) MIN1="$2"; shift 2;;
        --max1) MAX1="$2"; shift 2;;
        --n1) N1="$2"; shift 2;;
        --poi2) POI2="$2"; shift 2;;
        --min2) MIN2="$2"; shift 2;;
        --max2) MAX2="$2"; shift 2;;
        --n2) N2="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        --backend) BACKEND="$2"; shift 2;;
        --systematics) SYSTEMATICS="$2"; shift 2;;
        --output-dir) OUTPUT_DIR="$2"; shift 2;;
        --tag) TAG="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --config) CONFIG="$2"; shift 2;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

# Validate required arguments
if [[ -z "$WORKSPACE" || -z "$POI1" || -z "$MIN1" || -z "$MAX1" || \
      -z "$POI2" || -z "$MIN2" || -z "$MAX2" ]]; then
    echo "Error: Missing required arguments"
    usage
fi

mkdir -p "$OUTPUT_DIR"

if [[ -z "$TAG" ]]; then
    TAG="${WORKSPACE}_${POI1}_${POI2}_${MODE}"
fi

TOTAL_POINTS=$((N1 * N2))

echo "=============================================="
echo "2D Likelihood Scan"
echo "=============================================="
echo "  Workspace: $WORKSPACE"
echo "  POI1:      $POI1 [$MIN1, $MAX1] x $N1"
echo "  POI2:      $POI2 [$MIN2, $MAX2] x $N2"
echo "  Total:     $TOTAL_POINTS points"
echo "  Mode:      $MODE"
echo "  Backend:   $BACKEND"echo "  Systematics: $SYSTEMATICS"echo "  Output:    $OUTPUT_DIR"
echo "  Tag:       $TAG"
echo "=============================================="
echo

cd "$SCRIPT_DIR/.."
python3 -m quickfit.runner \
    --config "$CONFIG" \
    --scan-type 2d \
    --workspace "$WORKSPACE" \
    --poi "$POI1" \
    --min "$MIN1" \
    --max "$MAX1" \
    --n-points "$N1" \
    --poi2 "$POI2" \
    --min2 "$MIN2" \
    --max2 "$MAX2" \
    --n-points2 "$N2" \
    --mode "$MODE" \
    --backend "$BACKEND" \
    --systematics "$SYSTEMATICS" \
    --output-dir "$OUTPUT_DIR" \
    --tag "$TAG" \
    --queue "$QUEUE"

echo
echo "Done! Results in: $OUTPUT_DIR/root_${TAG}"

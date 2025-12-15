#!/usr/bin/env bash
# =============================================================================
# run_1d_scans.sh - User-friendly 1D scan runner
# =============================================================================
# This script provides a simple interface for running 1D likelihood scans
# using the quickfit module.
#
# Usage:
#   ./run_1d_scans.sh --workspace linear_obs --poi cHWtil_combine \
#                     --min -1 --max 1 --n 31 --mode parallel --backend condor
#
# Or use the analysis submission script for batch submission:
#   ./submit_1d_scans_hvv_cp.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../configs/hvv_cp_combination.yaml"

# Default values
WORKSPACE=""
POI=""
MIN=""
MAX=""
NPOINTS=31
MODE="parallel"
BACKEND="local"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/1D_scans"
TAG=""
QUEUE="medium"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run 1D likelihood scans using quickFit.

Required:
  --workspace <label>    Workspace label (linear_obs, linear_asimov, quad_obs, quad_asimov)
  --poi <name>          POI to scan (e.g., cHWtil_combine)
  --min <value>         Minimum scan value
  --max <value>         Maximum scan value

Optional:
  --n <N>               Number of scan points (default: 31)
  --mode <mode>         parallel|sequential (default: parallel)
  --backend <backend>   local|condor (default: local)
  --output-dir <dir>    Output directory (default: output/1D_scans)
  --tag <tag>           Tag for output naming
  --queue <queue>       Condor queue (default: medium)
  --config <file>       Config file (default: configs/hvv_cp_combination.yaml)
  -h, --help            Show this help message

Examples:
  # Local sequential scan
  $(basename "$0") --workspace linear_obs --poi cHWtil_combine \\
                   --min -1 --max 1 --n 21 --mode sequential --backend local

  # Condor parallel scan
  $(basename "$0") --workspace quad_obs --poi cHBtil_combine \\
                   --min -1.5 --max 1.5 --n 31 --mode parallel --backend condor

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace) WORKSPACE="$2"; shift 2;;
        --poi) POI="$2"; shift 2;;
        --min) MIN="$2"; shift 2;;
        --max) MAX="$2"; shift 2;;
        --n) NPOINTS="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        --backend) BACKEND="$2"; shift 2;;
        --output-dir) OUTPUT_DIR="$2"; shift 2;;
        --tag) TAG="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --config) CONFIG="$2"; shift 2;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

# Validate required arguments
if [[ -z "$WORKSPACE" || -z "$POI" || -z "$MIN" || -z "$MAX" ]]; then
    echo "Error: --workspace, --poi, --min, and --max are required"
    usage
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build tag if not provided
if [[ -z "$TAG" ]]; then
    TAG="${WORKSPACE}_${POI}_${MODE}"
fi

echo "=============================================="
echo "1D Likelihood Scan"
echo "=============================================="
echo "  Workspace: $WORKSPACE"
echo "  POI:       $POI"
echo "  Range:     [$MIN, $MAX] with $NPOINTS points"
echo "  Mode:      $MODE"
echo "  Backend:   $BACKEND"
echo "  Output:    $OUTPUT_DIR"
echo "  Tag:       $TAG"
echo "=============================================="
echo

# Run the scan using the Python quickfit runner
cd "$SCRIPT_DIR/.."
python3 -m quickfit.runner \
    --config "$CONFIG" \
    --scan-type 1d \
    --workspace "$WORKSPACE" \
    --poi "$POI" \
    --min "$MIN" \
    --max "$MAX" \
    --n-points "$NPOINTS" \
    --mode "$MODE" \
    --backend "$BACKEND" \
    --output-dir "$OUTPUT_DIR" \
    --tag "$TAG" \
    --queue "$QUEUE"

echo
echo "Done! Results in: $OUTPUT_DIR/root_${TAG}"

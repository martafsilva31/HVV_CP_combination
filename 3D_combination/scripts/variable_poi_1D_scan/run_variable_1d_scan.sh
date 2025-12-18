#!/usr/bin/env bash
# =============================================================================
# run_variable_1d_scan.sh - Variable POI 1D scan runner
# =============================================================================
# This script runs 1D likelihood scans with configurable number of floating POIs.
# Supports: 1POI (all others fixed), 2POI (one floats), or 3POI (both float) scans.
#
# Usage:
#   ./run_variable_1d_scan.sh --workspace linear_asimov --poi cHWtil_combine \
#                             --min -1 --max 1 --n 31 --float-pois "cHBtil_combine" \
#                             --mode parallel --backend condor
#
# Examples:
#   # 1POI scan: only cHWtil scanned, others fixed at 0
#   ./run_variable_1d_scan.sh --workspace linear_asimov --poi cHWtil_combine \
#                             --min -1 --max 1 --n 31 --float-pois "" --backend condor
#
#   # 2POI scan: cHWtil scanned, cHBtil floats, cHWBtil fixed at 0
#   ./run_variable_1d_scan.sh --workspace linear_asimov --poi cHWtil_combine \
#                             --min -1 --max 1 --n 31 --float-pois "cHBtil_combine" --backend condor
#
#   # 3POI scan: cHWtil scanned, both cHBtil and cHWBtil float
#   ./run_variable_1d_scan.sh --workspace linear_asimov --poi cHWtil_combine \
#                             --min -1 --max 1 --n 31 --float-pois "cHBtil_combine,cHWBtil_combine" --backend condor
#
#   # SPLIT SCAN: 0→max and 0→min as separate sequential jobs
#   ./run_variable_1d_scan.sh --workspace linear_asimov --poi cHWtil_combine \
#                             --min -1 --max 1 --n 31 --float-pois "" --backend condor --split-scan
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
SYSTEMATICS="stat_only"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/variable_1D_scans"
TAG=""
QUEUE="medium"
FLOAT_POIS=""  # Comma-separated list of POIs to float, empty = fix all
SPLIT_SCAN=false

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run 1D likelihood scans with variable number of floating POIs.

Required:
  --workspace <label>    Workspace label (linear_obs, linear_asimov, quad_obs, quad_asimov)
  --poi <name>          POI to scan (e.g., cHWtil_combine)
  --min <value>         Minimum scan value
  --max <value>         Maximum scan value

Optional:
  --float-pois <list>   Comma-separated POIs to float. Empty string = fix all at 0 (1POI scan).
                        Default: all other scan POIs float (3POI scan)
  --n <N>               Number of scan points (default: 31)
  --mode <mode>         parallel|sequential (default: parallel)
  --backend <backend>   local|condor (default: local)
  --systematics <sys>   full_syst|stat_only (default: stat_only)
  --output-dir <dir>    Output directory (default: output/variable_1D_scans)
  --tag <tag>           Tag for output naming
  --queue <queue>       Condor queue (default: medium)
  --config <file>       Config file (default: configs/hvv_cp_combination.yaml)
  --split-scan          Split scan into 0→max and 0→min (starts from SM value)
  -h, --help            Show this help message

Examples:
  # 1POI scan (all others fixed at 0)
  $(basename "$0") --workspace linear_asimov --poi cHWtil_combine \\
                   --min -1 --max 1 --n 31 --float-pois "" --backend condor

  # 2POI scan (cHBtil floats, cHWBtil fixed at 0)
  $(basename "$0") --workspace linear_asimov --poi cHWtil_combine \\
                   --min -1 --max 1 --n 31 --float-pois "cHBtil_combine" --backend condor

  # 3POI scan (both others float)
  $(basename "$0") --workspace linear_asimov --poi cHWtil_combine \\
                   --min -1 --max 1 --n 31 --float-pois "cHBtil_combine,cHWBtil_combine" --backend condor

  # SPLIT SCAN: starts from 0 and goes outward (0→max and 0→min)
  $(basename "$0") --workspace linear_asimov --poi cHWtil_combine \\
                   --min -1 --max 1 --n 31 --float-pois "" --backend condor --split-scan

EOF
    exit 0
}

# Parse arguments
FLOAT_POIS_SET=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace) WORKSPACE="$2"; shift 2;;
        --poi) POI="$2"; shift 2;;
        --min) MIN="$2"; shift 2;;
        --max) MAX="$2"; shift 2;;
        --n) NPOINTS="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        --backend) BACKEND="$2"; shift 2;;
        --systematics) SYSTEMATICS="$2"; shift 2;;
        --output-dir) OUTPUT_DIR="$2"; shift 2;;
        --tag) TAG="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --config) CONFIG="$2"; shift 2;;
        --float-pois) FLOAT_POIS="$2"; FLOAT_POIS_SET=true; shift 2;;
        --split-scan) SPLIT_SCAN=true; shift;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

# Validate required arguments
if [[ -z "$WORKSPACE" || -z "$POI" || -z "$MIN" || -z "$MAX" ]]; then
    echo "Error: --workspace, --poi, --min, and --max are required"
    usage
fi

# Convert OUTPUT_DIR to absolute path if relative
if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$(pwd)/$OUTPUT_DIR"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Determine scan type label based on floating POIs
if [[ -z "$FLOAT_POIS" ]]; then
    SCAN_TYPE="1POI"
    N_FLOAT=0
elif [[ "$FLOAT_POIS" == *","* ]]; then
    SCAN_TYPE="3POI"
    N_FLOAT=2
else
    SCAN_TYPE="2POI"
    N_FLOAT=1
fi

# Build tag if not provided
if [[ -z "$TAG" ]]; then
    TAG="${WORKSPACE}_${POI}_${SCAN_TYPE}_${MODE}"
fi

echo "=============================================="
echo "Variable POI 1D Likelihood Scan"
echo "=============================================="
echo "  Workspace:    $WORKSPACE"
echo "  Scanned POI:  $POI"
echo "  Range:        [$MIN, $MAX] with $NPOINTS points"
echo "  Scan Type:    $SCAN_TYPE ($N_FLOAT floating)"
echo "  Float POIs:   ${FLOAT_POIS:-none (all fixed)}"
echo "  Mode:         $MODE"
echo "  Backend:      $BACKEND"
echo "  Systematics:  $SYSTEMATICS"
echo "  Output:       $OUTPUT_DIR"
echo "  Tag:          $TAG"
echo "  Split Scan:   $SPLIT_SCAN"
echo "=============================================="
echo

# Build extra args
EXTRA_ARGS=""
if [[ "$SPLIT_SCAN" == "true" ]]; then
    EXTRA_ARGS="--split-scan"
fi

# Run the scan using the Python quickfit runner with float-pois option
cd "$SCRIPT_DIR/.."
python3 -m quickfit.variable_runner \
    --config "$CONFIG" \
    --workspace "$WORKSPACE" \
    --poi "$POI" \
    --min "$MIN" \
    --max "$MAX" \
    --n-points "$NPOINTS" \
    --float-pois "$FLOAT_POIS" \
    --mode "$MODE" \
    --backend "$BACKEND" \
    --systematics "$SYSTEMATICS" \
    --output-dir "$OUTPUT_DIR" \
    --tag "$TAG" \
    --queue "$QUEUE" \
    $EXTRA_ARGS

echo
echo "Done! Results in: $OUTPUT_DIR/root_${TAG}"

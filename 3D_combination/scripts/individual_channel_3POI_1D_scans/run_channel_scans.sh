#!/usr/bin/env bash
# =============================================================================
# run_channel_scans.sh - Individual channel 1D scan runner
# =============================================================================
# This script runs 1D scans over channel-specific Wilson coefficients
# (e.g., cHWtil_HZZ, cHWtil_HWW) while floating other channel coefficients
# and fixing the combine-level coefficients at 1.
#
# Usage:
#   ./run_channel_scans.sh --workspace linear_obs --channel HZZ \
#                          --poi cHWtil_HZZ --min -5 --max 5 --n 31 \
#                          --mode parallel --backend condor
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../configs/hvv_cp_combination.yaml"

WORKSPACE=""
CHANNEL=""
POI=""
MIN=-5
MAX=5
NPOINTS=31
MODE="parallel"
BACKEND="local"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/individual_channel_scans"
TAG=""
QUEUE="medium"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run individual channel 1D scans for Wilson coefficients.

Required:
  --workspace <label>   Workspace label
  --channel <name>      Channel name (HZZ, HWW, HTauTau, Hbb)
  --poi <name>         Channel POI to scan (e.g., cHWtil_HZZ)

Optional:
  --min <value>        Minimum scan value (default: -5)
  --max <value>        Maximum scan value (default: 5)
  --n <N>              Number of scan points (default: 31)
  --mode <mode>        parallel|sequential (default: parallel)
  --backend <backend>  local|condor (default: local)
  --output-dir <dir>   Output directory
  --tag <tag>          Tag for output naming
  --queue <queue>      Condor queue (default: medium)
  -h, --help           Show this help message

Notes:
  - Combine-level coefficients (cHWtil_combine, etc.) are fixed at 1
  - Other channel Wilson coefficients float freely
  - Useful for checking individual channel sensitivities

Examples:
  # Scan HZZ cHWtil locally
  $(basename "$0") --workspace linear_obs --channel HZZ \\
                   --poi cHWtil_HZZ --min -3 --max 3 --n 21 \\
                   --mode sequential --backend local

  # Submit HWW scan to Condor
  $(basename "$0") --workspace quad_obs --channel HWW \\
                   --poi cHWtil_HWW --min -5 --max 5 --n 31 \\
                   --mode parallel --backend condor

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace) WORKSPACE="$2"; shift 2;;
        --channel) CHANNEL="$2"; shift 2;;
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

if [[ -z "$WORKSPACE" || -z "$CHANNEL" || -z "$POI" ]]; then
    echo "Error: --workspace, --channel, and --poi are required"
    usage
fi

mkdir -p "$OUTPUT_DIR"

if [[ -z "$TAG" ]]; then
    TAG="${WORKSPACE}_${CHANNEL}_${POI}_${MODE}"
fi

echo "=============================================="
echo "Individual Channel 1D Scan"
echo "=============================================="
echo "  Workspace: $WORKSPACE"
echo "  Channel:   $CHANNEL"
echo "  POI:       $POI"
echo "  Range:     [$MIN, $MAX] with $NPOINTS points"
echo "  Mode:      $MODE"
echo "  Backend:   $BACKEND"
echo "  Output:    $OUTPUT_DIR"
echo "  Tag:       $TAG"
echo "=============================================="
echo "  Note: Combine-level coefficients fixed at 1"
echo "=============================================="
echo

# Use the Python runner with channel scan mode
cd "$SCRIPT_DIR/.."
python3 << EOF
import sys
sys.path.insert(0, '.')

from utils.config import AnalysisConfig
from quickfit.runner import QuickFitRunner

config = AnalysisConfig.from_yaml('$CONFIG')

# For channel scans, we need to modify the POI builder behavior
# The combine coefficients should be fixed at 1, channel coeffs should float

# Create a modified config for channel scans
config.fixed_pois = {
    'cHWtil_combine': 1.0,
    'cHBtil_combine': 1.0,
    'cHWBtil_combine': 1.0,
}
config.scan_pois = []  # No combine-level scans

runner = QuickFitRunner(config)
runner.run_1d_scan(
    workspace='$WORKSPACE',
    poi='$POI',
    min_val=float('$MIN'),
    max_val=float('$MAX'),
    n_points=int('$NPOINTS'),
    mode='$MODE',
    backend='$BACKEND',
    output_dir='$OUTPUT_DIR',
    tag='$TAG',
    queue='$QUEUE'
)
EOF

echo
echo "Done! Results in: $OUTPUT_DIR/root_${TAG}"

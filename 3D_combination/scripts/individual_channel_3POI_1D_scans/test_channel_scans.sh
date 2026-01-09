#!/usr/bin/env bash
# =============================================================================
# test_channel_scans.sh - Quick test of individual channel scan workflow
# =============================================================================
# This script runs a quick local test of the individual channel scan setup
# with a small number of points to verify everything works.
#
# Usage:
#   ./test_channel_scans.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/../.."

echo "=============================================="
echo "Individual Channel Scan - Quick Test"
echo "=============================================="
echo "This will run a quick local test with 5 points"
echo "to verify the channel scan setup."
echo "=============================================="
echo ""

# Test parameters
WORKSPACE="linear_obs"
NPOINTS=5
BACKEND="local"

# Test one POI from each channel
declare -A TEST_SCANS
TEST_SCANS["HZZ"]="cHWtil_HZZ"
TEST_SCANS["HWW"]="cHWtil_HWW"
TEST_SCANS["HTauTau"]="chwtilde_HTauTau"

echo "Test configuration:"
echo "  Workspace: $WORKSPACE"
echo "  Points:    $NPOINTS"
echo "  Backend:   $BACKEND"
echo ""

for channel in "${!TEST_SCANS[@]}"; do
    poi="${TEST_SCANS[$channel]}"
    
    echo ">>> Testing: $channel / $poi"
    
    "${SCRIPT_DIR}/run_channel_scans.sh" \
        --workspace "$WORKSPACE" \
        --channel "$channel" \
        --poi "$poi" \
        --min -2 \
        --max 2 \
        --n "$NPOINTS" \
        --mode sequential \
        --backend "$BACKEND" \
        --systematics stat_only
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Test passed for $channel"
    else
        echo "  ✗ Test failed for $channel"
        exit 1
    fi
    echo ""
done

echo "=============================================="
echo "All tests passed!"
echo "=============================================="
echo ""
echo "To run full production scans:"
echo "  cd ${SCRIPT_DIR}"
echo "  ./submit_channel_scans_hvv_cp.sh --all"
echo ""
echo "To plot results after scans complete:"
echo "  ./plot_all_channels.sh linear obs"
echo "=============================================="

#!/usr/bin/env bash
# =============================================================================
# submit_linear_statonly_wide_range.sh
# =============================================================================
# Submit 2D scans for linear-only workspaces with stat-only systematics
# and a wider floating POI range (-30 to 30) to investigate boundary issues.
#
# Usage:
#   ./submit_linear_statonly_wide_range.sh
# =============================================================================

# Disable set -e before sourcing ATLAS setup (it can cause issues)
set +e

# Setup ATLAS environment if ROOT is not available
if ! python3 -c "import ROOT" 2>/dev/null; then
    echo "Setting up ATLAS environment..."
    export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
    source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh 2>/dev/null
    asetup StatAnalysis,0.3.1 2>/dev/null
fi

# Re-enable strict mode
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/2D_scans_linear_statonly_wide_range"

MODE="parallel"
BACKEND="condor"
QUEUE="short"
SYSTEMATICS="stat_only"
FLOATING_MIN=-30
FLOATING_MAX=30

# POI ranges (same as standard analysis)
declare -A POI_MIN POI_MAX POI_NPOINTS
POI_MIN["cHWtil_combine"]=-1.0
POI_MAX["cHWtil_combine"]=1.0
POI_NPOINTS["cHWtil_combine"]=31

POI_MIN["cHBtil_combine"]=-1.5
POI_MAX["cHBtil_combine"]=1.5
POI_NPOINTS["cHBtil_combine"]=31

POI_MIN["cHWBtil_combine"]=-3.0
POI_MAX["cHWBtil_combine"]=3.0
POI_NPOINTS["cHWBtil_combine"]=31

# All POI pairs
PAIRS=(
    "cHWtil_combine:cHBtil_combine"
    "cHWtil_combine:cHWBtil_combine"
    "cHBtil_combine:cHWBtil_combine"
)

# Linear workspaces only (both obs and asimov)
WORKSPACES=(
    "linear_obs"
    "linear_asimov"
)

mkdir -p "$OUTPUT_DIR"

echo "=============================================="
echo "Linear Stat-Only 2D Scans with Wide Range"
echo "=============================================="
echo "  Mode:            $MODE"
echo "  Backend:         $BACKEND"
echo "  Queue:           $QUEUE"
echo "  Systematics:     $SYSTEMATICS"
echo "  Floating range:  [$FLOATING_MIN, $FLOATING_MAX]"
echo "  Workspaces:      ${WORKSPACES[*]}"
echo "  Pairs:           ${#PAIRS[@]}"
echo "  Output:          $OUTPUT_DIR"
echo "=============================================="
echo

for ws in "${WORKSPACES[@]}"; do
    for pair in "${PAIRS[@]}"; do
        IFS=':' read -r poi1 poi2 <<< "$pair"
        
        min1=${POI_MIN[$poi1]}
        max1=${POI_MAX[$poi1]}
        n1=${POI_NPOINTS[$poi1]}
        
        min2=${POI_MIN[$poi2]}
        max2=${POI_MAX[$poi2]}
        n2=${POI_NPOINTS[$poi2]}
        
        total=$((n1 * n2))
        tag="${ws}_${poi1}_${poi2}_${SYSTEMATICS}_wide_range_${MODE}"
        
        echo ">>> Submitting: $ws / $poi1 vs $poi2"
        echo "    Grid: ${n1}x${n2} = $total points"
        echo "    Floating POI range: [$FLOATING_MIN, $FLOATING_MAX]"
        
        "${SCRIPT_DIR}/run_2d_scans.sh" \
            --workspace "$ws" \
            --poi1 "$poi1" --min1 "$min1" --max1 "$max1" --n1 "$n1" \
            --poi2 "$poi2" --min2 "$min2" --max2 "$max2" --n2 "$n2" \
            --mode "$MODE" \
            --backend "$BACKEND" \
            --systematics "$SYSTEMATICS" \
            --floating-poi-range "$FLOATING_MIN" "$FLOATING_MAX" \
            --output-dir "$OUTPUT_DIR" \
            --tag "$tag" \
            --queue "$QUEUE"
        
        echo
    done
done

echo "=============================================="
echo "All submissions complete!"
echo "Monitor with: condor_q"
echo "Results in: $OUTPUT_DIR"
echo "=============================================="

#!/usr/bin/env bash
# =============================================================================
# submit_2d_scans_hvv_cp.sh - HVV CP analysis 2D scan submission script
# =============================================================================
# Submits 2D scans for all POI pairs in the HVV CP combination.
#
# Usage:
#   ./submit_2d_scans_hvv_cp.sh [options]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/2D_scans"

MODE="parallel"
BACKEND="condor"
QUEUE="short"
DRY_RUN=false

DO_LINEAR=true
DO_QUAD=true
DO_OBS=true
DO_ASIMOV=true
ONLY_PAIR=""

# POI ranges (analysis-specific)
declare -A POI_MIN POI_MAX POI_NPOINTS
POI_MIN["cHWtil_combine"]=-1.0
POI_MAX["cHWtil_combine"]=1.0
POI_NPOINTS["cHWtil_combine"]=21

POI_MIN["cHBtil_combine"]=-1.5
POI_MAX["cHBtil_combine"]=1.5
POI_NPOINTS["cHBtil_combine"]=21

POI_MIN["cHWBtil_combine"]=-3.0
POI_MAX["cHWBtil_combine"]=3.0
POI_NPOINTS["cHWBtil_combine"]=21

# All POI pairs
PAIRS=(
    "cHWtil_combine:cHBtil_combine"
    "cHWtil_combine:cHWBtil_combine"
    "cHBtil_combine:cHWBtil_combine"
)

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Submit 2D likelihood scans for HVV CP combination.

Options:
  --all             Submit all pairs for all workspaces (default)
  --linear          Submit only linear workspaces
  --quad            Submit only quadratic workspaces
  --obs             Submit only observed data
  --asimov          Submit only Asimov data
  --pair <p1:p2>    Submit only specified pair (e.g., cHWtil_combine:cHBtil_combine)
  --mode <mode>     parallel|sequential (default: parallel)
  --backend <b>     condor|local (default: condor)
  --queue <q>       Condor queue (default: short)
  --dry-run         Print commands without executing
  -h, --help        Show this help message

Examples:
  # Submit all 2D scans
  $(basename "$0") --all

  # Submit single pair for linear observed
  $(basename "$0") --linear --obs --pair cHWtil_combine:cHBtil_combine

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) DO_LINEAR=true; DO_QUAD=true; DO_OBS=true; DO_ASIMOV=true; shift;;
        --linear) DO_LINEAR=true; DO_QUAD=false; shift;;
        --quad) DO_LINEAR=false; DO_QUAD=true; shift;;
        --obs) DO_OBS=true; DO_ASIMOV=false; shift;;
        --asimov) DO_OBS=false; DO_ASIMOV=true; shift;;
        --pair) ONLY_PAIR="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        --backend) BACKEND="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --dry-run) DRY_RUN=true; shift;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

mkdir -p "$OUTPUT_DIR"

# Build workspace list
WORKSPACES=()
if $DO_LINEAR && $DO_OBS; then WORKSPACES+=("linear_obs"); fi
if $DO_LINEAR && $DO_ASIMOV; then WORKSPACES+=("linear_asimov"); fi
if $DO_QUAD && $DO_OBS; then WORKSPACES+=("quad_obs"); fi
if $DO_QUAD && $DO_ASIMOV; then WORKSPACES+=("quad_asimov"); fi

# Filter pairs
if [[ -n "$ONLY_PAIR" ]]; then
    PAIRS=("$ONLY_PAIR")
fi

echo "=============================================="
echo "HVV CP 2D Scan Submission"
echo "=============================================="
echo "  Mode:       $MODE"
echo "  Backend:    $BACKEND"
echo "  Queue:      $QUEUE"
echo "  Workspaces: ${WORKSPACES[*]}"
echo "  Pairs:      ${#PAIRS[@]}"
echo "  Dry run:    $DRY_RUN"
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
        tag="${ws}_${poi1}_${poi2}_${MODE}"
        
        echo ">>> Submitting: $ws / $poi1 vs $poi2"
        echo "    Grid: ${n1}x${n2} = $total points"
        
        cmd=(
            "${SCRIPT_DIR}/run_2d_scans.sh"
            --workspace "$ws"
            --poi1 "$poi1" --min1 "$min1" --max1 "$max1" --n1 "$n1"
            --poi2 "$poi2" --min2 "$min2" --max2 "$max2" --n2 "$n2"
            --mode "$MODE"
            --backend "$BACKEND"
            --output-dir "$OUTPUT_DIR"
            --tag "$tag"
            --queue "$QUEUE"
        )
        
        if $DRY_RUN; then
            echo "    [DRY RUN] ${cmd[*]}"
        else
            "${cmd[@]}"
        fi
        echo
    done
done

echo "=============================================="
echo "All submissions complete!"
echo "Monitor with: condor_q"
echo "Results in: $OUTPUT_DIR"
echo "=============================================="

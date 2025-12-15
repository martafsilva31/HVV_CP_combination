#!/usr/bin/env bash
# =============================================================================
# submit_1d_scans_hvv_cp.sh - HVV CP analysis 1D scan submission script
# =============================================================================
# This script submits 1D scans for the HVV CP combination analysis.
# It uses the analysis-specific configuration and provides convenient
# batch submission for all POIs and workspaces.
#
# Usage:
#   ./submit_1d_scans_hvv_cp.sh [options]
#
# Options:
#   --all           Submit all POIs for all workspaces
#   --linear        Submit only linear workspaces
#   --quad          Submit only quadratic workspaces
#   --obs           Submit only observed data
#   --asimov        Submit only Asimov data
#   --poi <name>    Submit only specified POI
#   --mode <mode>   parallel|sequential (default: parallel)
#   --dry-run       Print commands without executing
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/1D_scans"

# Defaults
MODE="parallel"
BACKEND="condor"
QUEUE="medium"
DRY_RUN=false

# Filters
DO_LINEAR=true
DO_QUAD=true
DO_OBS=true
DO_ASIMOV=true
ONLY_POI=""

# POIs and their ranges (analysis-specific)
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

POIS=("cHWtil_combine" "cHBtil_combine" "cHWBtil_combine")

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Submit 1D likelihood scans for HVV CP combination.

Options:
  --all             Submit all POIs for all workspaces (default)
  --linear          Submit only linear workspaces
  --quad            Submit only quadratic workspaces
  --obs             Submit only observed data
  --asimov          Submit only Asimov data
  --poi <name>      Submit only specified POI
  --mode <mode>     parallel|sequential (default: parallel)
  --backend <b>     condor|local (default: condor)
  --queue <q>       Condor queue (default: medium)
  --dry-run         Print commands without executing
  -h, --help        Show this help message

Examples:
  # Submit all scans
  $(basename "$0") --all

  # Submit only linear observed
  $(basename "$0") --linear --obs

  # Submit single POI, sequential mode
  $(basename "$0") --poi cHWtil_combine --mode sequential

  # Dry run to see commands
  $(basename "$0") --linear --dry-run

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) DO_LINEAR=true; DO_QUAD=true; DO_OBS=true; DO_ASIMOV=true; shift;;
        --linear) DO_LINEAR=true; DO_QUAD=false; shift;;
        --quad) DO_LINEAR=false; DO_QUAD=true; shift;;
        --obs) DO_OBS=true; DO_ASIMOV=false; shift;;
        --asimov) DO_OBS=false; DO_ASIMOV=true; shift;;
        --poi) ONLY_POI="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        --backend) BACKEND="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --dry-run) DRY_RUN=true; shift;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

mkdir -p "$OUTPUT_DIR"

# Build list of workspaces
WORKSPACES=()
if $DO_LINEAR && $DO_OBS; then WORKSPACES+=("linear_obs"); fi
if $DO_LINEAR && $DO_ASIMOV; then WORKSPACES+=("linear_asimov"); fi
if $DO_QUAD && $DO_OBS; then WORKSPACES+=("quad_obs"); fi
if $DO_QUAD && $DO_ASIMOV; then WORKSPACES+=("quad_asimov"); fi

# Filter POIs
if [[ -n "$ONLY_POI" ]]; then
    POIS=("$ONLY_POI")
fi

echo "=============================================="
echo "HVV CP 1D Scan Submission"
echo "=============================================="
echo "  Mode:       $MODE"
echo "  Backend:    $BACKEND"
echo "  Queue:      $QUEUE"
echo "  Workspaces: ${WORKSPACES[*]}"
echo "  POIs:       ${POIS[*]}"
echo "  Dry run:    $DRY_RUN"
echo "=============================================="
echo

# Submit scans
for ws in "${WORKSPACES[@]}"; do
    for poi in "${POIS[@]}"; do
        min=${POI_MIN[$poi]}
        max=${POI_MAX[$poi]}
        npts=${POI_NPOINTS[$poi]}
        tag="${ws}_${poi}_${MODE}"
        
        echo ">>> Submitting: $ws / $poi"
        echo "    Range: [$min, $max] with $npts points"
        
        cmd=(
            "${SCRIPT_DIR}/run_1d_scans.sh"
            --workspace "$ws"
            --poi "$poi"
            --min "$min"
            --max "$max"
            --n "$npts"
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

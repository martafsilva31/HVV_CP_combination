#!/usr/bin/env bash
# =============================================================================
# submit_fits_hvv_cp.sh - Submit all 3POI fits for HVV CP
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/3POI_fits"

BACKEND="condor"
QUEUE="medium"
DRY_RUN=false
DO_HESSE=true

DO_LINEAR=true
DO_QUAD=true
DO_OBS=true
DO_ASIMOV=true

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Submit 3POI fits for all HVV CP workspaces.

Options:
  --all             Submit all workspaces (default)
  --linear          Submit only linear workspaces
  --quad            Submit only quadratic workspaces
  --obs             Submit only observed data
  --asimov          Submit only Asimov data
  --backend <b>     condor|local (default: condor)
  --queue <q>       Condor queue (default: medium)
  --no-hesse        Skip Hesse error calculation
  --dry-run         Print commands without executing
  -h, --help        Show this help message

Examples:
  # Submit all fits
  $(basename "$0") --all

  # Submit only linear observed
  $(basename "$0") --linear --obs

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
        --backend) BACKEND="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --no-hesse) DO_HESSE=false; shift;;
        --dry-run) DRY_RUN=true; shift;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

mkdir -p "$OUTPUT_DIR"

WORKSPACES=()
if $DO_LINEAR && $DO_OBS; then WORKSPACES+=("linear_obs"); fi
if $DO_LINEAR && $DO_ASIMOV; then WORKSPACES+=("linear_asimov"); fi
if $DO_QUAD && $DO_OBS; then WORKSPACES+=("quad_obs"); fi
if $DO_QUAD && $DO_ASIMOV; then WORKSPACES+=("quad_asimov"); fi

echo "=============================================="
echo "HVV CP 3POI Fit Submission"
echo "=============================================="
echo "  Backend:    $BACKEND"
echo "  Queue:      $QUEUE"
echo "  Hesse:      $DO_HESSE"
echo "  Workspaces: ${WORKSPACES[*]}"
echo "  Dry run:    $DRY_RUN"
echo "=============================================="
echo

for ws in "${WORKSPACES[@]}"; do
    echo ">>> Submitting fit: $ws"
    
    cmd=(
        "${SCRIPT_DIR}/run_fit.sh"
        --workspace "$ws"
        --backend "$BACKEND"
        --output-dir "$OUTPUT_DIR"
        --queue "$QUEUE"
    )
    
    if $DO_HESSE; then
        cmd+=(--hesse)
    else
        cmd+=(--no-hesse)
    fi
    
    if $DRY_RUN; then
        echo "    [DRY RUN] ${cmd[*]}"
    else
        "${cmd[@]}"
    fi
    echo
done

echo "=============================================="
echo "All submissions complete!"
echo "Monitor with: condor_q"
echo "Results in: $OUTPUT_DIR"
echo "=============================================="

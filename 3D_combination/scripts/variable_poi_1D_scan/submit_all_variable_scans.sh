#!/usr/bin/env bash
# =============================================================================
# submit_all_variable_scans.sh - Submit 1POI, 2POI, and 3POI scans
# =============================================================================
# This script submits all variable POI 1D scan configurations for
# the HVV CP combination analysis.
#
# Configurations per POI:
#   - 1POI: only scanned POI varies, others fixed at 0
#   - 2POI (x2): one other POI floats, one fixed at 0 (both combinations)
#   - 3POI: both other POIs float (standard 3POI scan)
#
# Usage:
#   ./submit_all_variable_scans.sh [options]
#
# Examples:
#   # Submit all scans for linear asimov
#   ./submit_all_variable_scans.sh --linear --asimov --stat-only
#
#   # Submit all scans for quadratic asimov
#   ./submit_all_variable_scans.sh --quad --asimov --stat-only
#
#   # Dry run to see commands
#   ./submit_all_variable_scans.sh --linear --asimov --dry-run
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_BASE="${SCRIPT_DIR}/../../output/variable_1D_scans"

# Defaults
MODE="sequential"
BACKEND="condor"
QUEUE="medium"
DRY_RUN=false
SYSTEMATICS="stat_only"
SPLIT_SCAN=true  # Default to split scan for sequential mode

# Filters
DO_LINEAR=false
DO_QUAD=false
DO_OBS=false
DO_ASIMOV=false
ONLY_POI=""
ONLY_SCAN_TYPE=""  # 1POI, 2POI, or 3POI

# POIs and their ranges
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

Submit variable POI 1D scans (1POI, 2POI, 3POI) for HVV CP combination.
Uses SPLIT SCAN by default: 0→max and 0→min as separate sequential jobs
(ensures fits start from SM value and proceed outward).

Options:
  --linear          Include linear workspaces
  --quad            Include quadratic workspaces
  --obs             Include observed data (not recommended for variable POI studies)
  --asimov          Include Asimov data
  --poi <name>      Submit only specified POI (cHWtil_combine, cHBtil_combine, cHWBtil_combine)
  --scan-type <T>   Submit only specified scan type (1POI, 2POI, 3POI)
  --mode <mode>     parallel|sequential (default: sequential)
  --backend <b>     condor|local (default: condor)
  --queue <q>       Condor queue (default: medium)
  --stat-only       Use stat-only systematics (default)
  --full-syst       Use full systematics
  --split-scan      Split scan: 0→max and 0→min separately (default: enabled)
  --no-split        Disable split scan (run min→max in single job)
  --dry-run         Print commands without executing
  -h, --help        Show this help message

Examples:
  # Submit all scans for linear asimov stat-only (with split scan)
  $(basename "$0") --linear --asimov --stat-only

  # Submit both linear and quadratic asimov
  $(basename "$0") --linear --quad --asimov --stat-only

  # Submit only 1POI and 2POI scans
  $(basename "$0") --linear --asimov --scan-type 1POI
  $(basename "$0") --linear --asimov --scan-type 2POI

  # Submit single POI
  $(basename "$0") --linear --asimov --poi cHWtil_combine

  # Dry run
  $(basename "$0") --linear --asimov --dry-run

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --linear) DO_LINEAR=true; shift;;
        --quad) DO_QUAD=true; shift;;
        --obs) DO_OBS=true; shift;;
        --asimov) DO_ASIMOV=true; shift;;
        --poi) ONLY_POI="$2"; shift 2;;
        --scan-type) ONLY_SCAN_TYPE="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        --backend) BACKEND="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --stat-only) SYSTEMATICS="stat_only"; shift;;
        --full-syst) SYSTEMATICS="full_syst"; shift;;
        --split-scan) SPLIT_SCAN=true; shift;;
        --no-split) SPLIT_SCAN=false; shift;;
        --dry-run) DRY_RUN=true; shift;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

# Validate at least one model selected
if ! $DO_LINEAR && ! $DO_QUAD; then
    echo "Error: Must specify at least one of --linear or --quad"
    exit 1
fi

# Validate at least one data type selected  
if ! $DO_OBS && ! $DO_ASIMOV; then
    echo "Error: Must specify at least one of --obs or --asimov"
    exit 1
fi

# Build list of workspaces
WORKSPACES=()
if $DO_LINEAR && $DO_OBS; then WORKSPACES+=("linear_obs"); fi
if $DO_LINEAR && $DO_ASIMOV; then WORKSPACES+=("linear_asimov"); fi
if $DO_QUAD && $DO_OBS; then WORKSPACES+=("quad_obs"); fi
if $DO_QUAD && $DO_ASIMOV; then WORKSPACES+=("quad_asimov"); fi

# Filter POIs if specified
if [[ -n "$ONLY_POI" ]]; then
    POIS=("$ONLY_POI")
fi

echo "=============================================="
echo "Variable POI 1D Scan Submission"
echo "=============================================="
echo "  Mode:         $MODE"
echo "  Backend:      $BACKEND"
echo "  Queue:        $QUEUE"
echo "  Systematics:  $SYSTEMATICS"
echo "  Split Scan:   $SPLIT_SCAN (0→max and 0→min)"
echo "  Workspaces:   ${WORKSPACES[*]}"
echo "  POIs:         ${POIS[*]}"
echo "  Scan types:   ${ONLY_SCAN_TYPE:-all (1POI, 2POI, 3POI)}"
echo "  Dry run:      $DRY_RUN"
echo "=============================================="
echo

# Function to get the other two POIs given one
get_other_pois() {
    local poi="$1"
    local others=()
    for p in "${POIS[@]}"; do
        if [[ "$p" != "$poi" ]]; then
            others+=("$p")
        fi
    done
    echo "${others[@]}"
}

# Counter for submitted jobs
TOTAL_JOBS=0

# Submit scans
for ws in "${WORKSPACES[@]}"; do
    # Determine output directory based on workspace
    if [[ "$ws" == *"linear"* ]]; then
        MODEL_TYPE="linear_only"
    else
        MODEL_TYPE="linear_plus_quadratic"
    fi
    
    if [[ "$ws" == *"asimov"* ]]; then
        DATA_TYPE="asimov"
    else
        DATA_TYPE="obs"
    fi
    
    OUTPUT_DIR="${OUTPUT_BASE}/${MODEL_TYPE}/${SYSTEMATICS}/${DATA_TYPE}"
    mkdir -p "$OUTPUT_DIR"
    
    for poi in "${POIS[@]}"; do
        min=${POI_MIN[$poi]}
        max=${POI_MAX[$poi]}
        npts=${POI_NPOINTS[$poi]}
        
        # Get other POIs
        read -ra OTHER_POIS <<< "$(get_other_pois "$poi")"
        other1="${OTHER_POIS[0]}"
        other2="${OTHER_POIS[1]}"
        
        # Define scan configurations: (name, float_pois)
        declare -a CONFIGS
        CONFIGS=(
            "1POI:"                        # 1POI: no floats
            "2POI_${other1}:${other1}"     # 2POI: first other floats
            "2POI_${other2}:${other2}"     # 2POI: second other floats  
            "3POI:${other1},${other2}"     # 3POI: both float
        )
        
        for config in "${CONFIGS[@]}"; do
            config_name="${config%%:*}"
            float_pois="${config#*:}"
            
            # Extract scan type from config name
            scan_type="${config_name%%_*}"  # 1POI, 2POI, or 3POI
            
            # Skip if not matching filter
            if [[ -n "$ONLY_SCAN_TYPE" && "$scan_type" != "$ONLY_SCAN_TYPE" ]]; then
                continue
            fi
            
            # Build tag
            tag="${ws}_${poi}_${config_name}_${MODE}"
            
            echo ">>> Submitting: $ws / $poi / $config_name"
            echo "    Range: [$min, $max] with $npts points"
            echo "    Float POIs: ${float_pois:-none}"
            
            cmd=(
                "${SCRIPT_DIR}/run_variable_1d_scan.sh"
                --workspace "$ws"
                --poi "$poi"
                --min "$min"
                --max "$max"
                --n "$npts"
                --float-pois "$float_pois"
                --mode "$MODE"
                --backend "$BACKEND"
                --systematics "$SYSTEMATICS"
                --output-dir "$OUTPUT_DIR"
                --tag "$tag"
                --queue "$QUEUE"
            )
            
            # Add split scan flag only for linear workspaces (not quadratic)
            if $SPLIT_SCAN && [[ "$ws" == *"linear"* ]]; then
                cmd+=(--split-scan)
                echo "    Split scan: YES (0→max and 0→min)"
            else
                echo "    Split scan: NO (min→max)"
            fi
            
            if $DRY_RUN; then
                echo "    [DRY RUN] ${cmd[*]}"
            else
                "${cmd[@]}"
                TOTAL_JOBS=$((TOTAL_JOBS + 1))
            fi
            echo
        done
    done
done

echo "=============================================="
if $DRY_RUN; then
    echo "Dry run complete - no jobs submitted"
else
    echo "Submitted $TOTAL_JOBS scan configurations"
fi
echo "Monitor with: condor_q"
echo "Results in: $OUTPUT_BASE"
echo "=============================================="

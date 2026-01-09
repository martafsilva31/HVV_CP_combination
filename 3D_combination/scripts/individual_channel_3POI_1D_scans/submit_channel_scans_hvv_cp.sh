#!/usr/bin/env bash
# =============================================================================
# submit_channel_scans_hvv_cp.sh - Submit all channel scans for HVV CP
# =============================================================================
# Submits individual channel Wilson coefficient scans for all channels.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/individual_channel_scans"

MODE="parallel"
BACKEND="condor"
QUEUE="medium"
SYSTEMATICS="stat_only"  # Default to stat_only for channel scans
DRY_RUN=false
SPLIT_SCAN=false  # Split into 0→min and 0→max

DO_LINEAR=true
DO_QUAD=false  # Usually only run linear for channel scans
DO_OBS=true
DO_ASIMOV=false
ONLY_CHANNEL=""
ONLY_POI=""

# Channel Wilson coefficients to scan
declare -A CHANNEL_POIS
CHANNEL_POIS["HZZ"]="cHWtil_HZZ cHBtil_HZZ cHWBtil_HZZ"
CHANNEL_POIS["HWW"]="cHWtil_HWW cHBtil_HWW cHWBtil_HWW"
CHANNEL_POIS["HTauTau"]="chwtilde_HTauTau chbtilde_HTauTau chbwtilde_HTauTau"
CHANNEL_POIS["Hbb"]="cHWtil_Hbb"

# Default ranges (can be different per channel)
declare -A POI_MIN POI_MAX POI_NPOINTS
POI_MIN["default"]=-5.0
POI_MAX["default"]=5.0
POI_NPOINTS["default"]=31

CHANNELS=("HZZ" "HWW" "HTauTau" "Hbb")

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Submit individual channel Wilson coefficient scans for HVV CP combination.

Options:
  --all             Submit all channels and POIs (default)
  --linear          Submit only linear workspaces (default)
  --quad            Submit only quadratic workspaces
  --obs             Submit only observed data (default)
  --asimov          Submit only Asimov data
  --channel <name>  Submit only specified channel (HZZ, HWW, HTauTau, Hbb)
  --poi <name>      Submit only specified POI
  --mode <mode>     parallel|sequential (default: parallel)
  --backend <b>     condor|local (default: condor)
  --queue <q>       Condor queue (default: medium)
  --stat-only       Use stat-only systematics (default)
  --full-syst       Use full systematics
  --split-scan      Split scan: submit 0→min and 0→max separately
  --dry-run         Print commands without executing
  -h, --help        Show this help message

Available channels and POIs:
  HZZ:      cHWtil_HZZ, cHBtil_HZZ, cHWBtil_HZZ
  HWW:      cHWtil_HWW, cHBtil_HWW, cHWBtil_HWW
  HTauTau:  chwtilde_HTauTau, chbtilde_HTauTau, chbwtilde_HTauTau
  Hbb:      cHWtil_Hbb

Examples:
  # Submit all channel scans
  $(basename "$0") --all

  # Submit only HZZ channel
  $(basename "$0") --channel HZZ

  # Submit single POI
  $(basename "$0") --channel HWW --poi cHWtil_HWW

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) DO_LINEAR=true; DO_QUAD=false; DO_OBS=true; DO_ASIMOV=false; shift;;
        --linear) DO_LINEAR=true; DO_QUAD=false; shift;;
        --quad) DO_LINEAR=false; DO_QUAD=true; shift;;
        --obs) DO_OBS=true; DO_ASIMOV=false; shift;;
        --asimov) DO_OBS=false; DO_ASIMOV=true; shift;;
        --channel) ONLY_CHANNEL="$2"; shift 2;;
        --poi) ONLY_POI="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        --backend) BACKEND="$2"; shift 2;;
        --queue) QUEUE="$2"; shift 2;;
        --stat-only) SYSTEMATICS="stat_only"; shift;;
        --full-syst) SYSTEMATICS="full_syst"; shift;;
        --split-scan) SPLIT_SCAN=true; shift;;
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

# Filter channels
if [[ -n "$ONLY_CHANNEL" ]]; then
    CHANNELS=("$ONLY_CHANNEL")
fi

echo "=============================================="
echo "HVV CP Individual Channel Scan Submission"
echo "=============================================="
echo "  Mode:        $MODE"
echo "  Backend:     $BACKEND"
echo "  Queue:       $QUEUE"
echo "  Systematics: $SYSTEMATICS"
echo "  Split scan:  $SPLIT_SCAN"
echo "  Workspaces:  ${WORKSPACES[*]}"
echo "  Channels:    ${CHANNELS[*]}"
echo "  Dry run:     $DRY_RUN"
echo "=============================================="
echo

for ws in "${WORKSPACES[@]}"; do
    for channel in "${CHANNELS[@]}"; do
        pois_str="${CHANNEL_POIS[$channel]}"
        read -ra pois <<< "$pois_str"
        
        # Filter POIs if specified
        if [[ -n "$ONLY_POI" ]]; then
            pois=("$ONLY_POI")
        fi
        
        for poi in "${pois[@]}"; do
            min=${POI_MIN["default"]}
            max=${POI_MAX["default"]}
            npts=${POI_NPOINTS["default"]}
            
            if $SPLIT_SCAN; then
                # Split into 0→min and 0→max
                # Negative side: min → 0
                tag="${ws}_${channel}_${poi}_${MODE}_neg"
                echo ">>> Submitting: $ws / $channel / $poi (NEGATIVE)"
                echo "    Range: [$min, 0] with $((npts/2+1)) points"
                
                cmd=(
                    "${SCRIPT_DIR}/run_channel_scans.sh"
                    --workspace "$ws"
                    --channel "$channel"
                    --poi "$poi"
                    --min "$min"
                    --max 0
                    --n "$((npts/2+1))"
                    --mode "$MODE"
                    --backend "$BACKEND"
                    --systematics "$SYSTEMATICS"
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
                
                # Positive side: 0 → max
                tag="${ws}_${channel}_${poi}_${MODE}_pos"
                echo ">>> Submitting: $ws / $channel / $poi (POSITIVE)"
                echo "    Range: [0, $max] with $((npts/2+1)) points"
                
                cmd=(
                    "${SCRIPT_DIR}/run_channel_scans.sh"
                    --workspace "$ws"
                    --channel "$channel"
                    --poi "$poi"
                    --min 0
                    --max "$max"
                    --n "$((npts/2+1))"
                    --mode "$MODE"
                    --backend "$BACKEND"
                    --systematics "$SYSTEMATICS"
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
            else
                # Normal full range scan
                tag="${ws}_${channel}_${poi}_${MODE}"
                
                echo ">>> Submitting: $ws / $channel / $poi"
                echo "    Range: [$min, $max] with $npts points"
                
                cmd=(
                    "${SCRIPT_DIR}/run_channel_scans.sh"
                    --workspace "$ws"
                    --channel "$channel"
                    --poi "$poi"
                    --min "$min"
                    --max "$max"
                    --n "$npts"
                    --mode "$MODE"
                    --backend "$BACKEND"
                    --systematics "$SYSTEMATICS"
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
            fi
        done
    done
done

echo "=============================================="
echo "All submissions complete!"
echo "Monitor with: condor_q"
echo "Results in: $OUTPUT_DIR"
echo "=============================================="

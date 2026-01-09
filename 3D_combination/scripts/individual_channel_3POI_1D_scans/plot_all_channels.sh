#!/usr/bin/env bash
# =============================================================================
# plot_all_channels.sh - Plot all channels on same plot for each Wilson coeff
# =============================================================================
# This script creates combined plots showing all channel contributions for
# each Wilson coefficient type (cHWtil, cHBtil, cHWBtil).
#
# Usage:
#   ./plot_all_channels.sh [linear|quad] [obs|asimov]
#
# Prerequisites:
#   - Individual channel scans completed in output/individual_channel_scans/
#   - RooFitUtils environment sourced
#
# Output:
#   - output/plots/individual_channels/scan_cHWtil_all_channels.pdf
#   - output/plots/individual_channels/scan_cHBtil_all_channels.pdf
#   - output/plots/individual_channels/scan_cHWBtil_all_channels.pdf
# =============================================================================

# Setup ATLAS environment if not already set
if [ -z "${ATLAS_LOCAL_ROOT_BASE:-}" ]; then
    export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
    source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh 2>&1 | head -5
    lsetup "asetup StatAnalysis,0.3.1" 2>&1 | grep -v "^Configured" | head -5
    source /project/atlas/users/mfernand/software/RooFitUtils/build/setup.sh
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/../.."
INPUT_BASE="${BASE_DIR}/output/individual_channel_scans"
OUTPUT_DIR="${BASE_DIR}/output/plots/individual_channels"
PLOTSCAN="${PLOTSCAN:-/project/atlas/users/mfernand/software/RooFitUtils/scripts/plotscan.py}"

# Defaults
MODEL="linear"
DATA_TYPE="obs"

usage() {
    cat << EOF
Usage: $(basename "$0") [MODEL] [DATA_TYPE]

Plot all channels together for each Wilson coefficient type.

Arguments:
  MODEL       linear or quad (default: linear)
  DATA_TYPE   obs or asimov (default: obs)

Output:
  Creates combined plots in output/plots/individual_channels/:
    - scan_cHWtil_all_channels_{MODEL}_{DATA_TYPE}.pdf
    - scan_cHBtil_all_channels_{MODEL}_{DATA_TYPE}.pdf  
    - scan_cHWBtil_all_channels_{MODEL}_{DATA_TYPE}.pdf

Examples:
  # Linear observed (default)
  $(basename "$0") linear obs

  # Quadratic Asimov
  $(basename "$0") quad asimov

  # Use defaults
  $(basename "$0")

EOF
    exit 0
}

# Parse arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help) usage;;
        linear|quad) MODEL="$1"; shift;;
        *) echo "Unknown model: $1"; usage;;
    esac
fi

if [[ $# -gt 0 ]]; then
    case "$1" in
        obs|asimov) DATA_TYPE="$1"; shift;;
        *) echo "Unknown data type: $1"; usage;;
    esac
fi

# Check plotscan.py exists
if [[ ! -f "$PLOTSCAN" ]]; then
    echo "Error: plotscan.py not found at: $PLOTSCAN"
    echo "Make sure RooFitUtils is sourced or set PLOTSCAN environment variable"
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
TXT_DIR="${OUTPUT_DIR}/txt_${MODEL}_${DATA_TYPE}"
mkdir -p "${TXT_DIR}"

# Wilson coefficient types and their channel mappings
declare -A WILSON_CHANNELS
WILSON_CHANNELS["cHWtil"]="HZZ:cHWtil_HZZ HWW:cHWtil_HWW HTauTau:chwtilde_HTauTau Hbb:cHWtil_Hbb"
WILSON_CHANNELS["cHBtil"]="HZZ:cHBtil_HZZ HWW:cHBtil_HWW HTauTau:chbtilde_HTauTau"
WILSON_CHANNELS["cHWBtil"]="HZZ:cHWBtil_HZZ HWW:cHWBtil_HWW HTauTau:chbwtilde_HTauTau"

# Labels for plot
declare -A WILSON_LABELS
WILSON_LABELS["cHWtil"]='\$c_{H\tilde{W}}\$'
WILSON_LABELS["cHBtil"]='\$c_{H\tilde{B}}\$'
WILSON_LABELS["cHWBtil"]='\$c_{H\tilde{W}B}\$'

# Channel colors and styles
declare -A CHANNEL_COLORS
CHANNEL_COLORS["HZZ"]="blue"
CHANNEL_COLORS["HWW"]="red"
CHANNEL_COLORS["HTauTau"]="green"
CHANNEL_COLORS["Hbb"]="orange"

declare -A CHANNEL_STYLES
CHANNEL_STYLES["HZZ"]="solid"
CHANNEL_STYLES["HWW"]="dashed"
CHANNEL_STYLES["HTauTau"]="dotted"
CHANNEL_STYLES["Hbb"]="dashdot"

# Function to convert ROOT files to txt format
convert_root_to_txt() {
    local input_dir=$1
    local poi=$2
    local output_txt=$3
    
    python3 << PYTHON
import ROOT
import glob
import os

ROOT.gROOT.SetBatch(True)

input_dir = "${input_dir}"
poi = "${poi}"
output_txt = "${output_txt}"

pattern = os.path.join(input_dir, f'fit_{poi}_*.root')
files = sorted(glob.glob(pattern))

if not files:
    print(f"WARNING: No ROOT files found: {pattern}")
    exit(0)

data_points = []
for fpath in files:
    f = ROOT.TFile.Open(fpath)
    if not f or f.IsZombie():
        continue
    tree = f.Get('nllscan')
    if not tree:
        f.Close()
        continue
    tree.GetEntry(0)
    try:
        poi_val = getattr(tree, poi)
        nll = tree.nll
        status = getattr(tree, 'status', 0)
        data_points.append((poi_val, nll, int(status)))
    except:
        pass
    f.Close()

if not data_points:
    print(f"WARNING: No valid data points extracted from {input_dir}")
    exit(0)

data_points.sort(key=lambda x: x[0])

os.makedirs(os.path.dirname(output_txt) or '.', exist_ok=True)
with open(output_txt, 'w') as f:
    f.write(f"{poi}   nll   status\\n")
    for poi_val, nll, status in data_points:
        f.write(f"{poi_val:.6f}  {nll:.6f}  {status}\\n")

print(f"Created: {output_txt} ({len(data_points)} points)")
PYTHON
}

echo "=============================================="
echo "Plotting Individual Channel Scans"
echo "=============================================="
echo "  Model:      $MODEL"
echo "  Data type:  $DATA_TYPE"
echo "  Input:      $INPUT_BASE"
echo "  Output:     $OUTPUT_DIR"
echo "=============================================="
echo

# Loop over Wilson coefficient types
for wilson_type in cHWtil cHBtil cHWBtil; do
    echo ""
    echo ">>> Processing: $wilson_type"
    
    channels_str="${WILSON_CHANNELS[$wilson_type]}"
    label="${WILSON_LABELS[$wilson_type]}"
    
    # Build plotscan command
    plotscan_inputs=""
    n_channels=0
    
    for channel_mapping in $channels_str; do
        IFS=':' read -r channel poi <<< "$channel_mapping"
        
        # Find the scan directory
        scan_tag="${MODEL}_${DATA_TYPE}_${channel}_${poi}_parallel"
        root_dir="${INPUT_BASE}/root_${scan_tag}"
        
        if [[ ! -d "$root_dir" ]]; then
            echo "  WARNING: Directory not found: $root_dir"
            echo "           Skipping $channel"
            continue
        fi
        
        # Check if ROOT files exist
        nfiles=$(ls "$root_dir"/*.root 2>/dev/null | wc -l)
        if [[ $nfiles -eq 0 ]]; then
            echo "  WARNING: No ROOT files in $root_dir"
            echo "           Skipping $channel"
            continue
        fi
        
        # Convert to txt
        txt_file="${TXT_DIR}/${wilson_type}_${channel}.txt"
        echo "  Converting $channel ($poi)... ($nfiles files)"
        convert_root_to_txt "$root_dir" "$poi" "$txt_file"
        
        if [[ ! -f "$txt_file" ]]; then
            echo "  WARNING: Failed to create $txt_file"
            continue
        fi
        
        # Add to plotscan inputs
        color="${CHANNEL_COLORS[$channel]}"
        style="${CHANNEL_STYLES[$channel]}"
        plotscan_inputs+=" -i legend=${channel},color=${color},style=${style} ${txt_file}"
        n_channels=$((n_channels + 1))
    done
    
    if [[ $n_channels -eq 0 ]]; then
        echo "  ERROR: No channels found for $wilson_type"
        continue
    fi
    
    # Generate plot
    output_tex="${OUTPUT_DIR}/scan_${wilson_type}_all_channels_${MODEL}_${DATA_TYPE}.tex"
    echo "  Creating combined plot... ($n_channels channels)"
    
    python3 "$PLOTSCAN" \
        $plotscan_inputs \
        -o "$output_tex" \
        --ymax 10 \
        --labels "$label" "\$-2\\Delta \\ln L\$" \
        --drawpoints
    
    # Compile to PDF
    output_pdf="${OUTPUT_DIR}/scan_${wilson_type}_all_channels_${MODEL}_${DATA_TYPE}.pdf"
    echo "  Compiling to PDF..."
    cd "${OUTPUT_DIR}"
    pdflatex -interaction=nonstopmode "$(basename "$output_tex")" > /dev/null 2>&1 || true
    
    if [[ -f "$output_pdf" ]]; then
        echo "  ✓ Created: $output_pdf"
    else
        echo "  WARNING: PDF compilation failed, check .tex file"
        echo "          TeX: $output_tex"
    fi
done

echo ""
echo "=============================================="
echo "All plots complete!"
echo "Output: $OUTPUT_DIR"
echo "=============================================="
echo ""
echo "Generated plots:"
find "$OUTPUT_DIR" -name "scan_*_all_channels_${MODEL}_${DATA_TYPE}.pdf" 2>/dev/null | sort
echo ""

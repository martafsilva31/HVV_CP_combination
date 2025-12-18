#!/bin/bash
# Plot 1POI, 2POI, and 3POI 1D scan comparisons using plotscan.py
#
# Usage:
#   ./plot_1poi_2poi_3poi_plotscan.sh [linear|quad|all] [asimov|data]
#
# This script creates comparison plots showing NLL scans for each POI with:
# - 1POI: Only the scanned POI floats
# - 2POI: Scanned POI + one other POI floats (2 curves)  
# - 3POI: All three POIs float

# Don't use set -e as it causes issues with ATLAS setup

# Configuration
BASE_OUTPUT="/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/output"
VARIABLE_SCANS="${BASE_OUTPUT}/variable_1D_scans"
THREE_POI_SCANS="${BASE_OUTPUT}/3POI_1D_scans"
PLOTSCAN="/project/atlas/users/mfernand/software/RooFitUtils/scripts/plotscan.py"

POIS=("cHWtil_combine" "cHBtil_combine" "cHWBtil_combine")

# POI labels for plots
declare -A POI_LABELS
POI_LABELS["cHWtil_combine"]='\$c_{H\\tilde{W}}\$'
POI_LABELS["cHBtil_combine"]='\$c_{H\\tilde{B}}\$'
POI_LABELS["cHWBtil_combine"]='\$c_{H\\tilde{W}B}\$'

# Short names for legend (without $ for use in legend text)
declare -A POI_SHORT
POI_SHORT["cHWtil_combine"]='cHWtil'
POI_SHORT["cHBtil_combine"]='cHBtil'
POI_SHORT["cHWBtil_combine"]='cHWBtil'

# Function to convert ROOT files to txt format
convert_root_to_txt() {
    local input_dir=$1
    local scanned_poi=$2
    local output_txt=$3
    
    # Use Python to convert ROOT to txt
    python3 << PYTHON
import ROOT
import glob
import os

ROOT.gROOT.SetBatch(True)

input_dir = "${input_dir}"
scanned_poi = "${scanned_poi}"
output_txt = "${output_txt}"

pattern = os.path.join(input_dir, f'fit_{scanned_poi}_*.root')
files = sorted(glob.glob(pattern))

if not files:
    print(f"No ROOT files found: {pattern}")
    exit(1)

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
    poi_val = getattr(tree, scanned_poi)
    nll = tree.nll
    status = getattr(tree, 'status', 0)
    data_points.append((poi_val, nll, int(status)))
    f.Close()

data_points.sort(key=lambda x: x[0])

os.makedirs(os.path.dirname(output_txt) or '.', exist_ok=True)
with open(output_txt, 'w') as f:
    f.write(f"{scanned_poi}   nll   status\n")
    for poi_val, nll, status in data_points:
        f.write(f"{poi_val:.6f}  {nll:.6f}  {status}\n")

print(f"Created: {output_txt} ({len(data_points)} points)")
PYTHON
}

# Function to generate plots for a given model
generate_plots() {
    local model=$1      # linear or quad
    local data_type=$2  # asimov or data
    
    if [[ "$model" == "linear" ]]; then
        ws_prefix="linear"
        model_subdir="linear_only"
        model_label="Linear"
        scan_suffix="sequential"
    else
        ws_prefix="quad"
        model_subdir="linear_plus_quadratic"
        model_label="Linear + Quadratic"
        scan_suffix="parallel"  # 3POI quad uses parallel
    fi
    
    local var_base="${VARIABLE_SCANS}/${model_subdir}/stat_only/${data_type}"
    local three_poi_base="${THREE_POI_SCANS}/${model_subdir}/stat_only/${data_type}"
    local output_dir="${BASE_OUTPUT}/plots/combined_1poi_2poi_3poi_plotscan/${model}/stat_only/${data_type}"
    local txt_dir="${output_dir}/txt"
    
    mkdir -p "$output_dir"
    mkdir -p "$txt_dir"
    
    echo ""
    echo "============================================================"
    echo "Generating plots for ${model_label} model, ${data_type}"
    echo "============================================================"
    
    for scanned_poi in "${POIS[@]}"; do
        echo ""
        echo "Processing ${scanned_poi}..."
        
        # Get other POIs
        other_pois=()
        for p in "${POIS[@]}"; do
            if [[ "$p" != "$scanned_poi" ]]; then
                other_pois+=("$p")
            fi
        done
        
        # Build input arguments for plotscan
        input_args=""
        
        # Get short names for other POIs
        other1_short="${POI_SHORT[${other_pois[0]}]}"
        other2_short="${POI_SHORT[${other_pois[1]}]}"
        
        # 1POI scan - both other POIs fixed to 0
        dir_1poi="${var_base}/root_${ws_prefix}_asimov_${scanned_poi}_1POI_sequential"
        if [[ -d "$dir_1poi" ]]; then
            txt_1poi="${txt_dir}/${scanned_poi}_1POI.txt"
            convert_root_to_txt "$dir_1poi" "$scanned_poi" "$txt_1poi"
            # Legend: 1POI with both other POIs fixed to 0
            legend_1poi="1POI:${other1_short}+${other2_short}:fix"
            input_args+=" -i color=blue,legend=${legend_1poi},style=solid $txt_1poi"
        fi
        
        # 2POI scans
        for other_poi in "${other_pois[@]}"; do
            dir_2poi="${var_base}/root_${ws_prefix}_asimov_${scanned_poi}_2POI_${other_poi}_sequential"
            if [[ -d "$dir_2poi" ]]; then
                txt_2poi="${txt_dir}/${scanned_poi}_2POI_${other_poi}.txt"
                convert_root_to_txt "$dir_2poi" "$scanned_poi" "$txt_2poi"
                
                # Get the POI that's floating vs the one that's fixed
                floating_short="${POI_SHORT[$other_poi]}"
                
                # Find the fixed POI (the other one that's not being floated)
                if [[ "$other_poi" == "${other_pois[0]}" ]]; then
                    fixed_short="${POI_SHORT[${other_pois[1]}]}"
                    color="orange"
                else
                    fixed_short="${POI_SHORT[${other_pois[0]}]}"
                    color="red"
                fi
                
                # Legend: 2POI with floating and fixed POI specified
                legend_2poi="2POI:${floating_short}+float:${fixed_short}+fix"
                input_args+=" -i color=${color},legend=${legend_2poi},style=dashed $txt_2poi"
            fi
        done
        
        # 3POI scan
        if [[ "$model" == "linear" ]]; then
            dir_3poi="${three_poi_base}/root_${ws_prefix}_asimov_${scanned_poi}_sequential"
        else
            dir_3poi="${three_poi_base}/root_${ws_prefix}_asimov_${scanned_poi}_parallel"
        fi
        
        # Check for existing txt file first
        txt_3poi_existing="${three_poi_base}/txt_${ws_prefix}_asimov_${scanned_poi}_${scan_suffix}/${ws_prefix}_asimov_${scanned_poi}_${scan_suffix}_nllscan.txt"
        txt_3poi="${txt_dir}/${scanned_poi}_3POI.txt"
        
        if [[ -f "$txt_3poi_existing" ]]; then
            cp "$txt_3poi_existing" "$txt_3poi"
            echo "  Copied existing: $txt_3poi"
        elif [[ -d "$dir_3poi" ]]; then
            convert_root_to_txt "$dir_3poi" "$scanned_poi" "$txt_3poi"
        fi
        
        if [[ -f "$txt_3poi" ]]; then
            # Legend: 3POI with all floating
            legend_3poi="3POI:all+float"
            input_args+=" -i color=green,legend=${legend_3poi},style=densely_dashdotted $txt_3poi"
        fi
        
        # Skip if no data
        if [[ -z "$input_args" ]]; then
            echo "  No scan data found for ${scanned_poi}"
            continue
        fi
        
        # Generate plot
        poi_short="${scanned_poi/_combine/}"
        output_file="${output_dir}/${poi_short}_1poi_2poi_3poi_comparison.tex"
        poi_label="${POI_LABELS[$scanned_poi]}"
        
        echo "  Generating plot..."
        eval "python $PLOTSCAN $input_args -o $output_file --atlas Internal --labels \"$poi_label\" --ymax 10"
        
        # Compile to PDF
        echo "  Compiling PDF..."
        cd "$output_dir"
        pdflatex -interaction=batchmode "${poi_short}_1poi_2poi_3poi_comparison.tex" > /dev/null 2>&1 || true
        
        if [[ -f "${poi_short}_1poi_2poi_3poi_comparison.pdf" ]]; then
            echo "  Created: ${output_file%.tex}.pdf"
        fi
    done
}

# Main
MODEL=${1:-all}
DATA=${2:-asimov}

# Setup environment
echo "Setting up ATLAS environment..."
export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh --quiet
asetup StatAnalysis,0.3.1 --quiet
source /project/atlas/users/mfernand/software/RooFitUtils/build/setup.sh

if [[ "$MODEL" == "all" ]]; then
    generate_plots "linear" "$DATA"
    generate_plots "quad" "$DATA"
elif [[ "$MODEL" == "linear" ]] || [[ "$MODEL" == "quad" ]]; then
    generate_plots "$MODEL" "$DATA"
else
    echo "Usage: $0 [linear|quad|all] [asimov|data]"
    exit 1
fi

echo ""
echo "============================================================"
echo "All plots saved to: ${BASE_OUTPUT}/plots/combined_1poi_2poi_3poi_plotscan/"
echo "============================================================"

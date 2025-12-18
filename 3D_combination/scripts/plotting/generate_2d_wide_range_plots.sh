#!/usr/bin/env bash
# =============================================================================
# generate_wide_range_plots_v2.sh
# =============================================================================
# Generate all plots for linear stat-only wide-range 2D scans:
# 1. plotscan.py - Combined obs+exp contour plots (tex)
# 2. plot_2d_scan.py - Density plots (no contours, no legend)
# 3. plot_2d_profiled_poi.py - Profiled 3rd POI plots
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/../.."
INPUT_BASE="${BASE_DIR}/output/2D_scans_linear_statonly_wide_range"
OUTPUT_BASE="${BASE_DIR}/output/plots/2D_wide_range"

# RooFitUtils plotscan script
PLOTSCAN="/project/atlas/users/mfernand/software/RooFitUtils/scripts/plotscan.py"

# Create output directories
mkdir -p "${OUTPUT_BASE}/contours"
mkdir -p "${OUTPUT_BASE}/density"
mkdir -p "${OUTPUT_BASE}/profiled"
mkdir -p "${INPUT_BASE}/txt"

# POI combinations: POI1:POI2:FLOATING
declare -a POI_PAIRS=(
    "cHWtil_combine:cHBtil_combine:cHWBtil_combine"
    "cHWtil_combine:cHWBtil_combine:cHBtil_combine"
    "cHBtil_combine:cHWBtil_combine:cHWtil_combine"
)

echo "=============================================="
echo "Generating Wide Range 2D Plots (v2)"
echo "=============================================="
echo "Input:  ${INPUT_BASE}"
echo "Output: ${OUTPUT_BASE}"
echo "=============================================="

# Function to convert ROOT files to txt for plotscan
convert_root_to_txt() {
    local root_dir="$1"
    local poi1="$2"
    local poi2="$3"
    local output_txt="$4"
    
    python3 << EOF
import ROOT
import glob
import os
ROOT.gROOT.SetBatch(True)

root_dir = "${root_dir}"
poi1 = "${poi1}"
poi2 = "${poi2}"
output = "${output_txt}"

files = sorted(glob.glob(os.path.join(root_dir, 'fit_*.root')))
print(f'  Reading {len(files)} ROOT files...')

data = []
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
        v1 = getattr(tree, poi1)
        v2 = getattr(tree, poi2)
        nll = tree.nll
        status = 0  # assume converged
        data.append((v1, v2, nll, status))
    except:
        pass
    f.Close()

# Sort by poi1, then poi2
data.sort(key=lambda x: (x[0], x[1]))

# Write txt file in plotscan format
with open(output, 'w') as out:
    out.write(f'{poi1}   {poi2}   nll   status\n')
    for v1, v2, nll, status in data:
        out.write(f'{v1:f}  {v2:f}  {nll:.6f}  {status}\n')
print(f'  Wrote {len(data)} points to {output}')
EOF
}

# Track total plots
TOTAL_PLOTS=0

for pair in "${POI_PAIRS[@]}"; do
    IFS=':' read -r POI1 POI2 FLOATING <<< "$pair"
    
    # POI labels for plotscan
    case "$POI1" in
        cHWtil_combine) POI1_LABEL='$c_{H\tilde{W}}$' ;;
        cHBtil_combine) POI1_LABEL='$c_{H\tilde{B}}$' ;;
        cHWBtil_combine) POI1_LABEL='$c_{H\tilde{W}B}$' ;;
    esac
    case "$POI2" in
        cHWtil_combine) POI2_LABEL='$c_{H\tilde{W}}$' ;;
        cHBtil_combine) POI2_LABEL='$c_{H\tilde{B}}$' ;;
        cHWBtil_combine) POI2_LABEL='$c_{H\tilde{W}B}$' ;;
    esac
    
    echo ""
    echo ">>> Processing: ${POI1} vs ${POI2}"
    echo "    Floating: ${FLOATING}"
    
    # =================================================================
    # Step 1: Convert ROOT files to txt (both obs and asimov)
    # =================================================================
    for dtype in obs asimov; do
        ROOT_DIR="${INPUT_BASE}/root_linear_${dtype}_${POI1}_${POI2}_stat_only_wide_range_parallel"
        TXT_FILE="${INPUT_BASE}/txt/linear_${dtype}_${POI1}_${POI2}_nllscan.txt"
        
        if [[ ! -d "${ROOT_DIR}" ]]; then
            echo "Warning: Directory not found: ${ROOT_DIR}"
            continue
        fi
        
        if [[ ! -f "${TXT_FILE}" ]] || [[ $(wc -l < "${TXT_FILE}") -lt 100 ]]; then
            echo "    [Step 1] Converting ${dtype} ROOT to txt..."
            convert_root_to_txt "${ROOT_DIR}" "${POI1}" "${POI2}" "${TXT_FILE}"
        else
            echo "    [Step 1] Using existing ${dtype} txt file"
        fi
    done
    
    OBS_TXT="${INPUT_BASE}/txt/linear_obs_${POI1}_${POI2}_nllscan.txt"
    EXP_TXT="${INPUT_BASE}/txt/linear_asimov_${POI1}_${POI2}_nllscan.txt"
    
    # =================================================================
    # Step 2: Generate COMBINED contour plot (obs + exp) with plotscan.py
    # =================================================================
    echo "    [Step 2] Generating combined obs+exp contour plot..."
    CONTOUR_TEX="${OUTPUT_BASE}/contours/scan_2D_linear_wide_${POI1}_${POI2}.tex"
    
    python3 "${PLOTSCAN}" \
        -i "style=solid,color=black" "${OBS_TXT}" \
        -i "style=dashed,color=blue" "${EXP_TXT}" \
        --poi "${POI1},${POI2}" \
        --labels "${POI1_LABEL}" "${POI2_LABEL}" \
        --sigma-levels 1 2 \
        --show-sigma \
        --npoints 100 \
        -o "${CONTOUR_TEX}"
    
    TOTAL_PLOTS=$((TOTAL_PLOTS + 1))
    echo "    Created: ${CONTOUR_TEX}"
    
    # =================================================================
    # Step 3: Generate density plots (no contours, no legend) - obs and asimov
    # =================================================================
    for dtype in obs asimov; do
        TXT_FILE="${INPUT_BASE}/txt/linear_${dtype}_${POI1}_${POI2}_nllscan.txt"
        echo "    [Step 3] Generating ${dtype} density plot (clean)..."
        DENSITY_PDF="${OUTPUT_BASE}/density/density_linear_wide_${POI1}_${POI2}_${dtype}.pdf"
        
        python3 "${SCRIPT_DIR}/plot_2d_scan.py" \
            --input "${TXT_FILE}" \
            --poi1 "${POI1}" \
            --poi2 "${POI2}" \
            --output "${DENSITY_PDF}" \
            --z-max 10 \
            --no-contours \
            --no-legend \
            --no-bestfit \
            --no-atlas
        
        TOTAL_PLOTS=$((TOTAL_PLOTS + 1))
        echo "    Created: ${DENSITY_PDF}"
    done
    
    # =================================================================
    # Step 4: Generate profiled 3rd POI plots - obs and asimov
    # =================================================================
    for dtype in obs asimov; do
        ROOT_DIR="${INPUT_BASE}/root_linear_${dtype}_${POI1}_${POI2}_stat_only_wide_range_parallel"
        echo "    [Step 4] Generating ${dtype} profiled ${FLOATING} plot..."
        PROFILED_PDF="${OUTPUT_BASE}/profiled/profiled_${FLOATING}_${POI1}_vs_${POI2}_linear_wide_${dtype}.pdf"
        
        python3 "${SCRIPT_DIR}/plot_2d_profiled_poi.py" \
            --input "${ROOT_DIR}" \
            --poi1 "${POI1}" \
            --poi2 "${POI2}" \
            --floating "${FLOATING}" \
            --output "${PROFILED_PDF}" \
            --interpolation linear \
            --ncontours 50
        
        TOTAL_PLOTS=$((TOTAL_PLOTS + 1))
        echo "    Created: ${PROFILED_PDF}"
    done
    
done

echo ""
echo "=============================================="
echo "Generated ${TOTAL_PLOTS} plots"
echo "=============================================="
echo "Combined contours (tex): ${OUTPUT_BASE}/contours/ (3 plots)"
echo "Density plots (pdf):     ${OUTPUT_BASE}/density/ (6 plots)"
echo "Profiled plots (pdf):    ${OUTPUT_BASE}/profiled/ (6 plots)"
echo "=============================================="
echo ""
echo "To compile tex files to PDF, run pdflatex after fixing:"
echo "  cd ${OUTPUT_BASE}/contours"
echo "  for f in *.tex; do"
echo "    sed -i 's/\\\\begin{tikzpicture}\\[font={\\\\fontfamily{qhv}\\\\selectfont}\\]/% removed duplicate tikzpicture/g' \"\$f\""
echo "    sed -i 's/c\\\\_/c_/g' \"\$f\""
echo "    pdflatex -interaction=nonstopmode \"\$f\""
echo "  done"
echo "=============================================="

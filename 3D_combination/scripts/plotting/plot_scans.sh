#!/usr/bin/env bash
# =============================================================================
# plot_scans.sh - Plot likelihood scans using RooFitUtils
# =============================================================================
# Wrapper around RooFitUtils plotscan.py for HVV CP scan results.
# Requires RooFitUtils Global EFT branch to be sourced.
#
# Usage:
#   ./plot_scans.sh --type 1d --obs linear_obs_cHWtil.txt \
#                   --exp linear_asimov_cHWtil.txt --poi cHWtil
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/plots"

TYPE=""
OBS_FILE=""
EXP_FILE=""
POI=""
POI2=""
OUTPUT=""
LABEL=""
LABEL2=""
PERCENT_LEVEL="68"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Plot likelihood scans using RooFitUtils plotscan.py.

Required:
  --type <1d|2d>        Scan type
  --poi <name>          POI being scanned (for axis label)

Input (at least one required):
  --obs <file>          Observed data scan file
  --exp <file>          Expected (Asimov) scan file

Optional:
  --poi2 <name>         Second POI (for 2D scans)
  --output <file>       Output file (default: auto-generated)
  --output-dir <dir>    Output directory
  --label <text>        POI axis label (default: auto from POI name)
  --label2 <text>       Second POI axis label (for 2D)
  --cl <level>          Confidence level (default: 68)
  -h, --help            Show this help message

Notes:
  - Requires RooFitUtils to be sourced (plotscan.py must be in PATH)
  - Output format is .tex, compiled to .pdf if pdflatex available

Examples:
  # 1D scan comparison (obs vs exp)
  $(basename "$0") --type 1d --poi cHWtil_combine \\
                   --obs linear_obs_cHWtil_nllscan.txt \\
                   --exp linear_asimov_cHWtil_nllscan.txt

  # 2D scan
  $(basename "$0") --type 2d --poi cHWtil_combine --poi2 cHBtil_combine \\
                   --obs 2d_linear_obs_nllscan.txt

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type) TYPE="$2"; shift 2;;
        --obs) OBS_FILE="$2"; shift 2;;
        --exp) EXP_FILE="$2"; shift 2;;
        --poi) POI="$2"; shift 2;;
        --poi2) POI2="$2"; shift 2;;
        --output) OUTPUT="$2"; shift 2;;
        --output-dir) OUTPUT_DIR="$2"; shift 2;;
        --label) LABEL="$2"; shift 2;;
        --label2) LABEL2="$2"; shift 2;;
        --cl) PERCENT_LEVEL="$2"; shift 2;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

if [[ -z "$TYPE" || -z "$POI" ]]; then
    echo "Error: --type and --poi are required"
    usage
fi

if [[ -z "$OBS_FILE" && -z "$EXP_FILE" ]]; then
    echo "Error: At least one of --obs or --exp is required"
    usage
fi

# Check for plotscan.py
if ! command -v plotscan.py &> /dev/null; then
    echo "Error: plotscan.py not found in PATH"
    echo "Please source RooFitUtils environment first"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Generate default labels
declare -A POI_LABELS
POI_LABELS["cHWtil_combine"]='$c_{H\tilde{W}}$'
POI_LABELS["cHBtil_combine"]='$c_{H\tilde{B}}$'
POI_LABELS["cHWBtil_combine"]='$c_{H\tilde{W}B}$'
POI_LABELS["cHWtil"]='$c_{H\tilde{W}}$'
POI_LABELS["cHBtil"]='$c_{H\tilde{B}}$'
POI_LABELS["cHWBtil"]='$c_{H\tilde{W}B}$'

if [[ -z "$LABEL" ]]; then
    LABEL="${POI_LABELS[$POI]:-$POI}"
fi

if [[ -z "$LABEL2" && -n "$POI2" ]]; then
    LABEL2="${POI_LABELS[$POI2]:-$POI2}"
fi

# Generate output filename
if [[ -z "$OUTPUT" ]]; then
    if [[ "$TYPE" == "1d" ]]; then
        OUTPUT="${OUTPUT_DIR}/scan_${POI}.tex"
    else
        OUTPUT="${OUTPUT_DIR}/scan_${POI}_${POI2}.tex"
    fi
fi

echo "=============================================="
echo "Plotting Likelihood Scan"
echo "=============================================="
echo "  Type:   $TYPE"
echo "  POI:    $POI ($LABEL)"
if [[ -n "$POI2" ]]; then
    echo "  POI2:   $POI2 ($LABEL2)"
fi
echo "  Obs:    ${OBS_FILE:-none}"
echo "  Exp:    ${EXP_FILE:-none}"
echo "  Output: $OUTPUT"
echo "=============================================="
echo

# Build plotscan.py command
cmd=(plotscan.py)

if [[ -n "$OBS_FILE" ]]; then
    cmd+=(--input "color='black',legend=\"Obs\"" "$OBS_FILE")
fi

if [[ -n "$EXP_FILE" ]]; then
    cmd+=(--input "color='blue',legend=\"Exp\"" "$EXP_FILE")
fi

cmd+=(-o "$OUTPUT")
cmd+=(--label "$LABEL")

if [[ "$TYPE" == "2d" && -n "$LABEL2" ]]; then
    cmd+=("$LABEL2")
fi

cmd+=(--percent-level "$PERCENT_LEVEL")

echo "Running: ${cmd[*]}"
"${cmd[@]}"

# Try to compile PDF
PDF_OUTPUT="${OUTPUT%.tex}.pdf"
if command -v pdflatex &> /dev/null; then
    echo
    echo "Compiling PDF..."
    cd "$(dirname "$OUTPUT")"
    pdflatex -interaction=nonstopmode "$(basename "$OUTPUT")" > /dev/null 2>&1 || true
    
    if [[ -f "$PDF_OUTPUT" ]]; then
        echo "PDF created: $PDF_OUTPUT"
    fi
else
    echo "pdflatex not found, skipping PDF compilation"
fi

echo
echo "Done!"

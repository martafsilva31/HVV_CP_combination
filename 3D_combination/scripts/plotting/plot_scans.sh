#!/usr/bin/env bash
# =============================================================================
# plot_scans.sh - Wrapper for RooFitUtils plotscan.py
# =============================================================================
# This script provides a simplified interface for plotting likelihood scans
# using the RooFitUtils plotscan.py script.
#
# Usage:
#   ./plot_scans.sh --type 1d --poi cHWtil_combine \
#                   --obs obs.txt --exp asimov.txt --output scan.pdf
#
#   ./plot_scans.sh --type 2d --poi cHWtil,cHBtil \
#                   --obs obs.txt --output contour.pdf
#
# Requires: RooFitUtils (Global EFT branch) sourced in environment
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# RooFitUtils plotscan script location
PLOTSCAN="${PLOTSCAN:-/project/atlas/users/mfernand/software/RooFitUtils/scripts/plotscan.py}"

# Default values
TYPE=""
POI=""
OBS_FILE=""
EXP_FILE=""
OUTPUT=""
OUTPUT_DIR="${SCRIPT_DIR}/../../output/plots"
EXTRA_ARGS=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Wrapper for RooFitUtils plotscan.py to create scan plots.

Required:
  --type <1d|2d>        Scan type
  --poi <name(s)>       POI(s) to plot (comma-separated for 2D)

Input (at least one required):
  --obs <file>          Observed scan txt file
  --exp <file>          Expected (Asimov) scan txt file

Optional:
  --output <file>       Output file (default: auto-generated)
  --output-dir <dir>    Output directory (default: output/plots)
  --extra "<args>"      Extra arguments to pass to plotscan.py
  -h, --help            Show this help message

The txt files should be in plotscan format:
  1D: poi nll status
  2D: poi1 poi2 nll status

Examples:
  # 1D scan: observed vs expected
  $(basename "$0") --type 1d --poi cHWtil_combine \\
                   --obs linear_obs.txt --exp linear_asimov.txt \\
                   --output scan_cHWtil.pdf

  # 2D contour plot
  $(basename "$0") --type 2d --poi cHWtil_combine,cHBtil_combine \\
                   --obs linear_obs.txt --output contour_cHWtil_cHBtil.pdf

Environment Variables:
  PLOTSCAN  Path to plotscan.py (default: RooFitUtils location)

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type) TYPE="$2"; shift 2;;
        --poi) POI="$2"; shift 2;;
        --obs) OBS_FILE="$2"; shift 2;;
        --exp) EXP_FILE="$2"; shift 2;;
        --output) OUTPUT="$2"; shift 2;;
        --output-dir) OUTPUT_DIR="$2"; shift 2;;
        --extra) EXTRA_ARGS="$2"; shift 2;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

# Validate required arguments
if [[ -z "$TYPE" || -z "$POI" ]]; then
    echo "Error: --type and --poi are required"
    usage
fi

if [[ -z "$OBS_FILE" && -z "$EXP_FILE" ]]; then
    echo "Error: At least one of --obs or --exp is required"
    usage
fi

# Check plotscan.py exists
if [[ ! -f "$PLOTSCAN" ]]; then
    echo "Error: plotscan.py not found at: $PLOTSCAN"
    echo "Make sure RooFitUtils is sourced or set PLOTSCAN environment variable"
    exit 1
fi

# Convert paths to absolute
if [[ -n "$OBS_FILE" && "$OBS_FILE" != /* ]]; then
    OBS_FILE="$(pwd)/$OBS_FILE"
fi
if [[ -n "$EXP_FILE" && "$EXP_FILE" != /* ]]; then
    EXP_FILE="$(pwd)/$EXP_FILE"
fi
if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$(pwd)/$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"

# Generate default output filename if not provided
if [[ -z "$OUTPUT" ]]; then
    if [[ "$TYPE" == "1d" ]]; then
        OUTPUT="${OUTPUT_DIR}/scan_${POI}.tex"
    else
        POI_CLEAN="${POI//,/_}"
        OUTPUT="${OUTPUT_DIR}/contour_${POI_CLEAN}.tex"
    fi
else
    if [[ "$OUTPUT" != /* ]]; then
        OUTPUT="${OUTPUT_DIR}/$OUTPUT"
    fi
fi

# Build plotscan.py command
CMD="python3 $PLOTSCAN"

if [[ "$TYPE" == "1d" ]]; then
    # 1D scan
    CMD+=" -p $POI"
    
    if [[ -n "$OBS_FILE" ]]; then
        CMD+=" -i legend=Observed,style=solid,color=black $OBS_FILE"
    fi
    if [[ -n "$EXP_FILE" ]]; then
        CMD+=" -i legend=Expected,style=dashed,color=blue $EXP_FILE"
    fi
    
    CMD+=" -o $OUTPUT"
    CMD+=" --ymax 10 --xaxis \"$POI\" --yaxis \"-2#Delta ln L\""
    
elif [[ "$TYPE" == "2d" ]]; then
    # 2D scan - split POIs
    IFS=',' read -r POI1 POI2 <<< "$POI"
    CMD+=" -p $POI1 -p $POI2"
    
    if [[ -n "$OBS_FILE" ]]; then
        CMD+=" -i legend=Observed,style=solid,color=black $OBS_FILE"
    fi
    if [[ -n "$EXP_FILE" ]]; then
        CMD+=" -i legend=Expected,style=dashed,color=blue $EXP_FILE"
    fi
    
    CMD+=" -o $OUTPUT"
    CMD+=" --xaxis \"$POI1\" --yaxis \"$POI2\""
else
    echo "Error: Unknown scan type: $TYPE (use 1d or 2d)"
    exit 1
fi

# Add extra arguments
if [[ -n "$EXTRA_ARGS" ]]; then
    CMD+=" $EXTRA_ARGS"
fi

echo "Running: $CMD"
eval "$CMD"

echo ""
echo "Output: $OUTPUT"

# If output is .tex, try to compile to PDF
if [[ "$OUTPUT" == *.tex ]]; then
    PDF_OUTPUT="${OUTPUT%.tex}.pdf"
    echo "Compiling to PDF..."
    cd "$(dirname "$OUTPUT")"
    pdflatex -interaction=nonstopmode "$(basename "$OUTPUT")" > /dev/null 2>&1 || true
    if [[ -f "$PDF_OUTPUT" ]]; then
        echo "PDF: $PDF_OUTPUT"
    fi
fi

#!/usr/bin/env bash
# =============================================================================
# convert_scans.sh - Convert ROOT scan results to text format
# =============================================================================
# Converts quickFit scan output ROOT files to text format for plotting
# with RooFitUtils plotscan.py.
#
# Usage:
#   ./convert_scans.sh --type 1d --tag linear_obs_cHWtil_combine_parallel
#   ./convert_scans.sh --type 2d --tag linear_obs_cHWtil_cHBtil_parallel
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TYPE=""
TAG=""
INPUT_DIR=""
OUTPUT_FILE=""
POI=""
POI2=""
PATTERN="fit_*.root"

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Convert ROOT scan results to text format for plotting.

Required:
  --type <1d|2d>        Scan type
  --tag <tag>           Tag used for scan output (determines input directory)

Optional:
  --input-dir <dir>     Override input directory (default: derived from tag)
  --output <file>       Output text file (default: derived from tag)
  --poi <name>          POI name (default: derived from tag)
  --poi2 <name>         Second POI name (for 2D, default: derived from tag)
  --pattern <glob>      File pattern (default: fit_*.root)
  -h, --help            Show this help message

The output format is compatible with RooFitUtils plotscan.py:
  1D: poi deltaNLL
  2D: poi1 poi2 deltaNLL

Examples:
  # Convert 1D scan
  $(basename "$0") --type 1d --tag linear_obs_cHWtil_combine_parallel

  # Convert 2D scan with explicit POIs
  $(basename "$0") --type 2d --tag linear_obs_cHWtil_cHBtil --poi cHWtil_combine --poi2 cHBtil_combine

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type) TYPE="$2"; shift 2;;
        --tag) TAG="$2"; shift 2;;
        --input-dir) INPUT_DIR="$2"; shift 2;;
        --output) OUTPUT_FILE="$2"; shift 2;;
        --poi) POI="$2"; shift 2;;
        --poi2) POI2="$2"; shift 2;;
        --pattern) PATTERN="$2"; shift 2;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

if [[ -z "$TYPE" || -z "$TAG" ]]; then
    echo "Error: --type and --tag are required"
    usage
fi

# Try to determine paths from standard directory structure
if [[ -z "$INPUT_DIR" ]]; then
    # Look in common locations
    for base in "${SCRIPT_DIR}/../../output/1D_scans" \
                "${SCRIPT_DIR}/../../output/2D_scans" \
                "${SCRIPT_DIR}/../../output/individual_channel_scans" \
                "."; do
        if [[ -d "${base}/root_${TAG}" ]]; then
            INPUT_DIR="${base}/root_${TAG}"
            break
        fi
    done
fi

if [[ -z "$INPUT_DIR" || ! -d "$INPUT_DIR" ]]; then
    echo "Error: Could not find input directory for tag: $TAG"
    echo "Tried: */root_${TAG}"
    echo "Use --input-dir to specify explicitly"
    exit 1
fi

# Derive output file
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_DIR="$(dirname "$INPUT_DIR")"
    OUTPUT_FILE="${OUTPUT_DIR}/txt_${TAG}/${TAG}_nllscan.txt"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

# Try to extract POI name from tag if not provided
if [[ -z "$POI" ]]; then
    # Try common patterns: ..._cHWtil_combine_... or ..._cHWtil_HZZ_...
    for poi_candidate in cHWtil_combine cHBtil_combine cHWBtil_combine \
                         cHWtil_HZZ cHBtil_HZZ cHWBtil_HZZ \
                         cHWtil_HWW cHBtil_HWW cHWBtil_HWW \
                         chwtilde_HTauTau chbtilde_HTauTau chbwtilde_HTauTau \
                         cHWtil_Hbb; do
        if [[ "$TAG" == *"$poi_candidate"* ]]; then
            POI="$poi_candidate"
            break
        fi
    done
fi

if [[ -z "$POI" ]]; then
    echo "Error: Could not determine POI from tag. Use --poi to specify."
    exit 1
fi

echo "=============================================="
echo "Converting Scan Results"
echo "=============================================="
echo "  Type:      $TYPE"
echo "  Tag:       $TAG"
echo "  Input:     $INPUT_DIR"
echo "  Output:    $OUTPUT_FILE"
echo "  POI:       $POI"
if [[ "$TYPE" == "2d" ]]; then
    echo "  POI2:      $POI2"
fi
echo "=============================================="
echo

# Run conversion
cd "$SCRIPT_DIR/.."

if [[ "$TYPE" == "1d" ]]; then
    python3 -m utils.converters \
        --indir "$INPUT_DIR" \
        --out "$OUTPUT_FILE" \
        --poi "$POI" \
        --pattern "$PATTERN"
elif [[ "$TYPE" == "2d" ]]; then
    if [[ -z "$POI2" ]]; then
        echo "Error: --poi2 is required for 2D conversion"
        exit 1
    fi
    python3 -m utils.converters \
        --indir "$INPUT_DIR" \
        --out "$OUTPUT_FILE" \
        --poi "$POI" \
        --poi2 "$POI2" \
        --pattern "$PATTERN"
else
    echo "Error: Unknown type: $TYPE"
    exit 1
fi

echo
echo "Done! Output: $OUTPUT_FILE"

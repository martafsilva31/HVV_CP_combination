#!/usr/bin/env bash
# =============================================================================
# plot_2d_density.sh - Create 2D density/contour plots for likelihood scans
# =============================================================================
# Wrapper around plot_2d_scan.py for HVV CP 2D scan results.
#
# Usage:
#   ./plot_2d_density.sh --poi1 cHWtil_combine --poi2 cHBtil_combine \
#                        --obs obs_scan.txt --exp exp_scan.txt
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../../output/plots/2D"

POI1=""
POI2=""
OBS_FILE=""
EXP_FILE=""
OUTPUT=""
Z_MAX="10"
ATLAS_LABEL="Work in Progress"
NO_DENSITY=""
NO_LEGEND=""
NO_ATLAS=""
NO_CONTOURS=""
NO_BESTFIT=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Create 2D density/contour plots for likelihood scans.

Required:
  --poi1 <name>         First POI (x-axis)
  --poi2 <name>         Second POI (y-axis)

Input (at least one required):
  --obs <file>          Observed scan txt file
  --exp <file>          Expected (Asimov) scan txt file

Optional:
  --output <file>       Output file (default: auto-generated)
  --output-dir <dir>    Output directory
  --z-max <value>       Maximum deltaNLL for z-axis (default: 10)
  --atlas-label <text>  ATLAS label (default: Work in Progress)
  --no-density          Disable color density (contours only)
  --no-legend           Disable legend
  --no-atlas            Disable ATLAS label
  --no-contours         Disable contour lines
  --no-bestfit          Disable best-fit markers
  -h, --help            Show this help message

Examples:
  # Observed only (clean density, no overlays)
  $(basename "$0") --poi1 cHWtil_combine --poi2 cHBtil_combine --obs linear_obs.txt \\
                   --no-legend --no-atlas --no-contours --no-bestfit

  # Observed vs Expected overlay
  $(basename "$0") --poi1 cHWtil_combine --poi2 cHBtil_combine \\
                   --obs linear_obs.txt --exp linear_exp.txt

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --poi1) POI1="$2"; shift 2;;
        --poi2) POI2="$2"; shift 2;;
        --obs) OBS_FILE="$2"; shift 2;;
        --exp) EXP_FILE="$2"; shift 2;;
        --output) OUTPUT="$2"; shift 2;;
        --output-dir) OUTPUT_DIR="$2"; shift 2;;
        --z-max) Z_MAX="$2"; shift 2;;
        --atlas-label) ATLAS_LABEL="$2"; shift 2;;
        --no-density) NO_DENSITY="--no-density"; shift 1;;
        --no-legend) NO_LEGEND="--no-legend"; shift 1;;
        --no-atlas) NO_ATLAS="--no-atlas"; shift 1;;
        --no-contours) NO_CONTOURS="--no-contours"; shift 1;;
        --no-bestfit) NO_BESTFIT="--no-bestfit"; shift 1;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

if [[ -z "$POI1" || -z "$POI2" ]]; then
    echo "Error: --poi1 and --poi2 are required"
    usage
fi

if [[ -z "$OBS_FILE" && -z "$EXP_FILE" ]]; then
    echo "Error: At least one of --obs or --exp is required"
    usage
fi

# Convert to absolute paths
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

# Generate output filename
if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${OUTPUT_DIR}/density_${POI1}_${POI2}.pdf"
fi

# Build command
cmd=(python3 "${SCRIPT_DIR}/plot_2d_scan.py")
cmd+=(--poi1 "$POI1" --poi2 "$POI2")

LABELS=()
if [[ -n "$OBS_FILE" ]]; then
    cmd+=(--input "$OBS_FILE")
    LABELS+=("Obs")
fi
if [[ -n "$EXP_FILE" ]]; then
    cmd+=(--input "$EXP_FILE")
    LABELS+=("Exp")
fi

if [[ ${#LABELS[@]} -gt 0 ]]; then
    cmd+=(--labels "${LABELS[@]}")
fi

cmd+=(--output "$OUTPUT")
cmd+=(--z-max "$Z_MAX")
cmd+=(--atlas-label "$ATLAS_LABEL")

if [[ -n "$NO_DENSITY" ]]; then
    cmd+=($NO_DENSITY)
fi

if [[ -n "$NO_LEGEND" ]]; then
    cmd+=($NO_LEGEND)
fi

if [[ -n "$NO_ATLAS" ]]; then
    cmd+=($NO_ATLAS)
fi

if [[ -n "$NO_CONTOURS" ]]; then
    cmd+=($NO_CONTOURS)
fi

if [[ -n "$NO_BESTFIT" ]]; then
    cmd+=($NO_BESTFIT)
fi


echo "=============================================="
echo "2D Density Plot"
echo "=============================================="
echo "  POI1:    $POI1"
echo "  POI2:    $POI2"
echo "  Obs:     ${OBS_FILE:-none}"
echo "  Exp:     ${EXP_FILE:-none}"
echo "  Output:  $OUTPUT"
echo "=============================================="
echo

echo "Running: ${cmd[*]}"
"${cmd[@]}"

echo
echo "Done!"

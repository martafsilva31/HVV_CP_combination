#!/bin/bash
# =============================================================================
# rerun_linear_plots.sh - Regenerate 1POI/2POI/3POI comparison plots for linear model
# =============================================================================
# Run this script after the linear sequential scans have completed.
#
# Usage:
#   ./rerun_linear_plots.sh
#
# Prerequisites:
#   - Linear 1POI/2POI scans completed in output/variable_1D_scans/linear_only/stat_only/asimov/
#   - Linear 3POI scans completed in output/3POI_1D_scans/linear_only/stat_only/asimov/
#   - ATLAS environment setup
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/../.."

# Check if jobs are still running
echo "Checking for running Condor jobs..."
RUNNING_JOBS=$(condor_q -nobatch 2>/dev/null | grep -c "linear_asimov" || true)
if [[ "$RUNNING_JOBS" -gt 0 ]]; then
    echo "WARNING: There are still $RUNNING_JOBS linear scan jobs in the queue!"
    echo "Run 'condor_q' to check status. Continuing anyway..."
    echo
fi

# Check if output files exist
VAR_SCAN_DIR="${BASE_DIR}/output/variable_1D_scans/linear_only/stat_only/asimov"
echo "Checking for scan results in: $VAR_SCAN_DIR"

# Count ROOT files for 1POI/2POI scans
for poi in cHWtil_combine cHBtil_combine cHWBtil_combine; do
    for scan_type in 1POI 2POI; do
        # Find the root directory for this scan type
        root_dirs=$(ls -d "${VAR_SCAN_DIR}/root_linear_asimov_${poi}_${scan_type}"* 2>/dev/null || true)
        if [[ -z "$root_dirs" ]]; then
            echo "  WARNING: No ${scan_type} scan found for ${poi}"
        else
            for dir in $root_dirs; do
                n_files=$(ls "$dir"/*.root 2>/dev/null | wc -l || echo 0)
                echo "  $poi ${dir##*/}: $n_files ROOT files"
            done
        fi
    done
done
echo

# Setup ATLAS environment if not already done
if ! command -v quickFit &> /dev/null; then
    echo "Setting up ATLAS environment..."
    export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
    source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh
    asetup StatAnalysis,0.3.1
fi

# Source RooFitUtils
source /project/atlas/users/mfernand/software/RooFitUtils/build/setup.sh

# Remove old linear plots only
PLOT_DIR="${BASE_DIR}/output/plots/combined_1poi_2poi_3poi_plotscan"
if [[ -d "${PLOT_DIR}/linear" ]]; then
    echo "Removing old linear plots..."
    rm -rf "${PLOT_DIR}/linear"
fi

# Run the main plotting script for linear only
echo "Regenerating linear model plots..."
cd "$SCRIPT_DIR"
bash plot_1poi_2poi_3poi_plotscan.sh linear asimov

echo
echo "============================================================"
echo "Linear plots regenerated successfully!"
echo "Output: ${PLOT_DIR}/linear/stat_only/asimov/"
echo "============================================================"

# List generated plots
echo
echo "Generated PDFs:"
find "${PLOT_DIR}/linear" -name "*.pdf" 2>/dev/null | sort

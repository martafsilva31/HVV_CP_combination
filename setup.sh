#!/bin/bash
# =============================================================================
# HVV CP Combination - Environment Setup
# =============================================================================
# Usage:
#   source setup.sh           # Default: quickFit mode
#   source setup.sh quickfit  # quickFit for scans/fits
#   source setup.sh plotting  # RooFitUtils for plotting
#
# Note: quickFit and RooFitUtils cannot be sourced together (incompatible).
# =============================================================================

MODE="${1:-quickfit}"

# Common setup
setupATLAS
asetup StatAnalysis,0.3.1

# Unlimited stack (required for complex workspaces)
ulimit -s unlimited

case "$MODE" in
    quickfit|fit|scan)
        echo "Setting up quickFit environment..."
        source /project/atlas/users/mfernand/software/quickFit/setup_lxplus.sh 2>/dev/null || \
            echo "Warning: quickFit setup script not found"
        echo "Environment ready for scans and fits."
        ;;
    plotting|plot|roofitutils)
        echo "Setting up RooFitUtils environment..."
        source /project/atlas/users/mfernand/software/RooFitUtils/build/setup.sh 2>/dev/null || \
            echo "Warning: RooFitUtils setup script not found"
        echo "Environment ready for plotting."
        ;;
    *)
        echo "Unknown mode: $MODE"
        echo "Usage: source setup.sh [quickfit|plotting]"
        return 1 2>/dev/null || exit 1
        ;;
esac

echo ""
echo "HVV CP Combination environment loaded (mode: $MODE)"
echo "Working directory: $(pwd)"

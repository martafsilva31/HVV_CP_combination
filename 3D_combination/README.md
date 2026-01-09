# HVV CP 3D Combination

This directory contains the cleaned, reproducible workflow for the HVV CP 3POI 
combination with Wilson coefficients cHWtil, cHBtil, and cHWBtil.

## Directory Structure

```
3D_combination/
├── original_ws/           # Original channel workspaces (read-only input)
├── modified_ws/           # Edited/split workspaces for combination
├── combined_ws/           # Final combined workspaces
├── run_combination/       # Workspace combination pipeline (4-step)
├── scripts/               # Analysis scripts (see scripts/README.md)
│   ├── quickfit/          # Core Python modules
│   ├── utils/             # Configuration and utilities
│   ├── configs/           # YAML configurations
│   ├── 3POI_1D_scan/      # 1D likelihood scans
│   ├── 3POI_2D_scan/      # 2D likelihood scans
│   ├── 3POI_fit/          # 3POI simultaneous fits
│   ├── variable_poi_1D_scan/  # 1POI/2POI/3POI comparison scans
│   └── plotting/          # Plotting utilities
└── output/                # Results (scans, fits, plots)
```

## Quick Start

1. **Environment Setup**: Source ATLAS StatAnalysis and quickFit
   ```bash
   setupATLAS
   asetup StatAnalysis,0.3.1
   source /project/atlas/users/mfernand/software/quickFit/setup_lxplus.sh
   ```

2. **Run 1D Scans**:
   ```bash
   cd scripts
   ./3POI_1D_scan/run_1d_scans.sh --workspace linear_obs --poi cHWtil_combine \
       --min -1 --max 1 --n 31 --mode parallel --backend condor
   ```

3. **Run Fits**:
   ```bash
   ./3POI_fit/run_fit.sh --workspace linear_obs --backend condor --hesse
   ```

4. **Generate Plots** (requires RooFitUtils):
   ```bash
   source /project/atlas/users/mfernand/software/RooFitUtils/build/setup.sh
   ./plotting/plot_scans.sh --type 1d --poi cHWtil_combine \
       --obs output/txt_linear_obs.txt --exp output/txt_linear_asimov.txt
   ```

## Documentation

- **[REPRODUCE.md](REPRODUCE.md)**: Step-by-step analysis reproduction
- **[scripts/README.md](scripts/README.md)**: Detailed scripts documentation
- **[run_combination/README.md](run_combination/README.md)**: Workspace combination pipeline

## Key Features

- **Modular Python codebase** in `scripts/quickfit/` and `scripts/utils/`
- **YAML configuration** for analysis parameters (`scripts/configs/`)
- **Local and HTCondor backends** for all scan types
- **Variable POI scans** for 1POI/2POI/3POI comparisons
- **RooFitUtils integration** for publication-quality plots


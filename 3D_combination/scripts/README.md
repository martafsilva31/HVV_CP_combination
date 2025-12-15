# HVV CP 3POI Combination - Scripts Package

This directory contains a modular, reusable package for running quickFit-based
statistical analyses. It is designed with separation of concerns:

- **Generic modules** (`quickfit/`, `utils/`) - Reusable across different analyses
- **Analysis-specific configs** (`configs/`) - HVV CP specific settings
- **User-facing scripts** (`3POI_*/`, `plotting/`) - Convenient wrappers

## Directory Structure

```
scripts/
├── quickfit/                    # Core quickFit runner module
│   ├── __init__.py
│   └── runner.py               # QuickFitRunner class
│
├── utils/                       # Utility modules
│   ├── __init__.py
│   ├── config.py               # Configuration management
│   ├── poi_builder.py          # POI string construction
│   ├── fit_result_parser.py    # Result extraction from ROOT files
│   └── converters.py           # ROOT to text conversion
│
├── configs/                     # Analysis configurations
│   └── hvv_cp_combination.yaml # HVV CP specific settings
│
├── 3POI_1D_scan/               # 1D scan scripts
│   ├── run_1d_scans.sh         # Generic runner
│   └── submit_1d_scans_hvv_cp.sh  # HVV CP batch submission
│
├── 3POI_2D_scan/               # 2D scan scripts
│   ├── run_2d_scans.sh         # Generic runner
│   └── submit_2d_scans_hvv_cp.sh  # HVV CP batch submission
│
├── 3POI_fit/                   # 3POI fit scripts
│   ├── run_fit.sh              # Generic runner
│   └── submit_fits_hvv_cp.sh   # HVV CP batch submission
│
├── individual_channel_3POI_1D_scans/  # Channel-specific scans
│   ├── run_channel_scans.sh
│   └── submit_channel_scans_hvv_cp.sh
│
├── plotting/                   # Plotting utilities
│   ├── convert_scans.sh        # ROOT to text conversion
│   ├── plot_scans.sh           # Scan plotting (wraps RooFitUtils)
│   ├── plot_correlation_matrix.py
│   └── plot_fit_summary.py
│
└── common.sh                   # Legacy common functions
```

## Quick Start

### Environment Setup

```bash
# Source quickFit environment
source /project/atlas/users/mfernand/software/quickFit/setup_lxplus.sh

# For plotting, also source RooFitUtils
source /project/atlas/users/mfernand/software/RooFitUtils/setup.sh
```

### Running a 1D Scan

```bash
# Local sequential scan (for testing)
./3POI_1D_scan/run_1d_scans.sh \
    --workspace linear_obs \
    --poi cHWtil_combine \
    --min -1 --max 1 --n 21 \
    --mode sequential --backend local

# Condor parallel scan (for production)
./3POI_1D_scan/run_1d_scans.sh \
    --workspace linear_obs \
    --poi cHWtil_combine \
    --min -1 --max 1 --n 31 \
    --mode parallel --backend condor

# Submit all POIs for HVV CP
./3POI_1D_scan/submit_1d_scans_hvv_cp.sh --all
```

### Running a 2D Scan

```bash
# Condor parallel 2D scan
./3POI_2D_scan/run_2d_scans.sh \
    --workspace linear_obs \
    --poi1 cHWtil_combine --min1 -1 --max1 1 --n1 21 \
    --poi2 cHBtil_combine --min2 -1.5 --max2 1.5 --n2 21 \
    --mode parallel --backend condor

# Submit all POI pairs
./3POI_2D_scan/submit_2d_scans_hvv_cp.sh --all
```

### Running a 3POI Fit

```bash
# Local fit with Hesse errors
./3POI_fit/run_fit.sh --workspace linear_obs --backend local --hesse

# Condor fit
./3POI_fit/run_fit.sh --workspace quad_obs --backend condor

# Submit all workspaces
./3POI_fit/submit_fits_hvv_cp.sh --all
```

### Converting and Plotting Results

```bash
# Convert ROOT scan results to text
./plotting/convert_scans.sh --type 1d --tag linear_obs_cHWtil_combine_parallel

# Plot 1D scan (requires RooFitUtils)
./plotting/plot_scans.sh --type 1d --poi cHWtil_combine \
    --obs txt_linear_obs/nllscan.txt \
    --exp txt_linear_asimov/nllscan.txt

# Plot correlation matrix
python plotting/plot_correlation_matrix.py \
    --input fit_linear_obs.root \
    --pois cHWtil,cHBtil,cHWBtil \
    --output correlation_matrix.pdf

# Create summary plot
python plotting/plot_fit_summary.py \
    --linear-obs fit_linear_obs.root \
    --linear-exp fit_linear_asimov.root \
    --output summary.pdf
```

## Configuration

The analysis configuration is stored in `configs/hvv_cp_combination.yaml`.
Edit this file to modify:

- **Workspaces**: Input ROOT file paths
- **POIs**: Wilson coefficients and signal strength parameters
- **Scan ranges**: Default min/max/npoints per POI
- **Exclude NPs**: Nuisance parameters to exclude from fits

### Creating a New Analysis Configuration

```yaml
name: "My_Analysis"

scan_pois:
  - my_poi_1
  - my_poi_2

scan_ranges:
  my_poi_1:
    min: -3.0
    max: 3.0
    n_points: 31

workspaces:
  my_workspace:
    path: /path/to/workspace.root
    workspace_name: combWS
    data_name: combData

float_pois:
  - name: mu_signal
    default: 1.0
    min: -10.0
    max: 10.0
```

## Python API

You can also use the modules directly from Python:

```python
from utils.config import AnalysisConfig
from quickfit.runner import QuickFitRunner

# Load configuration
config = AnalysisConfig.from_yaml('configs/hvv_cp_combination.yaml')

# Create runner
runner = QuickFitRunner(config)

# Run 1D scan
runner.run_1d_scan(
    workspace='linear_obs',
    poi='cHWtil_combine',
    min_val=-1, max_val=1, n_points=21,
    mode='parallel', backend='condor'
)

# Run 2D scan
runner.run_2d_scan(
    workspace='linear_obs',
    poi1='cHWtil_combine', min1=-1, max1=1, n1=21,
    poi2='cHBtil_combine', min2=-1.5, max2=1.5, n2=21,
    mode='parallel', backend='condor'
)

# Run fit
runner.run_fit(workspace='linear_obs', hesse=True)
```

## Execution Modes

### Parallel Mode
- Each scan point is a separate job
- Fast for large grids (N jobs run simultaneously)
- No dependency between points
- Use for production scans

### Sequential Mode
- Points run one after another
- Previous fit seeds next point (better convergence)
- Single long-running job
- Use for difficult fits or debugging

## Backends

### Local
- Runs on current machine
- Good for testing with few points
- Forces sequential mode

### Condor
- Submits to HTCondor batch system
- Use for production runs
- Supports both parallel and sequential modes

## Output Structure

```
output/
├── 1D_scans/
│   ├── root_linear_obs_cHWtil_combine_parallel/  # ROOT files
│   ├── logs_linear_obs_cHWtil_combine_parallel/  # Log files
│   └── txt_linear_obs_cHWtil_combine_parallel/   # Converted text
│
├── 2D_scans/
│   ├── root_linear_obs_cHWtil_cHBtil_parallel/
│   ├── logs_*/
│   └── txt_*/
│
├── 3POI_fits/
│   ├── linear_obs_3POI_fit.root
│   └── logs_linear_obs_3POI_fit/
│
├── individual_channel_scans/
│   └── ...
│
└── plots/
    ├── scan_cHWtil.pdf
    ├── correlation_matrix.pdf
    └── summary.pdf
```

## Legacy Scripts

The old scripts are preserved in `archive/` for reference:
- `run_scans.sh` - Old unified runner for 1D/2D scans
- `scan_1D_condor.py`, `scan_2D_Condor.py` - Old condor submission

## Troubleshooting

### Fits not converging
- Use sequential mode to seed from previous results
- Check scan range (may need to adjust)
- Try fixing problematic nuisance parameters

### Condor jobs failing
- Check log files in `logs_*/` directory
- Verify quickFit setup in wrapper scripts
- Check memory/time limits

### Missing plotscan.py
- Source RooFitUtils environment
- Ensure Global EFT branch is checked out

## References

- [quickFit documentation](https://gitlab.cern.ch/atlas-physics/higgs/hbb/stat/quickFit)
- [RooFitUtils Global EFT branch](https://gitlab.cern.ch/atlas-physics/higgs/hcomb/RooFitUtils)
- [ATLAS HVV CP combination note](internal)

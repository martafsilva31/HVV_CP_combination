# Reproducing the HVV CP 3POI Combination

This document provides step-by-step instructions for reproducing the full 
HVV CP combination analysis with cHWtil, cHBtil, and cHWBtil Wilson coefficients.

## Prerequisites

- Linux environment with ATLAS analysis tools
- quickFit built and available in PATH
- RooFitUtils (Global EFT branch) for plotting
- HTCondor access for production runs
- Input workspaces from individual channels (HZZ, HWW, HTauTau, Hbb)

## Environment Setup

```bash
# Source ATLAS environment
setupATLAS
asetup StatAnalysis,0.3.1

# Source quickFit
source /project/atlas/users/mfernand/software/quickFit/setup_lxplus.sh

# Source RooFitUtils for plotting
source /project/atlas/users/mfernand/software/RooFitUtils/setup.sh

# Unlimited stack (required for complex workspaces)
ulimit -s unlimited
```

## Directory Structure

```
3D_combination/
├── original_ws/           # Original channel workspaces (read-only)
├── modified_ws/           # Edited/split workspaces
├── combined_ws/           # Combined workspaces (output)
│   ├── linear_obs.root
│   ├── linear_asimov.root
│   ├── quad_obs.root
│   └── quad_asimov.root
├── run_combination/       # Workspace combination scripts
├── scripts/               # Analysis scripts (scans, fits, plotting)
└── output/                # Results
```

## Step 1: Workspace Combination

If you need to regenerate combined workspaces from scratch, follow the 4-step
combination pipeline. **Otherwise, skip to Step 2 if combined workspaces already exist.**

See [run_combination/README.md](run_combination/README.md) for detailed documentation.

### Quick Combination Workflow

```bash
# Setup WorkspaceCombiner
cd /project/atlas/users/mfernand/software/workspaceCombiner
source setup_lxplus.sh

# Navigate to combination directory
cd /project/atlas/users/mfernand/HVV_CP_comb/3D_combination/run_combination

# Run 4-step pipeline
cd 1_ws_editing && bash 1.WSEditing.sh          # Split channel workspaces
cd ../2_POI_editing && bash 2.POIEditing.sh     # Edit POI definitions
cd ../3_ws_combine && bash 3.WSCombine.sh       # Combine channels
cd ../4_generate_asimov && bash 4.genAsimov.sh  # Generate Asimov datasets

# Verify outputs
ls -lh ../combined_ws/*.root
```

**Expected outputs**:
- `combined_ws/combined_linear_obs.root` - Linear EFT, observed
- `combined_ws/combine_linear_asimov.root` - Linear EFT, Asimov
- `combined_ws/combined_quad_obs.root` - Quadratic EFT, observed
- `combined_ws/combine_quad_asimov.root` - Quadratic EFT, Asimov

> **Note**: This step only needs to be done once, or when input channel workspaces change.
> The combined workspaces are already available in `combined_ws/` for analysis.

## Step 2: Analysis Setup

### 2.1 Verify Combined Workspaces

```bash
# Check workspace contents
python -c "
import ROOT
f = ROOT.TFile('combined_ws/combined_linear_obs.root')
ws = f.Get('combWS')
ws.Print()
mc = ws.obj('ModelConfig')
mc.GetParametersOfInterest().Print()
"
```

Expected POIs: `cHWtil_combine`, `cHBtil_combine`, `cHWBtil_combine`, plus channel-specific POIs.

## Step 3: Run 3POI Fits

### 3.1 Quick Test (Local)

```bash
cd scripts

# Single local fit for testing
./3POI_fit/run_fit.sh --workspace linear_obs --backend local --hesse
```

### 3.2 Production Fits (Condor)

```bash
# Submit all fits to Condor
./3POI_fit/submit_fits_hvv_cp.sh --all

# Or individual workspaces
./3POI_fit/run_fit.sh --workspace linear_obs --backend condor --hesse
./3POI_fit/run_fit.sh --workspace linear_asimov --backend condor --hesse
./3POI_fit/run_fit.sh --workspace quad_obs --backend condor --hesse
./3POI_fit/run_fit.sh --workspace quad_asimov --backend condor --hesse
```

### 3.3 Check Fit Results

```bash
# View best-fit values
python -c "
from utils.fit_result_parser import FitResultParser
parser = FitResultParser()
result = parser.extract_detailed('../output/3POI_fits/linear_obs_3POI_fit.root')
for poi, info in result['pois'].items():
    print(f'{poi}: {info[\"value\"]:.3f} +/- {info[\"error\"]:.3f}')
"
```

## Step 4: Run 1D Likelihood Scans

### 4.1 Quick Test (Local Sequential)

```bash
cd scripts

# Test single POI scan
./3POI_1D_scan/run_1d_scans.sh \
    --workspace linear_obs \
    --poi cHWtil_combine \
    --min -1 --max 1 --n 11 \
    --mode sequential --backend local
```

### 4.2 Production Scans (Condor Parallel)

```bash
# Submit all POI scans
./3POI_1D_scan/submit_1d_scans_hvv_cp.sh --all

# Or individual POIs with more points
./3POI_1D_scan/run_1d_scans.sh \
    --workspace linear_obs \
    --poi cHWtil_combine \
    --min -1 --max 1 --n 51 \
    --mode parallel --backend condor
```

### 4.3 Convert to Text Format

```bash
./plotting/convert_scans.sh --type 1d --tag linear_obs_cHWtil_combine_parallel
```

## Step 5: Run 2D Likelihood Scans

### 5.1 Production 2D Scans

```bash
# Submit all POI pairs
./3POI_2D_scan/submit_2d_scans_hvv_cp.sh --all

# Or specific pair
./3POI_2D_scan/run_2d_scans.sh \
    --workspace linear_obs \
    --poi1 cHWtil_combine --min1 -1 --max1 1 --n1 21 \
    --poi2 cHBtil_combine --min2 -1.5 --max2 1.5 --n2 21 \
    --mode parallel --backend condor
```

### 5.2 Convert 2D Scans

```bash
./plotting/convert_scans.sh --type 2d --tag linear_obs_cHWtil_cHBtil_parallel
```

## Step 6: Individual Channel Scans (Optional)

```bash
# Scan individual channel Wilson coefficients
./individual_channel_3POI_1D_scans/submit_channel_scans_hvv_cp.sh --all

# Or specific channel
./individual_channel_3POI_1D_scans/run_channel_scans.sh \
    --workspace linear_obs \
    --poi cHWtil_HZZ \
    --channel HZZ \
    --min -2 --max 2 --n 21 \
    --backend condor
```

## Step 6b: Variable POI 1D Scans (1POI/2POI Comparisons)

For comparing different numbers of floating POIs, use the variable POI scan scripts.
These produce scans where you control exactly which POIs float vs stay fixed at 0:

### Run 1POI scans (only scanned POI varies, others fixed at SM=0)

```bash
./variable_poi_1D_scan/run_variable_1d_scan.sh \
    --workspace linear_asimov --poi cHWtil_combine \
    --min -1 --max 1 --n 31 --float-pois "" \
    --backend condor --split-scan
```

### Run 2POI scans (scanned POI + one other floats)

```bash
# cHWtil scanned, cHBtil floats, cHWBtil fixed at 0
./variable_poi_1D_scan/run_variable_1d_scan.sh \
    --workspace linear_asimov --poi cHWtil_combine \
    --min -1 --max 1 --n 31 --float-pois "cHBtil_combine" \
    --backend condor --split-scan
```

### Submit all 1POI/2POI configurations

```bash
# Submit all for linear Asimov
./variable_poi_1D_scan/submit_all_variable_scans.sh --linear --asimov --stat-only

# Submit all for both models
./variable_poi_1D_scan/submit_all_variable_scans.sh --linear --quad --asimov --stat-only
```

### Generate 1POI/2POI/3POI comparison plots

```bash
./plotting/plot_1poi_2poi_3poi_plotscan.sh linear asimov
./plotting/plot_1poi_2poi_3poi_plotscan.sh quad asimov
```

## Step 7: Generate Plots

### 7.1 1D Scan Plots

```bash
# Plot observed vs expected
./plotting/plot_scans.sh --type 1d --poi cHWtil_combine \
    --obs ../output/1D_scans/txt_linear_obs_cHWtil_combine_parallel/nllscan.txt \
    --exp ../output/1D_scans/txt_linear_asimov_cHWtil_combine_parallel/nllscan.txt \
    --output ../output/plots/scan_cHWtil.pdf
```

### 7.2 2D Scan Contours

```bash
./plotting/plot_scans.sh --type 2d --poi cHWtil,cHBtil \
    --obs ../output/2D_scans/txt_linear_obs_cHWtil_cHBtil_parallel/nllscan.txt \
    --output ../output/plots/contour_cHWtil_cHBtil.pdf
```

### 7.3 Correlation Matrix

```bash
python plotting/plot_correlation_matrix.py \
    --input ../output/3POI_fits/linear_obs_3POI_fit.root \
    --pois cHWtil,cHBtil,cHWBtil \
    --output ../output/plots/correlation_matrix.pdf
```

### 7.4 Summary Plot

```bash
python plotting/plot_fit_summary.py \
    --linear-obs ../output/3POI_fits/linear_obs_3POI_fit.root \
    --linear-exp ../output/3POI_fits/linear_asimov_3POI_fit.root \
    --quad-obs ../output/3POI_fits/quad_obs_3POI_fit.root \
    --quad-exp ../output/3POI_fits/quad_asimov_3POI_fit.root \
    --output ../output/plots/summary.pdf
```

## Complete Production Run

For a full production run with all workspaces and POIs:

```bash
cd scripts

# 1. Submit all 3POI fits
./3POI_fit/submit_fits_hvv_cp.sh --all

# 2. Submit all 1D scans (wait for fits to complete first if using sequential)
./3POI_1D_scan/submit_1d_scans_hvv_cp.sh --all

# 3. Submit all 2D scans  
./3POI_2D_scan/submit_2d_scans_hvv_cp.sh --all

# 4. Monitor Condor jobs
condor_q | grep mfernand

# 5. After completion, convert all scans
for tag in linear_obs linear_asimov quad_obs quad_asimov; do
    for poi in cHWtil_combine cHBtil_combine cHWBtil_combine; do
        ./plotting/convert_scans.sh --type 1d --tag ${tag}_${poi}_parallel
    done
done

# 6. Generate all plots
./plotting/generate_all_plots.sh  # (create this wrapper if needed)
```

## Expected Runtime

| Task | Local (lxplus) | Condor (parallel) |
|------|----------------|-------------------|
| 3POI fit | ~30 min | ~30 min |
| 1D scan (51 pts) | ~8 hours | ~30 min |
| 2D scan (21×21) | ~40 hours | ~45 min |

## Output Files

After successful completion:

```
output/
├── 3POI_fits/
│   ├── linear_obs_3POI_fit.root
│   ├── linear_asimov_3POI_fit.root
│   ├── quad_obs_3POI_fit.root
│   └── quad_asimov_3POI_fit.root
├── 1D_scans/
│   ├── root_linear_obs_cHWtil_combine_parallel/
│   ├── txt_linear_obs_cHWtil_combine_parallel/nllscan.txt
│   └── ...
├── 2D_scans/
│   └── ...
└── plots/
    ├── scan_cHWtil.pdf
    ├── scan_cHBtil.pdf
    ├── scan_cHWBtil.pdf
    ├── contour_cHWtil_cHBtil.pdf
    ├── contour_cHWtil_cHWBtil.pdf
    ├── contour_cHBtil_cHWBtil.pdf
    ├── correlation_matrix.pdf
    └── summary.pdf
```

## Troubleshooting

### Jobs Stuck in Condor Queue
```bash
# Check job status
condor_q -better-analyze <job_id>

# Check logs
tail -f output/*/logs_*/*.log
```

### Fits Not Converging
- Try sequential mode with seeding
- Narrow scan range
- Check for problematic NPs in logs

### Missing ROOT Files After Conversion
- Verify all Condor jobs completed successfully
- Check for failed jobs: `condor_history -constraint 'ExitCode!=0'`

## Contact

For questions about this analysis, contact the HVV CP combination team.

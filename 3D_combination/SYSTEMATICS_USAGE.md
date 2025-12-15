# Using the --systematics Flag

The `--systematics` flag allows you to easily switch between statistical-only and full systematics modes when running scans, fits, and individual channel analyses.

## Overview

- **`--systematics full_syst`** (default): Uses full systematics, only fixing channel-specific spurious NPs
- **`--systematics stat_only`**: Statistical uncertainties only, fixes all experimental and theory systematics

## Configuration

The NP fixing patterns are defined in [scripts/configs/hvv_cp_combination.yaml](scripts/configs/hvv_cp_combination.yaml):

```yaml
systematics:
  stat_only:
    fix_nps:
      - ATLAS_JES*, ATLAS_EG*, ATLAS_LUMI*, ...  # All experimental NPs
      - gamma*, alpha*, theo*, ...                # Theory NPs
      - *_HZZ_spurious, HWW*, NF*, ...           # Other problematic NPs

  full_syst:
    fix_nps:
      - "*_HZZ_spurious"                          # Only channel-specific spurious NPs
```

## Usage Examples

### 1D Scans (cHWtil_combine)

#### Full Systematics (default)
```bash
./scripts/3POI_1D_scan/run_1d_scans.sh \
    --workspace linear_asimov \
    --poi cHWtil_combine \
    --min -1 --max 1 --n 31 \
    --mode sequential --backend local
```

#### Statistical Uncertainties Only
```bash
./scripts/3POI_1D_scan/run_1d_scans.sh \
    --workspace linear_asimov \
    --poi cHWtil_combine \
    --min -1 --max 1 --n 31 \
    --mode sequential --backend local \
    --systematics stat_only
```

### 2D Scans (cHWtil vs cHBtil)

#### Full Systematics
```bash
./scripts/3POI_2D_scan/run_2d_scans.sh \
    --workspace linear_obs \
    --poi1 cHWtil_combine --min1 -1 --max1 1 --n1 21 \
    --poi2 cHBtil_combine --min2 -1 --max2 1 --n2 21 \
    --mode parallel --backend condor
```

#### Statistical Uncertainties Only
```bash
./scripts/3POI_2D_scan/run_2d_scans.sh \
    --workspace linear_obs \
    --poi1 cHWtil_combine --min1 -1 --max1 1 --n1 21 \
    --poi2 cHBtil_combine --min2 -1 --max2 1 --n2 21 \
    --mode parallel --backend condor \
    --systematics stat_only
```

### Fits (3POI)

#### Full Systematics
```bash
./scripts/3POI_fit/run_fit.sh \
    --workspace linear_obs \
    --backend local --hesse
```

#### Statistical Uncertainties Only
```bash
./scripts/3POI_fit/run_fit.sh \
    --workspace linear_obs \
    --backend local --hesse \
    --systematics stat_only
```

### Individual Channel Scans

#### HZZ cHWtil - Full Systematics
```bash
./scripts/individual_channel_3POI_1D_scans/run_channel_scans.sh \
    --workspace linear_obs \
    --channel HZZ \
    --poi cHWtil_HZZ \
    --min -3 --max 3 --n 21 \
    --mode sequential --backend local
```

#### HZZ cHWtil - Statistical Only
```bash
./scripts/individual_channel_3POI_1D_scans/run_channel_scans.sh \
    --workspace linear_obs \
    --channel HZZ \
    --poi cHWtil_HZZ \
    --min -3 --max 3 --n 21 \
    --mode sequential --backend local \
    --systematics stat_only
```

## How It Works

1. **Shell Script** receives `--systematics <mode>` flag
2. **Python Runner** (`quickfit.runner`) passes it to the `AnalysisConfig`
3. **Config Module** calls `get_exclude_nps_pattern(systematics=<mode>)`
4. **NP Pattern** is merged with base exclusions and passed to `quickFit` via `-n` flag
5. **quickFit** excludes/fixes the specified nuisance parameters

### Code Flow Example

```bash
# User runs:
./run_1d_scans.sh --poi cHWtil --systematics stat_only

# Script calls:
python3 -m quickfit.runner --systematics stat_only ...

# Inside runner.py:
config = AnalysisConfig.from_yaml(...)
np_pattern = config.get_exclude_nps_pattern(systematics="stat_only")
# np_pattern = "ATLAS_JES*,ATLAS_EG*,ATLAS_LUMI*,..."

# Passed to quickFit:
quickfit ... -n "ATLAS_JES*,ATLAS_EG*,ATLAS_LUMI*,..." ...
```

## Comparison: stat_only vs full_syst

| Aspect | stat_only | full_syst |
|--------|-----------|-----------|
| **Experimental NPs** | ✗ Fixed | ✓ Floating |
| **Theory NPs** | ✗ Fixed | ✓ Floating |
| **Spurious NPs** | ✗ Fixed | ✗ Fixed |
| **Constraining** | Stronger | Weaker |
| **Expected Errors** | Smaller | Larger |
| **Uncertainties Included** | Statistical only | Statistical + Systematic |

## Adding New Systematics Patterns

To add a new NP pattern to stat_only mode, edit [scripts/configs/hvv_cp_combination.yaml](scripts/configs/hvv_cp_combination.yaml):

```yaml
systematics:
  stat_only:
    fix_nps:
      - "ATLAS_JES*"
      - "ATLAS_JET*"
      - "MY_NEW_NP_PATTERN*"  # Add here
```

## Python Usage

If using the runner directly in Python:

```python
from utils.config import AnalysisConfig
from quickfit.runner import QuickFitRunner

config = AnalysisConfig.from_yaml("scripts/configs/hvv_cp_combination.yaml")
runner = QuickFitRunner(config)

# Stat-only scan
runner.run_1d_scan(
    workspace="linear_asimov",
    poi="cHWtil_combine",
    min_val=-1, max_val=1, n_points=31,
    systematics="stat_only",  # <-- Control here
    mode="sequential",
    backend="local"
)

# Full systematics scan
runner.run_1d_scan(
    workspace="linear_asimov",
    poi="cHWtil_combine",
    min_val=-1, max_val=1, n_points=31,
    systematics="full_syst",   # <-- Or here
    mode="sequential",
    backend="local"
)
```

## Troubleshooting

### "Unknown option: --systematics"
This script doesn't support the `--systematics` flag. Check that you're using an updated version of the script that includes this feature.

### NP Pattern Not Being Applied
1. Check that the NP pattern is correctly spelled in the YAML config
2. Verify the pattern actually matches the NP names in your workspace (use `-n "NP_NAME"` to test individual patterns)
3. Check the quickFit output log to see which NPs were actually excluded

### Different Results Between Modes
This is expected! The differences come from:
- **stat_only**: Fixes systematic uncertainties, smaller expected errors
- **full_syst**: Lets systematics float, larger expected errors due to additional nuisance parameter constraints

## See Also

- [README.md](README.md) - General analysis overview
- [scripts/configs/hvv_cp_combination.yaml](scripts/configs/hvv_cp_combination.yaml) - Configuration file with NP patterns
- [REPRODUCE.md](REPRODUCE.md) - How to reproduce published results

# Individual Channel 3POI 1D Scans

This directory contains scripts for scanning channel-specific Wilson coefficients
to study the individual sensitivity of each Higgs decay channel.

## Overview

The individual channel scans differ from the main 3POI scans in that they scan
**channel-specific** Wilson coefficients (e.g., `cHWtil_HZZ`, `cHWtil_HWW`) while
fixing the **combine-level** coefficients (`cHWtil_combine`, etc.) at 1.

This allows you to:
- Study the sensitivity of each individual channel (H→ZZ, H→WW, H→ττ, H→bb)
- Compare channel contributions to the combined result
- Identify which channels drive constraints on each Wilson coefficient

## Available Channels and POIs

| Channel  | Wilson Coefficients |
|----------|---------------------|
| **HZZ**  | `cHWtil_HZZ`, `cHBtil_HZZ`, `cHWBtil_HZZ` |
| **HWW**  | `cHWtil_HWW`, `cHBtil_HWW`, `cHWBtil_HWW` |
| **HTauTau** | `chwtilde_HTauTau`, `chbtilde_HTauTau`, `chbwtilde_HTauTau` |
| **Hbb**  | `cHWtil_Hbb` |

## Quick Start

### 1. Run Production Scans (Condor, stat-only)

```bash
# Submit all channels and all Wilson coefficients
./submit_channel_scans_hvv_cp.sh --all

# Submit only specific channel
./submit_channel_scans_hvv_cp.sh --channel HZZ

# Submit only specific POI
./submit_channel_scans_hvv_cp.sh --channel HWW --poi cHWtil_HWW

# Use full systematics instead of stat-only
./submit_channel_scans_hvv_cp.sh --all --full-syst
```

### 2. Generate Combined Plots

After scans complete, create plots showing all channels together:

```bash
# Linear observed data (default)
./plot_all_channels.sh linear obs

# Quadratic Asimov data
./plot_all_channels.sh quad asimov
```

## Scripts

| Script | Description |
|--------|-------------|
| `run_channel_scans.sh` | Run a single channel scan (1D likelihood) |
| `submit_channel_scans_hvv_cp.sh` | Submit all channel scans to Condor |
| `plot_all_channels.sh` | Plot all channels together per Wilson coefficient |

## Workflow Details

### Scanning Behavior

When scanning a channel-specific coefficient (e.g., `cHWtil_HZZ`):
- **Scanned POI**: Fixed at each scan point (e.g., `cHWtil_HZZ = -3.0, -2.5, ...`)
- **Combine coefficients**: Fixed at 1 (`cHWtil_combine = 1`, `cHBtil_combine = 1`, `cHWBtil_combine = 1`)
- **Other channel coefficients**: Float freely (e.g., `cHWtil_HWW`, `cHWtil_HTauTau`, etc.)
- **Signal strengths**: Float freely (mu's, etc.)

This setup isolates the sensitivity of the scanned channel while allowing
correlations with other channels through floating parameters.

### Output Structure

```
output/individual_channel_scans/
├── root_linear_obs_HZZ_cHWtil_HZZ_parallel/
│   ├── fit_cHWtil_HZZ_-5.0000.root
│   ├── fit_cHWtil_HZZ_-4.6667.root
│   └── ...
├── logs_linear_obs_HZZ_cHWtil_HZZ_parallel/
│   └── ...
└── ...

output/plots/individual_channels/
├── scan_cHWtil_all_channels_linear_obs.pdf   # All channels' cHWtil scans
├── scan_cHBtil_all_channels_linear_obs.pdf   # All channels' cHBtil scans
└── scan_cHWBtil_all_channels_linear_obs.pdf  # All channels' cHWBtil scans
```

## Examples

### Example 1: Scan HZZ cHWtil Locally (Testing)

```bash
./run_channel_scans.sh \
    --workspace linear_obs \
    --channel HZZ \
    --poi cHWtil_HZZ \
    --min -5 --max 5 --n 11 \
    --mode sequential --backend local
```

### Example 2: Submit All HWW Scans to Condor

```bash
./submit_channel_scans_hvv_cp.sh --channel HWW
```

This submits:
- `cHWtil_HWW` scan
- `cHBtil_HWW` scan
- `cHWBtil_HWW` scan

### Example 3: Compare All Channels for cHWtil

```bash
# After scans complete
./plot_all_channels.sh linear obs
```

This creates a single plot with:
- Blue solid line: HZZ
- Red dashed line: HWW
- Green dotted line: HTauTau
- Orange dash-dot line: Hbb

## Monitoring

```bash
# Check Condor jobs
condor_q | grep channel

# Check output files
ls -lh ../../output/individual_channel_scans/root_*/

# Check for errors
tail ../../output/individual_channel_scans/logs_*/linear_obs*.err
```

## Troubleshooting

### No ROOT files in output directory
- Check Condor logs in `output/individual_channel_scans/logs_*/`
- Verify workspace file exists and POI names are correct
- Try running locally first with small number of points

### Plotting fails with "No data points"
- Ensure scans completed successfully
- Check that ROOT files exist and contain nllscan tree
- Verify POI names match between scan and plot script

### PDFLaTeX compilation fails
- LaTeX compilation errors are non-fatal
- `.tex` files are still created and can be compiled manually
- Check for missing LaTeX packages

## Notes

- Default scan range is [-5, 5] with 31 points
- Recommend using `parallel` mode on Condor for production
- Channel scans are typically run with observed data only
- Combine these results with main 3POI scans for full picture

## See Also

- [scripts/README.md](../README.md) - Main scripts documentation
- [REPRODUCE.md](../../REPRODUCE.md) - Full analysis workflow
- [configs/hvv_cp_combination.yaml](../configs/hvv_cp_combination.yaml) - Configuration file

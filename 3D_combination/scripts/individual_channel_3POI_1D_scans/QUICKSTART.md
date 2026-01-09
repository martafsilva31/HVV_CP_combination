# Individual Channel Scans - Quick Reference

## Quick Start Commands

```bash
# 1. Submit all channel scans to Condor (stat-only, default)
./submit_channel_scans_hvv_cp.sh --all

# 2. Monitor jobs
condor_q | grep channel

# 3. After scans complete, create combined plots
./plot_all_channels.sh linear obs
```

## Channel POI Mapping

| Wilson Coeff Type | HZZ | HWW | HTauTau | Hbb |
|-------------------|-----|-----|---------|-----|
| **cHWtil** | `cHWtil_HZZ` | `cHWtil_HWW` | `chwtilde_HTauTau` | `cHWtil_Hbb` |
| **cHBtil** | `cHBtil_HZZ` | `cHBtil_HWW` | `chbtilde_HTauTau` | N/A |
| **cHWBtil** | `cHWBtil_HZZ` | `cHWBtil_HWW` | `chbwtilde_HTauTau` | N/A |

## Output Plots

The `plot_all_channels.sh` script creates 3 combined plots:

1. **scan_cHWtil_all_channels_linear_obs.pdf**
   - Blue solid: HZZ (cHWtil_HZZ)
   - Red dashed: HWW (cHWtil_HWW)
   - Green dotted: HTauTau (chwtilde_HTauTau)
   - Orange dash-dot: Hbb (cHWtil_Hbb)

2. **scan_cHBtil_all_channels_linear_obs.pdf**
   - Blue solid: HZZ (cHBtil_HZZ)
   - Red dashed: HWW (cHBtil_HWW)
   - Green dotted: HTauTau (chbtilde_HTauTau)

3. **scan_cHWBtil_all_channels_linear_obs.pdf**
   - Blue solid: HZZ (cHWBtil_HZZ)
   - Red dashed: HWW (cHWBtil_HWW)
   - Green dotted: HTauTau (chbwtilde_HTauTau)

## Selective Submissions

```bash
# Submit only HZZ channel (all 3 Wilson coeffs)
./submit_channel_scans_hvv_cp.sh --channel HZZ

# Submit single POI
./submit_channel_scans_hvv_cp.sh --channel HWW --poi cHWtil_HWW

# Dry run to see commands
./submit_channel_scans_hvv_cp.sh --all --dry-run
```

## Monitoring

```bash
# Check Condor queue
condor_q | grep channel

# Check results
ls -lh ../../output/individual_channel_scans/root_*/

# Count completed scans
for dir in ../../output/individual_channel_scans/root_*/; do
    echo "$dir: $(ls $dir/*.root 2>/dev/null | wc -l) files"
done
```

## See Full Documentation

- [README.md](README.md) - Complete guide with troubleshooting
- [../README.md](../README.md) - Main scripts package documentation
- [../../REPRODUCE.md](../../REPRODUCE.md) - Full analysis workflow

# Quick Reference: --systematics Flag

## TL;DR

Add `--systematics stat_only` to any script to run with statistical uncertainties only:

```bash
./scripts/3POI_1D_scan/run_1d_scans.sh --workspace linear_asimov --poi cHWtil_combine --min -1 --max 1 --systematics stat_only --mode sequential --backend local
```

Default is `--systematics full_syst` (includes all systematics).

## Modes

| Mode | What's Fixed | What Floats | Use When |
|------|-------------|-----------|----------|
| `stat_only` | All experimental & theory NPs | Statistical only | Understand pure statistical power |
| `full_syst` | Only spurious NPs | All experimental & theory NPs | Getting physics results (default) |

## All Scripts

### 1D Scan
```bash
./scripts/3POI_1D_scan/run_1d_scans.sh \
    --workspace linear_asimov \
    --poi cHWtil_combine \
    --min -1 --max 1 \
    --systematics stat_only
```

### 2D Scan
```bash
./scripts/3POI_2D_scan/run_2d_scans.sh \
    --workspace linear_obs \
    --poi1 cHWtil --min1 -1 --max1 1 --n1 21 \
    --poi2 cHBtil --min2 -1.5 --max2 1.5 --n2 21 \
    --systematics stat_only
```

### Fit
```bash
./scripts/3POI_fit/run_fit.sh \
    --workspace linear_obs \
    --systematics stat_only
```

### Channel Scan
```bash
./scripts/individual_channel_3POI_1D_scans/run_channel_scans.sh \
    --workspace linear_obs \
    --channel HZZ \
    --poi cHWtil_HZZ \
    --min -3 --max 3 \
    --systematics stat_only
```

## Key Differences

| Aspect | stat_only | full_syst |
|--------|-----------|-----------|
| Error bars | Smaller | Larger |
| NPs floating | ~10-15 | ~40-50 |
| Fit time | Faster | Slower |
| Realism | Less realistic | More realistic |

## NP Patterns

**stat_only fixes**: 
- ATLAS_JES*, ATLAS_EG*, ATLAS_LUMI*, ATLAS_MUON*, ATLAS_PRW*, ATLAS_FTAG*, ATLAS_FT*, ATLAS_JER*, ATLAS_MET*, ATLAS_a*, ATLAS_pdf*, ATLAS_shower*, ATLAS_th*
- gamma*, alpha*, Gamma*, HWW*, NF*, Parton*, auto*, theo*
- *_HZZ_spurious

**full_syst fixes**: 
- *_HZZ_spurious

## Help

```bash
./scripts/3POI_1D_scan/run_1d_scans.sh --help
./scripts/3POI_2D_scan/run_2d_scans.sh --help
./scripts/3POI_fit/run_fit.sh --help
./scripts/individual_channel_3POI_1D_scans/run_channel_scans.sh --help
```

## For Developers

Edit NP patterns in: `scripts/configs/hvv_cp_combination.yaml`

```yaml
systematics:
  stat_only:
    fix_nps:
      - "ATLAS_JES*"
      - "MY_NEW_PATTERN*"
  full_syst:
    fix_nps:
      - "*_HZZ_spurious"
```

## FAQ

**Q: What's the default?**  
A: `--systematics full_syst` (most realistic)

**Q: Why are my error bars different?**  
A: You're probably comparing stat_only vs full_syst. stat_only has smaller errors.

**Q: How do I know which NPs are being fixed?**  
A: Check the quickFit output or see the patterns in hvv_cp_combination.yaml

**Q: Can I add a new NP pattern?**  
A: Yes, edit hvv_cp_combination.yaml under systematics > stat_only > fix_nps

## Examples

Compare modes:
```bash
# Stat only
./scripts/3POI_1D_scan/run_1d_scans.sh --workspace linear_asimov --poi cHWtil_combine --min -1 --max 1 --systematics stat_only --tag stat_only --mode sequential --backend local

# Full syst
./scripts/3POI_1D_scan/run_1d_scans.sh --workspace linear_asimov --poi cHWtil_combine --min -1 --max 1 --systematics full_syst --tag full_syst --mode sequential --backend local
```

Then compare output files:
- `output/1D_scans/root_linear_asimov_cHWtil_combine_stat_only/`
- `output/1D_scans/root_linear_asimov_cHWtil_combine_full_syst/`

## Resources

- **SYSTEMATICS_USAGE.md** - Detailed usage guide
- **IMPLEMENTATION_SUMMARY.md** - Technical details
- **scripts/configs/hvv_cp_combination.yaml** - Configuration file

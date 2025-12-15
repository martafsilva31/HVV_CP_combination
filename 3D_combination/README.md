HVV CP 3D Combination

This directory contains the cleaned, reproducible workflow for the HVV CP 3POI combination. It is organized to separate inputs, modified workspaces, final combined outputs, scripts, and plots.

Structure
- run_combination: pipeline drivers to generate Asimov datasets, run fits, scans, and produce plots.
- original_ws: canonical, unmodified input workspaces.
- modified_ws: edited/split/re-parameterized workspaces used by the combination.
- combined_ws: final combined workspaces and fit outputs (ROOT, JSON).
- HZZ_spurious_sys_study: spurious-signal tests for HZZ.
- scripts: standardized utilities and pipelines for 3POI fits and scans.
- plots: generated figures (PDF/PNG) and TeX sources.
- output: scan results, merged JSONs, logs, and small artifacts.

Getting Started
1. Source the environment via the top-level setup.sh.
2. See REPRODUCE.md for step-by-step commands.
3. Scans: use unified runners under scripts/3POI_1D_scan and scripts/3POI_2D_scan (`run_scans.sh`) with `--mode` (parallel|sequential) and `--backend` (local|condor).
4. Per-channel scans: see scripts/individual_channel_3POI_1D_scans.
5. Plotting: plotting relies on RooFitUtils (Global EFT branch). Ensure RooFitUtils is sourced; wrappers under scripts/*/plot_scans.sh call RooFitUtils plotting scripts (e.g., plotscan.py).

#!/usr/bin/env python3
"""
Plot 3POI 1D scan results showing the profiled values of floating Wilson coefficients.

This script creates a multi-panel plot showing:
1. Top panel: The deltaNLL scan vs the scanned POI
2. Middle panel: Profiled value of the first floating POI
3. Bottom panel: Profiled value of the second floating POI

Usage:
    python plot_3poi_profile.py --input <directory> --poi <scanned_poi> --output <plot_name>
"""

import argparse
import glob
import os
import sys
import numpy as np

# Use Agg backend for non-interactive plotting
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

def extract_poi_from_filename(filename, poi_name):
    """Extract POI value from filename like fit_cHWtil_combine_-0.4000.root"""
    import re
    basename = os.path.basename(filename)
    # Match pattern: fit_<poi_name>_<value>.root
    pattern = rf'fit_{re.escape(poi_name)}_([+-]?\d+\.?\d*).root'
    match = re.search(pattern, basename)
    if match:
        return float(match.group(1))
    return None

def read_scan_data(input_dir, scanned_poi, floating_pois):
    """
    Read scan data from ROOT files.
    
    Returns:
        dict with keys: 'scanned_poi', 'nll', 'deltaNLL', and each floating POI name
              plus their uncertainties (<name>_up, <name>_down)
    """
    try:
        import ROOT
        ROOT.gROOT.SetBatch(True)
    except ImportError:
        print("Error: ROOT is not available. Please set up the ATLAS environment.")
        sys.exit(1)
    
    # Find all ROOT files
    pattern = os.path.join(input_dir, f'fit_{scanned_poi}_*.root')
    files = sorted(glob.glob(pattern))
    
    if not files:
        print(f"Error: No ROOT files found matching {pattern}")
        sys.exit(1)
    
    print(f"Found {len(files)} scan points")
    
    # Initialize data arrays
    data = {
        'scanned_poi': [],
        'nll': [],
    }
    for fp in floating_pois:
        data[fp] = []
        data[f'{fp}_up'] = []
        data[f'{fp}_down'] = []
    
    # Read each file
    for fpath in files:
        f = ROOT.TFile.Open(fpath)
        if not f or f.IsZombie():
            print(f"Warning: Could not open {fpath}")
            continue
        
        tree = f.Get('nllscan')
        if not tree:
            print(f"Warning: No nllscan tree in {fpath}")
            f.Close()
            continue
        
        tree.GetEntry(0)
        
        # Get scanned POI value
        try:
            scanned_val = getattr(tree, scanned_poi)
            data['scanned_poi'].append(scanned_val)
            data['nll'].append(tree.nll)
            
            # Get floating POI values and uncertainties
            for fp in floating_pois:
                data[fp].append(getattr(tree, fp))
                data[f'{fp}_up'].append(getattr(tree, f'{fp}__up'))
                data[f'{fp}_down'].append(getattr(tree, f'{fp}__down'))
        except AttributeError as e:
            print(f"Warning: Missing attribute in {fpath}: {e}")
        
        f.Close()
    
    # Convert to numpy arrays
    for key in data:
        data[key] = np.array(data[key])
    
    # Sort by scanned POI value
    sort_idx = np.argsort(data['scanned_poi'])
    for key in data:
        data[key] = data[key][sort_idx]
    
    # Calculate deltaNLL (2 * (nll - nll_min))
    nll_min = np.min(data['nll'])
    data['deltaNLL'] = 2 * (data['nll'] - nll_min)
    
    return data

def find_best_fit(data):
    """Find the best fit point (minimum deltaNLL)"""
    min_idx = np.argmin(data['deltaNLL'])
    return min_idx

def plot_3poi_profile(data, scanned_poi, floating_pois, output_file, 
                      show_atlas=True, show_legend=True, show_errors=True,
                      poi_labels=None, title=None, data_type='Data'):
    """
    Create a 2-panel profile plot with NLL scan and profiled floating POIs.
    
    Args:
        data: dict with scan data
        scanned_poi: name of the scanned POI
        floating_pois: list of floating POI names
        output_file: output file path (PDF)
        show_atlas: show ATLAS label
        show_legend: show legend
        show_errors: show uncertainty bands on floating POIs
        poi_labels: dict mapping POI names to display labels
        title: plot title (not used, kept for API compatibility)
        data_type: 'Data' or 'Asimov'
    """
    # Default POI labels
    if poi_labels is None:
        poi_labels = {
            'cHWtil_combine': r'$\tilde{c}_{HW}$',
            'cHBtil_combine': r'$\tilde{c}_{HB}$',
            'cHWBtil_combine': r'$\tilde{c}_{H\tilde{W}B}$',
        }
    
    # Get display labels
    scanned_label = poi_labels.get(scanned_poi, scanned_poi)
    floating_labels = [poi_labels.get(fp, fp) for fp in floating_pois]
    
    # Create figure with GridSpec - 2 panels: NLL (top) and floating POIs (bottom ratio)
    fig = plt.figure(figsize=(8, 8), constrained_layout=False)
    gs = GridSpec(2, 1, height_ratios=[3, 1], hspace=0.05, top=0.95, bottom=0.10, left=0.12, right=0.95)
    
    ax_nll = fig.add_subplot(gs[0])
    ax_ratio = fig.add_subplot(gs[1], sharex=ax_nll)
    
    # Colors for floating POIs
    colors = ['#E24A33', '#348ABD', '#8EBA42', '#988ED5']
    
    # Find best fit point
    best_idx = find_best_fit(data)
    x_best = data['scanned_poi'][best_idx]
    
    # --- Top panel: deltaNLL (same style as plot_scans) ---
    ax_nll.plot(data['scanned_poi'], data['deltaNLL'], 'ko', markersize=4)
    ax_nll.axhline(1, color='#348ABD', linestyle='--', linewidth=1, label=r'68% CL')
    ax_nll.axhline(3.84, color='#E24A33', linestyle='--', linewidth=1, label=r'95% CL')
    
    ax_nll.set_ylabel(r'$-2\Delta\ln L$', fontsize=12)
    ax_nll.set_ylim(0, max(10, 1.2 * max(data['deltaNLL'])))
    ax_nll.tick_params(labelbottom=False)
    
    if show_legend:
        ax_nll.legend(loc='upper right', fontsize=10)
    
    if show_atlas:
        ax_nll.text(0.05, 0.95, 'ATLAS', fontsize=14, fontweight='bold', 
                   transform=ax_nll.transAxes, verticalalignment='top')
        ax_nll.text(0.18, 0.95, 'Internal', fontsize=12,
                   transform=ax_nll.transAxes, verticalalignment='top', style='italic')
    
    # --- Bottom panel: Both floating POIs in same ratio plot ---
    for i, (fp, label) in enumerate(zip(floating_pois, floating_labels)):
        color = colors[i % len(colors)]
        
        # Plot points
        ax_ratio.plot(data['scanned_poi'], data[fp], 'o', color=color, markersize=4, label=label)
        
        # Plot uncertainty band (optional)
        if show_errors:
            y_up = data[fp] + data[f'{fp}_up']
            y_down = data[fp] + data[f'{fp}_down']  # _down is already negative
            ax_ratio.fill_between(data['scanned_poi'], y_down, y_up, alpha=0.2, color=color)
    
    ax_ratio.set_ylabel('Profiled value', fontsize=11)
    ax_ratio.set_xlabel(scanned_label, fontsize=12)
    ax_ratio.axhline(0, color='gray', linestyle='-', alpha=0.5, linewidth=0.5)
    
    if show_legend:
        ax_ratio.legend(loc='best', fontsize=10)
    
    # Save figure
    fig.savefig(output_file, bbox_inches='tight', dpi=150)
    print(f"Saved plot to {output_file}")
    plt.close(fig)

def main():
    parser = argparse.ArgumentParser(description='Plot 3POI profile scan results')
    parser.add_argument('--input', '-i', required=True, help='Directory containing ROOT scan files')
    parser.add_argument('--poi', '-p', required=True, help='Name of the scanned POI')
    parser.add_argument('--floating', '-f', nargs='+', default=None,
                       help='Names of floating POIs to plot (default: auto-detect)')
    parser.add_argument('--output', '-o', required=True, help='Output file path (PDF)')
    parser.add_argument('--output-dir', default='.', help='Output directory (default: current)')
    parser.add_argument('--title', default=None, help='Plot title')
    parser.add_argument('--data-type', default='Data', choices=['Data', 'Asimov'],
                       help='Data type label (default: Data)')
    parser.add_argument('--no-atlas', action='store_true', help='Disable ATLAS label')
    parser.add_argument('--no-legend', action='store_true', help='Disable legend')
    parser.add_argument('--no-errors', action='store_true', help='Disable uncertainty bands')
    
    args = parser.parse_args()
    
    # Determine floating POIs
    if args.floating:
        floating_pois = args.floating
    else:
        # Auto-detect based on scanned POI
        all_pois = ['cHWtil_combine', 'cHBtil_combine', 'cHWBtil_combine']
        floating_pois = [p for p in all_pois if p != args.poi]
    
    print(f"Scanned POI: {args.poi}")
    print(f"Floating POIs: {', '.join(floating_pois)}")
    
    # Read scan data
    data = read_scan_data(args.input, args.poi, floating_pois)
    
    # Determine output path
    output_file = args.output
    if not os.path.dirname(output_file):
        output_file = os.path.join(args.output_dir, output_file)
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    # Create plot
    plot_3poi_profile(
        data, args.poi, floating_pois, output_file,
        show_atlas=not args.no_atlas,
        show_legend=not args.no_legend,
        show_errors=not args.no_errors,
        title=args.title,
        data_type=args.data_type
    )

if __name__ == '__main__':
    main()

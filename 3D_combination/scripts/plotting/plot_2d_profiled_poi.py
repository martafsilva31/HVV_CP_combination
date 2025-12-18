#!/usr/bin/env python3
"""
Plot 2D scan results showing the profiled value of the floating Wilson coefficient.

This script creates a 2D density/contour plot where:
- X-axis: First scanned POI
- Y-axis: Second scanned POI  
- Z-axis (color): Profiled value of the third (floating) POI

Usage:
    python plot_2d_profiled_poi.py --input <directory> --poi1 <poi1> --poi2 <poi2> --output <plot_name>
"""

import argparse
import glob
import os
import sys
import re
import numpy as np

# Use Agg backend for non-interactive plotting
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import colors
from scipy.interpolate import griddata

def extract_poi_values_from_filename(filename, poi1_name, poi2_name):
    """Extract POI values from filename like fit_cHWtil_combine_-0.0345__cHBtil_combine_-0.0517.root"""
    basename = os.path.basename(filename)
    # Match pattern: fit_<poi1>_<value1>__<poi2>_<value2>.root
    pattern = rf'fit_{re.escape(poi1_name)}_([+-]?\d+\.?\d*)__{re.escape(poi2_name)}_([+-]?\d+\.?\d*)\.root'
    match = re.search(pattern, basename)
    if match:
        return float(match.group(1)), float(match.group(2))
    return None, None

def read_2d_scan_data(input_dir, poi1, poi2, floating_poi):
    """
    Read 2D scan data from ROOT files.
    
    Returns:
        dict with keys: 'poi1', 'poi2', 'nll', 'deltaNLL', 'floating_poi', 'floating_poi_up', 'floating_poi_down'
    """
    try:
        import ROOT
        ROOT.gROOT.SetBatch(True)
    except ImportError:
        print("Error: ROOT is not available. Please set up the ATLAS environment.")
        sys.exit(1)
    
    # Find all ROOT files
    pattern = os.path.join(input_dir, f'fit_{poi1}_*__{poi2}_*.root')
    files = sorted(glob.glob(pattern))
    
    if not files:
        print(f"Error: No ROOT files found matching {pattern}")
        sys.exit(1)
    
    print(f"Found {len(files)} 2D scan points")
    
    # Initialize data arrays
    data = {
        'poi1': [],
        'poi2': [],
        'nll': [],
        'floating_poi': [],
        'floating_poi_up': [],
        'floating_poi_down': [],
    }
    
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
        
        # Get scanned POI values from filename (more reliable)
        val1, val2 = extract_poi_values_from_filename(fpath, poi1, poi2)
        if val1 is None:
            # Try from tree
            try:
                val1 = getattr(tree, poi1)
                val2 = getattr(tree, poi2)
            except AttributeError as e:
                print(f"Warning: Could not extract POI values from {fpath}: {e}")
                f.Close()
                continue
        
        try:
            data['poi1'].append(val1)
            data['poi2'].append(val2)
            data['nll'].append(tree.nll)
            
            # Get floating POI value and uncertainties
            data['floating_poi'].append(getattr(tree, floating_poi))
            data['floating_poi_up'].append(getattr(tree, f'{floating_poi}__up'))
            data['floating_poi_down'].append(getattr(tree, f'{floating_poi}__down'))
        except AttributeError as e:
            print(f"Warning: Missing attribute in {fpath}: {e}")
        
        f.Close()
    
    # Convert to numpy arrays
    for key in data:
        data[key] = np.array(data[key])
    
    # Calculate deltaNLL (2 * (nll - nll_min))
    nll_min = np.min(data['nll'])
    data['deltaNLL'] = 2 * (data['nll'] - nll_min)
    
    print(f"Floating POI '{floating_poi}' range: [{np.min(data['floating_poi']):.4f}, {np.max(data['floating_poi']):.4f}]")
    
    return data

def plot_2d_profiled_poi(data, poi1, poi2, floating_poi, output_file, 
                         show_atlas=True, poi_labels=None, interpolation='linear',
                         ncontours=50, show_contour_lines=True):
    """
    Create a 2D density plot showing the profiled floating POI value.
    
    Args:
        data: dict with scan data
        poi1: name of the first scanned POI (x-axis)
        poi2: name of the second scanned POI (y-axis)
        floating_poi: name of the floating POI (z-axis, color)
        output_file: output file path (PDF)
        show_atlas: show ATLAS label
        poi_labels: dict mapping POI names to display labels
        interpolation: interpolation method for griddata ('linear', 'cubic', 'nearest')
        ncontours: number of contour levels
        show_contour_lines: whether to show contour lines
    """
    # Default POI labels - matching plotscan.py style (tilde on W/B, not on c)
    if poi_labels is None:
        poi_labels = {
            'cHWtil_combine': r'$c_{H\tilde{W}}$',
            'cHBtil_combine': r'$c_{H\tilde{B}}$',
            'cHWBtil_combine': r'$c_{H\tilde{W}B}$',
        }
    
    # Get display labels
    poi1_label = poi_labels.get(poi1, poi1)
    poi2_label = poi_labels.get(poi2, poi2)
    floating_label = poi_labels.get(floating_poi, floating_poi)
    
    # Create figure
    fig, ax = plt.subplots(figsize=(8, 7))
    
    # Create grid for interpolation
    x = data['poi1']
    y = data['poi2']
    z = data['floating_poi']
    
    # Create regular grid
    xi = np.linspace(np.min(x), np.max(x), 100)
    yi = np.linspace(np.min(y), np.max(y), 100)
    Xi, Yi = np.meshgrid(xi, yi)
    
    # Interpolate data onto grid
    Zi = griddata((x, y), z, (Xi, Yi), method=interpolation)
    
    # Use viridis_r colormap (yellow-to-purple, like NLL density plots)
    cmap = 'viridis_r'
    
    # Create filled contour plot
    cf = ax.contourf(Xi, Yi, Zi, levels=ncontours, cmap=cmap)
    
    # Add contour lines
    if show_contour_lines:
        cs = ax.contour(Xi, Yi, Zi, levels=10, colors='white', linewidths=0.5, alpha=0.5)
        ax.clabel(cs, inline=True, fontsize=8, fmt='%.2f')
    
    # Add colorbar
    cbar = fig.colorbar(cf, ax=ax, shrink=0.9, pad=0.02)
    cbar.set_label(f'Profiled {floating_label}', fontsize=12)
    
    # Mark best fit point (minimum NLL)
    best_idx = np.argmin(data['deltaNLL'])
    ax.plot(data['poi1'][best_idx], data['poi2'][best_idx], 'k*', markersize=15, 
            markeredgecolor='white', markeredgewidth=1.5, label='Best fit')
    
    # Mark SM point (0, 0)
    ax.plot(0, 0, 'ko', markersize=10, markeredgecolor='white', markeredgewidth=1.5, label='SM')
    
    # Labels
    ax.set_xlabel(poi1_label, fontsize=14)
    ax.set_ylabel(poi2_label, fontsize=14)
    
    # ATLAS label
    if show_atlas:
        ax.text(0.05, 0.95, 'ATLAS', fontsize=14, fontweight='bold', 
               transform=ax.transAxes, verticalalignment='top',
               style='italic', fontfamily='sans-serif')
        ax.text(0.18, 0.95, 'Internal', fontsize=14,
               transform=ax.transAxes, verticalalignment='top', 
               style='italic', fontfamily='sans-serif')
    
    # Legend
    ax.legend(loc='upper right', fontsize=10, frameon=False)
    
    # Grid
    ax.grid(True, alpha=0.3, linestyle='--')
    
    # Save figure
    fig.tight_layout()
    fig.savefig(output_file, bbox_inches='tight', dpi=150)
    print(f"Saved plot to {output_file}")
    plt.close(fig)

def main():
    parser = argparse.ArgumentParser(description='Plot 2D scan with profiled floating POI')
    parser.add_argument('--input', '-i', required=True, help='Directory containing ROOT scan files')
    parser.add_argument('--poi1', '-p1', required=True, help='First scanned POI (x-axis)')
    parser.add_argument('--poi2', '-p2', required=True, help='Second scanned POI (y-axis)')
    parser.add_argument('--floating', '-f', default=None,
                       help='Floating POI to show on z-axis (default: auto-detect)')
    parser.add_argument('--output', '-o', required=True, help='Output file path (PDF)')
    parser.add_argument('--output-dir', default='.', help='Output directory (default: current)')
    parser.add_argument('--no-atlas', action='store_true', help='Disable ATLAS label')
    parser.add_argument('--interpolation', default='linear', choices=['linear', 'cubic', 'nearest'],
                       help='Interpolation method (default: linear)')
    parser.add_argument('--ncontours', type=int, default=50, help='Number of contour levels (default: 50)')
    parser.add_argument('--no-contour-lines', action='store_true', help='Disable contour lines')
    
    args = parser.parse_args()
    
    # Determine floating POI
    if args.floating:
        floating_poi = args.floating
    else:
        # Auto-detect based on scanned POIs
        all_pois = ['cHWtil_combine', 'cHBtil_combine', 'cHWBtil_combine']
        remaining = [p for p in all_pois if p != args.poi1 and p != args.poi2]
        if len(remaining) == 1:
            floating_poi = remaining[0]
        else:
            print(f"Error: Could not auto-detect floating POI. Remaining: {remaining}")
            print("Please specify with --floating")
            sys.exit(1)
    
    print(f"Scanned POIs: {args.poi1} (x), {args.poi2} (y)")
    print(f"Floating POI: {floating_poi} (z/color)")
    
    # Read scan data
    data = read_2d_scan_data(args.input, args.poi1, args.poi2, floating_poi)
    
    # Determine output path
    output_file = args.output
    if not output_file.endswith('.pdf'):
        output_file += '.pdf'
    if not os.path.dirname(output_file):
        output_file = os.path.join(args.output_dir, output_file)
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_file) if os.path.dirname(output_file) else '.', exist_ok=True)
    
    # Create plot
    plot_2d_profiled_poi(
        data, args.poi1, args.poi2, floating_poi, output_file,
        show_atlas=not args.no_atlas,
        interpolation=args.interpolation,
        ncontours=args.ncontours,
        show_contour_lines=not args.no_contour_lines
    )

if __name__ == '__main__':
    main()

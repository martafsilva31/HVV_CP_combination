#!/usr/bin/env python3
"""
2D Likelihood Scan Density Plot.

Creates publication-quality 2D density/contour plots for likelihood scans
in the HVV CP combination analysis.

Supports:
- Reading from converted txt files or directly from ROOT files
- Multiple input files for overlay (obs vs exp, linear vs quadratic)
- Contour levels at 68% and 95% CL
- ATLAS style formatting

Usage:
    python plot_2d_scan.py --input scan_obs.txt --poi1 cHWtil_combine --poi2 cHBtil_combine
    python plot_2d_scan.py --input scan_obs.txt --input scan_exp.txt --labels Obs Exp
    python plot_2d_scan.py --root-file scan.root --poi1 cHWtil --poi2 cHBtil

Author: HVV CP Combination Analysis
"""

import argparse
import os
import sys
import numpy as np
from typing import Dict, List, Optional, Tuple

# Check for ROOT
try:
    import ROOT
    ROOT.PyConfig.IgnoreCommandLineOptions = True
    ROOT.gROOT.SetBatch(True)
    HAS_ROOT = True
except ImportError:
    HAS_ROOT = False


# POI labels for axis titles
POI_LABELS = {
    'cHWtil_combine': 'c_{H#tilde{W}}',
    'cHBtil_combine': 'c_{H#tilde{B}}',
    'cHWBtil_combine': 'c_{H#tilde{W}B}',
    'cHWtil': 'c_{H#tilde{W}}',
    'cHBtil': 'c_{H#tilde{B}}',
    'cHWBtil': 'c_{H#tilde{W}B}',
}

# Colors for multiple inputs
COLORS = [ROOT.kBlack, ROOT.kBlue, ROOT.kRed, ROOT.kGreen+2, ROOT.kMagenta] if HAS_ROOT else []
LINE_STYLES = [1, 2, 3, 4, 5]  # solid, dashed, dotted, dash-dotted, etc.


def setup_atlas_style():
    """Set up ATLAS-like plotting style."""
    ROOT.gStyle.SetOptStat(0)
    ROOT.gStyle.SetOptTitle(0)
    ROOT.gStyle.SetPadTickX(1)
    ROOT.gStyle.SetPadTickY(1)
    ROOT.gStyle.SetPadLeftMargin(0.14)
    ROOT.gStyle.SetPadRightMargin(0.16)
    ROOT.gStyle.SetPadTopMargin(0.08)
    ROOT.gStyle.SetPadBottomMargin(0.13)
    ROOT.gStyle.SetTitleXOffset(1.2)
    ROOT.gStyle.SetTitleYOffset(1.3)
    ROOT.gStyle.SetLabelSize(0.045, "XYZ")
    ROOT.gStyle.SetTitleSize(0.05, "XYZ")
    ROOT.gStyle.SetLegendBorderSize(0)
    ROOT.gStyle.SetLegendFillColor(0)
    ROOT.gStyle.SetPalette(ROOT.kBird)


def read_txt_file(filepath: str) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Read 2D scan data from txt file.
    
    Returns:
        Tuple of (poi1_values, poi2_values, nll_values)
    """
    poi1_vals, poi2_vals, nll_vals = [], [], []
    
    with open(filepath, 'r') as f:
        header = f.readline()  # Skip header
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 3:
                poi1_vals.append(float(parts[0]))
                poi2_vals.append(float(parts[1]))
                nll_vals.append(float(parts[2]))
    
    return np.array(poi1_vals), np.array(poi2_vals), np.array(nll_vals)


def read_root_file(filepath: str, poi1: str, poi2: str, 
                   tree_name: str = 'nllscan') -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Read 2D scan data directly from ROOT file.
    
    Returns:
        Tuple of (poi1_values, poi2_values, nll_values)
    """
    if not HAS_ROOT:
        raise ImportError("ROOT not available")
    
    tfile = ROOT.TFile.Open(filepath)
    if not tfile or tfile.IsZombie():
        raise IOError(f"Cannot open {filepath}")
    
    tree = tfile.Get(tree_name)
    if not tree:
        raise ValueError(f"Tree '{tree_name}' not found in {filepath}")
    
    poi1_vals, poi2_vals, nll_vals = [], [], []
    
    for i in range(tree.GetEntries()):
        tree.GetEntry(i)
        poi1_vals.append(getattr(tree, poi1))
        poi2_vals.append(getattr(tree, poi2))
        nll_vals.append(tree.nll)
    
    tfile.Close()
    return np.array(poi1_vals), np.array(poi2_vals), np.array(nll_vals)


def compute_delta_nll(nll_vals: np.ndarray) -> np.ndarray:
    """Compute deltaNLL = nll - min(nll)."""
    return nll_vals - np.min(nll_vals)


def create_histogram(poi1_vals: np.ndarray, poi2_vals: np.ndarray, 
                     delta_nll: np.ndarray, name: str = "h2_nll") -> 'ROOT.TH2D':
    """
    Create 2D histogram from scan data.
    
    Automatically determines binning from data.
    """
    # Get unique values to determine grid
    poi1_unique = np.sort(np.unique(poi1_vals))
    poi2_unique = np.sort(np.unique(poi2_vals))
    
    n1 = len(poi1_unique)
    n2 = len(poi2_unique)
    
    # Calculate bin edges (extend by half bin width)
    if n1 > 1:
        dx = (poi1_unique[-1] - poi1_unique[0]) / (n1 - 1)
        x_min = poi1_unique[0] - dx/2
        x_max = poi1_unique[-1] + dx/2
    else:
        x_min, x_max = poi1_unique[0] - 0.5, poi1_unique[0] + 0.5
        
    if n2 > 1:
        dy = (poi2_unique[-1] - poi2_unique[0]) / (n2 - 1)
        y_min = poi2_unique[0] - dy/2
        y_max = poi2_unique[-1] + dy/2
    else:
        y_min, y_max = poi2_unique[0] - 0.5, poi2_unique[0] + 0.5
    
    # Create histogram
    h2 = ROOT.TH2D(name, "", n1, x_min, x_max, n2, y_min, y_max)
    
    # Fill histogram (clamp deltaNLL to minimum of 0.001 to avoid white bins at exactly 0)
    for v1, v2, dnll in zip(poi1_vals, poi2_vals, delta_nll):
        h2.Fill(v1, v2, max(dnll, 0.001))
    
    return h2


def get_contour_levels():
    """
    Get deltaNLL levels for 68% and 95% CL contours (2D case).
    
    For 2D: 
    - 68% CL (1 sigma): deltaNLL = 1.15 (chi2(2) quantile 0.68)
    - 95% CL (2 sigma): deltaNLL = 3.0  (chi2(2) quantile 0.95)
    """
    return {
        '68': 1.15,  # 2.30/2
        '95': 3.0,   # 5.99/2
    }


def draw_contours(h2: 'ROOT.TH2D', color: int, style: int = 1,
                  draw_68: bool = True, draw_95: bool = True) -> List['ROOT.TGraph']:
    """
    Draw contour lines at specified confidence levels.
    
    Returns list of TGraph contours for legend.
    """
    contours = []
    levels = get_contour_levels()
    
    # Clone histogram for contouring
    h2_cont = h2.Clone(f"{h2.GetName()}_contour")
    
    contour_levels = []
    if draw_68:
        contour_levels.append(levels['68'])
    if draw_95:
        contour_levels.append(levels['95'])
    
    if not contour_levels:
        return contours
    
    # Set contour levels
    h2_cont.SetContour(len(contour_levels), np.array(contour_levels, dtype='d'))
    
    # Draw to get contours
    canvas_temp = ROOT.TCanvas("temp", "", 100, 100)
    h2_cont.Draw("CONT LIST")
    canvas_temp.Update()
    
    # Get contours from special list
    cont_list = ROOT.gROOT.GetListOfSpecials().FindObject("contours")
    if cont_list:
        for i, level in enumerate(contour_levels):
            graphs = cont_list.At(i)
            if graphs:
                for j in range(graphs.GetSize()):
                    graph = graphs.At(j)
                    if graph:
                        g_clone = graph.Clone()
                        g_clone.SetLineColor(color)
                        g_clone.SetLineWidth(2)
                        # 68% dashed, 95% solid
                        if level == levels['68']:
                            g_clone.SetLineStyle(2)  # dashed
                        else:
                            g_clone.SetLineStyle(1)  # solid
                        contours.append(g_clone)
    
    canvas_temp.Close()
    return contours


def plot_2d_scan(inputs: List[str], poi1: str, poi2: str,
                 output: str, labels: Optional[List[str]] = None,
                 from_root: bool = False, tree_name: str = 'nllscan',
                 show_density: bool = True, z_max: float = 10.0,
                 atlas_label: str = "Work in Progress",
                 extra_text: str = "",
                 show_legend: bool = True,
                 show_atlas: bool = True,
                 show_contours: bool = True,
                 show_bestfit: bool = True) -> bool:
    """
    Create 2D likelihood scan plot.
    
    Args:
        inputs: List of input files (txt or root)
        poi1: First POI name
        poi2: Second POI name
        output: Output file path
        labels: Labels for legend (one per input)
        from_root: If True, read directly from ROOT files
        tree_name: Name of TTree in ROOT files
        show_density: If True, show color density (only for single input)
        z_max: Maximum deltaNLL for z-axis
        atlas_label: ATLAS label text
        extra_text: Additional text below ATLAS label
        show_legend: If True, show legend with CL labels
        show_atlas: If True, show ATLAS label
        show_contours: If True, show 68% and 95% CL contours
        show_bestfit: If True, show best-fit markers
    
    Returns:
        True if successful
    """
    if not HAS_ROOT:
        print("Error: ROOT not available")
        return False
    
    setup_atlas_style()
    
    # Default labels
    if labels is None:
        labels = [f"Input {i+1}" for i in range(len(inputs))]
    
    # Density only makes sense for single input
    if len(inputs) > 1 and show_density:
        print("Note: Multiple inputs - disabling density, showing contours only")
        show_density = False
    
    # Read all inputs
    histograms = []
    all_contours = []
    best_fit_points = []
    
    for i, input_file in enumerate(inputs):
        print(f"Reading {input_file}...")
        
        if from_root:
            poi1_vals, poi2_vals, nll_vals = read_root_file(
                input_file, poi1, poi2, tree_name
            )
        else:
            poi1_vals, poi2_vals, nll_vals = read_txt_file(input_file)
        
        # Compute deltaNLL
        delta_nll = compute_delta_nll(nll_vals)
        
        # Find best-fit point
        min_idx = np.argmin(delta_nll)
        best_fit_points.append((poi1_vals[min_idx], poi2_vals[min_idx]))
        
        # Create histogram
        h2 = create_histogram(poi1_vals, poi2_vals, delta_nll, f"h2_{i}")
        histograms.append(h2)
        
        # Get contours
        color = COLORS[i % len(COLORS)]
        contours = draw_contours(h2, color)
        all_contours.append(contours)
    
    # Create canvas
    canvas = ROOT.TCanvas("c1", "", 800, 700)
    canvas.cd()
    
    # Get axis labels
    x_label = POI_LABELS.get(poi1, poi1)
    y_label = POI_LABELS.get(poi2, poi2)
    
    # Draw first histogram as density
    h2_main = histograms[0]
    h2_main.GetXaxis().SetTitle(x_label)
    h2_main.GetYaxis().SetTitle(y_label)
    h2_main.GetZaxis().SetTitle("-2#Delta ln L")
    h2_main.GetZaxis().SetRangeUser(0.001, z_max)
    
    if show_density:
        h2_main.Draw("COLZ")
    else:
        # Just set up the frame
        h2_main.Draw("AXIS")
    
    # Draw all contours (optional)
    if show_contours:
        for i, contours in enumerate(all_contours):
            for cont in contours:
                cont.Draw("L SAME")
    
    # Draw best-fit markers (optional)
    markers = []
    if show_bestfit:
        for i, (x, y) in enumerate(best_fit_points):
            marker = ROOT.TMarker(x, y, 34)  # cross
            marker.SetMarkerColor(COLORS[i % len(COLORS)])
            marker.SetMarkerSize(1.5)
            marker.Draw()
            markers.append(marker)
    
    # Draw SM point at (0, 0)
    sm_marker = ROOT.TMarker(0, 0, 29)  # star
    sm_marker.SetMarkerColor(ROOT.kRed)
    sm_marker.SetMarkerSize(1.8)
    if show_legend:  # Only draw SM marker if legend is shown
        sm_marker.Draw()
    
    # Create legend (optional)
    if show_legend:
        legend = ROOT.TLegend(0.55, 0.70, 0.88, 0.90)
        legend.SetTextSize(0.035)
        
        for i, label in enumerate(labels):
            # Create dummy graphs for legend
            g_68 = ROOT.TGraph()
            g_68.SetLineColor(COLORS[i % len(COLORS)])
            g_68.SetLineStyle(2)
            g_68.SetLineWidth(2)
            legend.AddEntry(g_68, f"{label} 68% CL", "L")
            
            g_95 = ROOT.TGraph()
            g_95.SetLineColor(COLORS[i % len(COLORS)])
            g_95.SetLineStyle(1)
            g_95.SetLineWidth(2)
            legend.AddEntry(g_95, f"{label} 95% CL", "L")
        
        legend.AddEntry(sm_marker, "SM", "P")
        legend.Draw()
    
    # ATLAS label (optional)
    if show_atlas:
        latex = ROOT.TLatex()
        latex.SetNDC()
        latex.SetTextFont(72)
        latex.SetTextSize(0.045)
        latex.DrawLatex(0.18, 0.88, "ATLAS")
        
        latex.SetTextFont(42)
        latex.DrawLatex(0.30, 0.88, atlas_label)
        
        if extra_text:
            latex.SetTextSize(0.035)
            latex.DrawLatex(0.18, 0.83, extra_text)
    
    # Redraw axis on top
    ROOT.gPad.RedrawAxis()
    
    # Save
    canvas.SaveAs(output)
    print(f"Saved: {output}")
    
    # Also save as ROOT file for later editing
    root_output = output.replace('.pdf', '.root').replace('.png', '.root')
    if root_output != output:
        canvas.SaveAs(root_output)
        print(f"Saved: {root_output}")
    
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Create 2D likelihood scan density/contour plots",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Single observed scan
  %(prog)s --input obs_scan.txt --poi1 cHWtil_combine --poi2 cHBtil_combine

  # Observed vs Expected overlay
  %(prog)s --input obs.txt --input exp.txt --labels Obs Exp --poi1 cHWtil_combine --poi2 cHBtil_combine

  # From ROOT file directly
  %(prog)s --root-file scan.root --poi1 cHWtil --poi2 cHBtil --output plot.pdf
        """
    )
    
    parser.add_argument('--input', '-i', action='append', dest='inputs',
                        help='Input txt file (can specify multiple times)')
    parser.add_argument('--root-file', action='append', dest='root_files',
                        help='Input ROOT file (alternative to --input)')
    parser.add_argument('--poi1', required=True,
                        help='First POI name (x-axis)')
    parser.add_argument('--poi2', required=True,
                        help='Second POI name (y-axis)')
    parser.add_argument('--labels', '-l', nargs='+',
                        help='Labels for legend (one per input)')
    parser.add_argument('--output', '-o', default='scan_2d.pdf',
                        help='Output file (default: scan_2d.pdf)')
    parser.add_argument('--tree-name', default='nllscan',
                        help='TTree name in ROOT files (default: nllscan)')
    parser.add_argument('--no-density', action='store_true',
                        help='Disable color density (contours only)')
    parser.add_argument('--no-legend', action='store_true',
                        help='Disable legend')
    parser.add_argument('--no-atlas', action='store_true',
                        help='Disable ATLAS label')
    parser.add_argument('--no-contours', action='store_true',
                        help='Disable contour lines')
    parser.add_argument('--no-bestfit', action='store_true',
                        help='Disable best-fit markers')
    parser.add_argument('--z-max', type=float, default=10.0,
                        help='Maximum deltaNLL for z-axis (default: 10)')
    parser.add_argument('--atlas-label', default='Work in Progress',
                        help='ATLAS label text')
    parser.add_argument('--extra-text', default='',
                        help='Additional text below ATLAS label')
    
    args = parser.parse_args()
    
    # Determine input type
    if args.root_files:
        inputs = args.root_files
        from_root = True
    elif args.inputs:
        inputs = args.inputs
        from_root = False
    else:
        parser.error("Either --input or --root-file is required")
    
    success = plot_2d_scan(
        inputs=inputs,
        poi1=args.poi1,
        poi2=args.poi2,
        output=args.output,
        labels=args.labels,
        from_root=from_root,
        tree_name=args.tree_name,
        show_density=not args.no_density,
        z_max=args.z_max,
        atlas_label=args.atlas_label,
        extra_text=args.extra_text,
        show_legend=not args.no_legend,
        show_atlas=not args.no_atlas,
        show_contours=not args.no_contours,
        show_bestfit=not args.no_bestfit,
    )
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

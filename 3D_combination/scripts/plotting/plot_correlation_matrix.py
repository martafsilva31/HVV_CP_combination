#!/usr/bin/env python3
"""
Plot correlation matrices from quickFit results.

This script extracts correlation matrices from fit results and creates
publication-quality plots.

Usage:
    python plot_correlation_matrix.py --input fit_result.root --pois cHWtil,cHBtil,cHWBtil
"""

import argparse
import os
import sys

# Check for ROOT
try:
    import ROOT
    ROOT.PyConfig.IgnoreCommandLineOptions = True
    ROOT.gROOT.SetBatch(True)
except ImportError:
    print("Error: ROOT not found. Please source your analysis setup.")
    sys.exit(1)


def get_latex_label(poi_name: str) -> str:
    """Get LaTeX label for a POI name."""
    labels = {
        'cHWtil': '#tilde{c}_{HW}',
        'cHWtil_combine': '#tilde{c}_{HW}',
        'cHBtil': '#tilde{c}_{HB}',
        'cHBtil_combine': '#tilde{c}_{HB}',
        'cHWBtil': '#tilde{c}_{HWB}',
        'cHWBtil_combine': '#tilde{c}_{HWB}',
    }
    # Remove _combine suffix for lookup
    base_name = poi_name.replace('_combine', '')
    return labels.get(poi_name, labels.get(base_name, poi_name))


def find_fit_result(tfile):
    """Find RooFitResult object in file."""
    names = ['fitResult', 'fitresult', 'fit_result', 'nll_fitResult']
    
    for name in names:
        obj = tfile.Get(name)
        if obj and obj.InheritsFrom('RooFitResult'):
            return obj
    
    # Search all keys
    for key in tfile.GetListOfKeys():
        obj = tfile.Get(key.GetName())
        if obj and obj.InheritsFrom('RooFitResult'):
            return obj
    
    return None


def resolve_pois(fit_result, requested_pois):
    """Resolve requested POI names to actual parameter names in fit result."""
    # Get all float parameter names
    pars = fit_result.floatParsFinal()
    all_names = [pars.at(i).GetName() for i in range(pars.getSize())]
    all_names_set = set(all_names)
    
    resolved = []
    for poi in requested_pois:
        if poi in all_names_set:
            resolved.append(poi)
        elif poi + '_combine' in all_names_set:
            resolved.append(poi + '_combine')
        else:
            # Try partial match
            matches = [n for n in all_names if poi in n]
            if matches:
                resolved.append(matches[0])
                print(f"Warning: Using '{matches[0]}' for requested POI '{poi}'")
    
    return resolved


def build_correlation_histogram(fit_result, pois, as_percent=False):
    """Build TH2D correlation matrix histogram."""
    n = len(pois)
    h = ROOT.TH2D("h_cor", "", n, 0, n, n, 0, n)
    
    # Set axis labels
    for i, poi in enumerate(pois):
        label = get_latex_label(poi)
        h.GetXaxis().SetBinLabel(i + 1, label)
        h.GetYaxis().SetBinLabel(n - i, label)  # Reversed for y-axis
    
    # Fill correlation values
    for i, pi in enumerate(pois):
        for j, pj in enumerate(pois):
            corr = fit_result.correlation(pi, pj)
            if as_percent:
                corr *= 100
            # Note: y-axis is reversed in histogram
            h.SetBinContent(i + 1, n - j, corr)
    
    return h


def plot_correlation_matrix(
    input_file: str,
    pois: list,
    output: str,
    title: str = "",
    as_percent: bool = False,
    internal: bool = True,
    margin: float = 0.2,
    decimal_places: int = 2
):
    """Create correlation matrix plot."""
    
    # Open file and get fit result
    tfile = ROOT.TFile.Open(input_file)
    if not tfile or tfile.IsZombie():
        print(f"Error: Cannot open {input_file}")
        return False
    
    fit_result = find_fit_result(tfile)
    if not fit_result:
        print(f"Error: No RooFitResult found in {input_file}")
        tfile.Close()
        return False
    
    # Resolve POI names
    resolved_pois = resolve_pois(fit_result, pois)
    if not resolved_pois:
        print("Error: No matching POIs found")
        tfile.Close()
        return False
    
    print(f"Using POIs: {resolved_pois}")
    
    # Build histogram
    h_cor = build_correlation_histogram(fit_result, resolved_pois, as_percent)
    
    # Setup canvas and style
    ROOT.gStyle.SetOptStat(0)
    ROOT.gStyle.SetPaintTextFormat(f".{decimal_places}f")
    
    n = len(resolved_pois)
    canvas_size = 400 + 100 * n
    canvas = ROOT.TCanvas("c", "", canvas_size, canvas_size)
    canvas.SetLeftMargin(margin)
    canvas.SetRightMargin(margin)
    canvas.SetTopMargin(margin)
    canvas.SetBottomMargin(margin)
    
    # Color palette
    ROOT.gStyle.SetPalette(ROOT.kBird)
    
    # Draw
    h_cor.SetMarkerSize(1.5)
    h_cor.GetZaxis().SetRangeUser(-1 if not as_percent else -100, 
                                   1 if not as_percent else 100)
    h_cor.Draw("COLZ TEXT")
    
    # Add ATLAS label
    latex = ROOT.TLatex()
    latex.SetNDC()
    latex.SetTextFont(72)
    latex.SetTextSize(0.05)
    latex.DrawLatex(margin + 0.02, 1 - margin + 0.02, "ATLAS")
    
    latex.SetTextFont(42)
    if internal:
        latex.DrawLatex(margin + 0.15, 1 - margin + 0.02, "Internal")
    
    if title:
        latex.SetTextSize(0.035)
        latex.DrawLatex(margin + 0.02, 1 - margin - 0.04, title)
    
    # Save
    canvas.SaveAs(output)
    
    # Also save as PDF if .tex requested
    if output.endswith('.tex'):
        canvas.SaveAs(output.replace('.tex', '.pdf'))
    
    tfile.Close()
    print(f"Saved: {output}")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Plot correlation matrices from quickFit results."
    )
    parser.add_argument('--input', required=True, help='Input ROOT file')
    parser.add_argument('--pois', required=True, 
                       help='Comma-separated list of POIs')
    parser.add_argument('--output', help='Output file (default: input_corr.pdf)')
    parser.add_argument('--title', default='', help='Plot title')
    parser.add_argument('--percent', action='store_true',
                       help='Show correlation as percent')
    parser.add_argument('--internal', action='store_true', default=True,
                       help='Add ATLAS Internal label')
    parser.add_argument('--margin', type=float, default=0.2,
                       help='Canvas margin')
    parser.add_argument('--dp', type=int, default=2,
                       help='Decimal places for text')
    
    args = parser.parse_args()
    
    pois = [p.strip() for p in args.pois.split(',')]
    
    output = args.output
    if not output:
        base = os.path.splitext(args.input)[0]
        output = f"{base}_corr.pdf"
    
    plot_correlation_matrix(
        args.input,
        pois,
        output,
        title=args.title,
        as_percent=args.percent,
        internal=args.internal,
        margin=args.margin,
        decimal_places=args.dp
    )


if __name__ == '__main__':
    main()

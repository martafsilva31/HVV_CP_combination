#!/usr/bin/env python3
"""
Summary plot for 3POI fit results.

Creates a publication-quality summary plot showing:
- Best-fit values for all three Wilson coefficients
- 68% CL intervals from likelihood scans
- Comparison between observed and expected (Asimov)

Usage:
    python plot_fit_summary.py --linear-obs fit_linear_obs.root \
                               --linear-exp fit_linear_asimov.root \
                               --output summary.pdf
"""

import argparse
import os
import sys
from typing import Dict, List, Optional, Tuple

try:
    import ROOT
    ROOT.PyConfig.IgnoreCommandLineOptions = True
    ROOT.gROOT.SetBatch(True)
    ROOT.gStyle.SetOptStat(0)
except ImportError:
    print("Error: ROOT not found. Please source your analysis setup.")
    sys.exit(1)


# POI configuration
POIS = ['cHWtil_combine', 'cHBtil_combine', 'cHWBtil_combine']
POI_LABELS = {
    'cHWtil_combine': '#tilde{c}_{HW}',
    'cHBtil_combine': '#tilde{c}_{HB}',
    'cHWBtil_combine': '#tilde{c}_{HWB}',
}


def find_fit_result(tfile):
    """Find RooFitResult in file."""
    names = ['fitResult', 'fitresult', 'fit_result', 'nll_fitResult']
    for name in names:
        obj = tfile.Get(name)
        if obj and obj.InheritsFrom('RooFitResult'):
            return obj
    for key in tfile.GetListOfKeys():
        obj = tfile.Get(key.GetName())
        if obj and obj.InheritsFrom('RooFitResult'):
            return obj
    return None


def extract_results(filepath: str) -> Dict[str, Dict[str, float]]:
    """Extract POI values and errors from fit result."""
    results = {}
    
    tfile = ROOT.TFile.Open(filepath)
    if not tfile or tfile.IsZombie():
        print(f"Warning: Cannot open {filepath}")
        return results
    
    fit_result = find_fit_result(tfile)
    if not fit_result:
        # Try nllscan tree
        tree = tfile.Get('nllscan')
        if tree and tree.GetEntries() > 0:
            tree.GetEntry(0)
            for poi in POIS:
                try:
                    val = getattr(tree, poi)
                    # Try to get error
                    err = 0
                    for err_name in [f'{poi}_err', f'{poi}_error']:
                        try:
                            err = getattr(tree, err_name)
                            break
                        except:
                            pass
                    results[poi] = {
                        'value': val,
                        'error': err,
                        'error_hi': err,
                        'error_lo': -err
                    }
                except:
                    pass
        tfile.Close()
        return results
    
    pars = fit_result.floatParsFinal()
    for i in range(pars.getSize()):
        par = pars.at(i)
        name = par.GetName()
        if name in POIS:
            results[name] = {
                'value': par.getVal(),
                'error': par.getError(),
                'error_hi': par.getErrorHi() if par.getErrorHi() != 0 else par.getError(),
                'error_lo': par.getErrorLo() if par.getErrorLo() != 0 else -par.getError()
            }
    
    tfile.Close()
    return results


def create_summary_plot(
    results_dict: Dict[str, Dict[str, Dict[str, float]]],
    output: str,
    title: str = ""
):
    """Create summary plot.
    
    Args:
        results_dict: Dict mapping label to POI results.
                     e.g., {"Linear Obs": {poi_name: {value, error, ...}}}
        output: Output file path.
        title: Plot title.
    """
    
    n_pois = len(POIS)
    n_results = len(results_dict)
    
    # Setup canvas
    canvas = ROOT.TCanvas("c", "", 800, 600)
    canvas.SetLeftMargin(0.15)
    canvas.SetRightMargin(0.05)
    canvas.SetTopMargin(0.1)
    canvas.SetBottomMargin(0.15)
    
    # Create frame
    h_frame = ROOT.TH2F("frame", "", 100, -4, 4, n_pois, 0, n_pois)
    h_frame.GetXaxis().SetTitle("Wilson coefficient value")
    h_frame.GetYaxis().SetLabelSize(0.06)
    h_frame.Draw()
    
    # Set y-axis labels
    for i, poi in enumerate(POIS):
        h_frame.GetYaxis().SetBinLabel(i + 1, POI_LABELS.get(poi, poi))
    
    # Colors for different results
    colors = [ROOT.kBlack, ROOT.kBlue, ROOT.kRed, ROOT.kGreen+2]
    markers = [20, 24, 21, 25]
    
    # Legend
    legend = ROOT.TLegend(0.65, 0.75, 0.92, 0.88)
    legend.SetBorderSize(0)
    legend.SetFillStyle(0)
    legend.SetTextSize(0.035)
    
    # Draw SM line at 0
    sm_line = ROOT.TLine(0, 0, 0, n_pois)
    sm_line.SetLineStyle(2)
    sm_line.SetLineColor(ROOT.kGray+1)
    sm_line.Draw()
    
    # Store graphs to prevent garbage collection
    graphs = []
    
    for idx, (label, poi_results) in enumerate(results_dict.items()):
        color = colors[idx % len(colors)]
        marker = markers[idx % len(markers)]
        
        g = ROOT.TGraphAsymmErrors(n_pois)
        g.SetMarkerStyle(marker)
        g.SetMarkerColor(color)
        g.SetLineColor(color)
        g.SetMarkerSize(1.2)
        
        for i, poi in enumerate(POIS):
            if poi in poi_results:
                r = poi_results[poi]
                y = i + 0.5 + (idx - n_results/2 + 0.5) * 0.15
                g.SetPoint(i, r['value'], y)
                g.SetPointError(i, -r['error_lo'], r['error_hi'], 0, 0)
            else:
                g.SetPoint(i, 0, i + 0.5)
                g.SetPointError(i, 0, 0, 0, 0)
        
        g.Draw("P SAME")
        legend.AddEntry(g, label, "lep")
        graphs.append(g)
    
    legend.Draw()
    
    # ATLAS label
    latex = ROOT.TLatex()
    latex.SetNDC()
    latex.SetTextFont(72)
    latex.SetTextSize(0.05)
    latex.DrawLatex(0.17, 0.85, "ATLAS")
    
    latex.SetTextFont(42)
    latex.DrawLatex(0.30, 0.85, "Internal")
    
    if title:
        latex.SetTextSize(0.035)
        latex.DrawLatex(0.17, 0.80, title)
    
    # Save
    canvas.SaveAs(output)
    print(f"Saved: {output}")


def main():
    parser = argparse.ArgumentParser(
        description="Create summary plot of 3POI fit results."
    )
    parser.add_argument('--linear-obs', help='Linear observed fit result')
    parser.add_argument('--linear-exp', help='Linear expected (Asimov) fit result')
    parser.add_argument('--quad-obs', help='Quadratic observed fit result')
    parser.add_argument('--quad-exp', help='Quadratic expected fit result')
    parser.add_argument('--output', default='fit_summary.pdf', help='Output file')
    parser.add_argument('--title', default='HVV CP Combination', help='Plot title')
    
    args = parser.parse_args()
    
    results_dict = {}
    
    if args.linear_obs:
        r = extract_results(args.linear_obs)
        if r:
            results_dict['Linear Obs'] = r
    
    if args.linear_exp:
        r = extract_results(args.linear_exp)
        if r:
            results_dict['Linear Exp'] = r
    
    if args.quad_obs:
        r = extract_results(args.quad_obs)
        if r:
            results_dict['Quad Obs'] = r
    
    if args.quad_exp:
        r = extract_results(args.quad_exp)
        if r:
            results_dict['Quad Exp'] = r
    
    if not results_dict:
        print("Error: No valid fit results provided")
        sys.exit(1)
    
    create_summary_plot(results_dict, args.output, args.title)


if __name__ == '__main__':
    main()

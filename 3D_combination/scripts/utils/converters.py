#!/usr/bin/env python3
"""
ROOT to text converters for scan results.

This module converts quickFit scan output ROOT files to text format
suitable for plotting with RooFitUtils plotscan.py tool.

Example usage:
    from utils.converters import RootToTxtConverter
    
    converter = RootToTxtConverter()
    
    # Convert 1D scan results
    converter.convert_1d_scan(
        input_dir="root_cHWtil_scan/",
        output_file="cHWtil_nllscan.txt",
        poi="cHWtil_combine"
    )
    
    # Convert 2D scan results
    converter.convert_2d_scan(
        input_dir="root_2d_scan/",
        output_file="2d_nllscan.txt",
        poi1="cHWtil_combine",
        poi2="cHBtil_combine"
    )
"""

import argparse
import glob
import os
import re
import sys
from typing import List, Optional, Tuple

# Check for ROOT availability
try:
    import ROOT
    ROOT.PyConfig.IgnoreCommandLineOptions = True
    HAS_ROOT = True
except ImportError:
    HAS_ROOT = False


class RootToTxtConverter:
    """
    Convert quickFit scan output ROOT files to text format.
    
    The output format is compatible with RooFitUtils plotscan.py:
    - 1D: poi_name deltaNLL
    - 2D: poi1_name poi2_name deltaNLL
    """
    
    def __init__(self, tree_name: str = 'nllscan'):
        """Initialize converter.
        
        Args:
            tree_name: Name of the TTree containing scan results.
        """
        if not HAS_ROOT:
            raise ImportError("ROOT module not found. Please source your setup.")
        self.tree_name = tree_name
    
    def _extract_poi_value_from_filename(
        self, 
        filename: str, 
        poi: str
    ) -> Optional[float]:
        """Extract POI value from filename pattern.
        
        Handles patterns like:
        - fit_cHWtil_combine_0.5000.root
        - fit_cHWtil_-1.2.root
        - fit_cHWtil_combine_0.5000__cHBtil_combine_-0.3.root
        
        Args:
            filename: Filename (basename).
            poi: POI name to extract.
        
        Returns:
            POI value or None if not found.
        """
        # Pattern: poi_name followed by underscore and number
        # Handle negative numbers and decimals
        pattern = rf'{re.escape(poi)}_(-?\d+\.?\d*)'
        match = re.search(pattern, filename)
        if match:
            return float(match.group(1))
        
        # Also try without underscore before number (legacy format)
        pattern = rf'{re.escape(poi)}(-?\d+\.?\d*)'
        match = re.search(pattern, filename)
        if match:
            return float(match.group(1))
        
        return None
    
    def _get_nll_from_tree(
        self, 
        filepath: str, 
        poi: Optional[str] = None
    ) -> Tuple[Optional[float], Optional[float], Optional[int]]:
        """Get NLL value, POI value, and fit status from scan tree.
        
        Args:
            filepath: Path to ROOT file.
            poi: POI name (optional, for extracting value from tree).
        
        Returns:
            Tuple of (poi_value, nll_value, status) or (None, None, None) if error.
        """
        tfile = ROOT.TFile.Open(filepath)
        if not tfile or tfile.IsZombie():
            return (None, None, None)
        
        tree = tfile.Get(self.tree_name)
        if not tree:
            tfile.Close()
            return (None, None, None)
        
        # Get first entry (scan files typically have one entry)
        if tree.GetEntries() == 0:
            tfile.Close()
            return (None, None, None)
        
        tree.GetEntry(0)
        
        # Try to get NLL value
        nll = None
        for nll_name in ['nll', 'NLL', 'minNll', 'deltaNLL']:
            try:
                nll = getattr(tree, nll_name)
                break
            except AttributeError:
                continue
        
        # Try to get fit status
        status = None
        for status_name in ['status', 'fitStatus', 'fit_status', 'covQual']:
            try:
                status = int(getattr(tree, status_name))
                break
            except (AttributeError, ValueError):
                continue
        
        # Try to get POI value
        poi_val = None
        if poi:
            try:
                poi_val = getattr(tree, poi)
            except AttributeError:
                pass
        
        tfile.Close()
        return (poi_val, nll, status)
    
    def convert_1d_scan(
        self,
        input_dir: str,
        output_file: str,
        poi: str,
        pattern: str = "fit_*.root"
    ) -> bool:
        """Convert 1D scan ROOT files to text format for plotscan.py.
        
        Output format: POI deltaNLL (for compatibility with RooFitUtils plotscan.py)
        
        Args:
            input_dir: Directory containing scan ROOT files.
            output_file: Output text file path.
            poi: POI name being scanned.
            pattern: Glob pattern for ROOT files.
        
        Returns:
            True if successful, False otherwise.
        """
        # Find all ROOT files
        files = sorted(glob.glob(os.path.join(input_dir, pattern)))
        if not files:
            print(f"Warning: No files found matching {os.path.join(input_dir, pattern)}", 
                  file=sys.stderr)
            return False
        
        # Extract data points
        points = []  # List of (poi_value, nll, status)
        
        for filepath in files:
            filename = os.path.basename(filepath)
            
            # Get POI value from filename or tree
            poi_val = self._extract_poi_value_from_filename(filename, poi)
            tree_poi_val, nll, status = self._get_nll_from_tree(filepath, poi)
            
            if poi_val is None:
                poi_val = tree_poi_val
            
            if poi_val is None or nll is None:
                print(f"Warning: Could not extract data from {filename}", file=sys.stderr)
                continue
            
            points.append((poi_val, nll, status))
        
        if not points:
            print("Error: No valid data points extracted", file=sys.stderr)
            return False
        
        # Sort by POI value
        points.sort(key=lambda x: x[0])
        
        # Calculate delta NLL (relative to minimum) for plotscan.py
        nll_min = min(p[1] for p in points)
        
        # Write output in plotscan.py format
        os.makedirs(os.path.dirname(output_file) or '.', exist_ok=True)
        with open(output_file, 'w') as f:
            # plotscan.py expects: POI deltaNLL format
            for poi_val, nll, status in points:
                delta_nll = nll - nll_min
                f.write(f"{poi_val:.6f}\t{delta_nll:.6f}\n")
        
        print(f"Wrote {len(points)} points to {output_file}")
        return True
    
    def convert_2d_scan(
        self,
        input_dir: str,
        output_file: str,
        poi1: str,
        poi2: str,
        pattern: str = "fit_*.root"
    ) -> bool:
        """Convert 2D scan ROOT files to text format for plotscan.py.
        
        Output format: POI1 POI2 deltaNLL (for compatibility with RooFitUtils plotscan.py)
        
        Args:
            input_dir: Directory containing scan ROOT files.
            output_file: Output text file path.
            poi1: First POI name.
            poi2: Second POI name.
            pattern: Glob pattern for ROOT files.
        
        Returns:
            True if successful, False otherwise.
        """
        # Find all ROOT files
        files = sorted(glob.glob(os.path.join(input_dir, pattern)))
        if not files:
            print(f"Warning: No files found matching {os.path.join(input_dir, pattern)}",
                  file=sys.stderr)
            return False
        
        # Extract data points
        points = []  # List of (poi1_value, poi2_value, nll)
        
        for filepath in files:
            filename = os.path.basename(filepath)
            
            # Get POI values from filename
            val1 = self._extract_poi_value_from_filename(filename, poi1)
            val2 = self._extract_poi_value_from_filename(filename, poi2)
            
            # Get NLL from tree
            _, nll, status = self._get_nll_from_tree(filepath)
            
            if val1 is None or val2 is None or nll is None:
                print(f"Warning: Could not extract data from {filename}", file=sys.stderr)
                continue
            
            points.append((val1, val2, nll))
        
        if not points:
            print("Error: No valid data points extracted", file=sys.stderr)
            return False
        
        # Sort by poi1, then poi2
        points.sort(key=lambda x: (x[0], x[1]))
        
        # Calculate delta NLL (relative to minimum) for plotscan.py
        nll_min = min(p[2] for p in points)
        
        # Write output in plotscan.py format
        os.makedirs(os.path.dirname(output_file) or '.', exist_ok=True)
        with open(output_file, 'w') as f:
            # plotscan.py expects: POI1 POI2 deltaNLL format
            for val1, val2, nll in points:
                delta_nll = nll - nll_min
                f.write(f"{val1:.6f}\t{val2:.6f}\t{delta_nll:.6f}\n")
        
        print(f"Wrote {len(points)} points to {output_file}")
        return True


def main():
    """CLI interface for ROOT to text conversion."""
    parser = argparse.ArgumentParser(
        description="Convert quickFit scan ROOT files to text format for plotting."
    )
    parser.add_argument('--indir', required=True, help='Input directory with ROOT files')
    parser.add_argument('--out', required=True, help='Output text file')
    parser.add_argument('--par', '--poi', dest='poi', required=True, 
                       help='POI name (for 1D) or first POI (for 2D)')
    parser.add_argument('--par2', '--poi2', dest='poi2', 
                       help='Second POI name (for 2D scan)')
    parser.add_argument('--pattern', default='fit_*.root', 
                       help='Glob pattern for ROOT files')
    parser.add_argument('--tree', default='nllscan', 
                       help='TTree name containing scan results')
    
    args = parser.parse_args()
    
    if not HAS_ROOT:
        print("ERROR: ROOT module not found!", file=sys.stderr)
        sys.exit(1)
    
    converter = RootToTxtConverter(tree_name=args.tree)
    
    if args.poi2:
        success = converter.convert_2d_scan(
            args.indir, args.out, args.poi, args.poi2,
            pattern=args.pattern
        )
    else:
        success = converter.convert_1d_scan(
            args.indir, args.out, args.poi,
            pattern=args.pattern
        )
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

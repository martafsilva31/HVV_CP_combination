#!/usr/bin/env python3
"""
Fit result parser for quickFit output ROOT files.

This module extracts POI values, errors, and correlations from
quickFit output ROOT files containing RooFitResult objects.

Example usage:
    from utils.fit_result_parser import FitResultParser
    
    parser = FitResultParser()
    
    # Extract all POI values
    results = parser.extract_pois("fit_output.root")
    # Returns: {"cHWtil_combine": 0.05, "cHBtil_combine": -0.1, ...}
    
    # Get detailed results with errors
    detailed = parser.extract_detailed("fit_output.root")
    # Returns: {"cHWtil_combine": {"value": 0.05, "error": 0.1, ...}, ...}
    
    # Extract correlation matrix
    corr = parser.extract_correlation_matrix("fit_output.root", pois=["cHWtil", "cHBtil"])
"""

import argparse
import os
import sys
from typing import Dict, List, Optional, Any, Tuple

# Check for ROOT availability
try:
    import ROOT
    ROOT.PyConfig.IgnoreCommandLineOptions = True
    HAS_ROOT = True
except ImportError:
    HAS_ROOT = False


class FitResultParser:
    """
    Parse quickFit output ROOT files and extract fit results.
    
    Attributes:
        result_names: List of object names to try when looking for RooFitResult.
        poi_patterns: Patterns to identify POIs (vs nuisance parameters).
    """
    
    # Common names for RooFitResult in quickFit outputs
    RESULT_NAMES = ['fitResult', 'fitresult', 'fit_result', 'nll_fitResult']
    
    # Patterns that identify Wilson coefficients and POIs (not NPs)
    POI_PATTERNS = [
        'cHWtil', 'cHBtil', 'cHWBtil', 'chwtilde', 'chbtilde', 'chbwtilde',
        'mu_', 'SigXsec', 'CSM_', '_combine'
    ]
    
    def __init__(self, result_name: Optional[str] = None):
        """Initialize parser.
        
        Args:
            result_name: Specific RooFitResult name to use (optional).
        """
        if not HAS_ROOT:
            raise ImportError(
                "ROOT module not found. Please source your analysis setup."
            )
        self.result_name = result_name
    
    def _find_fit_result(self, tfile: 'ROOT.TFile') -> Optional['ROOT.RooFitResult']:
        """Find RooFitResult object in a ROOT file.
        
        Args:
            tfile: Open ROOT TFile.
        
        Returns:
            RooFitResult object or None.
        """
        # Try explicit name first
        if self.result_name:
            obj = tfile.Get(self.result_name)
            if obj and obj.InheritsFrom('RooFitResult'):
                return obj
        
        # Try common names
        for name in self.RESULT_NAMES:
            obj = tfile.Get(name)
            if obj and obj.InheritsFrom('RooFitResult'):
                return obj
        
        # Search all keys
        for key in tfile.GetListOfKeys():
            obj = tfile.Get(key.GetName())
            if obj and obj.InheritsFrom('RooFitResult'):
                return obj
        
        return None
    
    def _is_poi(self, name: str) -> bool:
        """Check if a parameter name looks like a POI (not a nuisance parameter).
        
        Args:
            name: Parameter name.
        
        Returns:
            True if this appears to be a POI.
        """
        return any(pattern in name for pattern in self.POI_PATTERNS)
    
    def extract_pois(
        self, 
        filepath: str, 
        pois_only: bool = True,
        poi_list: Optional[List[str]] = None
    ) -> Dict[str, float]:
        """Extract POI values from fit result.
        
        Args:
            filepath: Path to ROOT file.
            pois_only: If True, filter to only POIs (not NPs).
            poi_list: Explicit list of POI names to extract.
        
        Returns:
            Dict mapping POI names to fitted values.
        """
        results = {}
        
        tfile = ROOT.TFile.Open(filepath)
        if not tfile or tfile.IsZombie():
            print(f"Warning: Cannot open {filepath}", file=sys.stderr)
            return results
        
        fit_result = self._find_fit_result(tfile)
        if not fit_result:
            print(f"Warning: No RooFitResult found in {filepath}", file=sys.stderr)
            tfile.Close()
            return results
        
        # Extract from floatParsFinal
        pars = fit_result.floatParsFinal()
        for i in range(pars.getSize()):
            par = pars.at(i)
            name = par.GetName()
            
            # Filter logic
            if poi_list is not None:
                if name not in poi_list:
                    continue
            elif pois_only:
                if not self._is_poi(name):
                    continue
            
            results[name] = par.getVal()
        
        tfile.Close()
        return results
    
    def extract_detailed(
        self,
        filepath: str,
        pois_only: bool = True,
        poi_list: Optional[List[str]] = None
    ) -> Dict[str, Dict[str, float]]:
        """Extract detailed POI information including errors.
        
        Args:
            filepath: Path to ROOT file.
            pois_only: If True, filter to only POIs.
            poi_list: Explicit list of POI names to extract.
        
        Returns:
            Dict mapping POI names to dicts with 'value', 'error', 'error_hi', 'error_lo'.
        """
        results = {}
        
        tfile = ROOT.TFile.Open(filepath)
        if not tfile or tfile.IsZombie():
            return results
        
        fit_result = self._find_fit_result(tfile)
        if not fit_result:
            tfile.Close()
            return results
        
        pars = fit_result.floatParsFinal()
        for i in range(pars.getSize()):
            par = pars.at(i)
            name = par.GetName()
            
            if poi_list is not None:
                if name not in poi_list:
                    continue
            elif pois_only:
                if not self._is_poi(name):
                    continue
            
            results[name] = {
                'value': par.getVal(),
                'error': par.getError(),
                'error_hi': par.getErrorHi() if par.getErrorHi() != 0 else par.getError(),
                'error_lo': par.getErrorLo() if par.getErrorLo() != 0 else -par.getError(),
                'min': par.getMin(),
                'max': par.getMax()
            }
        
        tfile.Close()
        return results
    
    def extract_nll(self, filepath: str) -> Optional[float]:
        """Extract NLL value from fit result.
        
        Args:
            filepath: Path to ROOT file.
        
        Returns:
            Minimum NLL value or None.
        """
        tfile = ROOT.TFile.Open(filepath)
        if not tfile or tfile.IsZombie():
            return None
        
        fit_result = self._find_fit_result(tfile)
        if not fit_result:
            tfile.Close()
            return None
        
        nll = fit_result.minNll()
        tfile.Close()
        return nll
    
    def extract_correlation_matrix(
        self,
        filepath: str,
        pois: List[str]
    ) -> Tuple[List[str], List[List[float]]]:
        """Extract correlation matrix for specified POIs.
        
        Args:
            filepath: Path to ROOT file.
            pois: List of POI names for the correlation matrix.
        
        Returns:
            Tuple of (poi_names, correlation_matrix) where correlation_matrix
            is a 2D list.
        """
        tfile = ROOT.TFile.Open(filepath)
        if not tfile or tfile.IsZombie():
            return ([], [])
        
        fit_result = self._find_fit_result(tfile)
        if not fit_result:
            tfile.Close()
            return ([], [])
        
        # Get actual parameter names (may have suffix like _combine)
        pars = fit_result.floatParsFinal()
        par_names = [pars.at(i).GetName() for i in range(pars.getSize())]
        
        # Resolve requested POIs to actual names
        resolved = []
        for poi in pois:
            if poi in par_names:
                resolved.append(poi)
            elif poi + '_combine' in par_names:
                resolved.append(poi + '_combine')
            else:
                # Try partial match
                matches = [p for p in par_names if poi in p]
                if matches:
                    resolved.append(matches[0])
        
        # Build correlation matrix
        n = len(resolved)
        matrix = [[0.0] * n for _ in range(n)]
        
        for i, pi in enumerate(resolved):
            for j, pj in enumerate(resolved):
                try:
                    matrix[i][j] = fit_result.correlation(pi, pj)
                except Exception:
                    matrix[i][j] = 1.0 if i == j else 0.0
        
        tfile.Close()
        return (resolved, matrix)
    
    def extract_from_nllscan_tree(
        self,
        filepath: str,
        tree_name: str = 'nllscan'
    ) -> Dict[str, Any]:
        """Extract values from nllscan tree (quickFit scan output).
        
        Args:
            filepath: Path to ROOT file.
            tree_name: Name of the TTree.
        
        Returns:
            Dict with 'poi_values' and 'nll' for each scan point.
        """
        results = {'entries': []}
        
        tfile = ROOT.TFile.Open(filepath)
        if not tfile or tfile.IsZombie():
            return results
        
        tree = tfile.Get(tree_name)
        if not tree:
            tfile.Close()
            return results
        
        # Get branch names
        branches = [b.GetName() for b in tree.GetListOfBranches()]
        
        for entry in tree:
            point = {}
            for branch in branches:
                try:
                    point[branch] = getattr(entry, branch)
                except Exception:
                    pass
            results['entries'].append(point)
        
        tfile.Close()
        return results


def main():
    """CLI interface for fit result parsing."""
    parser = argparse.ArgumentParser(
        description="Parse quickFit output ROOT files and extract results."
    )
    parser.add_argument('--input', required=True, help='Input ROOT file')
    parser.add_argument('--pois-only', action='store_true', default=True,
                       help='Only extract POIs (not NPs)')
    parser.add_argument('--all-params', action='store_true',
                       help='Extract all parameters including NPs')
    parser.add_argument('--poi', help='Extract specific POI (returns just value)')
    parser.add_argument('--format', choices=['simple', 'detailed', 'json'],
                       default='simple', help='Output format')
    parser.add_argument('--result-name', help='Specific RooFitResult name')
    
    args = parser.parse_args()
    
    if not HAS_ROOT:
        print("ERROR: ROOT module not found!", file=sys.stderr)
        sys.exit(1)
    
    parser_obj = FitResultParser(result_name=args.result_name)
    
    pois_only = not args.all_params
    
    if args.poi:
        # Extract single POI value
        results = parser_obj.extract_pois(args.input, pois_only=False, 
                                         poi_list=[args.poi])
        if args.poi in results:
            print(results[args.poi])
        else:
            print(f"POI {args.poi} not found", file=sys.stderr)
            sys.exit(1)
    elif args.format == 'detailed':
        results = parser_obj.extract_detailed(args.input, pois_only=pois_only)
        for name, data in results.items():
            print(f"{name}: {data['value']:.6f} +/- {data['error']:.6f}")
    elif args.format == 'json':
        import json
        results = parser_obj.extract_detailed(args.input, pois_only=pois_only)
        print(json.dumps(results, indent=2))
    else:  # simple
        results = parser_obj.extract_pois(args.input, pois_only=pois_only)
        for name, value in results.items():
            print(f"{name}={value:.6f}")


if __name__ == '__main__':
    main()

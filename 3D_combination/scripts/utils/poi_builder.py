#!/usr/bin/env python3
"""
POI string builder for quickFit commands.

This module constructs the -p (POI) argument string for quickFit,
handling different scan types (1D, 2D, fit) and supporting
sequential scans where previous fit results seed the next point.

Example usage:
    from utils.poi_builder import POIBuilder
    from utils.config import AnalysisConfig
    
    config = AnalysisConfig.from_yaml('configs/hvv_cp.yaml')
    builder = POIBuilder(config)
    
    # For a 1D scan fixing cHWtil_combine at 0.5
    poi_str = builder.build_1d_scan("cHWtil_combine", 0.5)
    
    # For a 2D scan 
    poi_str = builder.build_2d_scan("cHWtil_combine", 0.5, "cHBtil_combine", -0.3)
    
    # For a 3POI fit
    poi_str = builder.build_fit()
    
    # With previous results for sequential scanning
    poi_str = builder.build_1d_scan("cHWtil_combine", 0.5, previous_results=prev_dict)
"""

import argparse
import sys
import os
from typing import Dict, List, Optional, Any

# Handle both module and script execution
try:
    from .config import AnalysisConfig, POIConfig
except ImportError:
    # When run as a script, add parent directory to path
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from config import AnalysisConfig, POIConfig


class POIBuilder:
    """
    Build quickFit POI strings for different scan/fit configurations.
    
    Attributes:
        config: Analysis configuration containing POI definitions.
        scan_pois: List of main POIs to scan (combine-level Wilson coefficients).
        individual_wilson_coeffs: List of individual channel Wilson coefficients.
        float_pois: POIs that should float during scans.
        fixed_pois: POIs that should remain fixed.
    """
    
    def __init__(self, config: AnalysisConfig):
        """Initialize with analysis configuration.
        
        Args:
            config: AnalysisConfig instance with POI definitions.
        """
        self.config = config
        self.scan_pois = config.scan_pois  # combine-level: cHWtil_combine, etc.
        self.individual_wilson_coeffs = getattr(config, 'individual_wilson_coeffs', [])
        self.float_pois = config.float_pois
        self.fixed_pois = config.fixed_pois
    
    def _is_combine_poi(self, poi: str) -> bool:
        """Check if POI is a combine-level Wilson coefficient."""
        return poi in self.scan_pois
    
    def _is_individual_wilson_coeff(self, poi: str) -> bool:
        """Check if POI is an individual channel Wilson coefficient."""
        return poi in self.individual_wilson_coeffs
    
    def build_1d_scan(
        self,
        scan_poi: str,
        scan_value: float,
        previous_results: Optional[Dict[str, float]] = None,
        fix_other_scan_pois: bool = False
    ) -> str:
        """Build POI string for a 1D scan point.
        
        Logic:
        - If scanning a combine POI (cHWtil_combine, etc.):
          - Fix individual channel Wilson coeffs at 1
          - Float other combine POIs
        - If scanning an individual channel POI (cHWtil_HZZ, etc.):
          - Fix combine POIs at 1
          - Float other individual channel Wilson coeffs
        
        Args:
            scan_poi: Name of the POI being scanned.
            scan_value: Fixed value for the scan POI at this point.
            previous_results: Dict of POI names to values from previous fit.
            fix_other_scan_pois: If True, fix other scan POIs at 0.
        
        Returns:
            Comma-separated POI string for quickFit -p argument.
        """
        pois = []
        prev = previous_results or {}
        scanning_combine = self._is_combine_poi(scan_poi)
        
        # Handle combine-level POIs
        for poi in self.scan_pois:
            if poi == scan_poi:
                # The POI being scanned is fixed at scan_value
                pois.append(f"{poi}={scan_value:.6f}")
            elif scanning_combine:
                # Scanning a combine POI: float other combine POIs
                if fix_other_scan_pois:
                    pois.append(f"{poi}=0")
                else:
                    default = prev.get(poi, 0.0)
                    pois.append(f"{poi}={default:.6f}_-3_3")
            else:
                # Scanning an individual channel POI: fix combine POIs at 1
                pois.append(f"{poi}=1")
        
        # Handle individual channel Wilson coefficients
        for poi in self.individual_wilson_coeffs:
            if poi == scan_poi:
                # This is the POI being scanned (already handled if it's in scan_pois)
                if scan_poi not in self.scan_pois:
                    pois.append(f"{poi}={scan_value:.6f}")
            elif scanning_combine:
                # Scanning a combine POI: fix individual channel coeffs at 1
                pois.append(f"{poi}=1")
            else:
                # Scanning an individual POI: float other individual coeffs
                default = prev.get(poi, 1.0)
                pois.append(f"{poi}={default:.6f}_-5_5")
        
        # Add other float POIs (mu's, signal strengths, etc.) - not Wilson coeffs
        for name, poi_config in self.float_pois.items():
            if name in self.scan_pois or name in self.individual_wilson_coeffs:
                continue  # Already handled above
            if name == scan_poi:
                continue  # Already handled
            default = prev.get(name, poi_config.default)
            pois.append(poi_config.to_quickfit_str(default))
        
        # Add explicitly fixed POIs
        for name, value in self.fixed_pois.items():
            pois.append(f"{name}={value}")
        
        return ",".join(pois)
    
    def build_2d_scan(
        self,
        scan_poi1: str,
        scan_value1: float,
        scan_poi2: str,
        scan_value2: float,
        previous_results: Optional[Dict[str, float]] = None,
        fix_other_scan_pois: bool = False
    ) -> str:
        """Build POI string for a 2D scan point.
        
        Two scan POIs are fixed at their respective values.
        The third scan POI floats (unless fix_other_scan_pois=True).
        
        Same logic as 1D scan:
        - If scanning combine POIs: fix individual channel coeffs at 1
        - If scanning individual POIs: fix combine POIs at 1
        
        Args:
            scan_poi1: First POI being scanned.
            scan_value1: Value for first scan POI.
            scan_poi2: Second POI being scanned.
            scan_value2: Value for second scan POI.
            previous_results: Dict of POI names to values from previous fit.
            fix_other_scan_pois: If True, fix the third scan POI at 0.
        
        Returns:
            Comma-separated POI string for quickFit -p argument.
        """
        pois = []
        prev = previous_results or {}
        scan_set = {scan_poi1, scan_poi2}
        scanning_combine = self._is_combine_poi(scan_poi1) or self._is_combine_poi(scan_poi2)
        
        # Handle combine-level POIs
        for poi in self.scan_pois:
            if poi == scan_poi1:
                pois.append(f"{poi}={scan_value1:.6f}")
            elif poi == scan_poi2:
                pois.append(f"{poi}={scan_value2:.6f}")
            elif scanning_combine:
                # Scanning combine POIs: float other combine POIs
                if fix_other_scan_pois:
                    pois.append(f"{poi}=0")
                else:
                    default = prev.get(poi, 0.0)
                    pois.append(f"{poi}={default:.6f}_-3_3")
            else:
                # Scanning individual POIs: fix combine POIs at 1
                pois.append(f"{poi}=1")
        
        # Handle individual channel Wilson coefficients
        for poi in self.individual_wilson_coeffs:
            if poi in scan_set:
                if poi == scan_poi1:
                    pois.append(f"{poi}={scan_value1:.6f}")
                elif poi == scan_poi2:
                    pois.append(f"{poi}={scan_value2:.6f}")
            elif scanning_combine:
                # Scanning combine POIs: fix individual coeffs at 1
                pois.append(f"{poi}=1")
            else:
                # Scanning individual POIs: float other individual coeffs
                default = prev.get(poi, 1.0)
                pois.append(f"{poi}={default:.6f}_-5_5")
        
        # Add other float POIs (mu's, signal strengths, etc.)
        for name, poi_config in self.float_pois.items():
            if name in self.scan_pois or name in self.individual_wilson_coeffs:
                continue
            if name in scan_set:
                continue
            default = prev.get(name, poi_config.default)
            pois.append(poi_config.to_quickfit_str(default))
        
        # Add explicitly fixed POIs
        for name, value in self.fixed_pois.items():
            pois.append(f"{name}={value}")
        
        return ",".join(pois)
    
    def build_fit(
        self,
        poi_ranges: Optional[Dict[str, Dict[str, float]]] = None,
        previous_results: Optional[Dict[str, float]] = None
    ) -> str:
        """Build POI string for a full fit (all POIs floating).
        
        Args:
            poi_ranges: Override ranges for scan POIs, e.g.,
                        {"cHWtil_combine": {"min": -3, "max": 3}}
            previous_results: Dict of POI names to values for seeding.
        
        Returns:
            Comma-separated POI string for quickFit -p argument.
        """
        pois = []
        prev = previous_results or {}
        ranges = poi_ranges or {}
        
        # All scan POIs float
        for poi in self.scan_pois:
            default = prev.get(poi, 0.0)
            r = ranges.get(poi, {'min': -3, 'max': 3})
            pois.append(f"{poi}={default:.6f}_{r['min']}_{r['max']}")
        
        # Fix individual channel Wilson coefficients at 1 for fits
        for poi in self.individual_wilson_coeffs:
            pois.append(f"{poi}=1")
        
        # Float POIs
        for name, poi_config in self.float_pois.items():
            if name in self.scan_pois or name in self.individual_wilson_coeffs:
                continue
            default = prev.get(name, poi_config.default)
            pois.append(poi_config.to_quickfit_str(default))
        
        # Fixed POIs
        for name, value in self.fixed_pois.items():
            pois.append(f"{name}={value}")
        
        return ",".join(pois)
    
    def build_individual_channel_scan(
        self,
        channel_poi: str,
        scan_value: float,
        channel_suffix: str,
        previous_results: Optional[Dict[str, float]] = None
    ) -> str:
        """Build POI string for individual channel scan.
        
        Scans a channel-specific Wilson coefficient (e.g., cHWtil_HZZ)
        while floating other channel coefficients and fixing combine-level
        coefficients at 1.
        
        Args:
            channel_poi: The channel POI being scanned (e.g., "cHWtil_HZZ").
            scan_value: Value for the scan POI.
            channel_suffix: Channel identifier (e.g., "HZZ", "HWW").
            previous_results: Dict of POI names to values from previous fit.
        
        Returns:
            Comma-separated POI string for quickFit -p argument.
        """
        pois = []
        prev = previous_results or {}
        
        # Fix combine-level coefficients at 1
        for poi in self.scan_pois:
            pois.append(f"{poi}=1")
        
        # Handle channel POIs
        for name, poi_config in self.float_pois.items():
            if name == channel_poi:
                # This is the POI being scanned
                pois.append(f"{name}={scan_value:.6f}")
            elif self._is_channel_wilson_coeff(name):
                # Float other channel Wilson coefficients
                default = prev.get(name, poi_config.default)
                pois.append(poi_config.to_quickfit_str(default))
            else:
                # Float mu's and other parameters
                default = prev.get(name, poi_config.default)
                pois.append(poi_config.to_quickfit_str(default))
        
        return ",".join(pois)
    
    def _is_channel_wilson_coeff(self, name: str) -> bool:
        """Check if a POI is a channel-level Wilson coefficient.
        
        Args:
            name: POI name.
        
        Returns:
            True if this looks like a channel Wilson coefficient.
        """
        wilson_prefixes = ['cHWtil_', 'cHBtil_', 'cHWBtil_', 
                          'chwtilde_', 'chbtilde_', 'chbwtilde_']
        return any(name.startswith(p) for p in wilson_prefixes)


def main():
    """CLI interface for POI string building."""
    parser = argparse.ArgumentParser(
        description="Build quickFit POI strings from configuration."
    )
    parser.add_argument('--config', required=True, help='Path to YAML config file')
    parser.add_argument('--scan-type', choices=['1d', '2d', 'fit', 'channel'],
                       default='fit', help='Type of scan/fit')
    parser.add_argument('--scan-par', help='POI to scan (for 1d/channel)')
    parser.add_argument('--scan-val', type=float, help='Scan value (for 1d/channel)')
    parser.add_argument('--scan-par2', help='Second POI (for 2d)')
    parser.add_argument('--scan-val2', type=float, help='Second scan value (for 2d)')
    parser.add_argument('--previous', default='', 
                       help='Previous results as comma-sep key=val pairs')
    parser.add_argument('--channel', help='Channel suffix (for channel scan)')
    
    args = parser.parse_args()
    
    # Load config
    config = AnalysisConfig.from_yaml(args.config)
    builder = POIBuilder(config)
    
    # Parse previous results
    prev = {}
    if args.previous:
        for kv in args.previous.split(','):
            if '=' in kv:
                k, v = kv.split('=', 1)
                try:
                    prev[k.strip()] = float(v.strip())
                except ValueError:
                    pass
    
    # Build POI string
    if args.scan_type == '1d':
        if not args.scan_par or args.scan_val is None:
            parser.error("1d scan requires --scan-par and --scan-val")
        poi_str = builder.build_1d_scan(args.scan_par, args.scan_val, prev)
    elif args.scan_type == '2d':
        if not all([args.scan_par, args.scan_val is not None, 
                   args.scan_par2, args.scan_val2 is not None]):
            parser.error("2d scan requires --scan-par, --scan-val, --scan-par2, --scan-val2")
        poi_str = builder.build_2d_scan(
            args.scan_par, args.scan_val, 
            args.scan_par2, args.scan_val2, prev
        )
    elif args.scan_type == 'channel':
        if not args.scan_par or args.scan_val is None or not args.channel:
            parser.error("channel scan requires --scan-par, --scan-val, --channel")
        poi_str = builder.build_individual_channel_scan(
            args.scan_par, args.scan_val, args.channel, prev
        )
    else:  # fit
        poi_str = builder.build_fit(previous_results=prev)
    
    print(poi_str)


if __name__ == '__main__':
    main()

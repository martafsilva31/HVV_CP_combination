#!/usr/bin/env python3
"""
Configuration management for quickFit analysis.

This module provides a flexible configuration system that separates:
- Generic quickFit options (reusable across analyses)
- Analysis-specific settings (POIs, workspaces, ranges, NPs)

Example usage:
    from utils.config import AnalysisConfig
    
    # Load from YAML file
    config = AnalysisConfig.from_yaml('configs/hvv_cp_combination.yaml')
    
    # Or create programmatically
    config = AnalysisConfig(
        name="HVV_CP_3POI",
        scan_pois=["cHWtil_combine", "cHBtil_combine", "cHWBtil_combine"],
        float_pois={"cHWtil_HZZ": {"default": 1, "min": -5, "max": 5}, ...}
    )
"""

import os
import yaml
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any


@dataclass
class POIConfig:
    """Configuration for a single Parameter of Interest."""
    name: str
    default: float = 0.0
    min_val: float = -5.0
    max_val: float = 5.0
    fixed: bool = False
    
    def to_quickfit_str(self, value: Optional[float] = None) -> str:
        """Convert to quickFit POI string format.
        
        Args:
            value: Override value. If None, uses default.
        
        Returns:
            String like 'name=val_min_max' or 'name=val' if fixed.
        """
        val = value if value is not None else self.default
        if self.fixed:
            return f"{self.name}={val}"
        return f"{self.name}={val}_{self.min_val}_{self.max_val}"


@dataclass
class WorkspaceConfig:
    """Configuration for a workspace file."""
    path: str
    workspace_name: str = "combWS"
    data_name: str = "combData"
    model_config: str = "ModelConfig"
    label: str = ""
    
    def validate(self) -> bool:
        """Check if the workspace file exists."""
        return os.path.isfile(self.path)


@dataclass
class ScanConfig:
    """Configuration for a scan (1D or 2D)."""
    poi: str
    min_val: float
    max_val: float
    n_points: int = 25
    
    @property
    def step(self) -> float:
        """Calculate step size."""
        if self.n_points <= 1:
            return 0.0
        return (self.max_val - self.min_val) / (self.n_points - 1)
    
    def get_values(self) -> List[float]:
        """Get list of scan values."""
        if self.n_points == 1:
            return [self.min_val]
        return [self.min_val + i * self.step for i in range(self.n_points)]


@dataclass 
class AnalysisConfig:
    """
    Master configuration for a quickFit-based analysis.
    
    Attributes:
        name: Analysis identifier (e.g., "HVV_CP_3POI")
        scan_pois: List of POI names to scan (the main Wilson coefficients)
        float_pois: Dict of POIs to float during scans (channel-specific, mu's, etc.)
        fixed_pois: Dict of POIs to keep fixed at specific values
        exclude_nps: Pattern(s) for nuisance parameters to exclude
        workspaces: Dict of workspace configurations by label
        scan_ranges: Default scan ranges per POI
        quickfit_defaults: Default quickFit command options
    """
    name: str
    scan_pois: List[str] = field(default_factory=list)
    float_pois: Dict[str, POIConfig] = field(default_factory=dict)
    fixed_pois: Dict[str, float] = field(default_factory=dict)
    exclude_nps: List[str] = field(default_factory=list)
    workspaces: Dict[str, WorkspaceConfig] = field(default_factory=dict)
    scan_ranges: Dict[str, Dict[str, float]] = field(default_factory=dict)
    quickfit_defaults: Dict[str, Any] = field(default_factory=dict)
    
    def __post_init__(self):
        """Set sensible defaults for quickfit options."""
        defaults = {
            'min_tolerance': 0.0001,
            'minos': 0,
            'hesse': 0,
            'save_fit_result': 1,
            'save_errors': 1,
        }
        for k, v in defaults.items():
            self.quickfit_defaults.setdefault(k, v)
    
    @classmethod
    def from_yaml(cls, filepath: str) -> 'AnalysisConfig':
        """Load configuration from a YAML file.
        
        Args:
            filepath: Path to YAML configuration file.
        
        Returns:
            AnalysisConfig instance.
        """
        with open(filepath, 'r') as f:
            data = yaml.safe_load(f)
        
        # Parse POI configurations
        float_pois = {}
        for poi_data in data.get('float_pois', []):
            if isinstance(poi_data, dict):
                name = poi_data.get('name')
                float_pois[name] = POIConfig(
                    name=name,
                    default=poi_data.get('default', 1.0),
                    min_val=poi_data.get('min', -10.0),
                    max_val=poi_data.get('max', 10.0),
                    fixed=poi_data.get('fixed', False)
                )
            elif isinstance(poi_data, str):
                # Simple string format: "name=default_min_max" or "name=default"
                float_pois[poi_data] = POIConfig(name=poi_data)
        
        # Parse workspace configurations  
        workspaces = {}
        for label, ws_data in data.get('workspaces', {}).items():
            if isinstance(ws_data, str):
                workspaces[label] = WorkspaceConfig(path=ws_data, label=label)
            else:
                workspaces[label] = WorkspaceConfig(
                    path=ws_data.get('path'),
                    workspace_name=ws_data.get('workspace_name', 'combWS'),
                    data_name=ws_data.get('data_name', 'combData'),
                    label=label
                )
        
        return cls(
            name=data.get('name', 'analysis'),
            scan_pois=data.get('scan_pois', []),
            float_pois=float_pois,
            fixed_pois=data.get('fixed_pois', {}),
            exclude_nps=data.get('exclude_nps', []),
            workspaces=workspaces,
            scan_ranges=data.get('scan_ranges', {}),
            quickfit_defaults=data.get('quickfit_defaults', {})
        )
    
    def to_yaml(self, filepath: str) -> None:
        """Save configuration to a YAML file.
        
        Args:
            filepath: Output YAML file path.
        """
        data = {
            'name': self.name,
            'scan_pois': self.scan_pois,
            'float_pois': [
                {
                    'name': p.name,
                    'default': p.default,
                    'min': p.min_val,
                    'max': p.max_val,
                    'fixed': p.fixed
                }
                for p in self.float_pois.values()
            ],
            'fixed_pois': self.fixed_pois,
            'exclude_nps': self.exclude_nps,
            'workspaces': {
                label: {
                    'path': ws.path,
                    'workspace_name': ws.workspace_name,
                    'data_name': ws.data_name
                }
                for label, ws in self.workspaces.items()
            },
            'scan_ranges': self.scan_ranges,
            'quickfit_defaults': self.quickfit_defaults
        }
        
        with open(filepath, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    
    def get_scan_range(self, poi: str) -> ScanConfig:
        """Get scan configuration for a POI.
        
        Args:
            poi: POI name.
        
        Returns:
            ScanConfig with default or configured range.
        """
        if poi in self.scan_ranges:
            r = self.scan_ranges[poi]
            return ScanConfig(
                poi=poi,
                min_val=r.get('min', -3.0),
                max_val=r.get('max', 3.0),
                n_points=r.get('n_points', 25)
            )
        # Default range
        return ScanConfig(poi=poi, min_val=-3.0, max_val=3.0, n_points=25)
    
    def get_exclude_nps_pattern(self) -> str:
        """Get combined exclude NP pattern for quickFit -n flag.
        
        Returns:
            Comma-separated pattern string or empty string if none.
        """
        if not self.exclude_nps:
            return ""
        return ",".join(self.exclude_nps)

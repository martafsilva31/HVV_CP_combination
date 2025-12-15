"""
QuickFit module - Unified interface for running quickFit scans and fits.

This module provides:
- QuickFitRunner: Main runner class for scans and fits
- Command building and execution (local and HTCondor)
- Support for parallel and sequential execution modes

Example:
    from quickfit import QuickFitRunner
    from utils.config import AnalysisConfig
    
    config = AnalysisConfig.from_yaml('configs/hvv_cp_combination.yaml')
    runner = QuickFitRunner(config)
    
    # 1D scan
    runner.run_1d_scan("linear_obs", "cHWtil_combine", -1, 1, 21, mode="parallel")
    
    # 2D scan
    runner.run_2d_scan("linear_obs", "cHWtil_combine", -1, 1, 21,
                       "cHBtil_combine", -1.5, 1.5, 21, mode="parallel")
    
    # 3POI fit
    runner.run_fit("linear_obs", hesse=True)
"""

from .runner import QuickFitRunner, QuickFitCommand

__all__ = ['QuickFitRunner', 'QuickFitCommand']

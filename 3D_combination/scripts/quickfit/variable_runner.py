#!/usr/bin/env python3
"""
Variable POI 1D scan runner for quickFit.

This module runs 1D likelihood scans with configurable floating POIs,
supporting 1POI, 2POI, or 3POI scan configurations.

Usage as module:
    from quickfit.variable_runner import VariablePOIScanRunner
    runner = VariablePOIScanRunner(config)
    runner.run_scan(workspace="linear_asimov", poi="cHWtil_combine", 
                    min_val=-1, max_val=1, n_points=31,
                    float_pois=["cHBtil_combine"])  # 2POI scan

Usage from CLI:
    python -m quickfit.variable_runner --config config.yaml \
           --workspace linear_asimov --poi cHWtil_combine \
           --min -1 --max 1 --n-points 31 --float-pois "cHBtil_combine"
"""

import os
import sys
import subprocess
import time
import argparse
from typing import Dict, List, Optional

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.config import AnalysisConfig, WorkspaceConfig


class VariablePOIScanRunner:
    """
    Runner for 1D scans with variable number of floating POIs.
    
    Supports:
    - 1POI scans: only scanned POI varies, others fixed at 0
    - 2POI scans: one other POI floats, one fixed at 0
    - 3POI scans: both other POIs float (standard 3POI behavior)
    """
    
    def __init__(self, config: AnalysisConfig, verbose: bool = True):
        """Initialize runner.
        
        Args:
            config: Analysis configuration.
            verbose: Print progress messages.
        """
        self.config = config
        self.verbose = verbose
        self.scan_pois = config.scan_pois  # ['cHWtil_combine', 'cHBtil_combine', 'cHWBtil_combine']
    
    def _log(self, msg: str):
        """Print message if verbose."""
        if self.verbose:
            print(msg)
    
    def _get_workspace(self, label: str) -> WorkspaceConfig:
        """Get workspace configuration by label."""
        if label not in self.config.workspaces:
            raise ValueError(f"Unknown workspace: {label}. Available: {list(self.config.workspaces.keys())}")
        return self.config.workspaces[label]
    
    def _linspace(self, n: int, min_val: float, max_val: float) -> List[float]:
        """Generate linearly spaced values."""
        if n <= 1:
            return [min_val]
        step = (max_val - min_val) / (n - 1)
        return [min_val + i * step for i in range(n)]
    
    def _build_poi_string(
        self,
        scanned_poi: str,
        scan_value: float,
        float_pois: List[str],
        prev_results: Optional[Dict[str, float]] = None
    ) -> str:
        """Build POI string for quickFit.
        
        Args:
            scanned_poi: POI being scanned (fixed at scan_value).
            scan_value: Value to fix scanned POI at.
            float_pois: List of other POIs to float.
            prev_results: Previous fit results for seeding.
        
        Returns:
            POI string for quickFit -p argument.
        """
        pois = []
        prev = prev_results or {}
        
        # Handle combine-level scan POIs
        for poi in self.scan_pois:
            if poi == scanned_poi:
                # The POI being scanned is fixed at scan_value
                pois.append(f"{poi}={scan_value:.6f}")
            elif poi in float_pois:
                # This POI should float
                default = prev.get(poi, 0.0)
                pois.append(f"{poi}={default:.6f}_-3_3")
            else:
                # This POI is fixed at 0
                pois.append(f"{poi}=0")
        
        # Handle individual channel Wilson coefficients - fix at 1
        individual_wilson_coeffs = getattr(self.config, 'individual_wilson_coeffs', [])
        for poi in individual_wilson_coeffs:
            pois.append(f"{poi}=1")
        
        # Add other float POIs (mu's, signal strengths, etc.)
        for name, poi_config in self.config.float_pois.items():
            if name in self.scan_pois or name in individual_wilson_coeffs:
                continue
            default = prev.get(name, poi_config.default)
            pois.append(poi_config.to_quickfit_str(default))
        
        # Add explicitly fixed POIs
        for name, value in self.config.fixed_pois.items():
            pois.append(f"{name}={value}")
        
        return ",".join(pois)
    
    def _write_condor_wrapper(
        self,
        wrapper_path: str,
        commands: List[str],
        workdir: str
    ):
        """Write a Condor job wrapper script."""
        with open(wrapper_path, 'w') as f:
            f.write("#!/bin/bash\n")
            f.write("# Do NOT use set -e to avoid premature exit on non-critical failures\n\n")
            
            # Environment setup
            f.write("# Setup ATLAS LCG environment\n")
            f.write("export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase\n")
            f.write("source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh\n")
            f.write("export PYTHONPATH=/cvmfs/atlas.cern.ch/repo/sw/software/0.3/lcg/rel1/Python/x86_64-el9-gcc13-opt/lib/python3.10/site-packages:${PYTHONPATH}\n\n")
            
            f.write(f"cd {workdir}\n\n")
            
            for cmd in commands:
                f.write(f"{cmd}\n")
        
        os.chmod(wrapper_path, 0o755)
    
    def _write_condor_submit(
        self,
        submit_path: str,
        wrapper_path: str,
        log_dir: str,
        job_name: str,
        queue: str = "medium",
        memory: int = 64000
    ):
        """Write a Condor submit file."""
        with open(submit_path, 'w') as f:
            f.write("universe = vanilla\n")
            f.write("getenv = True\n")
            f.write('+UseOS = "el9"\n')
            f.write(f'+JobCategory = "{queue}"\n')
            f.write("request_cpus = 1\n")
            f.write(f"request_memory = {memory}\n\n")
            f.write(f"executable = {wrapper_path}\n")
            f.write(f"JobBatchName = {job_name}\n")
            f.write(f"log = {log_dir}/{job_name}.log\n")
            f.write(f"output = {log_dir}/{job_name}.out\n")
            f.write(f"error = {log_dir}/{job_name}.err\n")
            f.write("queue\n")
    
    def run_scan(
        self,
        workspace: str,
        poi: str,
        min_val: float,
        max_val: float,
        n_points: int,
        float_pois: List[str],
        mode: str = "parallel",
        backend: str = "local",
        output_dir: str = ".",
        tag: Optional[str] = None,
        queue: str = "medium",
        systematics: str = "stat_only"
    ) -> str:
        """Run a 1D likelihood scan with specified floating POIs.
        
        Args:
            workspace: Workspace label from config.
            poi: POI to scan.
            min_val: Minimum scan value.
            max_val: Maximum scan value.
            n_points: Number of scan points.
            float_pois: List of other POIs to float.
            mode: "parallel" or "sequential".
            backend: "local" or "condor".
            output_dir: Base output directory.
            tag: Optional tag for output naming.
            queue: Condor queue (if backend=condor).
            systematics: "full_syst" or "stat_only".
        
        Returns:
            Path to output directory with ROOT files.
        """
        ws = self._get_workspace(workspace)
        values = self._linspace(n_points, min_val, max_val)
        
        # Determine scan type
        n_float = len(float_pois)
        scan_type = f"{n_float + 1}POI"  # 1POI if 0 float, 2POI if 1 float, etc.
        
        # Setup output directories
        timestamp = time.strftime('%Y%m%d_%H%M%S')
        tag = tag or f"{workspace}_{poi}_{scan_type}_{mode}_{timestamp}"
        root_dir = os.path.join(output_dir, f"root_{tag}")
        logs_dir = os.path.join(output_dir, f"logs_{tag}")
        os.makedirs(root_dir, exist_ok=True)
        os.makedirs(logs_dir, exist_ok=True)
        
        self._log(f"Starting {scan_type} {mode} scan: {poi} [{min_val}, {max_val}] with {n_points} points")
        self._log(f"Floating POIs: {float_pois if float_pois else 'none (all fixed at 0)'}")
        self._log(f"Output: {root_dir}")
        
        if backend == "local":
            self._run_scan_local(ws, poi, values, float_pois, root_dir, logs_dir, mode, systematics)
        elif backend == "condor":
            self._run_scan_condor(ws, poi, values, float_pois, root_dir, logs_dir, mode, tag, queue, systematics)
        else:
            raise ValueError(f"Unknown backend: {backend}")
        
        return root_dir
    
    def _run_scan_local(
        self,
        ws: WorkspaceConfig,
        poi: str,
        values: List[float],
        float_pois: List[str],
        root_dir: str,
        logs_dir: str,
        mode: str,
        systematics: str
    ):
        """Run scan locally."""
        prev_results = {}
        exclude_nps = self.config.get_exclude_nps_pattern(systematics=systematics)
        
        for i, val in enumerate(values):
            self._log(f"  Point {i+1}/{len(values)}: {poi}={val:.4f}")
            
            poi_string = self._build_poi_string(poi, val, float_pois, prev_results)
            output_file = os.path.join(root_dir, f"fit_{poi}_{val:.4f}.root")
            log_file = os.path.join(logs_dir, f"fit_{poi}_{val:.4f}.log")
            
            cmd = [
                'quickFit',
                '-f', ws.path,
                '-w', ws.workspace_name,
                '-d', ws.data_name,
                '-p', poi_string,
                '--minTolerance', '0.0001',
                '--minos', '0',
                '--hesse', '0',
                '-o', output_file,
                '--savefitresult', '1',
                '--saveErrors', '1'
            ]
            
            if exclude_nps:
                cmd.extend(['-n', exclude_nps])
            
            with open(log_file, 'w') as f:
                result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
            
            if mode == "sequential" and result.returncode == 0 and os.path.exists(output_file):
                try:
                    prev_results = self._extract_results(output_file)
                except Exception:
                    prev_results = {}
            elif mode == "parallel":
                prev_results = {}
    
    def _run_scan_condor(
        self,
        ws: WorkspaceConfig,
        poi: str,
        values: List[float],
        float_pois: List[str],
        root_dir: str,
        logs_dir: str,
        mode: str,
        tag: str,
        queue: str,
        systematics: str
    ):
        """Submit scan to Condor."""
        workdir = os.getcwd()
        exclude_nps = self.config.get_exclude_nps_pattern(systematics=systematics)
        
        if mode == "sequential":
            self._run_scan_condor_sequential(
                ws, poi, values, float_pois, root_dir, logs_dir, tag, queue, exclude_nps, workdir
            )
        else:
            self._run_scan_condor_parallel(
                ws, poi, values, float_pois, root_dir, logs_dir, tag, queue, exclude_nps, workdir
            )
    
    def _run_scan_condor_sequential(
        self,
        ws: WorkspaceConfig,
        poi: str,
        values: List[float],
        float_pois: List[str],
        root_dir: str,
        logs_dir: str,
        tag: str,
        queue: str,
        exclude_nps: str,
        workdir: str
    ):
        """Submit TRUE SEQUENTIAL scan to Condor as a single job.
        
        Each fit uses the best-fit values from the previous point as starting values.
        """
        wrapper_path = os.path.join(logs_dir, f"{tag}_sequential.sh")
        submit_path = os.path.join(logs_dir, f"{tag}_sequential.sub")
        
        # Build the base POI config (non-floating POIs)
        base_poi_parts = []
        for scan_poi in self.scan_pois:
            if scan_poi == poi:
                continue  # Will be set per-point
            elif scan_poi in float_pois:
                continue  # Will be set dynamically
            else:
                base_poi_parts.append(f"{scan_poi}=0")
        
        # Individual Wilson coefficients fixed at 1
        individual_wilson_coeffs = getattr(self.config, 'individual_wilson_coeffs', [])
        for wc in individual_wilson_coeffs:
            base_poi_parts.append(f"{wc}=1")
        
        # Other float POIs with their defaults
        for name, poi_config in self.config.float_pois.items():
            if name in self.scan_pois or name in individual_wilson_coeffs:
                continue
            base_poi_parts.append(poi_config.to_quickfit_str())
        
        # Fixed POIs
        for name, value in self.config.fixed_pois.items():
            base_poi_parts.append(f"{name}={value}")
        
        base_poi_string = ",".join(base_poi_parts)
        
        # Build shell script with true sequential fitting
        commands = [
            f"#!/bin/bash",
            f"# TRUE SEQUENTIAL variable POI scan: {poi}",
            f"# Each fit uses best-fit values from previous point as starting values",
            f"# Floating POIs: {float_pois}",
            f"",
            f"cd {workdir}",
            f"",
            f"# Initialize floating POI starting values to 0",
        ]
        
        # Initialize variables for floating POIs
        for fp in float_pois:
            commands.append(f"{fp.replace('_combine', '_val')}=0.0")
        
        commands.append("")
        commands.append("# Function to extract best-fit values from ROOT file")
        commands.append("extract_bestfit() {")
        commands.append("    local rootfile=$1")
        commands.append("    python3 << PYEOF")
        commands.append("import ROOT")
        commands.append("ROOT.gROOT.SetBatch(True)")
        commands.append("f = ROOT.TFile.Open('\\$rootfile')")
        commands.append("if f and not f.IsZombie():")
        commands.append("    tree = f.Get('nllscan')")
        commands.append("    if tree and tree.GetEntries() > 0:")
        commands.append("        tree.GetEntry(0)")
        for fp in float_pois:
            var_name = fp.replace('_combine', '_val')
            commands.append(f"        try:")
            commands.append(f"            print('{var_name}=' + str(getattr(tree, '{fp}')))")
            commands.append(f"        except: pass")
        commands.append("    f.Close()")
        commands.append("PYEOF")
        commands.append("}")
        commands.append("")
        
        # Generate fit commands for each point
        for i, val in enumerate(values):
            val_str = f"{val:.4f}"
            output_file = os.path.join(root_dir, f"fit_{poi}_{val_str}.root")
            
            commands.append(f"echo '===== Fitting {poi}={val_str} - Point {i+1}/{len(values)} ====='")
            
            # Build dynamic POI string using current best-fit values
            if float_pois:
                float_parts = []
                for fp in float_pois:
                    var_name = fp.replace('_combine', '_val')
                    float_parts.append(f'{fp}=${{{var_name}}}_-3_3')
                float_str = ",".join(float_parts)
                poi_string_expr = f"'{poi}={val_str},{float_str},{base_poi_string}'"
            else:
                poi_string_expr = f"'{poi}={val_str},{base_poi_string}'"
            
            cmd = f"quickFit -f {ws.path} -w {ws.workspace_name} -d {ws.data_name} " \
                  f"-p {poi_string_expr} --minTolerance 0.0001 --minos 0 --hesse 0 " \
                  f"-o {output_file} --savefitresult 1 --saveErrors 1"
            
            if exclude_nps:
                cmd += f" -n '{exclude_nps}'"
            
            commands.append(cmd)
            commands.append("")
            
            # Extract best-fit values for next iteration (if there are floating POIs)
            if float_pois and i < len(values) - 1:
                commands.append(f"# Extract best-fit values for next point")
                commands.append(f"if [ -f {output_file} ]; then")
                commands.append(f"    eval $(extract_bestfit {output_file})")
                for fp in float_pois:
                    var_name = fp.replace('_combine', '_val')
                    commands.append(f'    echo "  {fp} best-fit: ${{{var_name}}}"')
                commands.append("fi")
                commands.append("")
        
        commands.append("echo 'Sequential scan complete!'")
        
        self._write_condor_wrapper(wrapper_path, commands, workdir)
        self._write_condor_submit(submit_path, wrapper_path, logs_dir, f"{tag}_sequential", queue)
        
        subprocess.run(['condor_submit', submit_path], check=True)
        self._log(f"Submitted sequential scan job: {tag}")
    
    def _run_scan_condor_parallel(
        self,
        ws: WorkspaceConfig,
        poi: str,
        values: List[float],
        float_pois: List[str],
        root_dir: str,
        logs_dir: str,
        tag: str,
        queue: str,
        exclude_nps: str,
        workdir: str
    ):
        """Submit parallel scan to Condor (one job per point)."""
        submit_path = os.path.join(logs_dir, f"{tag}_parallel.sub")
        
        with open(submit_path, 'w') as sf:
            sf.write("universe = vanilla\n")
            sf.write("getenv = True\n")
            sf.write('+UseOS = "el9"\n')
            sf.write(f'+JobCategory = "{queue}"\n')
            sf.write("request_cpus = 1\n")
            sf.write("request_memory = 64000\n\n")
        
        for val in values:
            val_str = f"{val:.4f}"
            job_tag = f"{tag}_{poi}_{val_str}"
            wrapper_path = os.path.join(logs_dir, f"{job_tag}.sh")
            output_file = os.path.join(root_dir, f"fit_{poi}_{val_str}.root")
            
            poi_string = self._build_poi_string(poi, val, float_pois)
            
            cmd = f"quickFit -f {ws.path} -w {ws.workspace_name} -d {ws.data_name} " \
                  f"-p '{poi_string}' --minTolerance 0.0001 --minos 0 --hesse 0 " \
                  f"-o {output_file} --savefitresult 1 --saveErrors 1"
            
            if exclude_nps:
                cmd += f" -n '{exclude_nps}'"
            
            self._write_condor_wrapper(wrapper_path, [cmd], workdir)
            
            with open(submit_path, 'a') as sf:
                sf.write(f"executable = {wrapper_path}\n")
                sf.write(f"JobBatchName = {job_tag}\n")
                sf.write(f"log = {logs_dir}/{job_tag}.log\n")
                sf.write(f"output = {logs_dir}/{job_tag}.out\n")
                sf.write(f"error = {logs_dir}/{job_tag}.err\n")
                sf.write("queue\n\n")
        
        subprocess.run(['condor_submit', submit_path], check=True)
        self._log(f"Submitted {len(values)} parallel scan jobs: {tag}")
    
    def _extract_results(self, root_file: str) -> Dict[str, float]:
        """Extract POI values from a fit result ROOT file."""
        try:
            import ROOT
            ROOT.gROOT.SetBatch(True)
            
            f = ROOT.TFile.Open(root_file)
            if not f or f.IsZombie():
                return {}
            
            tree = f.Get('nllscan')
            if not tree:
                f.Close()
                return {}
            
            tree.GetEntry(0)
            
            results = {}
            for poi in self.scan_pois:
                try:
                    results[poi] = getattr(tree, poi)
                except AttributeError:
                    pass
            
            f.Close()
            return results
        except Exception:
            return {}

    def run_split_scan(
        self,
        workspace: str,
        poi: str,
        min_val: float,
        max_val: float,
        n_points: int,
        float_pois: List[str],
        backend: str = "condor",
        output_dir: str = ".",
        tag: Optional[str] = None,
        queue: str = "medium",
        systematics: str = "stat_only"
    ) -> str:
        """Run a split 1D likelihood scan: 0→max and 0→min as separate sequential jobs.
        
        This ensures sequential fits start from the SM value (0) and proceed outward,
        which is important for fit convergence.
        
        Args:
            workspace: Workspace label from config.
            poi: POI to scan.
            min_val: Minimum scan value (negative).
            max_val: Maximum scan value (positive).
            n_points: Total number of scan points (will be split approximately equally).
            float_pois: List of other POIs to float.
            backend: "local" or "condor".
            output_dir: Base output directory.
            tag: Optional tag for output naming.
            queue: Condor queue (if backend=condor).
            systematics: "full_syst" or "stat_only".
        
        Returns:
            Path to output directory with ROOT files.
        """
        ws = self._get_workspace(workspace)
        
        # Determine scan type
        n_float = len(float_pois)
        scan_type = f"{n_float + 1}POI"
        
        # Calculate number of points for each direction
        # Positive direction: 0 to max (includes 0)
        # Negative direction: 0 to min (includes 0, but 0 will be duplicated - that's fine)
        n_positive = (n_points + 1) // 2  # Ceiling division for positive
        n_negative = (n_points + 1) // 2  # Same for negative
        
        # Generate values: 0→max and 0→min (both include 0)
        values_positive = self._linspace(n_positive, 0.0, max_val)  # [0, ..., max]
        values_negative = self._linspace(n_negative, 0.0, min_val)  # [0, ..., min]
        
        # Setup output directories
        timestamp = time.strftime('%Y%m%d_%H%M%S')
        base_tag = tag or f"{workspace}_{poi}_{scan_type}_split_{timestamp}"
        root_dir = os.path.join(output_dir, f"root_{base_tag}")
        logs_dir = os.path.join(output_dir, f"logs_{base_tag}")
        os.makedirs(root_dir, exist_ok=True)
        os.makedirs(logs_dir, exist_ok=True)
        
        self._log(f"Starting SPLIT {scan_type} scan: {poi}")
        self._log(f"  Positive direction: 0 → {max_val} with {n_positive} points")
        self._log(f"  Negative direction: 0 → {min_val} with {n_negative} points")
        self._log(f"Floating POIs: {float_pois if float_pois else 'none (all fixed at 0)'}")
        self._log(f"Output: {root_dir}")
        
        exclude_nps = self.config.get_exclude_nps_pattern(systematics=systematics)
        workdir = os.getcwd()
        
        if backend == "condor":
            # Submit positive direction job
            self._submit_split_job(
                ws, poi, values_positive, float_pois, root_dir, logs_dir,
                f"{base_tag}_positive", queue, exclude_nps, workdir, "positive"
            )
            
            # Submit negative direction job
            self._submit_split_job(
                ws, poi, values_negative, float_pois, root_dir, logs_dir,
                f"{base_tag}_negative", queue, exclude_nps, workdir, "negative"
            )
        else:
            # Local execution
            self._log("Running positive direction locally...")
            self._run_split_local(ws, poi, values_positive, float_pois, root_dir, logs_dir, exclude_nps)
            self._log("Running negative direction locally...")
            self._run_split_local(ws, poi, values_negative, float_pois, root_dir, logs_dir, exclude_nps)
        
        return root_dir

    def _submit_split_job(
        self,
        ws: WorkspaceConfig,
        poi: str,
        values: List[float],
        float_pois: List[str],
        root_dir: str,
        logs_dir: str,
        tag: str,
        queue: str,
        exclude_nps: str,
        workdir: str,
        direction: str
    ):
        """Submit a single split scan job to Condor with TRUE sequential fitting.
        
        Each fit uses the best-fit values from the previous point as starting values.
        This is achieved by using the external poi_builder.py and fit_result_parser.py
        utilities - the same approach used in the working runner.py implementation.
        """
        wrapper_path = os.path.join(logs_dir, f"{tag}_sequential.sh")
        submit_path = os.path.join(logs_dir, f"{tag}_sequential.sub")
        
        # Get paths to utility scripts
        scripts_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        poi_builder_script = os.path.join(scripts_dir, "utils", "poi_builder.py")
        fit_parser_script = os.path.join(scripts_dir, "utils", "fit_result_parser.py")
        config_path = self.config.config_path  # Path to the YAML config
        
        # Format float POIs as comma-separated string
        float_pois_str = ",".join(float_pois) if float_pois else ""
        
        # Build shell script with true sequential fitting using external utilities
        commands = [
            f"#!/bin/bash",
            f"# TRUE SEQUENTIAL split scan ({direction} direction): {poi}",
            f"# Each fit uses best-fit values from previous point as starting values",
            f"# Values: {values[0]:.4f} → {values[-1]:.4f}",
            f"# Floating POIs: {float_pois}",
            f"",
            f"cd {workdir}",
            f"",
            f"# Initialize previous results (empty for first point)",
            f'prev_results=""',
            f"",
        ]
        
        # Generate fit commands for each point
        for i, val in enumerate(values):
            val_str = f"{val:.4f}"
            output_file = os.path.join(root_dir, f"fit_{poi}_{val_str}.root")
            
            commands.append(f"echo '===== Fitting {poi}={val_str} ({direction}) - Point {i+1}/{len(values)} ====='")
            
            # Build POI string using external poi_builder.py utility
            poi_builder_cmd = (
                f'pois=$(python3 {poi_builder_script} '
                f'--config {config_path} '
                f'--scan-type variable '
                f'--scan-par {poi} '
                f'--scan-val {val} '
            )
            if float_pois_str:
                poi_builder_cmd += f'--float-pois "{float_pois_str}" '
            poi_builder_cmd += f'--previous "$prev_results")'
            
            commands.append(poi_builder_cmd)
            commands.append('echo "POI string: $pois"')
            
            # Build quickFit command
            cmd = (
                f'quickFit -f {ws.path} -w {ws.workspace_name} -d {ws.data_name} '
                f'-p "$pois" --minTolerance 0.0001 --minos 0 --hesse 0 '
                f'-o {output_file} --savefitresult 1 --saveErrors 1'
            )
            
            if exclude_nps:
                cmd += f" -n '{exclude_nps}'"
            
            commands.append(cmd)
            commands.append("")
            
            # Extract best-fit values for next iteration
            if i < len(values) - 1:  # Don't need to extract after last point
                commands.append(f"# Extract best-fit values for next point")
                commands.append(f'if [ -f "{output_file}" ]; then')
                # Use fit_result_parser.py to extract POI values in name=value format
                commands.append(f'    prev_results=$(python3 {fit_parser_script} --input "{output_file}" --pois-only 2>/dev/null | tr "\\n" "," | sed "s/,$//" || echo "")')
                commands.append(f'    echo "Previous results: $prev_results"')
                commands.append("else")
                commands.append(f'    echo "WARNING: Output file {output_file} not found, continuing without seeding"')
                commands.append(f'    prev_results=""')
                commands.append("fi")
                commands.append("")
        
        commands.append("echo 'Sequential scan complete!'")
        
        self._write_condor_wrapper(wrapper_path, commands, workdir)
        self._write_condor_submit(submit_path, wrapper_path, logs_dir, f"{tag}_sequential", queue)
        
        subprocess.run(['condor_submit', submit_path], check=True)
        self._log(f"Submitted {direction} direction TRUE SEQUENTIAL scan job: {tag}")

    def _run_split_local(
        self,
        ws: WorkspaceConfig,
        poi: str,
        values: List[float],
        float_pois: List[str],
        root_dir: str,
        logs_dir: str,
        exclude_nps: str
    ):
        """Run split scan locally (sequential)."""
        prev_results = {}
        
        for i, val in enumerate(values):
            self._log(f"  Point {i+1}/{len(values)}: {poi}={val:.4f}")
            
            poi_string = self._build_poi_string(poi, val, float_pois, prev_results)
            val_str = f"{val:.4f}"
            output_file = os.path.join(root_dir, f"fit_{poi}_{val_str}.root")
            log_file = os.path.join(logs_dir, f"fit_{poi}_{val_str}.log")
            
            cmd = [
                'quickFit',
                '-f', ws.path,
                '-w', ws.workspace_name,
                '-d', ws.data_name,
                '-p', poi_string,
                '--minTolerance', '0.0001',
                '--minos', '0',
                '--hesse', '0',
                '-o', output_file,
                '--savefitresult', '1',
                '--saveErrors', '1'
            ]
            
            if exclude_nps:
                cmd.extend(['-n', exclude_nps])
            
            with open(log_file, 'w') as f:
                result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
            
            if result.returncode == 0 and os.path.exists(output_file):
                try:
                    prev_results = self._extract_results(output_file)
                except Exception:
                    prev_results = {}


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(description='Run variable POI 1D likelihood scans')
    parser.add_argument('--config', required=True, help='Path to analysis config YAML')
    parser.add_argument('--workspace', required=True, help='Workspace label')
    parser.add_argument('--poi', required=True, help='POI to scan')
    parser.add_argument('--min', type=float, required=True, dest='min_val', help='Minimum scan value')
    parser.add_argument('--max', type=float, required=True, dest='max_val', help='Maximum scan value')
    parser.add_argument('--n-points', type=int, default=31, help='Number of scan points')
    parser.add_argument('--float-pois', default='', help='Comma-separated POIs to float')
    parser.add_argument('--mode', choices=['parallel', 'sequential'], default='parallel')
    parser.add_argument('--backend', choices=['local', 'condor'], default='local')
    parser.add_argument('--output-dir', default='.', help='Output directory')
    parser.add_argument('--tag', default=None, help='Output tag')
    parser.add_argument('--queue', default='medium', help='Condor queue')
    parser.add_argument('--systematics', default='stat_only', 
                       choices=['full_syst', 'stat_only'])
    parser.add_argument('--split-scan', action='store_true',
                       help='Split scan: 0→max and 0→min as separate sequential jobs (starting from SM value)')
    
    args = parser.parse_args()
    
    # Load config
    config = AnalysisConfig.from_yaml(args.config)
    runner = VariablePOIScanRunner(config)
    
    # Parse float_pois
    float_pois = []
    if args.float_pois:
        float_pois = [p.strip() for p in args.float_pois.split(',') if p.strip()]
    
    # Run scan (split or regular)
    if args.split_scan:
        runner.run_split_scan(
            workspace=args.workspace,
            poi=args.poi,
            min_val=args.min_val,
            max_val=args.max_val,
            n_points=args.n_points,
            float_pois=float_pois,
            backend=args.backend,
            output_dir=args.output_dir,
            tag=args.tag,
            queue=args.queue,
            systematics=args.systematics
        )
    else:
        runner.run_scan(
            workspace=args.workspace,
            poi=args.poi,
            min_val=args.min_val,
            max_val=args.max_val,
            n_points=args.n_points,
            float_pois=float_pois,
            mode=args.mode,
            backend=args.backend,
            output_dir=args.output_dir,
            tag=args.tag,
            queue=args.queue,
            systematics=args.systematics
        )


if __name__ == '__main__':
    main()

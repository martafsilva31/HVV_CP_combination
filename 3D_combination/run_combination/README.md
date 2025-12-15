# Workspace Combination Pipeline

This directory contains the 4-step pipeline for combining individual channel workspaces into a single combined workspace for the HVV CP 3POI analysis.

## Prerequisites

- WorkspaceCombiner tools installed
- Original channel workspaces in `../original_ws/`
- Proper ATLAS environment setup

```bash
cd /project/atlas/users/mfernand/software/workspaceCombiner
source setup_lxplus.sh
```

## Pipeline Overview

```
original_ws/          →  1. Editing  →  modified_ws/
                      →  2. POI Edit →  modified_ws/
modified_ws/          →  3. Combine  →  combined_ws/
combined_ws/ (obs)    →  4. Asimov   →  combined_ws/ (asimov)
```

## Step 1: Workspace Editing

**Purpose**: Split and prepare channel workspaces from original inputs.

**Script**: `1_ws_editing/1.WSEditing.sh`

This step uses `manager -w split` to extract channel workspaces with proper indexing and data names.

```bash
cd 1_ws_editing
bash 1.WSEditing.sh
```

**Outputs**: 
- `modified_ws/HWW_Data.root`, `modified_ws/HWW_Data_quad.root`
- `modified_ws/HTauTau_Data.root`, `modified_ws/HTauTau_Data_quad.root`
- `modified_ws/hbb_Data.root`, `modified_ws/hbb_Data_quad.root`
- `modified_ws/hZZ/` (multiple files)

**Key flags**:
- `--editRFV 2`: Required for workspaces with RooFormulaVar dependencies
- `-i 0-N`: Index range for observable splitting

## Step 2: POI Editing

**Purpose**: Modify parameter definitions (e.g., replace POIs with product formulas).

**Script**: `2_POI_editing/2.POIEditing.sh`

This step applies channel-specific transformations to ensure POI compatibility across channels.

```bash
cd 2_POI_editing
bash 2.POIEditing.sh
```

**What it does**:
- Adjusts POI definitions for combination
- Ensures consistent parameterization across channels
- Uses ROOT macros for complex parameter manipulations

## Step 3: Workspace Combination

**Purpose**: Combine channel workspaces into unified analysis workspace.

**Script**: `3_ws_combine/3.WSCombine.sh`

**Configuration files**:
- `combine_CP_linear_obs.xml` - Linear EFT combination
- `combine_CP_quad_obs.xml` - Quadratic EFT combination

```bash
cd 3_ws_combine
bash 3.WSCombine.sh
```

**Outputs**:
- `../combined_ws/combined_linear_obs.root`
- `../combined_ws/combined_quad_obs.root`

### XML Configuration Structure

The XML files define how channels are combined:

```xml
<Combination WorkspaceName="combWS" DataName="combData">
  <POIList Combined="cHWtil_combine,cHBtil_combine,cHWBtil_combine"/>
  
  <Channel Name="HZZ" InputFile="modified_ws/hZZ/hZZ_Data.root">
    <POIList Input="cHWtil_HZZ,cHBtil_HZZ,cHWBtil_HZZ"/>
    <RenameMap InputFile="sys_xml_files/hZZ_list.xml"/>
  </Channel>
  
  <!-- Additional channels... -->
</Combination>
```

**Key components**:
- `POIList Combined`: Combined-level POIs
- `POIList Input`: Channel-specific POIs
- `RenameMap`: Maps channel nuisance parameters to avoid conflicts

## Step 4: Asimov Dataset Generation

**Purpose**: Generate Asimov (expected) datasets for combined workspaces.

**Script**: `4_generate_asimov/4.genAsimov.sh`

**Configuration files**:
- `combine_CP_linear_asimov.xml`
- `combine_CP_quad_asimov.xml`

```bash
cd 4_generate_asimov
bash 4.genAsimov.sh
```

**Outputs**:
- `../combined_ws/combine_linear_asimov.root`
- `../combined_ws/combine_quad_asimov.root`

**What happens**:
1. Reads observed workspace
2. Generates Asimov dataset at SM values (all POIs = 0)
3. Creates new workspace with Asimov data

## Running the Full Pipeline

To regenerate all combined workspaces from scratch:

```bash
# 1. Setup environment
cd /project/atlas/users/mfernand/software/workspaceCombiner
source setup_lxplus.sh

# 2. Navigate to combination directory
cd /project/atlas/users/mfernand/HVV_CP_comb/3D_combination/run_combination

# 3. Run all steps in order
cd 1_ws_editing && bash 1.WSEditing.sh
cd ../2_POI_editing && bash 2.POIEditing.sh
cd ../3_ws_combine && bash 3.WSCombine.sh
cd ../4_generate_asimov && bash 4.genAsimov.sh

# 4. Verify outputs
ls -lh ../combined_ws/*.root
```

## Verification

After completion, you should have:

```
combined_ws/
├── combined_linear_obs.root     # Linear, observed data
├── combine_linear_asimov.root   # Linear, Asimov data
├── combined_quad_obs.root       # Quadratic, observed data
└── combine_quad_asimov.root     # Quadratic, Asimov data
```

Check workspace contents:

```bash
python -c "
import ROOT
f = ROOT.TFile('combined_ws/combined_linear_obs.root')
ws = f.Get('combWS')
ws.Print()
mc = ws.obj('ModelConfig')
mc.GetParametersOfInterest().Print()
"
```

Expected POIs:
- `cHWtil_combine`, `cHBtil_combine`, `cHWBtil_combine` (3D)
- Channel-specific: `cHWtil_HZZ`, `cHBtil_HWW`, etc.
- Signal strengths: `mu_Signal_HZZ`, `mu_ggF_*_HWW`, etc.

## Troubleshooting

### Missing split workspaces
- Check that `original_ws/` contains all channel ROOT files
- Verify paths in `1.WSEditing.sh` match your setup

### Combination fails
- Verify POI names match between channel and combined XML
- Check that `sys_xml_files/*.xml` RenameMap files exist
- Look for NP name conflicts in combination logs

### Asimov generation hangs
- May need to run on Condor for complex workspaces
- Check available memory (`ulimit -s unlimited`)
- Review stderr logs in `4_generate_asimov/`

## Modifying the Combination

### Adding a new channel

1. Edit `1_ws_editing/1.WSEditing.sh` to split the new channel
2. Add channel block to `combine_CP_*.xml`:
   ```xml
   <Channel Name="NewChannel" InputFile="modified_ws/newchannel.root">
     <POIList Input="cHWtil_NewChannel,..."/>
     <RenameMap InputFile="sys_xml_files/newchannel_list.xml"/>
   </Channel>
   ```
3. Create `sys_xml_files/newchannel_list.xml` for NP renaming
4. Re-run steps 3 and 4

### Changing POIs

Edit the `<POIList Combined>` line in XML files to add/remove POIs.
Ensure channel-specific POIs are updated accordingly.

## Files Reference

| File | Purpose |
|------|---------|
| `*.WSEditing.sh` | Workspace splitting automation |
| `*.POIEditing.sh` | Parameter transformation |
| `*.WSCombine.sh` | Combination execution |
| `*.genAsimov.sh` | Asimov generation |
| `combine_CP_*.xml` | Combination configuration |
| `sys_xml_files/*.xml` | NP renaming maps |
| `Combination.dtd`, `asimovUtil.dtd` | XML schemas |

## Next Steps

After generating combined workspaces, proceed to:
- `../scripts/3POI_fit/` - Run 3POI fits
- `../scripts/3POI_1D_scan/` - Run 1D likelihood scans
- `../scripts/3POI_2D_scan/` - Run 2D likelihood scans

See `../scripts/README.md` for analysis workflow.

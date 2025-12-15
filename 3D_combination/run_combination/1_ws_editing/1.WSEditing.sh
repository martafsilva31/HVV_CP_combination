cd /project/atlas/users/mfernand/software/workspaceCombiner
source setup_lxplus.sh

# linear order

# HWW
manager -w split -f /project/atlas/users/mfernand/HVV_CP_comb/3D_combination/original_ws/hWW/workspace-preFit-param-hvv-linear.root --wsName HWW_ggFVBF_DPhijj_comb --dataName obsData -i 0-71 -p /project/atlas/users/mfernand/Hcomb/HVV_CP_comb/3D_combination/modified_ws/HWW_Data.root --editRFV 2

# HTau
manager -w split -f /project/atlas/users/mfernand/HVV_CP_comb/3D_combination/original_ws/hTau/chw_chb_chwb_1NF_data_FullSyst_LinearOnly.root --wsName combined --dataName obsData -i 0-12 -p /project/atlas/users/mfernand/Hcomb/HVV_CP_comb/3D_combination/modified_ws/HTauTau_Data.root --editRFV 2

# Hbb
manager -w split -f /project/atlas/users/mfernand/HVV_CP_comb/3D_combination/original_ws/hbb/ws_cosDelta_ptw_chwtil_linear_with_pTW_NFs_v23_unblinded_with_postfitAsimov.root --wsName combined --dataName combData -i 0-32 -p /project/atlas/users/mfernand/Hcomb/HVV_CP_comb/3D_combination/modified_ws/hbb_Data.root --editRFV 2


#lin + quad

# HWW
manager -w split -f /project/atlas/users/mfernand/HVV_CP_comb/3D_combination/original_ws/hWW/workspace-preFit-param-hvv-quad.root --wsName HWW_ggFVBF_DPhijj_comb --dataName obsData -i 0-71 -p /project/atlas/users/mfernand/Hcomb/HVV_CP_comb/3D_combination/modified_ws/HWW_Data_quad.root --editRFV 2

# HTau 
manager -w split -f /project/atlas/users/mfernand/HVV_CP_comb/3D_combination/original_ws/hTau/htt_ws_DATA_crossterm_FullSyst_reparam_NEWER_VERSION.root --wsName combined --dataName obsData -i 0-12 -p /project/atlas/users/mfernand/Hcomb/HVV_CP_comb/3D_combination/modified_ws/HTauTau_Data_quad.root --editRFV 2

# Hbb
manager -w split -f /project/atlas/users/mfernand/HVV_CP_comb/3D_combination/original_ws/hbb/ws_cosDelta_ptw_chwtil_linearquadratic_with_pTW_NFs_v23_unblinded_with_postfitAsimov.root --wsName combined --dataName combData -i 0-32 -p /project/atlas/users/mfernand/Hcomb/HVV_CP_comb/3D_combination/modified_ws/hbb_Data_quad.root --editRFV 2



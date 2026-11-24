#!/bin/bash
export FSLDIR=/opt/fsl/6.0.6.5
export FSLOUTPUTTYPE=NIFTI_GZ
export PATH=$PATH:$FSLDIR/bin
export FSLVERSION=6.0.6.5 || exit -1

basedir="/m/InProcess/External/ADNI4/pijp-qasl"
config="/m/Researchers/Eliana/synb0_asl_m0.cnf"
case="$1"
inp_dir="${basedir}/${case}/INPUTS"
out_dir="${basedir}/${case}/OUTPUTS"

# create lazy binary tissue mask from b0_u (no noise outside head)
fslmaths "${out_dir}/b0_u.nii.gz" -thrp 20 -bin "${out_dir}/temp_tissue_mask.nii.gz"

# compute median intensity inside the mask for both volumes
med_d=$(fslstats "${out_dir}/b0_d_smooth.nii.gz" -k "${out_dir}/temp_tissue_mask.nii.gz" -P 50)
med_u=$(fslstats "${out_dir}/b0_u.nii.gz" -k "${out_dir}/temp_tissue_mask.nii.gz" -P 50)

# normalize both volumes to 1000
fslmaths "${out_dir}/b0_d_smooth.nii.gz" -div $med_d -mul 1000 "${out_dir}/b0_d_norm.nii.gz"
fslmaths "${out_dir}/b0_u.nii.gz" -div $med_u -mul 1000 "${out_dir}/b0_u_norm.nii.gz"
fslmerge -t "${out_dir}/b0_all_norm.nii.gz" "${out_dir}/b0_d_norm.nii.gz" "${out_dir}/b0_u_norm.nii.gz"

# run topup on normalized volumes
topup -v --imain="${out_dir}/b0_all_norm.nii.gz" --datain="${inp_dir}/acqparams.txt" --config=$config --iout="${out_dir}/b0_all_norm_topup" --out="${out_dir}/topup_norm"
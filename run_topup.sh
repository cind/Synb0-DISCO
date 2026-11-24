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

# run topup
topup -v --imain="${out_dir}/b0_all.nii.gz" --datain="${inp_dir}/acqparams.txt" --config=$config --iout="${out_dir}/b0_all_topup" --out="${out_dir}/topup"

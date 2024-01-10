#!/bin/bash

function die {
    echo "Caught signal, exiting."
    exit -1
}

trap die ERR SIGINT

# Set paths for input/output
ROOT_DIR=/m/Dev/ADNI4_wFace/synb0/Synb0-DISCO
INPUTS=$1
OUTPUTS=$2

# Set vars
VENV=0
TOPUP=1
MNI_T1_1_MM_FILE=$ROOT_DIR/atlases/mni_icbm152_t1_tal_nlin_asym_09c.nii.gz

for arg in "$@"
do
    case $arg in
        -i|--notopup)
            TOPUP=0
	        ;;
    	-s|--stripped)
	        MNI_T1_1_MM_FILE=$ROOT_DIR/atlases/mni_icbm152_t1_tal_nlin_asym_09c_mask.nii.gz
            ;;
        -v|--usevenv)
            VENV=1
            source $ROOT_DIR/venv/bin/activate
            ;;
    esac
done

# Set up freesurfer
export FSVERSION=7.3.2
export FREESURFER_HOME=/opt/freesurfer/7.3.2
source $FREESURFER_HOME/SetUpFreeSurfer.sh

# Set up FSL
export FSLVERSION=6.0.5.2
export FSLOUTPUTTYPE=NIFTI_GZ
export FSLDIR=/opt/fsl/fsl-6.0.5.2
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh

# Set up ANTS
export ANTSVERSION=ants-2017-12-07
export ANTSPATH=/opt/ants/bin
export PATH=$PATH:$ANTSPATH

# Prepare input
$ROOT_DIR/prepare_input.sh $INPUTS/b0.nii.gz $INPUTS/T1.nii.gz $MNI_T1_1_MM_FILE $ROOT_DIR/atlases/mni_icbm152_t1_tal_nlin_asym_09c_2_5.nii.gz $OUTPUTS

# Run inference
NUM_FOLDS=5
for i in $(seq 1 $NUM_FOLDS);
  do echo Performing inference on FOLD: "$i"
  python3 $ROOT_DIR/inference.py $OUTPUTS/T1_norm_lin_atlas_2_5.nii.gz $OUTPUTS/b0_d_lin_atlas_2_5.nii.gz $OUTPUTS/b0_u_lin_atlas_2_5_FOLD_"$i".nii.gz $ROOT_DIR/dual_channel_unet/num_fold_"$i"_total_folds_"$NUM_FOLDS"_seed_1_num_epochs_100_lr_0.0001_betas_\(0.9\,\ 0.999\)_weight_decay_1e-05_num_epoch_*.pth
done

# Take mean
echo Taking ensemble average
fslmerge -t $OUTPUTS/b0_u_lin_atlas_2_5_merged.nii.gz $OUTPUTS/b0_u_lin_atlas_2_5_FOLD_*.nii.gz
fslmaths $OUTPUTS/b0_u_lin_atlas_2_5_merged.nii.gz -Tmean $OUTPUTS/b0_u_lin_atlas_2_5.nii.gz

# Apply inverse xform to undistorted b0
echo Applying inverse xform to undistorted b0
antsApplyTransforms -d 3 -i $OUTPUTS/b0_u_lin_atlas_2_5.nii.gz -r $INPUTS/b0.nii.gz -n BSpline -t [$OUTPUTS/epi_reg_d_ANTS.txt,1] -t [$OUTPUTS/ANTS0GenericAffine.mat,1] -o $OUTPUTS/b0_u.nii.gz

# Smooth image
echo Applying slight smoothing to distorted b0
fslmaths $INPUTS/b0.nii.gz -s 1.15 $OUTPUTS/b0_d_smooth.nii.gz

if [[ $TOPUP -eq 1 ]]; then
    # Merge results and run through topup
    echo Running topup
    fslmerge -t $OUTPUTS/b0_all.nii.gz $OUTPUTS/b0_d_smooth.nii.gz $OUTPUTS/b0_u.nii.gz
    topup -v --imain=$OUTPUTS/b0_all.nii.gz --datain=$INPUTS/acqparams.txt --config=b02b0.cnf --iout=$OUTPUTS/b0_all_topup.nii.gz --out=$OUTPUTS/topup --subsamp=1,1,1,1,1,1,1,1,1 --miter=10,10,10,10,10,20,20,30,30 --lambda=0.00033,0.000067,0.0000067,0.000001,0.00000033,0.000000033,0.0000000033,0.000000000033,0.00000000000067 --scale=0
fi


# Done
echo FINISHED!!!

#!/bin/bash
# ELIANA'S VERSION

# Get path
ROOT_DIR=/m/Dev/ADNI4_wFace/synb0/Synb0-DISCO

# Get inputs
B0_D_PATH=$1
T1_PATH=$2
T1_BRAIN_PATH=$3
T1_ATLAS_PATH=$4
T1_ATLAS_2_5_PATH=$5
INIT_REG_PATH=$6
INIT_REG_MAT_PATH=$7
RESULTS_PATH=$8

echo -------
echo INPUTS:
echo Distorted b0 path: $B0_D_PATH
echo T1 path: $T1_PATH
echo T1 brain path: $T1_BRAIN_PATH
echo T1 atlas path: $T1_ATLAS_PATH
echo T1 2.5 iso atlas path: $T1_ATLAS_2_5_PATH
echo Results path: $RESULTS_PATH
echo Initial registration path: $INIT_REG_PATH
echo Initial registration transform path: $INIT_REG_MAT_PATH

# Create temporary job directory
JOB_PATH=$(mktemp -d)
echo -------
echo Job directory path: $JOB_PATH

# Make results directory
echo -------
echo Making results directory...
mkdir -p $RESULTS_PATH

# Normalize T1 
# using whole-head T1
echo -------
echo Normalizing T1
T1_N3_PATH=$JOB_PATH/T1_N3.nii.gz
T1_NORM_PATH=$JOB_PATH/T1_norm.nii.gz
NORM_SCRPT=$ROOT_DIR/normalize_T1.sh
NORMALIZE_CMD="$NORM_SCRPT $T1_PATH $T1_N3_PATH $T1_NORM_PATH"
echo $NORMALIZE_CMD
eval $NORMALIZE_CMD

# Convert FSL transform (initial linear M0-to-T1 registration) to ANTS transform
echo -------
echo converting FSL transform to ANTS transform
INIT_REG_MAT_ANTS_PATH=$JOB_PATH/M0_to_T1_rigid_init_ANTS.txt
C3D_TOOL_PATH=/opt/itk-snap/c3d_affine_tool
C3D_CMD="$C3D_TOOL_PATH -ref $T1_PATH -src $B0_D_PATH $INIT_REG_MAT_PATH -fsl2ras -oitk $INIT_REG_MAT_ANTS_PATH"
echo $C3D_CMD
eval $C3D_CMD


# ANTs register T1 to atlas (both must either be full T1s or stripped T1s)
# using whole-head T1
# this uses input T1 and 1mm MNI atlas, then uses the transform later to register/warp the normalized T1 to the 2.5mm MNI atlas.
# that transform is also used to register/warp the distorted M0 to the 2.5mm MNI atlas.
echo -------
echo ANTS syn registration
ANTS_OUT=$JOB_PATH/ANTS
ANTS_CMD="antsRegistrationSyNQuick.sh -d 3 -f $T1_ATLAS_PATH -m $T1_PATH -o $ANTS_OUT"
echo $ANTS_CMD
eval $ANTS_CMD

# Apply linear transform to normalized T1 to get it into atlas space
echo -------
echo Apply linear transform to T1
T1_NORM_LIN_ATLAS_2_5_PATH=$JOB_PATH/T1_norm_lin_atlas_2_5.nii.gz
APPLYTRANSFORM_CMD="antsApplyTransforms -d 3 -i $T1_NORM_PATH -r $T1_ATLAS_2_5_PATH -n BSpline -t "$ANTS_OUT"0GenericAffine.mat -o $T1_NORM_LIN_ATLAS_2_5_PATH"
echo $APPLYTRANSFORM_CMD
eval $APPLYTRANSFORM_CMD

# Apply linear transform to distorted b0 to get it into atlas space
echo -------
echo Apply linear transform to distorted b0
B0_D_LIN_ATLAS_2_5_PATH=$JOB_PATH/b0_d_lin_atlas_2_5.nii.gz
APPLYTRANSFORM_CMD="antsApplyTransforms -d 3 -i $B0_D_PATH -r $T1_ATLAS_2_5_PATH -n BSpline -t "$ANTS_OUT"0GenericAffine.mat -t $INIT_REG_MAT_ANTS_PATH -o $B0_D_LIN_ATLAS_2_5_PATH"
echo $APPLYTRANSFORM_CMD
eval $APPLYTRANSFORM_CMD

# Copy what you want to results path
echo -------
echo Copying results to results path...
cp $T1_NORM_PATH $RESULTS_PATH
cp $T1_BRAIN_PATH $RESULTS_PATH
cp $INIT_REG_MAT_ANTS_PATH $RESULTS_PATH
cp "$ANTS_OUT"0GenericAffine.mat $RESULTS_PATH
cp "$ANTS_OUT"1Warp.nii.gz $RESULTS_PATH
cp "$ANTS_OUT"1InverseWarp.nii.gz $RESULTS_PATH
cp $T1_NORM_LIN_ATLAS_2_5_PATH $RESULTS_PATH
cp $B0_D_LIN_ATLAS_2_5_PATH $RESULTS_PATH

# Delete job directory
echo -------
echo Removing job directory...
rm -rf $JOB_PATH

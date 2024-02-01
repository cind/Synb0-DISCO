#!/bin/bash

function die {
    echo "Caught signal, exiting."
    exit -1
}

trap die ERR SIGINT

# Set paths for input/output
ROOT_DIR=/m/Dev/ADNI4_wFace/synb0/Synb0-DISCO
PIPELINE_DIR=/m/Researchers/Eliana/pipelines/pijp-oxasl
INPUTS=$1
OUTPUTS=$2
source $PIPELINE_DIR/venv/bin/activate

# Run inference
NUM_FOLDS=5
for i in $(seq 1 $NUM_FOLDS);
  do echo Performing inference on FOLD: "$i"
  python3.9 $ROOT_DIR/inference.py $OUTPUTS/T1_norm_lin_atlas_2_5.nii.gz $OUTPUTS/b0_d_lin_atlas_2_5.nii.gz $OUTPUTS/b0_u_lin_atlas_2_5_FOLD_"$i".nii.gz $ROOT_DIR/dual_channel_unet/num_fold_"$i"_total_folds_"$NUM_FOLDS"_seed_1_num_epochs_100_lr_0.0001_betas_\(0.9\,\ 0.999\)_weight_decay_1e-05_num_epoch_*.pth
done


# Synb0-DISCO

## Overview

This repository implements the paper "Synthesized b0 for diffusion distortion correction" and "Distortion correction of diffusion weighted MRI without reverse phase-encoding scans or field-maps". 

This tool aims to enable susceptibility distortion correction with historical and/or limited datasets that do not include specific sequences for distortion correction (i.e. reverse phase-encoded scans). In short, we synthesize an "undistorted" b=0 image that matches the geometry of structural T1w images and also matches the contrast from diffusion images. We can then use this 'undistorted' image in standard pipelines (i.e. TOPUP) and tell the algorithm that this synthetic image has an infinite bandwidth. Note that the processing below enables both image synthesis, and also synthesis + full pipeline correction, if desired. 

Please use the following citations to refer to this work:

Schilling KG, Blaber J, Hansen C, Cai L, Rogers B, Anderson AW, Smith S, Kanakaraj P, Rex T, Resnick SM, Shafer AT, Cutting LE, Woodward N, Zald D, Landman BA. Distortion correction of diffusion weighted MRI without reverse phase-encoding scans or field-maps. PLoS One. 2020 Jul 31;15(7):e0236418. doi: 10.1371/journal.pone.0236418. PMID: 32735601; PMCID: PMC7394453.

Schilling KG, Blaber J, Huo Y, Newton A, Hansen C, Nath V, Shafer AT, Williams O, Resnick SM, Rogers B, Anderson AW, Landman BA. Synthesized b0 for diffusion distortion correction (Synb0-DisCo). Magn Reson Imaging. 2019 Dec;64:62-70. doi: 10.1016/j.mri.2019.05.008. Epub 2019 May 7. PMID: 31075422; PMCID: PMC6834894.

## CIND Usage

The SynB0-DISCO tool performs distortion correction on ASL M0 scans and is used as part of the oxasl pipeline (hosted at https://github.com/cind/pijp-oxasl/tree/develop). This repo was forked from MASILab (hosted at https://github.com/MASILab/Synb0-DISCO) in order to use the tool in limited memory environments without CUDA or Docker/Singularity containers. The main change is that it uses a newer version of PyTorch that supports mixed precision computations in inference, so that it doesn't blow up the CPU.

If you have questions or find an issue, please contact Eliana Phillips at eliana.phillips2.718@gmail.com.

## Instructions

The main script is in `pipeline.sh`. The paths are specific to CIND's file system. SynB0-DISCO requires FSL, FreeSurfer, ANTs, and c3d_affine_tool and the paths in `pipeline.sh` must point to these programs.

To run the pipeline,

```
pipeline.sh path/to/inputs path/to/outputs <flags>
```

## Flags:

**--notopup**

Skip the application of FSL's topup susceptibility correction. As a default, we run topup for you, although you may want to run this on your own (for example with your own config file, or if you would like to utilize multiple b0's).

**--stripped**

Lets the script know the supplied T1 has already been skull stripped. As a default, we assume it is not skull stripped.
Please note this feature requires a well-stripped T1 as stripping artifacts can affect performance.
It is advisable to supply both a whole-head T1 and skull-stripped T1 and not use this flag.

**--usevenv**

Activates a python virtual environment. By default this is off as it is assumed SynB0-DISCO will be run from our oxasl pipeline, to avoid clobbering with the pipeline's virtual environment. When running outside of the pipeline, this flag must be used.

## Inputs

The INPUTS directory must contain the following:
* b0.nii.gz: the raw M0 image, must be named b0 to be picked up by Synb0
* T1.nii.gz: the T1-weighted image (whole-head)
* T1_brain.nii.gz: the T1 skull stripped image
* acqparams.txt: A text file that describes the acqusition parameters, and is described in detail on the FslWiki for topup (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup). Briefly,
it describes the direction of distortion and tells TOPUP that the synthesized image has an effective echo spacing of 0 (infinite bandwidth). An example acqparams.txt is
displayed below, in which distortion is in the second dimension, note that the second row corresponds to the synthesized, undistorted, b0:
    ```
    $ cat acqparams.txt 
    0 1 0 0.062
    0 1 0 0.000
    ```
* M0_to_T1_rigid_init.nii.gz: the input (distorted) M0 image rigid registered (linear, 6 degrees of freedom) to the T1 (whole-head) using Normalized Mutual Information cost function.
* M0_to_T1_rigid_init.mat: the transform matrix generating the above image.

## Outputs

After running, the OUTPUTS directory contains the following preprocessing files:

* T1_brain.nii.gz: brain extracted (skull-stripped) T1
* T1_norm.nii.gz: normalized T1
* M0_to_T1_rigid_init_ANTS.txt: initial M0-to-T1 registration matrix in ANTS format
* ANTS0GenericAffine.mat: Affine ANTs registration of T1_norm to/from MNI space
* ANTS1Warp.nii.gz: Deformable ANTs registration of T1_norm to/from MNI space  
* ANTS1InverseWarp.nii.gz: Inverse deformable ANTs registration of T1_norm to/from MNI space  
* T1_norm_lin_atlas_2_5.nii.gz: linear transform T1 to MNI   
* b0_d_lin_atlas_2_5.nii.gz: linear transform distorted b0 in MNI space   

The OUTPUTS directory also contains inferences (predictions) for each of five folds utilizing T1_norm_lin_atlas_2_5.nii.gz and b0_d_lin_atlas_2_5.nii.gz as inputs:

* b0_u_lin_atlas_2_5_FOLD_1.nii.gz  
* b0_u_lin_atlas_2_5_FOLD_2.nii.gz  
* b0_u_lin_atlas_2_5_FOLD_3.nii.gz  
* b0_u_lin_atlas_2_5_FOLD_4.nii.gz  
* b0_u_lin_atlas_2_5_FOLD_5.nii.gz  

After inference the ensemble average is taken in atlas space:

* b0_u_lin_atlas_2_5_merged.nii.gz  
* b0_u_lin_atlas_2_5.nii.gz         

It is then moved to native space for the undistorted, synthetic output:

* b0_u.nii.gz: Synthetic b0 native space                      

The undistorted synthetic output, and a smoothed distorted input can then be stacked together for topup:

* b0_d_smooth.nii.gz: smoothed b0
* b0_all.nii.gz: stack of distorted and synthetized image as input to topup        

The topup outputs:

* topup_movpar.txt
* b0_all_topup.nii.gz
* b0_all.topup_log         
* topup_fieldcoef.nii.gz

After running Synb0, `applytopup` must be run to apply the distortion corrections to the raw ASL image. The syntax is as follows, 

```
applytopup --imain=<raw ASL> --inindex=1 --datain=acqparams.txt --topup=topup --out=<undistorted ASL> --method=jac
```

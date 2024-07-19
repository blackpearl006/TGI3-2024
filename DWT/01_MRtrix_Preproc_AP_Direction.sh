#!/bin/bash

# Written by Andrew Jahn, University of Michigan, 02.25.2019
# Updated 07.10.2020 to incorporate changes from MRtrix version 3.0.1
# Based on Marlene Tahedl's BATMAN tutorial (http://www.miccai.org/edu/finalists/BATMAN_trimmed_tutorial.pdf)
# The main difference between this script and the other one in this repository, is that this script assumes that your diffusion images were acquired with AP phase encoding
# Thanks to John Plass and Bennet Fauber for useful comments

display_usage() {
	echo "$(basename $0) [Raw Diffusion] [RevPhaseImage] [AP bvec] [AP bval] [PA bvec] [PA bval] [Anatomical]"
	echo "This script uses MRtrix to analyze diffusion data. It requires 7 arguments: 
		1) The raw diffusion image;
		2) The image acquired with the reverse phase-encoding direction;
		3) The bvec file for the data acquired in the AP direction;
		4) The bval file for the data acquired in the AP direction;
		5) The bvec file for the data acquired in the PA direction;
		6) The bval file for the data acquired in the PA direction;
		7) The anatomical image"
	}

	if [ $# -le 6 ]
	then
		display_usage
		exit 1
	fi

RAW_DWI=$1
REV_PHASE=$2
AP_BVEC=$3
AP_BVAL=$4
PA_BVEC=$5
PA_BVAL=$6
ANAT=$7


########################### STEP 1 ###################################
#	        Convert data to .mif format and denoise	   	     #
######################################################################

# Also consider doing Gibbs denoising (using mrdegibbs). Check your diffusion data for ringing artifacts before deciding whether to use it
mrconvert $RAW_DWI raw_dwi.mif -fslgrad $AP_BVEC $AP_BVAL -force
dwidenoise raw_dwi.mif dwi_den.mif -noise noise.mif -force

# Extract the b0 images from the diffusion data acquired in the AP direction
dwiextract dwi_den.mif - -bzero | mrmath - mean mean_b0_AP.mif -axis 3 -force

# Extracts the b0 images for diffusion data acquired in the PA direction
# The term "fieldmap" is taken from the output from Michigan's fMRI Lab; it is not an actual fieldmap, but rather a collection of b0 images with both PA and AP phase encoding
# For the PA_BVEC and PA_BVAL files, they should be in the follwing format (assuming you extract only one volume):
# PA_BVEC: 0 0 0
# PA_BVAL: 0
mrconvert $REV_PHASE PA.mif -force # If the PA map contains only 1 image, you will need to add the option "-coord 3 0"
mrconvert PA.mif -fslgrad $PA_BVEC $PA_BVAL - | mrmath - mean mean_b0_PA.mif -axis 3 -force

# Concatenates the b0 images from AP and PA directions to create a paired b0 image
mrcat mean_b0_AP.mif mean_b0_PA.mif -axis 3 b0_pair.mif -force

# Runs the dwipreproc command, which is a wrapper for eddy and topup. This step takes about 2 hours on an iMac desktop with 8 cores
dwifslpreproc dwi_den.mif dwi_den_preproc.mif -nocleanup -pe_dir AP -rpe_pair -se_epi b0_pair.mif -eddy_options " --slm=linear --data_is_shelled"

# Performs bias field correction. Needs ANTs to be installed in order to use the "ants" option (use "fsl" otherwise)
dwibiascorrect ants dwi_den_preproc.mif dwi_den_preproc_unbiased.mif -bias bias.mif

# Create a mask for future processing steps
dwi2mask dwi_den_preproc_unbiased.mif mask.mif


########################### STEP 2 ###################################
#             Basis function for each tissue type                    #
######################################################################

# Create a basis function from the subject's DWI data. The "dhollander" function is best used for multi-shell acquisitions; it will estimate different basis functions for each tissue type. For single-shell acquisition, use the "tournier" function instead
dwi2response dhollander dwi_den_preproc_unbiased.mif wm.txt gm.txt csf.txt -voxels voxels.mif

# Performs multishell-multitissue constrained spherical deconvolution, using the basis functions estimated above
dwi2fod msmt_csd dwi_den_preproc_unbiased.mif -mask mask.mif wm.txt wmfod.mif gm.txt gmfod.mif csf.txt csffod.mif

# Creates an image of the fiber orientation densities overlaid onto the estimated tissues (Blue=WM; Green=GM; Red=CSF)
# You should see FOD's mostly within the white matter. These can be viewed later with the command "mrview vf.mif -odf.load_sh wmfod.mif"
mrconvert -coord 3 0 wmfod.mif - | mrcat csffod.mif gmfod.mif - vf.mif

# Now normalize the FODs to enable comparison between subjects
mtnormalise wmfod.mif wmfod_norm.mif gmfod.mif gmfod_norm.mif csffod.mif csffod_norm.mif -mask mask.mif


########################### STEP 3 ###################################
#            Create a GM/WM boundary for seed analysis               #
######################################################################

# Convert the anatomical image to .mif format, and then extract all five tissue catagories (1=GM; 2=Subcortical GM; 3=WM; 4=CSF; 5=Pathological tissue)
mrconvert $ANAT anat.mif -force
5ttgen fsl anat.mif 5tt_nocoreg.mif -force

# The following series of commands will take the average of the b0 images (which have the best contrast), convert them and the 5tt image to NIFTI format, and use it for coregistration.
dwiextract dwi_den_preproc_unbiased.mif - -bzero | mrmath - mean mean_b0_processed.mif -axis 3
mrconvert mean_b0_processed.mif mean_b0_processed.nii.gz
mrconvert 5tt_nocoreg.mif 5tt_nocoreg.nii.gz -force

# Uses FSL commands fslroi and flirt to create a transformation matrix for regisitration between the tissue map and the b0 images
fslroi 5tt_nocoreg.nii.gz 5tt_vol0.nii.gz 0 1 #Extract the first volume of the 5tt dataset (since flirt can only use 3D images, not 4D images)
flirt -in mean_b0_processed.nii.gz -ref 5tt_vol0.nii.gz -interp nearestneighbour -dof 6 -omat diff2struct_fsl.mat
transformconvert diff2struct_fsl.mat mean_b0_processed.nii.gz 5tt_nocoreg.nii.gz flirt_import diff2struct_mrtrix.txt
mrtransform 5tt_nocoreg.mif -linear diff2struct_mrtrix.txt -inverse 5tt_coreg.mif

#Create a seed region along the GM/WM boundary
5tt2gmwmi 5tt_coreg.mif gmwmSeed_coreg.mif

########################### STEP 4 ###################################
#                 Run the streamline analysis                        #
######################################################################

# Create streamlines
# Note that the "right" number of streamlines is still up for debate. Last I read from the MRtrix documentation,
# They recommend about 100 million tracks. Here I use 10 million, if only to save time. Read their papers and then make a decision
tckgen -act 5tt_coreg.mif -backtrack -seed_gmwmi gmwmSeed_coreg.mif -nthreads 8 -maxlength 250 -cutoff 0.06 -select 10000000 wmfod_norm.mif tracks_10M.tck -force

# Extract a subset of tracks (here, 200 thousand) for ease of visualization
tckedit tracks_10M.tck -number 200k smallerTracks_200k.tck

# Reduce the number of streamlines with tcksift
tcksift2 -act 5tt_coreg.mif -out_mu sift_mu.txt -out_coeffs sift_coeffs.txt -nthreads 8 tracks_10M.tck wmfod_norm.mif sift_1M.txt

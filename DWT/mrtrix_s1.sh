#!/bin/bash
#SBATCH --partition=cbr_q_small
#SBATCH --ntasks=3
#SBATCH --cpus-per-task=24
#SBATCH --nodes=4
#SBATCH --output=mrtrix.log
#SBATCH --error=mrtrix.err

module load fsl-6.0.7.7
module load freesurfer-7.1.0
module load python3.11.4
source  activate mrtrix3

while read sub; do
        cp *.sh ${sub}/ses-preop/dwi; 
  	cd ${sub}/ses-preop/dwi; 
 	bash 01_MRtrix_Preproc_AP_Direction.sh ${sub}_ses-preop_acq-AP_dwi.nii.gz ${sub}_ses-preop_acq-PA_dwi.nii.gz ${sub}_ses-preop_acq-AP_dwi.bvec ${sub}_ses-preop_acq-AP_dwi.bval  ${sub}_ses-preop_acq-PA_dwi.bvec ${sub}_ses-preop_acq-PA_dwi.bval  ../anat/${sub}_ses-preop_T1w.nii.gz &
  	cd ../../..;      
done < "samples"

wait

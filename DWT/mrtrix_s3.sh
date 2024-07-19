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
         cd ${sub}/ses-preop/dwi;
         SUBJECTS_DIR=/gpfs/data/user/debanjali/MRtrix_data/${sub}/ses-preop/dwi;
         recon-all -i ../anat/${sub}_ses-preop_T1w.nii.gz -s ${sub}_recon -all -sd /gpfs/data/user/debanjali/MRtrix_data/${sub}/ses-preop/dwi &
         cd ../../..;  
done < "samples"

wait

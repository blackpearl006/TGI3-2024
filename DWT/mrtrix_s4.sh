#!/bin/bash
#SBATCH --partition=cbr_q_large
#SBATCH --ntasks=3
#SBATCH --cpus-per-task=24
#SBATCH --nodes=4
#SBATCH --output=mrtrix_4.log
#SBATCH --error=mrtrix_4.err

module load fsl-6.0.7.7
module load freesurfer-7.1.0
module load python3.11.4
source  activate mrtrix3


while read sub; do
         cp 03_MRtrix_CreateConnectome.sh ${sub}/ses-preop/dwi
         cd ${sub}/ses-preop/dwi;
         bash 03_MRtrix_CreateConnectome.sh $sub &
         cd ../../..;         

done < "samples"

wait

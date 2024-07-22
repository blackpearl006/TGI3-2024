# Automating Diffusion Data Analysis on HPC using MRtrix

## Introduction

We used the MRtrix package for analyzing diffusion data. The MRtrix tutorial is available [here](https://andysbrainbook.readthedocs.io/en/latest/MRtrix/MRtrix_Introduction.html). Manually analyzing diffusion data for each subject is tedious and prone to error. Therefore, we scripted our analysis on HPC to automate it. This document illustrates a way to run our code on HPC.

## Setting Up the Environment

1. **Create a virtual environment named `mrtrix3` and install the following tools:**
    - MRtrix
    - fsl-6.0.7.7
    - freesurfer-7.1.0
    - Python3.11.4

## Generating Connectome from Diffusion Data

1. **Create a base folder `MRTrix_data` on HPC.**

2. **Place the datasets in the `MRtrix_data` folder. The folder structure for each dataset should be like:**

    - The dataset main folder should be named with the subject name “sub-XXXXX”.
    - Inside `sub-XXXXX` folder, create a folder `ses-preop`.
    - Inside `ses-preop`, create two folders: `anat` and `dwi`.
    - Inside the `anat` folder, place the anatomical image in NIfTI format and rename it in the format:  
                  `sub-XXXXX_ses-preop_T1w.nii.gz`.
    - Inside the `dwi` folder, place the diffusion data along with b-values and b-vectors for both directions (AP & PA). Rename the files as:
        - `sub-XXXXX_ses-preop_acq-AP_dwi.nii.gz`
        - `sub-XXXXX_ses-preop_acq-PA_dwi.nii.gz`
        - `sub-XXXXX_ses-preop_acq-AP_dwi.bval`
        - `sub-XXXXX_ses-preop_acq-AP_dwi.bvec`
        - `sub-XXXXX_ses-preop_acq-PA_dwi.bval`
        - `sub-XXXXX_ses-preop_acq-PA_dwi.bvec`
         
    - **Place the datasets in the `MRtrix_data` folder. The folder structure for each dataset should be:**
    ```
    MRtrix_data/
    └── sub-XXXXX/
        └── ses-preop/
            ├── anat/
            │   └── sub-XXXXX_ses-preop_T1w.nii.gz
            └── dwi/
                ├── sub-XXXXX_ses-preop_acq-AP_dwi.nii.gz
                ├── sub-XXXXX_ses-preop_acq-PA_dwi.nii.gz
                ├── sub-XXXXX_ses-preop_acq-AP_dwi.bval
                ├── sub-XXXXX_ses-preop_acq-AP_dwi.bvec
                ├── sub-XXXXX_ses-preop_acq-PA_dwi.bval
                └── sub-XXXXX_ses-preop_acq-PA_dwi.bvec
    ```

3. **Inside the `MRtrix_data` folder, create a text file `samples` and write the names of each subject (i.e., sub-XXXXX) on separate lines and save it.**

4. **Place all the script files in the `MRtrix_data` folder:**
    - `mrtrix_s1.sh`
    - `mrtrix_s3.sh`
    - `mrtrix_s4.sh`
    - `01_MRtrix_Preproc_AP_Direction.sh`
    - `03_MRtrix_CreateConnectome.sh`

5. **Open the `mrtrix_s1.sh` bash script file and replace `cbr_q_small` with the name of the partition as per your HPC. Check the idle node (command to check: `sinfo`) in that partition and assign a node to `nodelist`.**

6. **Repeat step 5 for `mrtrix_s3.sh` and `mrtrix_s4.sh`.**

7. **Edit the path in `mrtrix_s3.sh`:**
    ```bash
    /gpfs/data/user/debanjali/MRtrix_data/${sub}/ses-preop/dwi
    ```
    This path is mentioned two times. Replace `/gpfs/data/user/debanjali` in the path with the path of the folder `MRtrix` in both instances and save it.

8. **Edit the path in `03_MRtrix_CreateConnectome.sh`:**
    ```bash
    /gpfs/data/user/debanjali/.conda/envs/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt
    ```
    This is the path for the file `fs_default.txt`. Ensure you have `fs_default.txt` in your `mrtrix3` environment. Update the path accordingly. Generally, you have to replace `/gpfs/data/user/debanjali` (the part before `.conda`).

9. **To execute the script, change the directory to `MRtrix_data` and run the command:**
    ```bash
    sbatch mrtrix_s1.sh
    ```
    Before executing this script, ensure the nodelist you have mentioned is available.

10. **If there are any errors or warnings, you can see them in the `mrtrix.err` file generated in the `MRtrix_data` folder. This script calls and executes `01_MRtrix_Preproc_AP_Direction.sh` script. It takes around two hours to complete.**

11. **After the successful execution of `mrtrix_s1.sh`, execute the script `mrtrix_s3.sh`:**
    ```bash
    sbatch mrtrix_s3.sh
    ```
    Ensure to check the idle node and update your script accordingly. It takes around five hours to complete.

12. **Lastly, run the script `mrtrix_s4.sh` using the command:**
    ```bash
    sbatch mrtrix_s4.sh
    ```
    This script executes `03_MRtrix_CreateConnectome.sh`. It takes just a few minutes to complete.

13. **After the successful execution of all the steps, the connectome matrix, representing the strength of connection between each region of the brain, is saved in a `.csv` file (`sub-XXXXX_parcels.csv`) in the `dwi` folder.**

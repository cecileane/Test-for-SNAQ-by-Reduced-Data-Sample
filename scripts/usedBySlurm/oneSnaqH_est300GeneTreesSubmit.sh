#!/bin/bash
#SBATCH -o perfect_darwin_%a.out
#SBATCH --mail-type=ALL
#SBATCH --mail-user=nji3@wisc.edu
#SBATCH --array=0-239
#SBATCH -p darwin
export JULIA_PKGDIR="/workspace/nanji/.julia"
echo $(hostname)
/usr/bin/julia /workspace/nanji/oneSnaqH.jl est300 3 30 $SLURM_ARRAY_TASK_ID

#!/usr/bin/env bash
#SBATCH --job-name=citus
#SBATCH --nodes=5
#SBATCH --ntasks-per-node=5
#SBATCH --partition=long
#SBATCH --time=120
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=e0811482@u.nus.edu

rm -rf $PGDATA
coordinator_node=$(scontrol show hostnames | head -n 1)
srun -l bash setup.sh $coordinator_node
wait
echo "LOG: Job completed at $(date +"%Y-%m-%d %H:%M:%S")"



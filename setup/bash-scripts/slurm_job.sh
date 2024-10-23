#!/usr/bin/env bash
#SBATCH --job-name=citus
#SBATCH --nodes=5
#SBATCH --ntasks-per-node=5
#SBATCH --partition=normal
#SBATCH --time=120


rm -rf $PGDATA
rm -rf ${ADD_TABLE_SIGNAL_FILE}

coordinator_node=$(scontrol show hostnames | head -n 1)
srun -l bash setup.sh $coordinator_node
wait



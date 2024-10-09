#!/usr/bin/env bash
#SBATCH --job-name=citus
#SBATCH --nodes=5
#SBATCH --ntasks-per-node=5
#SBATCH --partition=normal
#SBATCH --time=120



rm -rf $PGDATA

coordinator_node=$(scontrol show hostnames | head -n 1)
echo $coordinator_node
srun -l bash slurm_task.sh $coordinator_node
sleep 10

echo "Stop postgres"
${INSTALLDIR}/bin/pg_ctl -D $PGDATA stop
wait



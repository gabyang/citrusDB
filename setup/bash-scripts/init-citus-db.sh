#!/usr/bin/env bash

# Install Citus database directory  & configure Citus extension

# INSTALLDIR - directory containing installed binaries, libraries, etc.
INSTALLDIR=$HOME/pgsql

TEAM_ID=b # IMPORTANT: change x to your actual team identifier (a/b/.../y/z) 
TEAM_ASCII=$(echo -n "${TEAM_ID}" | od -An -tuC)
PORT_NUM=$(( 5000+${TEAM_ASCII} ))

# DATADIR - directory containing database files
DATADIR=/tmp/team${TEAM_ID}-data


mkdir -p ${DATADIR}
# ${INSTALLDIR}/bin/initdb -D ${DATADIR}
${INSTALLDIR}/bin/initdb --locale=POSIX -D ${DATADIR}

if [ -e ${DATADIR}/postgresql.conf ]; then
	grep -q citus ${DATADIR}/postgresql.conf
	if [ $? -ne 0 ]; then
		echo "shared_preload_libraries = 'citus'" >> ${DATADIR}/postgresql.conf
		echo "listen_addresses = '*'" >> ${DATADIR}/postgresql.conf
		echo "port = ${PORT_NUM}" >> ${DATADIR}/postgresql.conf
		echo "max_wal_size = 5GB" >> ${DATADIR}/postgresql.conf
	fi
else
	echo "ERROR: ${DATADIR}/postgresql.conf missing!"
fi


if [ -e ${DATADIR}/pg_hba.conf ]; then
	grep -q citus ${DATADIR}/pg_hba.conf
	if [ $? -ne 0 ]; then
		echo "host    all             all             192.168.0.0/16              	trust" >> ${DATADIR}/pg_hba.conf
	fi
else
	echo "ERROR: ${DATADIR}/pg_hba.conf missing!"
fi

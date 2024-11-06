## CS4224 Team B

## Description
This project sets up and runs a database application using PostgreSQL with Citus extensions. The following instructions cover dependencies installation, configuration, and execution.

## Prerequisites
- Python 3.x
- PostgreSQL (Citus extension will be installed)
- Slurm (if running on a cluster environment)

## Project Structure
```plaintext
.
├── code
│   ├── README.md
│   ├── bash_scripts
│   │   ├── init-citus-db.sh
│   │   ├── init-data.sh
│   │   ├── install-citus.sh
│   │   ├── setup.sh
│   │   └── slurm_job.sh
│   ├── final_transactions.py
│   ├── main.py
│   ├── metrics.py
│   ├── query_statistics.py
│   ├── requirements.txt
│   ├── run.sh
│   ├── schema_v4.sql
│   ├── throughput.py
│   ├── data_files (omitted)
│   └── xact_files (omitted)
├── config
│   └── config.txt
└── output
    ├── clients.csv
    ├── dbstate.csv
    └── throughput.csv
```

## Setup and Configuration

### 1. Install Python Dependencies
From the root directory of the project `b_project`, install all necessary Python packages:
```bash
pip install -r code/requirements.txt
```

### 2. Install PostgreSQL with Citus Extension
For the initial setup, it is required to install PostgreSQL and the Citus extension locally. This installation may take several hours:
1. Move to the `bash_scripts` directory:
   ```bash
   cd code/bash_scripts
   ```
2. Run the installation script:
   ```bash
   ./install-citus.sh
   ```

### 3. Configure Database Connection
1. Navigate to the directory containing `final_transactions.py`:
   ```bash
   cd code
   ```
2. Create a `.env` file with database configurations:
   ```plaintext
   DATABASE_HOST=localhost
   DATABASE_PORT=5098
   DATABASE_USER=cs4224b
   DATABASE_NAME=project
   ```
3. Ensure the `.env` file is saved in the same directory as `final_transactions.py`.

### 4. Run the Application
Return to the `code` directory and execute the main application script:
```bash
cd ../
./run.sh
```

## Output
The following output files will be generated and saved in the `output` directory:
- `clients.csv`
- `dbstate.csv`
- `throughput.csv`

Certainly, here’s an expanded **Troubleshooting** section for your README:

---

## Troubleshooting

- **Batch script contains DOS line breaks**: If you encounter this error, it’s due to Windows-style line endings. Run the following command to convert the file:
  ```bash
  dos2unix <filename>
  ```

- **Directory permissions**: If you face permission issues with directories or files, ensure you have the required access. You can modify permissions using the `chmod` command:
  ```bash
  chmod -R 755 ./b_project
  ```
  If full read, write, and execute permissions are required (use with caution), run:
  ```bash
  chmod -R 777 ./b_project
  ```

### Team Members
- [Merrick Neo](https://github.com/Merrickneo)
- [Gabriel Yang Yao Guang](https://github.com/gabyang)
- [Kang Yue Hern](https://github.com/yuehernkang)
- [Brandon Ng Wei Jie](https://github.com/nwjbrandon)
- [Ting Yi Xin](https://github.com/tyx021)

### Tech Stack
- Driver: `Python`
    - ORM: `psycopg2`
- Database: `Postgres@14.0`, `Citus`
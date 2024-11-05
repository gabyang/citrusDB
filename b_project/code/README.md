## CS4224 Team B

## Pre-requisites
- Python 3.8
- Postgres 14.0
- Citus 10.2

### Setup
1. Install the required python dependencies
```
pip install -r requirements.txt
```

## Project Structure
.
├── code
│   ├── README.md
│   ├── bash_scripts
│   │   ├── 1_connect_nodes.sh
│   │   ├── 2_create_tables.sh
│   │   ├── 3_insert_data.sh
│   │   └── 4_drop_tables.sh
│   ├── main.py
│   ├── requirements.txt
│   ├── schema_v4.sql
│   └── transactions.py
├── config
└── output
    ├── clients.csv
    ├── dbstate.csv
    └── throughput.csv

> @yixin: Add the bash scripts for the batch jobs, adjust the file paths as necessary🙏🏻
> After inserting the relevant files, update the project structure and code running too:>


## Running the code
```
./run.sh
```
- After the script has completed, the output files will be generated in the `output` directory

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
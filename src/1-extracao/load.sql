CREATE OR REPLACE TABLE taxi_raw AS 
SELECT * FROM 'data/raw/yellow_tripdata_2024-01.parquet';
-- tabela raw das viagens de taxi

CREATE OR REPLACE TABLE zones_raw AS
SELECT * FROM 'data/raw/taxi_zone_lookup.csv';

/* wget https://github.com/duckdb/duckdb/releases/download/v1.1.3/duckdb_cli-linux-amd64.zip
unzip duckdb_cli-linux-amd64.zip
rm duckdb_cli-linux-amd64.zip 

codigo para baixar duckdb

./duckdb base.db

codigo para iniciar duck db
*/
CREATE OR REPLACE taxi_raw AS 
SELECT * FROM 'data/raw/yellow_tripdata_2024-01.parquet';
-- tabela raw das viagens de taxi

CREATE OR REPLACE TABLE zones_raw AS
SELECT * FROM 'data/raw/taxi_zone_lookup.csv';
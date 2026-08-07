-- Entregaveis: Criação das Tabelas: yellow_taxi_raw
--                                   taxi_zones_raw

-- Puxa os dados do parquet e estrutura no banco
CREATE OR REPLACE TABLE yellow_taxi_raw AS
SELECT * FROM 'data/raw/yellow_tripdata_2024-01.parquet';

-- Puxa os dados do csv e estrutura no banco
CREATE OR REPLACE TABLE taxi_zones_raw AS
SELECT * FROM 'data/raw/taxi_zone_lookup.csv'
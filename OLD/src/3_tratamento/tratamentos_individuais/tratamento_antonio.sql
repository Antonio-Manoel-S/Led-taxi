CREATE OR REPLACE TABLE yellow_taxi_filter AS 

SELECT 
    * EXCLUDE (
        RatecodeID,
        fare_amount, 
        extra, 
        mta_tax, 
        tip_amount, 
        tolls_amount, 
        improvement_surcharge, 
        congestion_surcharge, 
        Airport_fee
    ),
    NULLIF(RatecodeID, 99) AS RatecodeID,
    (
        COALESCE(fare_amount, 0) + 
        COALESCE(extra, 0) + 
        COALESCE(mta_tax, 0) + 
        COALESCE(tip_amount, 0) + 
        COALESCE(tolls_amount, 0) + 
        COALESCE(improvement_surcharge, 0) + 
        COALESCE(congestion_surcharge, 0) + 
        COALESCE(Airport_fee, 0)
    ) AS extra_total,
CASE 
        WHEN passenger_count IS NULL 
          OR passenger_count = 0 
          OR NOT (YEAR(tpep_pickup_datetime) = 2024 AND MONTH(tpep_pickup_datetime) = 1) 
        THEN TRUE
        ELSE FALSE 
    END AS excluido

FROM yellow_taxi_raw;


CREATE OR REPLACE TABLE yellow_taxi_deleted AS 
SELECT * FROM yellow_taxi_filter 
WHERE excluido = TRUE;

CREATE OR REPLACE TABLE yellow_taxi_silver AS 
SELECT * FROM yellow_taxi_filter 
WHERE excluido = FALSE;

DROP TABLE yellow_taxi_filter;

-- TABELA ANTIGA --------------------------------------------------------------------------------






CREATE OR REPLACE TABLE yellow_taxi AS SELECT * FROM yellow_taxi_raw 
WHERE passenger_count IS NOT NULL;

/* 
Escolhi desconsiderar os campos onde o número de passageiros é nulo, 
pois uma viagem sem passageiro é bem contraditório para um banco de dado de taxis. Os 
registros foram de 2964624 para 2824462, excluindo um total de 140.162 registros.
*/

DELETE FROM yellow_taxi 
WHERE passenger_count = 0;

-- Decidi desconsiderar as viagens com zero passageiros.

DELETE FROM yellow_taxi 
WHERE NOT (YEAR(tpep_pickup_datetime) = 2024 AND MONTH(tpep_pickup_datetime) = 1);

-- Desconsiderei as viagens fora de janeiro de 2024

UPDATE yellow_taxi 
SET RatecodeID = NULL 
WHERE RatecodeID = 99;

-- padronizei onde está 99 para NULL, uma vez que o 99 é nulo dentro do dicionario

ALTER TABLE yellow_taxi ADD COLUMN extra_total DOUBLE;

-- criação da coluna com todos os extras

UPDATE yellow_taxi 
SET extra_total = (
    COALESCE(fare_amount, 0) + 
    COALESCE(extra, 0) + 
    COALESCE(mta_tax, 0) + 
    COALESCE(tip_amount, 0) + 
    COALESCE(tolls_amount, 0) + 
    COALESCE(improvement_surcharge, 0) + 
    COALESCE(congestion_surcharge, 0) + 
    COALESCE(Airport_fee, 0)
);

-- adcionado os extras
CREATE OR REPLACE TABLE yellow_taxi AS 
SELECT * EXCLUDE (
    fare_amount, 
    extra, 
    mta_tax, 
    tip_amount, 
    tolls_amount, 
    improvement_surcharge, 
    congestion_surcharge, 
    Airport_fee
) 
FROM yellow_taxi;
-- remover as colunas de taxas
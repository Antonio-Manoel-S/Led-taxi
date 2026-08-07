-- VERIFICANDO NULOS DA TABELA RAW.YELLOW_TRIPS

--Verificando nulos da tabela raw.yellow_trips

SELECT
  count(*) AS total_linhas,
  count(*) - count(passenger_count) AS nulos_passenger,
  count(*) - count(RatecodeID)      AS nulos_ratecode,
  count(*) - count(store_and_fwd_flag) AS nulos_flag,
  count(*) - count(congestion_surcharge) AS nulos_surcharge,
  count(*) - count(Airport_fee) AS nulos_airport_fee
FROM yellow_taxi_raw;
--resultado: 140162 linhas nulas em todas as colunas



-- Verificando se os nulos das colunas estão nas mesmas linhas
SELECT count(*) AS nulos_em_todas
FROM yellow_taxi_raw
WHERE passenger_count IS NULL
  AND RatecodeID IS NULL
  AND store_and_fwd_flag IS NULL
  AND congestion_surcharge IS NULL
  AND Airport_fee IS NULL;
--resultado: 140162 linhas, ou seja, os nulos das colunas estao nas mesma linhas



SELECT VendorID, count(*) AS qtd
FROM yellow_taxi_raw
WHERE passenger_count IS NULL
GROUP BY VendorID
ORDER BY qtd DESC;



-- verificando a relacao entre os nulos
SELECT DISTINCT(payment_type), tpep_pickup_datetime, tpep_dropoff_datetime, PULocationID, DOLocationID, mta_tax, total_amount 
FROM yellow_taxi_raw
WHERE passenger_count IS NULL
  AND RatecodeID IS NULL
  AND store_and_fwd_flag IS NULL
  AND congestion_surcharge IS NULL
  AND Airport_fee IS NULL
limit 20;


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--VERIFICANDO DATAS INCOMPATIVEIS DA TABELA YELLOW_TRIPS_RAW


SELECT
    MIN(tpep_pickup_datetime)  AS primeiro_pickup,
    MAX(tpep_pickup_datetime)  AS ultimo_pickup,
    MIN(tpep_dropoff_datetime) AS primeiro_dropoff,
    MAX(tpep_dropoff_datetime) AS ultimo_dropoff
FROM yellow_taxi_raw;



-- Verificando se existem datas de pickup menores que 2024-01-01 ou maiores ou iguais a 2024-02-01
SELECT tpep_pickup_datetime, tpep_dropoff_datetime
FROM yellow_taxi_raw
WHERE tpep_pickup_datetime <  TIMESTAMP '2024-01-01'
   OR tpep_pickup_datetime >= TIMESTAMP '2024-02-01';



-- Verificando quando dropoff é menor que pickup
SELECT tpep_pickup_datetime, tpep_dropoff_datetime
FROM yellow_taxi_raw
WHERE tpep_dropoff_datetime < tpep_pickup_datetime;



-- Verificando quando dropoff é igual a pickup

SELECT tpep_pickup_datetime, tpep_dropoff_datetime, store_and_fwd_flag, payment_type
FROM yellow_taxi_raw
WHERE tpep_dropoff_datetime = tpep_pickup_datetime;

-- quando store_and_fwd_flag é nulo payment_type é 0



SELECT COUNT(*) AS menor_que_um_minuto
FROM yellow_taxi_raw
WHERE date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime) > 0
  AND date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime) < 60;



SELECT
    COUNT(*) FILTER (
        WHERE passenger_count IS NULL
    ) AS passageiros_nulos,

    COUNT(*) FILTER (
        WHERE passenger_count = 0
    ) AS passageiros_zero,

    COUNT(*) FILTER (
        WHERE passenger_count < 0
    ) AS passageiros_negativos,

    COUNT(*) FILTER (
        WHERE passenger_count > 6
    ) AS passageiros_acima_de_seis,

    MAX(passenger_count) AS maior_quantidade

FROM yellow_taxi_raw;


-- Verificando valores negativos das colunas de valores monetários da tabela raw.yellow_trips
SELECT
    COUNT(*) FILTER (WHERE fare_amount < 0)
        AS fare_amount_negativo,

    COUNT(*) FILTER (WHERE extra < 0)
        AS extra_negativo,

    COUNT(*) FILTER (WHERE mta_tax < 0)
        AS mta_tax_negativo,

    COUNT(*) FILTER (WHERE tip_amount < 0)
        AS tip_amount_negativo,

    COUNT(*) FILTER (WHERE improvement_surcharge < 0)
        AS improvement_surcharge_negativo,

    COUNT(*) FILTER (WHERE total_amount < 0)
        AS total_amount_negativo,

    COUNT(*) FILTER (WHERE congestion_surcharge < 0)
        AS congestion_surcharge_negativo,

    COUNT(*) FILTER (WHERE Airport_fee < 0)
        AS airport_fee_negativo

FROM yellow_taxi_raw;

SELECT
    COUNT(*) FILTER (WHERE tolls_amount < 0)
        AS tolls_amount_negativo
FROM yellow_taxi_raw;



-- Verificando valores negativos da coluna total_amount
SELECT
    payment_type,
    COUNT(*) AS total_registros,

    COUNT(*) FILTER (
        WHERE total_amount < 0
    ) AS total_negativo
FROM yellow_taxi_raw
GROUP BY payment_type
ORDER BY total_registros DESC;

-- verificando zonas que possuem registros com airport_fee > 0 e que não são aeroportos
SELECT
    t.PULocationID,
    z.Zone,
    z.Borough,
    COUNT(*) AS total_registros
FROM yellow_taxi_raw t
JOIN taxi_zones_raw z
    ON t.PULocationID = z.LocationID
WHERE t.airport_fee > 0 
AND t.PULocationID NOT IN(
    SELECT LocationID FROM taxi_zones_raw
    WHERE Zone IN(
        'JFK Airport',
        'LaGuardia Airport'
    )
)
GROUP BY
    t.PULocationID,
    z.Borough,
    z.Zone
ORDER BY total_registros DESC;


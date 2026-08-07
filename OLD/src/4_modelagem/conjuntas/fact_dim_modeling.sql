-- 1. DIMENSÃO DE VENDOR
CREATE OR REPLACE TABLE dim_vendor AS
SELECT *
FROM (
    VALUES
        (1, 'Creative Mobile Technologies, LLC'),
        (2, 'Curb Mobility, LLC'),
        (6, 'Myle Technologies Inc'),
        (7, 'Helix')
) AS vendor(vendor_id, vendor_name);

-- 2. DIMENSÃO DE TARIFA
CREATE OR REPLACE TABLE dim_tarifa AS
SELECT *
FROM (
    VALUES
        (1,  'Standard rate'),
        (2,  'JFK'),
        (3,  'Newark'),
        (4,  'Nassau or Westchester'),
        (5,  'Negotiated fare'),
        (6,  'Group ride'),
        (99, 'Null/unknown')
) AS tarifa(ratecode_id, ratecode_description);


-- 3. DIMENSÃO DE PAGAMENTO
CREATE OR REPLACE TABLE dim_pagamento AS
SELECT *
FROM (
    VALUES
        (0, 'Flex Fare trip'),
        (1, 'Credit card'),
        (2, 'Cash'),
        (3, 'No charge'),
        (4, 'Dispute'),
        (5, 'Unknown'),
        (6, 'Voided trip')
) AS pagamento(payment_type_id, payment_description);


-- 4. DIMENSÃO DE CALENDÁRIO
CREATE OR REPLACE TABLE dim_calendario AS
WITH datas AS (
    SELECT CAST(tpep_pickup_datetime AS DATE) AS full_date FROM yellow_taxi_silver
    UNION
    SELECT CAST(tpep_dropoff_datetime AS DATE) AS full_date FROM yellow_taxi_silver
)
SELECT
    CAST(STRFTIME(full_date, '%Y%m%d') AS INTEGER) AS data_key,
    full_date,
    YEAR(full_date) AS year,
    MONTH(full_date) AS month,
    MONTHNAME(full_date) AS month_name,
    DAY(full_date) AS day,
    DAYNAME(full_date) AS day_of_week,
    CASE
        WHEN DAYOFWEEK(full_date) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM datas
WHERE full_date IS NOT NULL
ORDER BY full_date;


-- 5. DIMENSÃO DE HORA
CREATE OR REPLACE TABLE dim_hora AS
SELECT
    hora AS hora_key,
    hora AS hora_do_dia,
    CASE
        WHEN hora BETWEEN 0 AND 5 THEN 'Madrugada'
        WHEN hora BETWEEN 6 AND 11 THEN 'Manhã'
        WHEN hora BETWEEN 12 AND 17 THEN 'Tarde'
        ELSE 'Noite'
    END AS turno_dia,
    CASE
        WHEN hora BETWEEN 7 AND 9 OR hora BETWEEN 16 AND 19 THEN TRUE
        ELSE FALSE
    END AS eh_horario_pico
FROM RANGE(0, 24) AS horas(hora)
ORDER BY hora;


-- 6. DIMENSÃO DE LOCALIZAÇÃO (Com TRIM e Tratamento de Nulos)
CREATE OR REPLACE TABLE dim_localizacao AS
SELECT
    CAST("LocationID" AS INTEGER) AS location_id,
    COALESCE(NULLIF(TRIM(CAST("Borough" AS VARCHAR)), ''), 'Unknown') AS borough,
    CASE 
        WHEN "LocationID" = 264 THEN 'NV / Desconhecido'
        WHEN "LocationID" = 265 THEN 'Fora de NYC / Outros'
        ELSE COALESCE(NULLIF(TRIM(CAST("Zone" AS VARCHAR)), ''), 'Desconhecido')
    END AS zone_name,
    COALESCE(NULLIF(TRIM(CAST("service_zone" AS VARCHAR)), ''), 'Unknown') AS service_zone
FROM taxi_zones_raw

UNION ALL

SELECT
    264 AS location_id,
    'Unknown' AS borough,
    'NV / Desconhecido' AS zone_name,
    'Unknown' AS service_zone
WHERE NOT EXISTS (SELECT 1 FROM taxi_zones_raw WHERE "LocationID" = 264)

UNION ALL

SELECT
    265 AS location_id,
    'Unknown' AS borough,
    'Fora de NYC / Outros' AS zone_name,
    'Unknown' AS service_zone
WHERE NOT EXISTS (SELECT 1 FROM taxi_zones_raw WHERE "LocationID" = 265)

ORDER BY location_id;


-- 7. TABELA FATO 
CREATE OR REPLACE TABLE fato_viagens AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            s.tpep_pickup_datetime,
            s.tpep_dropoff_datetime,
            s.VendorID,
            s.PULocationID,
            s.DOLocationID,
            s.payment_type,
            s.trip_distance,
            s.total_amount_reconciled
    ) AS viagem_id,

    -- Chaves das dimensões de tempo
    calendario_pickup.data_key AS data_key_pickup,
    calendario_dropoff.data_key AS data_key_dropoff,
    hora_pickup.hora_key AS hora_key_pickup,

    -- Chaves naturais / FKs diretas sem depender de JOIN
    s.VendorID AS vendor_id,
    COALESCE(s.PULocationID, 264) AS location_id_pickup,
    COALESCE(s.DOLocationID, 264) AS location_id_dropoff,
    s.RatecodeID_clean AS ratecode_id,
    s.payment_type AS payment_type_id,

    -- Dados do evento
    s.tpep_pickup_datetime,
    s.tpep_dropoff_datetime,
    s.store_and_fwd_flag_clean AS store_and_fwd_flag,
    s.tipo_transacao,

    -- Medidas operacionais (Aproveitadas direto da Silver)
    s.passenger_count_clean AS passenger_count,
    s.trip_distance,
    s.trip_duration_seconds,
    s.average_speed_mph,

    -- Medidas financeiras
    s.fare_amount,
    s.extra,
    s.mta_tax,
    s.tip_amount,
    s.tolls_amount,
    s.improvement_surcharge,
    s.congestion_surcharge,
    s.Airport_fee AS airport_fee,
    s.total_amount_reconciled

FROM yellow_taxi_silver AS s

LEFT JOIN dim_calendario AS calendario_pickup
    ON calendario_pickup.full_date = CAST(s.tpep_pickup_datetime AS DATE)

LEFT JOIN dim_calendario AS calendario_dropoff
    ON calendario_dropoff.full_date = CAST(s.tpep_dropoff_datetime AS DATE)

LEFT JOIN dim_hora AS hora_pickup
    ON hora_pickup.hora_key = HOUR(s.tpep_pickup_datetime);
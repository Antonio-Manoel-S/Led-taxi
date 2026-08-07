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
    SELECT
        CAST(tpep_pickup_datetime AS DATE) AS full_date
    FROM yellow_taxi_silver

    UNION

    SELECT
        CAST(tpep_dropoff_datetime AS DATE) AS full_date
    FROM yellow_taxi_silver
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
        WHEN DAYOFWEEK(full_date) IN (0, 6)
        THEN TRUE
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
        WHEN hora BETWEEN 7 AND 9 OR hora BETWEEN 16 AND 19
        THEN TRUE
        ELSE FALSE
    END AS eh_horario_pico

FROM RANGE(0, 24) AS horas(hora)
ORDER BY hora;

-- 6. DIMENSÃO DE LOCALIZAÇÃO

CREATE OR REPLACE TABLE dim_localizacao AS

SELECT
    CAST("LocationID" AS INTEGER) AS location_id,
    CAST("Borough" AS VARCHAR) AS borough,
    CAST("Zone" AS VARCHAR) AS zone_name,
    CAST("service_zone" AS VARCHAR) AS service_zone
FROM taxi_zones_raw

UNION ALL

SELECT
    264 AS location_id,
    'Unknown' AS borough,
    'N/A' AS zone_name,
    'N/A' AS service_zone
WHERE NOT EXISTS (
    SELECT 1
    FROM taxi_zones_raw
    WHERE "LocationID" = 264
)

UNION ALL

SELECT
    265 AS location_id,
    'N/A' AS borough,
    'Outside of NYC' AS zone_name,
    'N/A' AS service_zone
WHERE NOT EXISTS (
    SELECT 1
    FROM taxi_zones_raw
    WHERE "LocationID" = 265
)

ORDER BY location_id;

-- VALIDAÇÕES DAS DIMENSÕES

-- Quantidade de linhas em cada dimensão
SELECT 'dim_vendor' AS tabela, COUNT(*) AS quantidade
FROM dim_vendor

UNION ALL

SELECT 'dim_tarifa', COUNT(*)
FROM dim_tarifa

UNION ALL

SELECT 'dim_pagamento', COUNT(*)
FROM dim_pagamento

UNION ALL

SELECT 'dim_calendario', COUNT(*)
FROM dim_calendario

UNION ALL

SELECT 'dim_hora', COUNT(*)
FROM dim_hora

UNION ALL

SELECT 'dim_localizacao', COUNT(*)
FROM dim_localizacao;


-- Verificar o unknown member e a localização fora de NYC
SELECT *
FROM dim_localizacao
WHERE location_id IN (264, 265)
ORDER BY location_id;


-- As consultas abaixo não devem retornar nenhuma linha.

SELECT vendor_id, COUNT(*) AS quantidade
FROM dim_vendor
GROUP BY vendor_id
HAVING COUNT(*) > 1;

SELECT ratecode_id, COUNT(*) AS quantidade
FROM dim_tarifa
GROUP BY ratecode_id
HAVING COUNT(*) > 1;

SELECT payment_type_id, COUNT(*) AS quantidade
FROM dim_pagamento
GROUP BY payment_type_id
HAVING COUNT(*) > 1;

SELECT data_key, COUNT(*) AS quantidade
FROM dim_calendario
GROUP BY data_key
HAVING COUNT(*) > 1;

SELECT hora_key, COUNT(*) AS quantidade
FROM dim_hora
GROUP BY hora_key
HAVING COUNT(*) > 1;

SELECT location_id, COUNT(*) AS quantidade
FROM dim_localizacao
GROUP BY location_id
HAVING COUNT(*) > 1;
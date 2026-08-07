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

    -- Chaves naturais das dimensões
    vendor.vendor_id,

    COALESCE(
        local_pickup.location_id,
        264
    ) AS location_id_pickup,

    COALESCE(
        local_dropoff.location_id,
        264
    ) AS location_id_dropoff,

    tarifa.ratecode_id,
    pagamento.payment_type_id,

    -- Dados do evento
    s.tpep_pickup_datetime,
    s.tpep_dropoff_datetime,
    s.store_and_fwd_flag_clean AS store_and_fwd_flag,
    s.tipo_transacao,

    -- Medidas operacionais
    s.passenger_count_clean AS passenger_count,
    s.trip_distance,

    DATEDIFF(
        'second',
        s.tpep_pickup_datetime,
        s.tpep_dropoff_datetime
    ) AS trip_duration_seconds,

    s.trip_distance
    /
    (
        DATEDIFF(
            'second',
            s.tpep_pickup_datetime,
            s.tpep_dropoff_datetime
        ) / 3600.0
    ) AS average_speed_mph,

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
    ON calendario_pickup.full_date
       = CAST(s.tpep_pickup_datetime AS DATE)

LEFT JOIN dim_calendario AS calendario_dropoff
    ON calendario_dropoff.full_date
       = CAST(s.tpep_dropoff_datetime AS DATE)

LEFT JOIN dim_hora AS hora_pickup
    ON hora_pickup.hora_key
       = HOUR(s.tpep_pickup_datetime)

LEFT JOIN dim_vendor AS vendor
    ON vendor.vendor_id
       = s.VendorID

LEFT JOIN dim_localizacao AS local_pickup
    ON local_pickup.location_id
       = s.PULocationID

LEFT JOIN dim_localizacao AS local_dropoff
    ON local_dropoff.location_id
       = s.DOLocationID

LEFT JOIN dim_tarifa AS tarifa
    ON tarifa.ratecode_id
       = s.RatecodeID_clean

LEFT JOIN dim_pagamento AS pagamento
    ON pagamento.payment_type_id
       = s.payment_type;

-- VALIDAÇÕES DA TABELA FATO

-- 1. A fato deve ter a mesma quantidade de linhas da Silver.
SELECT
    (SELECT COUNT(*) FROM yellow_taxi_silver) AS total_silver,
    (SELECT COUNT(*) FROM fato_viagens) AS total_fato,

    (SELECT COUNT(*) FROM yellow_taxi_silver) -
    (SELECT COUNT(*) FROM fato_viagens) AS diferenca;


-- 2. viagem_id deve ser único.
SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT viagem_id) AS ids_distintos,
    COUNT(*) - COUNT(DISTINCT viagem_id) AS ids_duplicados
FROM fato_viagens;


-- 3. As chaves abaixo não devem ficar nulas.
SELECT
    COUNT(*) FILTER (
        WHERE data_key_pickup IS NULL
    ) AS data_pickup_nula,

    COUNT(*) FILTER (
        WHERE data_key_dropoff IS NULL
    ) AS data_dropoff_nula,

    COUNT(*) FILTER (
        WHERE hora_key_pickup IS NULL
    ) AS hora_pickup_nula,

    COUNT(*) FILTER (
        WHERE vendor_id IS NULL
    ) AS vendor_nulo,

    COUNT(*) FILTER (
        WHERE location_id_pickup IS NULL
    ) AS local_pickup_nulo,

    COUNT(*) FILTER (
        WHERE location_id_dropoff IS NULL
    ) AS local_dropoff_nulo,

    COUNT(*) FILTER (
        WHERE ratecode_id IS NULL
    ) AS tarifa_nula,

    COUNT(*) FILTER (
        WHERE payment_type_id IS NULL
    ) AS pagamento_nulo

FROM fato_viagens;


-- 4. Códigos de localização sem correspondência antes do COALESCE.
SELECT
    COUNT(*) FILTER (
        WHERE local_pickup.location_id IS NULL
    ) AS pickup_sem_correspondencia,

    COUNT(*) FILTER (
        WHERE local_dropoff.location_id IS NULL
    ) AS dropoff_sem_correspondencia

FROM yellow_taxi_silver AS s

LEFT JOIN dim_localizacao AS local_pickup
    ON local_pickup.location_id = s.PULocationID

LEFT JOIN dim_localizacao AS local_dropoff
    ON local_dropoff.location_id = s.DOLocationID;


-- 5. Todas as chaves da fato devem encontrar uma dimensão.
SELECT
    COUNT(*) FILTER (
        WHERE calendario_pickup.data_key IS NULL
    ) AS data_pickup_orfa,

    COUNT(*) FILTER (
        WHERE calendario_dropoff.data_key IS NULL
    ) AS data_dropoff_orfa,

    COUNT(*) FILTER (
        WHERE hora_pickup.hora_key IS NULL
    ) AS hora_pickup_orfa,

    COUNT(*) FILTER (
        WHERE vendor.vendor_id IS NULL
    ) AS vendor_orfao,

    COUNT(*) FILTER (
        WHERE local_pickup.location_id IS NULL
    ) AS local_pickup_orfao,

    COUNT(*) FILTER (
        WHERE local_dropoff.location_id IS NULL
    ) AS local_dropoff_orfao,

    COUNT(*) FILTER (
        WHERE tarifa.ratecode_id IS NULL
    ) AS tarifa_orfa,

    COUNT(*) FILTER (
        WHERE pagamento.payment_type_id IS NULL
    ) AS pagamento_orfao

FROM fato_viagens AS fato

LEFT JOIN dim_calendario AS calendario_pickup
    ON calendario_pickup.data_key = fato.data_key_pickup

LEFT JOIN dim_calendario AS calendario_dropoff
    ON calendario_dropoff.data_key = fato.data_key_dropoff

LEFT JOIN dim_hora AS hora_pickup
    ON hora_pickup.hora_key = fato.hora_key_pickup

LEFT JOIN dim_vendor AS vendor
    ON vendor.vendor_id = fato.vendor_id

LEFT JOIN dim_localizacao AS local_pickup
    ON local_pickup.location_id = fato.location_id_pickup

LEFT JOIN dim_localizacao AS local_dropoff
    ON local_dropoff.location_id = fato.location_id_dropoff

LEFT JOIN dim_tarifa AS tarifa
    ON tarifa.ratecode_id = fato.ratecode_id

LEFT JOIN dim_pagamento AS pagamento
    ON pagamento.payment_type_id = fato.payment_type_id;
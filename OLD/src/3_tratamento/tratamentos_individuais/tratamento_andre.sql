DROP TABLE IF EXISTS yellow_taxi_classified;

CREATE TABLE yellow_taxi_classified AS

WITH base AS (
    SELECT
        *,

        DATEDIFF(
            'second',
            tpep_pickup_datetime,
            tpep_dropoff_datetime
        ) AS trip_duration_seconds

    FROM yellow_taxi_raw
)

SELECT
    VendorID,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance,

    COALESCE(RatecodeID, 99) AS RatecodeID,

    store_and_fwd_flag,
    PULocationID,
    DOLocationID,
    payment_type,

    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,

    COALESCE(
        congestion_surcharge,
        0.0
    ) AS congestion_surcharge,

    COALESCE(
        Airport_fee,
        0.0
    ) AS Airport_fee,

    trip_duration_seconds,

    CASE
        WHEN trip_duration_seconds > 0
         AND trip_distance IS NOT NULL
        THEN trip_distance /
             (trip_duration_seconds / 3600.0)

        ELSE NULL
    END AS average_speed_mph,

    CASE
        WHEN payment_type IN (3, 4)
          OR fare_amount < 0
          OR total_amount < 0
        THEN 'Estorno/Disputa'

        ELSE 'Regular'
    END AS tipo_transacao,

    (
        fare_amount
        + extra
        + mta_tax
        + tip_amount
        + tolls_amount
        + improvement_surcharge
        + COALESCE(congestion_surcharge, 0.0)
        + COALESCE(Airport_fee, 0.0)
    ) AS total_amount_reconciled,

    -- A REGRA DE VALIDADE É DEFINIDA UMA ÚNICA VEZ
    CASE
        WHEN tpep_pickup_datetime IS NOT NULL
         AND tpep_dropoff_datetime IS NOT NULL
         AND trip_distance IS NOT NULL

         AND tpep_pickup_datetime
                >= TIMESTAMP '2024-01-01 00:00:00'

         AND tpep_pickup_datetime
                < TIMESTAMP '2024-02-01 00:00:00'

         AND trip_distance > 0

         AND trip_duration_seconds > 0

         AND trip_distance * 36.0
                <= trip_duration_seconds

        THEN TRUE
        ELSE FALSE
    END AS eh_valido,

    -- MOTIVO PRINCIPAL DA REJEIÇÃO
    CASE
        WHEN tpep_pickup_datetime IS NULL
        THEN 'Pickup nulo'

        WHEN tpep_dropoff_datetime IS NULL
        THEN 'Dropoff nulo'

        WHEN tpep_pickup_datetime
                < TIMESTAMP '2024-01-01 00:00:00'
          OR tpep_pickup_datetime
                >= TIMESTAMP '2024-02-01 00:00:00'
        THEN 'Pickup fora de janeiro de 2024'

        WHEN trip_distance IS NULL
        THEN 'Distância nula'

        WHEN trip_distance <= 0
        THEN 'Distância menor ou igual a zero'

        WHEN trip_duration_seconds <= 0
        THEN 'Duração menor ou igual a zero'

        WHEN trip_distance * 36.0
                > trip_duration_seconds
        THEN 'Velocidade média superior a 100 mph'

        ELSE NULL
    END AS rejection_reason

FROM base;

DROP TABLE IF EXISTS yellow_taxi_clean;

CREATE TABLE yellow_taxi_clean AS

SELECT
    * EXCLUDE (
        eh_valido,
        rejection_reason
    )

FROM yellow_taxi_classified

WHERE eh_valido = TRUE;

DROP TABLE IF EXISTS yellow_taxi_rejected;

CREATE TABLE yellow_taxi_rejected AS

SELECT
    * EXCLUDE (eh_valido)

FROM yellow_taxi_classified

WHERE eh_valido = FALSE;
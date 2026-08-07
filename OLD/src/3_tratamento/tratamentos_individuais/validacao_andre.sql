--VERIFICA A DIFERENÇA ENTRE O TOTAL DE REGISTROS DA TABELA RAW, CLEAN E REJECTED

SELECT
    (SELECT COUNT(*) FROM yellow_taxi_raw) AS total_raw,
    (SELECT COUNT(*) FROM yellow_taxi_clean) AS total_clean,
    (SELECT COUNT(*) FROM yellow_taxi_rejected) AS total_rejected,

    (SELECT COUNT(*) FROM yellow_taxi_raw)
    - (SELECT COUNT(*) FROM yellow_taxi_clean)
    - (SELECT COUNT(*) FROM yellow_taxi_rejected) AS diferenca;

-- VERRIFICA PROBLEMAS NA TABELA CLEAN
-- Todos os resultados devem ser 0

SELECT
    COUNT(*) FILTER (
        WHERE tpep_pickup_datetime IS NULL
           OR tpep_dropoff_datetime IS NULL
    ) AS datas_nulas,

    COUNT(*) FILTER (
        WHERE tpep_pickup_datetime < TIMESTAMP '2024-01-01 00:00:00'
           OR tpep_pickup_datetime >= TIMESTAMP '2024-02-01 00:00:00'
    ) AS datas_fora_do_periodo,

    COUNT(*) FILTER (
        WHERE trip_distance IS NULL
           OR trip_distance <= 0
    ) AS distancias_invalidas,

    COUNT(*) FILTER (
        WHERE trip_duration_seconds <= 0
    ) AS duracoes_invalidas,

    COUNT(*) FILTER (
        WHERE trip_distance * 36.0 > trip_duration_seconds
    ) AS velocidades_invalidas

FROM yellow_taxi_clean;

-- VERIFICA DADOS VALIDOS NA TABELA REJECTED
-- Resultado deve ser 0

SELECT COUNT(*) AS registros_validos_na_rejected
FROM yellow_taxi_rejected
WHERE tpep_pickup_datetime IS NOT NULL
  AND tpep_dropoff_datetime IS NOT NULL
  AND trip_distance IS NOT NULL
  AND tpep_pickup_datetime >= TIMESTAMP '2024-01-01 00:00:00'
  AND tpep_pickup_datetime < TIMESTAMP '2024-02-01 00:00:00'
  AND trip_distance > 0
  AND trip_duration_seconds > 0
  AND trip_distance * 36.0 <= trip_duration_seconds;

-- VERIFICA SE EXISTEM REGISTROS REJEITADOS SEM MOTIVO
-- Resultado deve ser 0

SELECT COUNT(*) AS rejeitados_sem_motivo
FROM yellow_taxi_rejected
WHERE rejection_reason IS NULL;

-- VERIFICA OS CAMPOS TRATADOS
-- Resultado deve ser 0

SELECT
    COUNT(*) FILTER (
        WHERE RatecodeID IS NULL
    ) AS ratecode_nulo,

    COUNT(*) FILTER (
        WHERE total_amount_reconciled IS NULL
    ) AS total_reconciled_nulo

FROM yellow_taxi_clean;

-- VERIFICA O MOTIVO DA QUARENTENA

SELECT
    rejection_reason,
    COUNT(*) AS quantidade
FROM yellow_taxi_rejected
GROUP BY rejection_reason
ORDER BY quantidade DESC;
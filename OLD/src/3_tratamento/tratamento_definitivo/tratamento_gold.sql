-- Limpeza inicial do banco de dados para evitar conflitos de reexecução
DROP TABLE IF EXISTS yellow_taxi_silver;
DROP TABLE IF EXISTS yellow_taxi_rejected;
DROP TABLE IF EXISTS temp_taxi_classified;

-- Tabela Temporária de Classificação (Feature Engineering + Regras de Qualidade)
CREATE TEMPORARY TABLE temp_taxi_classified AS
WITH base_calculada AS (
    SELECT 
        *,
        -- Cálculo isolado da duração para reuso nas regras de velocidade e qualidade
        EXTRACT(EPOCH FROM (tpep_dropoff_datetime - tpep_pickup_datetime)) AS trip_duration_seconds
    FROM yellow_taxi_raw
)
SELECT 
    -- IDENTIFICAÇÃO BÁSICA
    VendorID,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    
    -- TRATAMENTO DE PASSAGEIROS (Regra retirada do script do Mateus: Salva vans e rastreia zeros)
    CASE 
        WHEN passenger_count IS NULL THEN 1
        WHEN passenger_count = 0 THEN 0
        WHEN passenger_count > 9 THEN 1
        ELSE passenger_count 
    END AS passenger_count_clean,
    
    trip_distance,
    
    -- TRATAMENTO DE NULOS / PADRONIZAÇÃO (Regra retirada do script do Mateus: Salvação de Receita)
    COALESCE(RatecodeID, 99) AS RatecodeID_clean,
    COALESCE(store_and_fwd_flag, 'U') AS store_and_fwd_flag_clean,
    
    -- CHAVES GEOGRÁFICAS
    PULocationID,
    DOLocationID,
    
    -- MÉTRICAS DERIVADAS (Retirada do Script de André: Facilita análises de tráfego futuras)
    trip_duration_seconds,
    CASE 
        WHEN trip_duration_seconds > 0 AND trip_distance > 0 
        THEN (trip_distance / (trip_duration_seconds / 3600.0))
        ELSE NULL 
    END AS average_speed_mph,
    
    -- INFORMAÇÕES FINANCEIRAS GRANULARES MANTIDAS
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    COALESCE(congestion_surcharge, 0.0) AS congestion_surcharge,
    COALESCE(Airport_fee, 0.0) AS Airport_fee,
    
    -- CLASSIFICAÇÃO DE RECEITA
    CASE 
        WHEN payment_type IN (3, 4) OR fare_amount < 0 OR total_amount < 0 THEN 'Estorno/Disputa'
        ELSE 'Regular'
    END AS tipo_transacao,
    
    -- CONCILIAÇÃO FINANCEIRA
    (
        fare_amount + extra + mta_tax + tip_amount + 
        tolls_amount + improvement_surcharge + 
        COALESCE(congestion_surcharge, 0.0) + COALESCE(Airport_fee, 0.0)
    ) AS total_amount_reconciled,

    -- MOTOR DE REGRAS (Data Quality Gate)
    CASE 
        WHEN tpep_pickup_datetime >= '2024-01-01 00:00:00' 
         AND tpep_pickup_datetime < '2024-02-01 00:00:00'
         AND trip_distance > 0
         AND trip_duration_seconds > 0
         AND (trip_distance * 36.0) <= trip_duration_seconds
        THEN TRUE
        ELSE FALSE
    END AS eh_valido,

    -- MOTIVO DA REJEIÇÃO (Arquitetura de Auditoria do André)
    CASE 
        WHEN tpep_pickup_datetime < '2024-01-01 00:00:00' OR tpep_pickup_datetime >= '2024-02-01 00:00:00' 
            THEN 'Fora do escopo (Jan/2024)'
        WHEN trip_distance <= 0 
            THEN 'Distância inválida (<= 0)'
        WHEN trip_duration_seconds <= 0 
            THEN 'Duração inválida (<= 0 ou retrógrada)'
        WHEN (trip_distance * 36.0) > trip_duration_seconds 
            THEN 'Velocidade impossível (> 100 mph)'
        ELSE NULL
    END AS motivo_rejeicao

FROM base_calculada;


-- CAMADA SILVER (Apenas os dados validados)
CREATE TABLE yellow_taxi_silver AS
SELECT * EXCLUDE (eh_valido, motivo_rejeicao)
FROM temp_taxi_classified
WHERE eh_valido = TRUE;

-- TABELA DE QUARENTENA (Para auditoria técnica de telemetria e GPS)
CREATE TABLE yellow_taxi_rejected AS
SELECT * EXCLUDE (eh_valido)
FROM temp_taxi_classified
WHERE eh_valido = FALSE;

-- Limpeza de Memória Cache (Destruição da tabela temporária)
DROP TABLE temp_taxi_classified;

****DROP TABLE IF EXISTS yellow_taxi_silver;

CREATE TABLE yellow_taxi_silver AS
SELECT 
    -- 1. IDENTIFICAÇÃO E DOMÍNIO
    VendorID,
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    
    -- 2. TRATAMENTO REFINADO DE PASSAGEIROS 
    CASE 
        WHEN passenger_count IS NULL THEN 1             
        WHEN passenger_count = 0 THEN 0                  
        WHEN passenger_count > 9 THEN 1                
        ELSE passenger_count 
    END AS passenger_count_clean,
    
    trip_distance,
    COALESCE(RatecodeID, 99) AS RatecodeID_clean,        
    COALESCE(store_and_fwd_flag, 'U') AS store_and_fwd_flag_clean,
    
    -- 3. CHAVES GEOGRÁFICAS
    PULocationID,
    DOLocationID,
    
    -- 4. INFORMAÇÕES FINANCEIRAS E CONCILIAÇÃO MÍNIMA
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    COALESCE(congestion_surcharge, 0.0) AS congestion_surcharge,
    COALESCE(Airport_fee, 0.0) AS Airport_fee,
    
    -- Sinalização de Estornos/Reembolsos 
    CASE 
        WHEN payment_type IN (3, 4) OR fare_amount < 0 OR total_amount < 0 THEN 'Estorno/Disputa'
        ELSE 'Regular'
    END AS tipo_transacao,
    
    -- Conciliação matemática forçada respeitando o sinal original da tarifa
    (
        fare_amount + extra + mta_tax + tip_amount + 
        tolls_amount + improvement_surcharge + 
        COALESCE(congestion_surcharge, 0.0) + COALESCE(Airport_fee, 0.0)
    ) AS total_amount_reconciled

FROM yellow_taxi_raw

-- 5. FILTROS ESTRITOS DE LIMPEZA DE RUÍDO
WHERE 
    -- Filtro Temporal Absoluto (Mateus/André)
    tpep_pickup_datetime >= '2024-01-01 00:00:00' 
    AND tpep_pickup_datetime < '2024-02-01 00:00:00'
    
    -- Filtro Operacional Físico: Remove distâncias inválidas (Mateus) e tempos zerados/retrógrados
    AND trip_distance > 0
    AND EXTRACT(EPOCH FROM (tpep_dropoff_datetime - tpep_pickup_datetime)) > 0
    
    -- Filtro de Física: Remove velocidades impossíveis (> 100 mph) sem divisões complexas
    AND (trip_distance * 36.0) <= EXTRACT(EPOCH FROM (tpep_dropoff_datetime - tpep_pickup_datetime));
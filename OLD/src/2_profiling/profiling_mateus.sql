-- Verificações ----------------------------------------

-- Temporal (Ano)
SELECT 
    YEAR(tpep_pickup_datetime) AS ano,
    MONTH(tpep_pickup_datetime) AS mes,
    COUNT(*) AS qtd_viagens
FROM yellow_taxi_raw
GROUP BY ano, mes
ORDER BY qtd_viagens DESC;

-- Espacial (Zonas de embarque desconhecidas ou chave de loc não tem na tabela de referência de zonas)
SELECT 
    COUNT(*) FILTER (WHERE PULocationID IN (264, 265)) AS locais_embarque_desconhecidos, -- !
    COUNT(*) FILTER (WHERE DOLocationID IN (264, 265)) AS locais_desembarque_desconhecidos, -- !
    COUNT(*) FILTER (WHERE PULocationID NOT IN (SELECT LocationID FROM taxi_zones_raw)) AS pul_orfaos,
    COUNT(*) FILTER (WHERE DOLocationID NOT IN (SELECT LocationID FROM taxi_zones_raw)) AS dol_orfaos
FROM yellow_taxi_raw y
LEFT JOIN taxi_zones_raw p ON y.PULocationID = p.LocationID
LEFT JOIN taxi_zones_raw d ON y.DOLocationID = d.LocationID;

-- Distância e Duração (viagêns com distâncias inválidas e/ou qtd passageiros inválidos e/ou tempos de viagem impossíveis)
SELECT 
    COUNT(*) FILTER (WHERE trip_distance <= 0) AS viagens_distancia_invalida,                            
    COUNT(*) FILTER (WHERE tpep_dropoff_datetime <= tpep_pickup_datetime) AS viagens_tempo_invalido,     
    COUNT(*) FILTER (WHERE passenger_count <= 0) AS viagens_sem_passageiros,                             
    COUNT(*) FILTER (WHERE passenger_count IS NULL) AS viagens_passageiros_nulos                         
FROM yellow_taxi_raw;

-- Valores coerentes (O valor pago pelo cliente faz sentido sendo a som des outros valores)
SELECT 
    COUNT(*) FILTER (WHERE fare_amount < 0) AS tarifas_negativas,                                       
    COUNT(*) FILTER (WHERE total_amount < 0) AS totais_negativos,                                       
    COUNT(*) FILTER (
        WHERE ABS(                                                                                   
            total_amount - (                                                                           
                fare_amount +                                                                         
                extra +                                                                                
                mta_tax +                                                                              
                tip_amount +                                                                           
                tolls_amount +                                                                         
                improvement_surcharge +                                                                
                congestion_surcharge +                                                                 
                COALESCE(Airport_fee, 0)                                                                
            )
        ) > 0.01                                                                                        
    ) AS divergencias_matematicas_totais                                                                
FROM yellow_taxi_raw; -- O 0.01 é para considerar pequenas diferenças de arredondamento que podem ocorrer em cálculos de ponto flutuante. 

-- Validação dos dominios do dicionário
SELECT 
    COUNT(*) FILTER (WHERE VendorID NOT IN (1, 2, 6, 7)) AS provedores_invalidos,                      
    COUNT(*) FILTER (WHERE RatecodeID NOT IN (1, 2, 3, 4, 5, 6, 99)) AS tarifas_invalidas,              
    COUNT(*) FILTER (WHERE payment_type NOT IN (0, 1, 2, 3, 4, 5, 6)) AS tipos_pagamento_invalidos     
FROM yellow_taxi_raw;

-- Validação de velocidade irreal
SELECT 
    COUNT(*) FILTER (
        WHERE trip_distance > 0                                                                        
          AND tpep_dropoff_datetime > tpep_pickup_datetime                                             
          -- Cálculo: Distância (milhas) / Tempo (convertido de segundos para horas) > 100.0 mph
          AND (trip_distance / (epoch(tpep_dropoff_datetime - tpep_pickup_datetime) / 3600.0)) > 100.0
    ) AS viagens_com_velocidade_impossivel  -- Conta quantas viagens ultrapassaram o limite físico de 100 mph
FROM yellow_taxi_raw;

-- Validações estruturais

    -- Duplicidade total de linhas
SELECT 
    (SELECT COUNT(*) FROM yellow_taxi_raw) AS total_linhas,
    (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM yellow_taxi_raw)) AS linhas_unicas,
    (SELECT COUNT(*) FROM yellow_taxi_raw) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM yellow_taxi_raw)) AS linhas_duplicadas;

    -- Mapeamento de nulos por coluna (Com Sum pra a memória não explodir)
SELECT
    SUM(CASE WHEN VendorID IS NULL THEN 1 ELSE 0 END) AS null_VendorID,
    SUM(CASE WHEN tpep_pickup_datetime IS NULL THEN 1 ELSE 0 END) AS null_pickup_time,
    SUM(CASE WHEN tpep_dropoff_datetime IS NULL THEN 1 ELSE 0 END) AS null_dropoff_time,
    SUM(CASE WHEN passenger_count IS NULL THEN 1 ELSE 0 END) AS null_passenger_count,
    SUM(CASE WHEN trip_distance IS NULL THEN 1 ELSE 0 END) AS null_trip_distance,
    SUM(CASE WHEN RatecodeID IS NULL THEN 1 ELSE 0 END) AS null_RatecodeID,
    SUM(CASE WHEN store_and_fwd_flag IS NULL THEN 1 ELSE 0 END) AS null_store_flag,
    SUM(CASE WHEN PULocationID IS NULL THEN 1 ELSE 0 END) AS null_PULocationID,
    SUM(CASE WHEN DOLocationID IS NULL THEN 1 ELSE 0 END) AS null_DOLocationID,
    SUM(CASE WHEN payment_type IS NULL THEN 1 ELSE 0 END) AS null_payment_type,
    SUM(CASE WHEN total_amount IS NULL THEN 1 ELSE 0 END) AS null_total_amount
FROM yellow_taxi_raw;

    -- Cardinalidade e valores distintos 
SELECT
    COUNT(DISTINCT VendorID) AS provedores_unicos,                                     
    COUNT(DISTINCT RatecodeID) AS tarifas_unicas_encontradas,                           
    COUNT(DISTINCT PULocationID) AS zonas_de_embarque_ativas,                          
    COUNT(DISTINCT DOLocationID) AS zonas_de_desembarque_ativas   
FROM yellow_taxi_raw;                     
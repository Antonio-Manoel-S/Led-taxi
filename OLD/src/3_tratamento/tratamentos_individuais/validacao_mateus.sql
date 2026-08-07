-- -----------------------------------------------------------------------------------------
-- AUDITORIA 1: ESCOPO TEMPORAL E DIAGNÓSTICO GERAL
-- Objetivo: Garantir que a base está estritamente restrita a Janeiro/2024 e checar o volume final.
-- -----------------------------------------------------------------------------------------
SELECT 
    COUNT(*) AS total_linhas_silver,                            -- Quantidade total de registros na Silver
    MIN(tpep_pickup_datetime) AS data_minima_pickup,             -- Deve ser exatamente 2024-01-01 00:00:00
    MAX(tpep_pickup_datetime) AS data_maxima_pickup              -- Deve ser no máximo 2024-01-31 23:59:55+
FROM yellow_taxi_silver;


-- -----------------------------------------------------------------------------------------
-- AUDITORIA 2: INTEGRIDADE DA REGRA DE PASSAGEIROS (INSIGHTS ANTONIO / ANDRÉ)
-- Objetivo: Verificar se os nulos sumiram, se os zeros foram mantidos e se vans grandes (7 a 9) existem.
-- -----------------------------------------------------------------------------------------
SELECT 
    COUNT(*) FILTER (WHERE passenger_count_clean IS NULL) AS nulos_restantes,       -- Deve retornar 0
    COUNT(*) FILTER (WHERE passenger_count_clean = 0) AS zeros_preservados,         -- Deve bater as ~31 mil linhas do André
    COUNT(*) FILTER (WHERE passenger_count_clean BETWEEN 7 AND 9) AS vans_grandes,  -- Deve mostrar os casos reais mapeados pelo Antonio
    COUNT(*) FILTER (WHERE passenger_count_clean > 9) AS absurdos_acima_de_9        -- Deve retornar 0 (tudo acima de 9 foi limpo)
FROM yellow_taxi_silver;


-- -----------------------------------------------------------------------------------------
-- AUDITORIA 3: TOLERÂNCIA ZERO PARA RUÍDO FÍSICO (MATEUS)
-- Objetivo: Confirmar que o filtro barrou TODAS as anomalias físicas. 
-- ATENÇÃO: Todas as colunas deste bloco DEVEM retornar ZERO.
-- -----------------------------------------------------------------------------------------
SELECT 
    COUNT(*) FILTER (WHERE trip_distance <= 0) AS erro_distancia_zero_ou_negativa,
    COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (tpep_dropoff_datetime - tpep_pickup_datetime)) <= 0) AS erro_tempo_zero_ou_retrogrado,
    COUNT(*) FILTER (WHERE (trip_distance * 36.0) > EXTRACT(EPOCH FROM (tpep_dropoff_datetime - tpep_pickup_datetime))) AS erro_velocidade_impossivel
FROM yellow_taxi_silver;


-- -----------------------------------------------------------------------------------------
-- AUDITORIA 4: CONCILIAÇÃO FINANCEIRA E DISTRIBUIÇÃO DE TRANSAÇÕES (INSIGHT ANDRÉ)
-- Objetivo: Avaliar o impacto da separação entre corridas normais e estornos.
-- Mostra a volumetria, média de tarifa e faturamento de cada categoria criada.
-- -----------------------------------------------------------------------------------------
SELECT 
    tipo_transacao,                                              -- Agrupa pelas categorias: 'Regular' ou 'Estorno/Disputa'
    COUNT(*) AS qtd_corridas,                                    -- Quantidade de registros em cada categoria
    ROUND(AVG(fare_amount), 2) AS media_tarifa,                  -- Média do valor da corrida por tipo
    ROUND(SUM(total_amount_reconciled), 2) AS faturamento_total  -- Soma perfeita e limpa do faturamento
FROM yellow_taxi_silver
GROUP BY tipo_transacao;

-- Auditar os dados aprovados na Silver e analisar os dados retidos na Quarentena.

SELECT 
    COUNT(*) AS total_viagens_validas,
    MIN(tpep_pickup_datetime) AS data_minima_pickup,
    MAX(tpep_pickup_datetime) AS data_maxima_pickup,
    SUM(CASE WHEN passenger_count_clean IS NULL THEN 1 ELSE 0 END) AS nulos_passageiros,
    SUM(CASE WHEN RatecodeID_clean IS NULL THEN 1 ELSE 0 END) AS nulos_ratecode
FROM yellow_taxi_silver;

SELECT 
    motivo_rejeicao,
    COUNT(*) AS volume_rejeitado,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM yellow_taxi_rejected)), 2) AS percentual_do_lixo
FROM yellow_taxi_rejected
GROUP BY motivo_rejeicao
ORDER BY volume_rejeitado DESC;

SELECT 
    COUNT(*) FILTER (WHERE passenger_count_clean = 0) AS viagens_canceladas_ou_zero,
    COUNT(*) FILTER (WHERE passenger_count_clean BETWEEN 7 AND 9) AS viagens_em_vans_grandes,
    COUNT(*) FILTER (WHERE passenger_count_clean > 9) AS erros_acima_de_9
FROM yellow_taxi_silver;

SELECT 
    tipo_transacao,
    COUNT(*) AS qtd_corridas,
    ROUND(AVG(trip_duration_seconds / 60.0), 2) AS duracao_media_minutos,
    ROUND(AVG(average_speed_mph), 2) AS velocidade_media_mph,
    ROUND(SUM(total_amount_reconciled), 2) AS faturamento_liquido
FROM yellow_taxi_silver
GROUP BY tipo_transacao;
-- 1. PERSPECTIVA TEMPORAL & RITMO DA CIDADE
-- Decisão: Mapear a distribuição de corridas e faturamento por turno e horário de pico.
-- Motivo: Permite a empresa programar tarifas dinâmicas (surge pricing) e enviar alertas
-- de escassez de motoristas para os horários de maior demanda.

SELECT 
    h.turno_dia,
    h.eh_horario_pico,
    COUNT(f.viagem_id) AS total_corridas,
    ROUND(SUM(f.total_amount_reconciled), 2) AS faturamento_total,
    ROUND(AVG(f.total_amount_reconciled), 2) AS ticket_medio
FROM fato_viagens f
INNER JOIN dim_hora h ON f.hora_key_pickup = h.hora_key
GROUP BY h.turno_dia, h.eh_horario_pico
ORDER BY total_corridas DESC;

-- Decisão: Comparar o volume de viagens e a duração média por dia da semana e fim de semana.
-- Motivo: Ajuda na alocação da frota urbana, identificando se a operação no fim de
-- semana exige estratégias de atratividade para motoristas em horários alternativos.

SELECT 
    c.day_of_week,
    c.is_weekend,
    COUNT(f.viagem_id) AS total_corridas,
    ROUND(AVG(f.trip_duration_seconds / 60.0), 2) AS duracao_media_minutos
FROM fato_viagens f
INNER JOIN dim_calendario c ON f.data_key_pickup = c.data_key
GROUP BY c.day_of_week, c.is_weekend, c.day
ORDER BY total_corridas DESC;

-- 2. PERSPECTIVA GEOGRÁFICA & FLUXOS URBANOS
-- Decisão: Mapear o Top 10 de rotas mais frequentes (Origem x Destino).
-- Motivo: Revela os principais corredores de mobilidade de NY (ex: bairros centrais e
-- aeroportos), permitindo parcerias comerciais e pontos fixos de embarque no app.

SELECT 
    loc_origem.zone_name AS zona_origem,
    loc_destino.zone_name AS zona_destino,
    COUNT(f.viagem_id) AS qtd_corridas,
    ROUND(AVG(f.trip_distance), 2) AS distancia_media_milhas,
    ROUND(SUM(f.total_amount_reconciled), 2) AS receita_total_rota
FROM fato_viagens f
INNER JOIN dim_localizacao loc_origem ON f.location_id_pickup = loc_origem.location_id
INNER JOIN dim_localizacao loc_destino ON f.location_id_dropoff = loc_destino.location_id
GROUP BY loc_origem.zone_name, loc_destino.zone_name
ORDER BY qtd_corridas DESC
LIMIT 10;

-- Decisão: Agrupar o volume e faturamento por Distrito (Borough) de origem.
-- Motivo: Identifica quais distritos sustentam a receita da empresa e quais áreas
-- estão desatendidas (oportunidades de expansão territorial).
SELECT 
    loc.borough AS distrito_origem,
    COUNT(f.viagem_id) AS total_corridas,
    ROUND(SUM(f.total_amount_reconciled), 2) AS faturamento_distrito,
    ROUND(AVG(f.total_amount_reconciled), 2) AS ticket_medio_distrito
FROM fato_viagens f
INNER JOIN dim_localizacao loc ON f.location_id_pickup = loc.location_id
GROUP BY loc.borough
ORDER BY faturamento_distrito DESC;

-- 3. PERSPECTIVA FINANCEIRA & PRECIFICAÇÃO

-- Decisão: Decompor o faturamento bruto em todos os seus componentes tarifários.
-- Motivo: Fornece transparência financeira à diretoria, mostrando o peso real da tarifa
-- base versus taxas regulatórias (MTA, aeroportos, congestionamento) e gorjetas.

SELECT 
    ROUND(SUM(fare_amount), 2) AS tarifa_base_total,
    ROUND(SUM(tip_amount), 2) AS gorjetas_total,
    ROUND(SUM(tolls_amount), 2) AS pedagios_total,
    ROUND(SUM(congestion_surcharge), 2) AS taxa_congestionamento_total,
    ROUND(SUM(airport_fee), 2) AS taxa_aeroporto_total,
    ROUND(SUM(mta_tax + extra + improvement_surcharge), 2) AS impostos_e_outros_totais,
    ROUND(SUM(total_amount_reconciled), 2) AS faturamento_bruto_reconciliado
FROM fato_viagens;

-- Decisão: Analisar a taxa de retenção de gorjeta por forma de pagamento.
-- Motivo: Comprova a hipótese de mercado de que pagamentos digitais (cartão) incentivam
-- o recebimento de gorjetas em relação ao pagamento em dinheiro.

SELECT 
    p.payment_description AS forma_pagamento,
    COUNT(f.viagem_id) AS qtd_corridas,
    ROUND(SUM(f.tip_amount), 2) AS total_gorjeta,
    ROUND(AVG(f.tip_amount), 2) AS gorjeta_media,
    ROUND(AVG(CASE WHEN f.fare_amount > 0 THEN (f.tip_amount / f.fare_amount) * 100 ELSE 0 END), 2) AS pct_medio_gorjeta_sobre_tarifa
FROM fato_viagens f
INNER JOIN dim_pagamento p ON f.payment_type_id = p.payment_type_id
GROUP BY p.payment_description
ORDER BY total_gorjeta DESC;

-- Decisão: Medir o volume e impacto financeiro das transações de Estorno/Disputa.
-- Motivo: Isola perdas operacionais e estornos na camada analítica, apoiando a equipe de
-- risco e prevenção a fraudes do aplicativo.
SELECT 
    f.tipo_transacao,
    COUNT(f.viagem_id) AS qtd_transacoes,
    ROUND(SUM(f.total_amount_reconciled), 2) AS valor_total,
    ROUND((COUNT(f.viagem_id) * 100.0 / (SELECT COUNT(*) FROM fato_viagens)), 2) AS pct_do_total_corridas
FROM fato_viagens f
GROUP BY f.tipo_transacao;

-- 4. PERSPECTIVA OPERACIONAL & EFICIÊNCIA DA FROTA

-- Decisão: Avaliar o impacto do horário de pico na velocidade média e tempo de corrida.
-- Motivo: Alimenta o algoritmo de estimativa de tempo de chegada (ETA) do aplicativo
-- para evitar falsas promessas de horário aos usuários.

SELECT 
    h.eh_horario_pico,
    ROUND(AVG(f.average_speed_mph), 2) AS velocidade_media_mph,
    ROUND(AVG(f.trip_duration_seconds / 60.0), 2) AS duracao_media_minutos,
    ROUND(AVG(f.trip_distance), 2) AS distancia_media_milhas
FROM fato_viagens f
INNER JOIN dim_hora h ON f.hora_key_pickup = h.hora_key
GROUP BY h.eh_horario_pico;


-- Decisão: Analisar a taxa de ocupação dos veículos e corridas com 0 passageiros.
-- Motivo: Avalia a eficiência da frota e dimensiona o volume de cancelamentos ou
-- transporte de mercadorias/entregas sem passageiros.
SELECT 
    f.passenger_count AS qtd_passageiros,
    COUNT(f.viagem_id) AS total_viagens,
    ROUND((COUNT(f.viagem_id) * 100.0 / (SELECT COUNT(*) FROM fato_viagens)), 2) AS pct_representacao
FROM fato_viagens f
GROUP BY f.passenger_count
ORDER BY f.passenger_count ASC;



-- 5. PERSPECTIVA ESTRATÉGICA & MARKET SHARE

-- Decisão: Mapear a distribuição de mercado e faturamento por Provedor de Tecnologia (Vendor).
-- Motivo: Auxilia a diretoria em negociações B2B e contratos de integração técnica com
-- os fornecedores dos taxímetros e hardware de bordo.
SELECT 
    v.vendor_name AS provedor_tecnologia,
    COUNT(f.viagem_id) AS volume_corridas,
    ROUND(SUM(f.total_amount_reconciled), 2) AS faturamento_gerado,
    ROUND((COUNT(f.viagem_id) * 100.0 / (SELECT COUNT(*) FROM fato_viagens)), 2) AS market_share_pct
FROM fato_viagens f
INNER JOIN dim_vendor v ON f.vendor_id = v.vendor_id
GROUP BY v.vendor_name
ORDER BY volume_corridas DESC;

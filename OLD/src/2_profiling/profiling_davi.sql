-- =====================================================================
-- Profiling - Davi
-- Foco: distancia, forma de pagamento e zonas geograficas
-- (angulos ainda nao cobertos por Mateus, Andre e Antonio)
-- Rodar sempre depois de: .read src/extracao/extract_load.sql
-- =====================================================================


-- 1) DISTANCIA DA VIAGEM (trip_distance) -------------------------------
SELECT MIN(trip_distance) AS min_dist,
       MAX(trip_distance) AS max_dist,
       ROUND(AVG(trip_distance), 2) AS media_dist
FROM yellow_taxi_raw;

/* A distancia media e 3.65 milhas, o que faz sentido para corridas
   urbanas. O problema esta nos extremos: o minimo e 0 e o maximo e
   312722.3 milhas (daria mais de 12 voltas na Terra numa unica corrida).
   Sao valores impossiveis - provavel falha de sensor/GPS. */

SELECT COUNT(*) AS dist_zero_ou_negativa
FROM yellow_taxi_raw
WHERE trip_distance <= 0;

/* Existem 60.371 corridas com distancia zero ou negativa, ou seja,
   viagens sem deslocamento fisico. Sugestao de tratamento: na camada
   de limpeza, filtrar trip_distance > 0 (bate com o que o Mateus propos
   no filtro de invalidez fisica). */


-- 2) FORMA DE PAGAMENTO (payment_type) ---------------------------------
SELECT payment_type, COUNT(*) AS qtd
FROM yellow_taxi_raw
GROUP BY payment_type
ORDER BY qtd DESC;

/* Distribuicao encontrada:
     1 (Cartao de credito) .... 2.319.046
     2 (Dinheiro) ..............  439.191
     0 (nao documentado) .......  140.162
     4 (Disputa) ...............   46.628
     3 (Sem cobranca) ..........   19.597
   Dois pontos importantes:
   - O codigo 0 NAO existe no dicionario de dados oficial (os validos
     vao de 1 a 6). E os 140.162 registros com payment_type = 0 sao
     exatamente a mesma quantidade de nulos que o grupo achou em
     passenger_count. Ou seja: sao as mesmas linhas "orfas" de
     telemetria. Tratamento sugerido: mapear o 0 como "Desconhecido"
     (unknown member), sem apagar, para nao perder a receita da corrida.
   - Cartao domina o pagamento (mais de 80% das corridas). */


-- 3) ZONAS GEOGRAFICAS (PULocationID / DOLocationID) -------------------
SELECT COUNT(DISTINCT PULocationID) AS zonas_origem,
       COUNT(DISTINCT DOLocationID) AS zonas_destino
FROM yellow_taxi_raw;

/* Aparecem 260 zonas de origem e 261 de destino distintas. A tabela de
   referencia taxi_zones_raw tem 265 zonas possiveis, entao quase todas
   sao usadas. Isso mostra que PULocationID/DOLocationID sao codigos que
   precisam ser traduzidos via JOIN com taxi_zones_raw (viram uma
   dim_zona no modelo dimensional da Fase 4). */


-- 4) DUPLICATAS EXATAS -------------------------------------------------
SELECT COUNT(*) AS total,
       (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM yellow_taxi_raw)) AS distintas
FROM yellow_taxi_raw;

/* total = 2.964.624 e distintas = 2.964.624. Nao ha nenhuma linha
   totalmente duplicada na base bruta. Boa noticia: nao precisamos de
   deduplicacao na camada de limpeza. */

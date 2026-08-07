-- Profilling - Antonio
-- Passo 1: Coletar as tabelas Raw.
CREATE OR REPLACE TABLE yellow_taxi_raw AS
SELECT * FROM 'data/raw/yellow_tripdata_2024-01.parquet';
-- Tabela raw dos Tripdata, as viagens dos taxi.

CREATE OR REPLACE TABLE taxi_zones_raw AS
SELECT * FROM 'data/raw/taxi_zone_lookup.csv';
-- Tabela raw das zonas de taxi.

-- Passo 2: Sumário geral da tabela, ter panorama para ter noção da tabela.
DESCRIBE yellow_taxi_raw;

SUMMARIZE SELECT * FROM yellow_taxi_raw ;

/* 
1. Observações Pessoais -

A principio, em testes anteriores, achei que não teria nulos através de "coluna IS NULL", 
 onde eu achei estranho e pedi ajuda por ter dado alguma coisa errada, foi onde Mateus me 
 sugeriu usar summarize. Cheguei a conclusão que as três primeiras colunas não possuem de 
 fato, nulos para ser comparados, e o Summarize me ajudou a ter essa noção. Eu tinha inserido 
 SELECT geral sem SUMMARIZE para verificar visualmente se tinha nulos nas primeiras colunas, 
 só que me levou a um equivoco... o DUCKDB cria uma espécie de "reticencias" entre as 
 linhas e colunas! para mostrar uma parte do começo e outra parte do fim, o Duckdb cria 3 
 linhas com "." (pontos) para mostrar que as linhas continuam, mas eu interpretei como se 
tivesse 3 linhas nulas.  

Códigos auxiliares - duck db

.mode line 

 modo para ver em linhas e evitar omissão de tabelas

 SELECT passenger_count FROM yellow_taxi_raw LIMIT 5;
 
 exemplo de visualização de linhas
*/

-- profiling após criado a tabela silver yellow_taxi (ainda com dados raw)

-- analise da coluna de passsageiros

SELECT DISTINCT passenger_count, COUNT(passenger_count) FROM yellow_taxi
GROUP BY passenger_count;

/* 
Esse código conta os número de passageiros, e nele consta 31465 registros com 0
passageiros, o que é curioso.
Eu também pude observar que teve uma viagem com 9 passageiros, 51 viagens com 8
passageiros e 7 viagens com 8 passageiros. O que é curioso, porque geralmente
um táxi pode comportar, em teoria, até 4 passageiros. 3 atrás e um do lado do
motorista, e mesmo assim tem registro de 5 e 6 passageiros, provavelmente de 
carros com 2 assentos a mais ou com crianças de colo contando, mas de 7 a 9
pessoas num carro de taxi é um caso isolado, ou um erro de registro. 
*/

--------------------------------------------------------------------------------

-- analise DATETIMES

SELECT tpep_pickup_datetime FROM yellow_taxi_raw 
ORDER BY tpep_pickup_datetime ASC LIMIT 10;

/* 
Ao selecionar os 10 primeiros valores de forma ascendente, 
encontrei dois registros de 2002, 3 de 2009 e 10 registros de 2023, 
especificamente na virada de ano, no dia 31-12-2023 
*/

SELECT tpep_pickup_datetime, tpep_dropoff_datetime, 
  (tpep_dropoff_datetime - tpep_pickup_datetime) 
  AS duracao_viagem FROM yellow_taxi_raw ORDER BY duracao_viagem ASC LIMIT 20;

-- Aqui verifiquei que tem 8 viagens com duração negativa

SELECT COUNT(*) AS total_viagens_zeradas
  FROM yellow_taxi_raw
  WHERE tpep_pickup_datetime = tpep_dropoff_datetime;

  -- Aqui constou 681 viagens com 0 segundos, pode ser corridas canceladas.

SELECT COUNT(*) AS total_viagens_ate_30_segundos
FROM yellow_taxi_raw
WHERE date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime) <= 30;

/* Aqui retornou 26603 viagens com menos de 30 segundos, o que é em 
teoria impossível de acontecer de forma cotidiana, no entanto, pode ser
cancelamento. */

SELECT tpep_pickup_datetime FROM yellow_taxi_raw
WHERE NOT (YEAR(tpep_pickup_datetime) = 2024 AND MONTH(tpep_pickup_datetime) = 1)
  ORDER BY tpep_pickup_datetime ASC LIMIT 20;

-- aqui verifiquei 18 registros fora de janeiro de 2024
---------------------------------------------------------------------------------------

-- analise trip_distance

SELECT trip_distance FROM yellow_taxi 
  ORDER BY trip_distance ASC LIMIT 10;

-- A partir daqui notei que tinha muitos 0

SELECT COUNT (*) FROM yellow_taxi_raw WHERE trip_distance = 0 
  GROUP BY trip_distance;

  -- aqui foi contado mais de 60371 registros
-------------------------------------------------------------------------

-- analise RatecodeID

 SELECT 
        RatecodeID, 
        COUNT(*) AS contagem
    FROM yellow_taxi 
    GROUP BY RatecodeID;

    /* verifiquei registros com 99, nulos de acordo com o dicionario. 
    No entanto, esse nulo não é padrão. Portanto, transformei em nulos padrões */
---------------------------------------------------------------------------------


--analise custos e total amount

    SELECT 
    total_amount,
    -- Soma de todos os componentes
    (
        COALESCE(fare_amount, 0) + 
        COALESCE(extra, 0) + 
        COALESCE(mta_tax, 0) + 
        COALESCE(tip_amount, 0) + 
        COALESCE(tolls_amount, 0) + 
        COALESCE(improvement_surcharge, 0) + 
        COALESCE(congestion_surcharge, 0) + 
        COALESCE(Airport_fee, 0)
    ) AS total_calculado,
    -- Mostra a diferença cobrada a mais ou a menos
    ROUND(
        total_amount - (
            COALESCE(fare_amount, 0) + 
            COALESCE(extra, 0) + 
            COALESCE(mta_tax, 0) + 
            COALESCE(tip_amount, 0) + 
            COALESCE(tolls_amount, 0) + 
            COALESCE(improvement_surcharge, 0) + 
            COALESCE(congestion_surcharge, 0) + 
            COALESCE(Airport_fee, 0)
        ), 2
    ) AS diferenca
FROM 
    yellow_taxi_raw;
-- calculo das taxas comparando com total_amount

SELECT 
    COUNT(*)
FROM 
    yellow_taxi_raw
WHERE 
    ROUND(
        total_amount - (
            COALESCE(fare_amount, 0) + 
            COALESCE(extra, 0) + 
            COALESCE(mta_tax, 0) + 
            COALESCE(tip_amount, 0) + 
            COALESCE(tolls_amount, 0) + 
            COALESCE(improvement_surcharge, 0) + 
            COALESCE(congestion_surcharge, 0) + 
            COALESCE(Airport_fee, 0)
        ), 2
    ) != 0;
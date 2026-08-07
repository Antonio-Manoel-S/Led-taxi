CREATE TABLE dim_vendor AS
SELECT * FROM (
VALUES
        (1, 'Creative Mobile Technologies, LLC'),
        (2, 'Curb Mobility, LLC'),
        (6, 'Myle Technologies Inc'),
        (7, 'Helix')
) AS vendor(vendor_id, vendor_name);
-- tabela vendor, com cada empresa prestadora do serviço de taxi
CREATE OR REPLACE TABLE dim_tarifa AS
SELECT *
FROM (
    VALUES
        (1,  'Standard rate'),
        (2,  'JFK'),
        (3,  'Newark'),
        (4,  'Nassau or Westchester'),
        (5,  'Negotiated fare'),
        (6,  'Group ride'),
        (99, 'Null/unknown')
) AS tarifa(ratecode_id, ratecode_description);
-- tabela rate code

CREATE OR REPLACE TABLE dim_pagamento AS
SELECT *
FROM (
    VALUES
        (0, 'Flex Fare trip'),
        (1, 'Credit card'),
        (2, 'Cash'),
        (3, 'No charge'),
        (4, 'Dispute'),
        (5, 'Unknown'),
        (6, 'Voided trip')
) AS pagamento(payment_type_id, payment_description);

-- tabela pagamentos



--calendario

CREATE OR REPLACE TABLE dim_localizacao AS
SELECT
LocationID,
CASE 
        WHEN "LocationID" = 264 THEN 'Unknown'
        WHEN "LocationID" = 265 THEN 'Outside of NYC'
        ELSE "Borough"
    END AS Borough,
CASE 
        WHEN "LocationID" = 264 THEN 'Unknown'
        WHEN "LocationID" = 265 THEN 'Outside of NYC'
        ELSE "Zone"
    END AS Zone

from taxi_zones_raw;
    --dimensao localizacao

--TABELA FATO

CREATE OR REPLACE TABLE viagens AS 
select
ROW_NUMBER() OVER (
        ORDER BY
            s.VendorID,
            s.tpep_pickup_datetime,
            s.tpep_dropoff_datetime,
            s.passenger_count,
            s.trip_distance,
            s.store_and_fwd_flag,
            s.PULocationID,
            s.DOLocationID,
            s.payment_type,
            s.total_amount,
            s.RatecodeID,
            s.extra_total
    ) AS viagem_id,

    --CALENDARIOO
vendor.vendor_id,
vendor.vendor_name,
--vendor id

pickup.LocationID as pickup_local,
pickup.Borough as bairro_pickup,
dropoff.LocationID as dropoff_local,
dropoff.Borough as bairro_dropoff,
--local

tarifa.ratecode_id as tarifaID,
tarifa.ratecode_description as tarifa, 

--ratecode id

s.tpep_pickup_datetime as hora_pickup,
s.tpep_dropoff_datetime as hora_dropoff,

--pickup e dropoff
s.store_and_fwd_flag,
--store and fwd

s.passenger_count,

-- passenger count

ROUND(s.trip_distance * 1.60934, 2) || ' km' AS trip_distance_km,

-- tripdistance transformada em km + string do km
ROUND(s.extra_total, 2) as total_reconciliado,
-- financeiras


FROM yellow_taxi_silver AS s

LEFT JOIN dim_vendor AS vendor
    ON vendor.vendor_id
       = s.VendorID

LEFT JOIN dim_tarifa AS tarifa
    ON tarifa.ratecode_id
       = s.RatecodeID

LEFT JOIN dim_pagamento AS pagamento
    ON pagamento.payment_type_id
       = s.payment_type

LEFT JOIN dim_localizacao AS pickup
    ON pickup.LocationID
       = s.PULocationID

LEFT JOIN dim_localizacao AS dropoff
    ON dropoff.LocationID
       = s.DOLocationID ;


--validacaos ----------------------------------------

select * from taxi_zones_raw order by LocationID desc LIMIT 30;
select * from dim_localizacao order by LocationID desc LIMIT 30;
-- validacao da taxi zones  

select * from viagens;

-- validacao da tabela
SELECT * EXCLUDE (
    viagem_id, 
    vendor_id, 
    vendor_name, 
    pickup_local, 
    bairro_pickup, 
    dropoff_local, 
    bairro_dropoff,
    tarifaID,
    tarifa,
    store_and_fwd_flag
    ) 
FROM viagens;

--validacao de colunas especificas
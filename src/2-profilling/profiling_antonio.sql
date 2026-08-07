SUMMARIZE taxi_raw;

SELECT VendorID, COUNT (VendorID) FROM taxi_raw group by VendorID;

-- VENDOR ID SEM O 7

select tpep_pickup_datetime FROM taxi_raw order by tpep_pickup_datetime ASC;


SELECT tpep_pickup_datetime 
FROM taxi_raw 
WHERE YEAR(tpep_pickup_datetime) != 2024 OR MONTH(tpep_pickup_datetime) != 1
ORDER BY tpep_pickup_datetime ASC limit 30;

-- 18 REGISTROS FORA DE JANEIRO 2024

SELECT passenger_count, COUNT (passenger_count) from taxi_raw group by passenger_count;

SELECT passenger_count, count (passenger_count) from taxi_raw 
where passenger_count > 4 group by passenger_count;

-- passageiros 

SELECT trip_distance FROM taxi_raw order by trip_distance asc;
-- Formula 1 Geospatial Analytics with Firebolt
-- =============================================
-- This demo showcases Firebolt's powerful geospatial capabilities using real F1 World Championship data
-- from 1950-2024, demonstrating how modern data warehouses can handle complex geographical analytics
-- at the speed of racing.

-- Create database for F1 geospatial analytics
CREATE DATABASE IF NOT EXISTS f1_geospatial_analytics;
USE f1_geospatial_analytics;

-- ===========================
-- EXTERNAL TABLES DEFINITION
-- ===========================

-- Create external table for circuits with geographical data
CREATE EXTERNAL TABLE IF NOT EXISTS circuits_ext (
  circuitId BIGINT NULL,
  circuitRef TEXT NULL,
  name TEXT NULL,
  location TEXT NULL,
  country TEXT NULL,
  lat DOUBLE PRECISION NULL,
  lng DOUBLE PRECISION NULL,
  alt DOUBLE PRECISION NULL,
  url TEXT NULL
) 
URL = 's3://your-bucket/f1-data/circuits.csv'
OBJECT_PATTERN = '*.csv' 
TYPE = (CSV SKIP_HEADER_ROWS = TRUE);

-- Create external table for races
CREATE EXTERNAL TABLE IF NOT EXISTS races_ext (
  raceId BIGINT NULL,
  year BIGINT NULL,
  round BIGINT NULL,
  circuitId BIGINT NULL,
  name TEXT NULL,
  date DATE NULL,
  time TEXT NULL,
  url TEXT NULL,
  fp1_date DATE NULL,
  fp1_time TEXT NULL,
  fp2_date DATE NULL,
  fp2_time TEXT NULL,
  fp3_date DATE NULL,
  fp3_time TEXT NULL,
  quali_date DATE NULL,
  quali_time TEXT NULL,
  sprint_date DATE NULL,
  sprint_time TEXT NULL
)
URL = 's3://your-bucket/f1-data/races.csv'
OBJECT_PATTERN = '*.csv'
TYPE = (CSV SKIP_HEADER_ROWS = TRUE);

-- Create external table for drivers
CREATE EXTERNAL TABLE IF NOT EXISTS drivers_ext (
  driverId BIGINT NULL,
  driverRef TEXT NULL,
  number BIGINT NULL,
  code TEXT NULL,
  forename TEXT NULL,
  surname TEXT NULL,
  dob DATE NULL,
  nationality TEXT NULL,
  url TEXT NULL
)
URL = 's3://your-bucket/f1-data/drivers.csv'
OBJECT_PATTERN = '*.csv'
TYPE = (CSV SKIP_HEADER_ROWS = TRUE);

-- Create external table for constructors
CREATE EXTERNAL TABLE IF NOT EXISTS constructors_ext (
  constructorId BIGINT NULL,
  constructorRef TEXT NULL,
  name TEXT NULL,
  nationality TEXT NULL,
  url TEXT NULL
)
URL = 's3://your-bucket/f1-data/constructors.csv'
OBJECT_PATTERN = '*.csv'
TYPE = (CSV SKIP_HEADER_ROWS = TRUE);

-- Create external table for race results
CREATE EXTERNAL TABLE IF NOT EXISTS results_ext (
  resultId BIGINT NULL,
  raceId BIGINT NULL,
  driverId BIGINT NULL,
  constructorId BIGINT NULL,
  number BIGINT NULL,
  grid BIGINT NULL,
  position BIGINT NULL,
  positionText TEXT NULL,
  positionOrder BIGINT NULL,
  points DOUBLE PRECISION NULL,
  laps BIGINT NULL,
  time TEXT NULL,
  milliseconds BIGINT NULL,
  fastestLap BIGINT NULL,
  rank BIGINT NULL,
  fastestLapTime TEXT NULL,
  fastestLapSpeed DOUBLE PRECISION NULL,
  statusId BIGINT NULL
)
URL = 's3://your-bucket/f1-data/results.csv'
OBJECT_PATTERN = '*.csv'
TYPE = (CSV SKIP_HEADER_ROWS = TRUE);

-- Create external table for lap times
CREATE EXTERNAL TABLE IF NOT EXISTS lap_times_ext (
  raceId BIGINT NULL,
  driverId BIGINT NULL,
  lap BIGINT NULL,
  position BIGINT NULL,
  time TEXT NULL,
  milliseconds BIGINT NULL
)
URL = 's3://your-bucket/f1-data/lap_times.csv'
OBJECT_PATTERN = '*.csv'
TYPE = (CSV SKIP_HEADER_ROWS = TRUE);

-- Create external table for qualifying results
CREATE EXTERNAL TABLE IF NOT EXISTS qualifying_ext (
  qualifyId BIGINT NULL,
  raceId BIGINT NULL,
  driverId BIGINT NULL,
  constructorId BIGINT NULL,
  number BIGINT NULL,
  position BIGINT NULL,
  q1 TEXT NULL,
  q2 TEXT NULL,
  q3 TEXT NULL
)
URL = 's3://your-bucket/f1-data/qualifying.csv'
OBJECT_PATTERN = '*.csv'
TYPE = (CSV SKIP_HEADER_ROWS = TRUE);

-- ===========================
-- INTERNAL TABLES WITH GEOSPATIAL FEATURES
-- ===========================

-- Create internal circuits table with geospatial point data
CREATE TABLE circuits AS
SELECT
  circuitId,
  circuitRef,
  name,
  location,
  country,
  lat,
  lng,
  alt,
  ST_GeogPoint(lng, lat) AS circuit_location,
  url
FROM circuits_ext;

-- Create internal races table
CREATE TABLE races AS
SELECT * FROM races_ext;

-- Create internal drivers table
CREATE TABLE drivers AS
SELECT * FROM drivers_ext;

-- Create internal constructors table with headquarters locations
CREATE TABLE constructors AS
SELECT 
  constructorId,
  constructorRef,
  name,
  nationality,
  -- Add approximate HQ locations for major constructors
  CASE 
    WHEN name = 'Mercedes' THEN ST_GeogPoint(-1.4167, 52.0786)  -- Brackley, UK
    WHEN name = 'Red Bull' THEN ST_GeogPoint(-0.4694, 52.0603)  -- Milton Keynes, UK
    WHEN name = 'Ferrari' THEN ST_GeogPoint(10.8639, 44.5322)   -- Maranello, Italy
    WHEN name = 'McLaren' THEN ST_GeogPoint(-0.5489, 51.3408)   -- Woking, UK
    WHEN name = 'Alpine F1 Team' THEN ST_GeogPoint(-1.3833, 51.2986) -- Enstone, UK
    WHEN name = 'AlphaTauri' THEN ST_GeogPoint(11.1972, 44.8936) -- Faenza, Italy
    WHEN name = 'Aston Martin' THEN ST_GeogPoint(-1.4514, 52.0719) -- Silverstone, UK
    WHEN name = 'Williams' THEN ST_GeogPoint(-0.8492, 51.6181)  -- Grove, UK
    WHEN name = 'Alfa Romeo' THEN ST_GeogPoint(8.5603, 47.4581) -- Hinwil, Switzerland
    WHEN name = 'Haas F1 Team' THEN ST_GeogPoint(-82.5361, 35.3492) -- Kannapolis, USA
    ELSE NULL
  END AS hq_location,
  url
FROM constructors_ext;

-- Create internal results table
CREATE TABLE results AS
SELECT * FROM results_ext;

-- Create internal lap times table
CREATE TABLE lap_times AS
SELECT * FROM lap_times_ext;

-- Create internal qualifying table
CREATE TABLE qualifying AS
SELECT * FROM qualifying_ext;

-- ===========================
-- GEOSPATIAL REGIONS DEFINITION
-- ===========================

-- Define major racing regions as polygons
SET query_parameters={"name":"europe","value":"POLYGON((-10 35, 40 35, 40 71, -10 71, -10 35))"};
SET query_parameters={"name":"asia","value":"POLYGON((50 -10, 150 -10, 150 55, 50 55, 50 -10))"};
SET query_parameters={"name":"americas","value":"POLYGON((-170 -60, -30 -60, -30 75, -170 75, -170 -60))"};

-- ===========================
-- ANALYTICAL QUERIES
-- ===========================

-- 1. Circuit Distribution by Continent
SELECT 
  CASE
    WHEN ST_COVERS(ST_GeogFromText(param('europe')), circuit_location) THEN 'Europe'
    WHEN ST_COVERS(ST_GeogFromText(param('asia')), circuit_location) THEN 'Asia'
    WHEN ST_COVERS(ST_GeogFromText(param('americas')), circuit_location) THEN 'Americas'
    ELSE 'Other'
  END AS continent,
  COUNT(*) as circuit_count,
  ARRAY_AGG(name) as circuit_names
FROM circuits
WHERE circuit_location IS NOT NULL
GROUP BY continent
ORDER BY circuit_count DESC;

-- 2. Find Nearest Circuits (Circuit Proximity Analysis)
WITH circuit_pairs AS (
  SELECT 
    c1.name as circuit1,
    c2.name as circuit2,
    c1.country as country1,
    c2.country as country2,
    ST_Distance(c1.circuit_location, c2.circuit_location) / 1000 as distance_km
  FROM circuits c1
  CROSS JOIN circuits c2
  WHERE c1.circuitId < c2.circuitId
    AND c1.circuit_location IS NOT NULL
    AND c2.circuit_location IS NOT NULL
)
SELECT 
  circuit1,
  circuit2,
  country1,
  country2,
  ROUND(distance_km, 2) as distance_km
FROM circuit_pairs
ORDER BY distance_km ASC
LIMIT 10;

-- 3. Racing Activity Heatmap by Geographic Cell
SELECT 
  ST_S2CellIDFromPoint(c.circuit_location, 8) as cell_id,
  c.country,
  c.location,
  COUNT(DISTINCT r.raceId) as total_races,
  COUNT(DISTINCT r.year) as years_active,
  MIN(r.year) as first_race,
  MAX(r.year) as last_race,
  ARRAY_AGG(DISTINCT c.name) as circuit_names
FROM circuits c
JOIN races r ON c.circuitId = r.circuitId
WHERE c.circuit_location IS NOT NULL
GROUP BY cell_id, c.country, c.location
ORDER BY total_races DESC;

-- 4. Constructor Success by Geographic Regions
SELECT 
  c.name as constructor,
  c.nationality,
  COUNT(DISTINCT r.raceId) as races_participated,
  SUM(res.points) as total_points,
  COUNT(CASE WHEN res.position = 1 THEN 1 END) as wins,
  COUNT(CASE WHEN res.position <= 3 THEN 1 END) as podiums,
  ROUND(AVG(res.points), 2) as avg_points_per_race
FROM constructors c
JOIN results res ON c.constructorId = res.constructorId
JOIN races r ON res.raceId = r.raceId
JOIN circuits cir ON r.circuitId = cir.circuitId
WHERE ST_COVERS(ST_GeogFromText(param('europe')), cir.circuit_location)
GROUP BY c.name, c.nationality
ORDER BY total_points DESC
LIMIT 20;

-- 5. Circuit Elevation Profile Analysis
SELECT 
  name,
  location,
  country,
  alt as elevation_meters,
  CASE
    WHEN alt < 100 THEN 'Sea Level'
    WHEN alt BETWEEN 100 AND 500 THEN 'Low Altitude'
    WHEN alt BETWEEN 500 AND 1000 THEN 'Medium Altitude'
    ELSE 'High Altitude'
  END as elevation_category,
  lat,
  lng
FROM circuits
WHERE alt IS NOT NULL
ORDER BY alt DESC;

-- 6. Calculate Total Racing Distance by Year
SELECT 
  r.year,
  COUNT(DISTINCT r.raceId) as num_races,
  SUM(
    CASE 
      WHEN res.laps IS NOT NULL AND cir.name LIKE '%Monaco%' THEN res.laps * 3.337  -- Monaco lap length
      WHEN res.laps IS NOT NULL AND cir.name LIKE '%Spa%' THEN res.laps * 7.004     -- Spa lap length
      WHEN res.laps IS NOT NULL AND cir.name LIKE '%Silverstone%' THEN res.laps * 5.891
      WHEN res.laps IS NOT NULL AND cir.name LIKE '%Monza%' THEN res.laps * 5.793
      ELSE res.laps * 5.0  -- Average F1 circuit length
    END
  ) as total_distance_km
FROM races r
JOIN results res ON r.raceId = res.raceId
JOIN circuits cir ON r.circuitId = cir.circuitId
WHERE res.position = 1  -- Only count winner's distance
GROUP BY r.year
ORDER BY r.year DESC
LIMIT 20;

-- 7. Geographic Spread of F1 Over Time
SELECT 
  FLOOR(r.year / 10) * 10 as decade,
  COUNT(DISTINCT cir.country) as countries_visited,
  COUNT(DISTINCT cir.circuitId) as unique_circuits,
  ARRAY_AGG(DISTINCT cir.country) as countries_list
FROM races r
JOIN circuits cir ON r.circuitId = cir.circuitId
GROUP BY decade
ORDER BY decade;

-- 8. Night Races Analysis (Singapore, Bahrain, Abu Dhabi, etc.)
SELECT 
  c.name,
  c.location,
  c.country,
  ST_AsText(c.circuit_location) as coordinates,
  COUNT(r.raceId) as total_races,
  CASE
    WHEN c.name LIKE '%Marina Bay%' THEN 'Night Race'
    WHEN c.name LIKE '%Yas Marina%' THEN 'Day-Night Race'
    WHEN c.name LIKE '%Bahrain%' THEN 'Night Race'
    WHEN c.name LIKE '%Jeddah%' THEN 'Night Race'
    WHEN c.name LIKE '%Las Vegas%' THEN 'Night Race'
    ELSE 'Day Race'
  END as race_time_category
FROM circuits c
JOIN races r ON c.circuitId = r.circuitId
WHERE c.circuit_location IS NOT NULL
GROUP BY c.name, c.location, c.country, c.circuit_location
ORDER BY total_races DESC;

-- 9. Create Racing Corridors (Paths Between Sequential Races)
WITH race_sequence AS (
  SELECT 
    r1.year,
    r1.round as round1,
    r2.round as round2,
    c1.name as circuit1,
    c2.name as circuit2,
    c1.circuit_location as loc1,
    c2.circuit_location as loc2,
    ST_Distance(c1.circuit_location, c2.circuit_location) / 1000 as distance_km
  FROM races r1
  JOIN races r2 ON r1.year = r2.year AND r2.round = r1.round + 1
  JOIN circuits c1 ON r1.circuitId = c1.circuitId
  JOIN circuits c2 ON r2.circuitId = c2.circuitId
  WHERE r1.year >= 2020
    AND c1.circuit_location IS NOT NULL
    AND c2.circuit_location IS NOT NULL
)
SELECT 
  year,
  circuit1,
  circuit2,
  ROUND(distance_km, 2) as travel_distance_km,
  CASE
    WHEN distance_km < 500 THEN 'Same Region'
    WHEN distance_km < 2000 THEN 'Continental'
    ELSE 'Intercontinental'
  END as travel_type
FROM race_sequence
ORDER BY year DESC, round1;

-- 10. Fastest Circuits by Average Speed
SELECT 
  c.name as circuit_name,
  c.location,
  c.country,
  AVG(res.fastestLapSpeed) as avg_fastest_lap_speed,
  MAX(res.fastestLapSpeed) as max_speed_recorded,
  COUNT(DISTINCT r.raceId) as races_analyzed,
  ST_AsText(c.circuit_location) as coordinates
FROM circuits c
JOIN races r ON c.circuitId = r.circuitId
JOIN results res ON r.raceId = res.raceId
WHERE res.fastestLapSpeed IS NOT NULL
  AND res.fastestLapSpeed > 0
  AND c.circuit_location IS NOT NULL
GROUP BY c.name, c.location, c.country, c.circuit_location
ORDER BY avg_fastest_lap_speed DESC
LIMIT 15;

-- 11. Driver Performance by Geographic Region
WITH driver_region_stats AS (
  SELECT 
    d.forename || ' ' || d.surname as driver_name,
    d.nationality,
    CASE
      WHEN ST_COVERS(ST_GeogFromText(param('europe')), c.circuit_location) THEN 'Europe'
      WHEN ST_COVERS(ST_GeogFromText(param('asia')), c.circuit_location) THEN 'Asia'
      WHEN ST_COVERS(ST_GeogFromText(param('americas')), c.circuit_location) THEN 'Americas'
      ELSE 'Other'
    END AS region,
    COUNT(res.raceId) as races,
    SUM(res.points) as points,
    COUNT(CASE WHEN res.position = 1 THEN 1 END) as wins
  FROM drivers d
  JOIN results res ON d.driverId = res.driverId
  JOIN races r ON res.raceId = r.raceId
  JOIN circuits c ON r.circuitId = c.circuitId
  WHERE c.circuit_location IS NOT NULL
    AND r.year >= 2010
  GROUP BY driver_name, d.nationality, region
)
SELECT 
  driver_name,
  nationality,
  region,
  races,
  points,
  wins,
  ROUND(points::FLOAT / races, 2) as points_per_race
FROM driver_region_stats
WHERE races >= 10
ORDER BY points_per_race DESC
LIMIT 30;

-- 12. Circuit Weather Patterns (Wet vs Dry Races)
SELECT 
  c.name as circuit,
  c.location,
  c.country,
  COUNT(r.raceId) as total_races,
  -- Estimate wet races based on circuit history
  CASE
    WHEN c.name LIKE '%Spa%' THEN 'High Rain Probability'
    WHEN c.name LIKE '%Interlagos%' THEN 'High Rain Probability'
    WHEN c.name LIKE '%Suzuka%' THEN 'Moderate Rain Probability'
    WHEN c.name LIKE '%Singapore%' THEN 'Moderate Rain Probability'
    WHEN c.name LIKE '%Monaco%' THEN 'Low Rain Probability'
    WHEN c.name LIKE '%Bahrain%' THEN 'Very Low Rain Probability'
    ELSE 'Variable'
  END as rain_likelihood,
  ST_AsText(c.circuit_location) as coordinates
FROM circuits c
JOIN races r ON c.circuitId = r.circuitId
WHERE c.circuit_location IS NOT NULL
GROUP BY c.name, c.location, c.country, c.circuit_location
ORDER BY total_races DESC;

-- ===========================
-- VISUALIZATION EXPORTS
-- ===========================

-- Export circuit locations for visualization
SELECT 
  'GEOMETRYCOLLECTION(' || 
  ARRAY_TO_STRING(
    ARRAY_AGG(ST_AsText(circuit_location)),
    ','
  ) || ')' AS geojson_collection
FROM circuits
WHERE circuit_location IS NOT NULL;

-- Export racing corridors for 2024 season
WITH season_2024 AS (
  SELECT 
    r.round,
    c.name,
    c.circuit_location,
    c.country
  FROM races r
  JOIN circuits c ON r.circuitId = c.circuitId
  WHERE r.year = 2024
    AND c.circuit_location IS NOT NULL
  ORDER BY r.round
)
SELECT 
  'LINESTRING(' || 
  ARRAY_TO_STRING(
    ARRAY_AGG(
      ST_X(circuit_location)::TEXT || ' ' || ST_Y(circuit_location)::TEXT 
      ORDER BY round
    ),
    ','
  ) || ')' AS season_path
FROM season_2024;
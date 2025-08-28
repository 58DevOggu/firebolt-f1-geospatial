#!/usr/bin/env python3
"""
F1 Data Ingestion Script for Firebolt
=====================================
This script uploads F1 CSV files to S3 and creates the necessary
external and internal tables in Firebolt for geospatial analytics.
"""

import os
import sys
import boto3
import pandas as pd
from pathlib import Path
import json
from datetime import datetime

def upload_to_s3(local_path, s3_bucket, s3_prefix):
    """
    Upload F1 CSV files to S3 bucket
    """
    s3_client = boto3.client('s3')
    
    files_to_upload = [
        'circuits.csv',
        'races.csv',
        'drivers.csv',
        'constructors.csv',
        'results.csv',
        'lap_times.csv',
        'qualifying.csv',
        'constructor_results.csv',
        'constructor_standings.csv',
        'driver_standings.csv',
        'pit_stops.csv',
        'sprint_results.csv',
        'status.csv'
    ]
    
    uploaded_files = []
    
    for file_name in files_to_upload:
        file_path = Path(local_path) / file_name
        if file_path.exists():
            s3_key = f"{s3_prefix}/{file_name}"
            print(f"Uploading {file_name} to s3://{s3_bucket}/{s3_key}")
            
            try:
                s3_client.upload_file(str(file_path), s3_bucket, s3_key)
                uploaded_files.append(s3_key)
                print(f"  ✓ Successfully uploaded {file_name}")
            except Exception as e:
                print(f"  ✗ Error uploading {file_name}: {e}")
        else:
            print(f"  ⚠ File not found: {file_name}")
    
    return uploaded_files

def generate_firebolt_script(s3_bucket, s3_prefix):
    """
    Generate Firebolt SQL script with correct S3 paths
    """
    script = f"""
-- ================================================
-- F1 Geospatial Analytics - Firebolt Setup Script
-- Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- ================================================

-- Create database
CREATE DATABASE IF NOT EXISTS f1_geospatial_analytics;
USE f1_geospatial_analytics;

-- Drop existing tables if they exist
DROP TABLE IF EXISTS circuits;
DROP TABLE IF EXISTS races;
DROP TABLE IF EXISTS drivers;
DROP TABLE IF EXISTS constructors;
DROP TABLE IF EXISTS results;
DROP TABLE IF EXISTS lap_times;
DROP TABLE IF EXISTS qualifying;

DROP TABLE IF EXISTS circuits_ext;
DROP TABLE IF EXISTS races_ext;
DROP TABLE IF EXISTS drivers_ext;
DROP TABLE IF EXISTS constructors_ext;
DROP TABLE IF EXISTS results_ext;
DROP TABLE IF EXISTS lap_times_ext;
DROP TABLE IF EXISTS qualifying_ext;

-- Create external tables pointing to S3 data
CREATE EXTERNAL TABLE circuits_ext (
  circuitId BIGINT,
  circuitRef TEXT,
  name TEXT,
  location TEXT,
  country TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  alt DOUBLE PRECISION,
  url TEXT
) 
URL = 's3://{s3_bucket}/{s3_prefix}/'
OBJECT_PATTERN = 'circuits.csv'
TYPE = (CSV SKIP_HEADER_ROWS = 1);

CREATE EXTERNAL TABLE races_ext (
  raceId BIGINT,
  year BIGINT,
  round BIGINT,
  circuitId BIGINT,
  name TEXT,
  date TEXT,
  time TEXT,
  url TEXT,
  fp1_date TEXT,
  fp1_time TEXT,
  fp2_date TEXT,
  fp2_time TEXT,
  fp3_date TEXT,
  fp3_time TEXT,
  quali_date TEXT,
  quali_time TEXT,
  sprint_date TEXT,
  sprint_time TEXT
)
URL = 's3://{s3_bucket}/{s3_prefix}/'
OBJECT_PATTERN = 'races.csv'
TYPE = (CSV SKIP_HEADER_ROWS = 1);

CREATE EXTERNAL TABLE drivers_ext (
  driverId BIGINT,
  driverRef TEXT,
  number TEXT,
  code TEXT,
  forename TEXT,
  surname TEXT,
  dob TEXT,
  nationality TEXT,
  url TEXT
)
URL = 's3://{s3_bucket}/{s3_prefix}/'
OBJECT_PATTERN = 'drivers.csv'
TYPE = (CSV SKIP_HEADER_ROWS = 1);

CREATE EXTERNAL TABLE constructors_ext (
  constructorId BIGINT,
  constructorRef TEXT,
  name TEXT,
  nationality TEXT,
  url TEXT
)
URL = 's3://{s3_bucket}/{s3_prefix}/'
OBJECT_PATTERN = 'constructors.csv'
TYPE = (CSV SKIP_HEADER_ROWS = 1);

CREATE EXTERNAL TABLE results_ext (
  resultId BIGINT,
  raceId BIGINT,
  driverId BIGINT,
  constructorId BIGINT,
  number TEXT,
  grid BIGINT,
  position TEXT,
  positionText TEXT,
  positionOrder BIGINT,
  points DOUBLE PRECISION,
  laps TEXT,
  time TEXT,
  milliseconds TEXT,
  fastestLap TEXT,
  rank TEXT,
  fastestLapTime TEXT,
  fastestLapSpeed TEXT,
  statusId BIGINT
)
URL = 's3://{s3_bucket}/{s3_prefix}/'
OBJECT_PATTERN = 'results.csv'
TYPE = (CSV SKIP_HEADER_ROWS = 1);

CREATE EXTERNAL TABLE lap_times_ext (
  raceId BIGINT,
  driverId BIGINT,
  lap BIGINT,
  position BIGINT,
  time TEXT,
  milliseconds BIGINT
)
URL = 's3://{s3_bucket}/{s3_prefix}/'
OBJECT_PATTERN = 'lap_times.csv'
TYPE = (CSV SKIP_HEADER_ROWS = 1);

CREATE EXTERNAL TABLE qualifying_ext (
  qualifyId BIGINT,
  raceId BIGINT,
  driverId BIGINT,
  constructorId BIGINT,
  number BIGINT,
  position BIGINT,
  q1 TEXT,
  q2 TEXT,
  q3 TEXT
)
URL = 's3://{s3_bucket}/{s3_prefix}/'
OBJECT_PATTERN = 'qualifying.csv'
TYPE = (CSV SKIP_HEADER_ROWS = 1);

-- Create internal tables with geospatial features
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
FROM circuits_ext
WHERE lat IS NOT NULL AND lng IS NOT NULL;

CREATE TABLE races AS
SELECT * FROM races_ext;

CREATE TABLE drivers AS
SELECT * FROM drivers_ext;

CREATE TABLE constructors AS
SELECT 
  constructorId,
  constructorRef,
  name,
  nationality,
  CASE 
    WHEN name LIKE '%Mercedes%' THEN ST_GeogPoint(-1.4167, 52.0786)
    WHEN name LIKE '%Red Bull%' THEN ST_GeogPoint(-0.4694, 52.0603)
    WHEN name LIKE '%Ferrari%' THEN ST_GeogPoint(10.8639, 44.5322)
    WHEN name LIKE '%McLaren%' THEN ST_GeogPoint(-0.5489, 51.3408)
    WHEN name LIKE '%Alpine%' THEN ST_GeogPoint(-1.3833, 51.2986)
    WHEN name LIKE '%AlphaTauri%' THEN ST_GeogPoint(11.1972, 44.8936)
    WHEN name LIKE '%Aston Martin%' THEN ST_GeogPoint(-1.4514, 52.0719)
    WHEN name LIKE '%Williams%' THEN ST_GeogPoint(-0.8492, 51.6181)
    WHEN name LIKE '%Alfa Romeo%' THEN ST_GeogPoint(8.5603, 47.4581)
    WHEN name LIKE '%Haas%' THEN ST_GeogPoint(-82.5361, 35.3492)
    ELSE NULL
  END AS hq_location,
  url
FROM constructors_ext;

CREATE TABLE results AS
SELECT 
  resultId,
  raceId,
  driverId,
  constructorId,
  CAST(number AS BIGINT) as number,
  grid,
  CAST(position AS BIGINT) as position,
  positionText,
  positionOrder,
  points,
  CAST(laps AS BIGINT) as laps,
  time,
  CAST(milliseconds AS BIGINT) as milliseconds,
  CAST(fastestLap AS BIGINT) as fastestLap,
  CAST(rank AS BIGINT) as rank,
  fastestLapTime,
  CAST(fastestLapSpeed AS DOUBLE PRECISION) as fastestLapSpeed,
  statusId
FROM results_ext;

CREATE TABLE lap_times AS
SELECT * FROM lap_times_ext;

CREATE TABLE qualifying AS
SELECT * FROM qualifying_ext;

-- Verify data ingestion
SELECT 'circuits' as table_name, COUNT(*) as row_count FROM circuits
UNION ALL
SELECT 'races', COUNT(*) FROM races
UNION ALL
SELECT 'drivers', COUNT(*) FROM drivers
UNION ALL
SELECT 'constructors', COUNT(*) FROM constructors
UNION ALL
SELECT 'results', COUNT(*) FROM results
UNION ALL
SELECT 'lap_times', COUNT(*) FROM lap_times
UNION ALL
SELECT 'qualifying', COUNT(*) FROM qualifying
ORDER BY table_name;

-- Sample geospatial query to verify setup
SELECT 
  name,
  location,
  country,
  ST_AsText(circuit_location) as coordinates
FROM circuits
WHERE circuit_location IS NOT NULL
LIMIT 5;
"""
    return script

def main():
    print("=" * 60)
    print("F1 Data Ingestion for Firebolt Geospatial Analytics")
    print("=" * 60)
    
    # Configuration
    local_data_path = "data/f1-data/F1-World-Championship-Data"
    
    # Check if data exists
    if not Path(local_data_path).exists():
        print(f"Error: Data directory not found at {local_data_path}")
        print("Please ensure the F1 dataset is downloaded and placed in the correct location.")
        sys.exit(1)
    
    # Get S3 configuration from user or environment
    s3_bucket = os.environ.get('FIREBOLT_S3_BUCKET')
    if not s3_bucket:
        s3_bucket = input("Enter your S3 bucket name (e.g., my-firebolt-data): ").strip()
    
    s3_prefix = f"f1-data/{datetime.now().strftime('%Y%m%d')}"
    
    print(f"\nConfiguration:")
    print(f"  Local path: {local_data_path}")
    print(f"  S3 bucket: {s3_bucket}")
    print(f"  S3 prefix: {s3_prefix}")
    
    # Upload to S3
    proceed = input("\nProceed with S3 upload? (y/n): ").strip().lower()
    if proceed == 'y':
        print("\nUploading files to S3...")
        uploaded = upload_to_s3(local_data_path, s3_bucket, s3_prefix)
        print(f"\n✓ Successfully uploaded {len(uploaded)} files to S3")
    else:
        print("Skipping S3 upload...")
    
    # Generate Firebolt script
    print("\nGenerating Firebolt SQL script...")
    sql_script = generate_firebolt_script(s3_bucket, s3_prefix)
    
    output_file = "f1_firebolt_setup.sql"
    with open(output_file, 'w') as f:
        f.write(sql_script)
    
    print(f"✓ SQL script saved to: {output_file}")
    
    print("\n" + "=" * 60)
    print("Next Steps:")
    print("=" * 60)
    print("1. Log into your Firebolt account")
    print("2. Create a new engine (S size is sufficient)")
    print("3. Run the generated SQL script: f1_firebolt_setup.sql")
    print("4. Execute the analytical queries from: f1_geospatial.sql")
    print("5. Explore the insights and build visualizations!")
    print("\nHappy racing with Firebolt! 🏎️")

if __name__ == "__main__":
    main()
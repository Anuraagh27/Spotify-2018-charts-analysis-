CREATE DATABASE SPOTIFYINFO;
GO
USE SPOTIFYINFO;
GO

USE SPOTIFYINFO;
GO
SELECT name FROM sys.tables;

SELECT MAX(LEN(artist_name)) AS long_artist,
MAX(LEN(track_title)) AS long_title 
FROM dbo.stg_charts;

SELECT TOP 5 artist_name , LEN(artist_name) as lens
FROM dbo.stg_charts
ORDER BY LEN(artist_name)DESC ;

-- Spotify charts 2017 , 2018 charts 
-- SQL server star schema 

-- Single source: dhruvildave "Spotify Charts" (Kaggle), cleaned and
-- filtered to 2017-2018 by clean_charts_only.py -> charts_2017_2018_clean.csv

/* Clean CSV columns:
   track_id, track_title, artist_name, chart_date, rank, region,
   chart_type, trend, streams, source_url */

-- Dimension tracks
--------------------------- 

-- Table for tracks
CREATE TABLE dbo.dim_tracks
(
 track_id NVARCHAR(50) NOT NULL PRIMARY KEY ,
 track_title NVARCHAR(600) NOT NULL
);

-- Table for artists
CREATE TABLE dbo.dim_artists 
(
 artist_id INT IDENTITY(1,1) PRIMARY KEY ,
 artist_name NVARCHAR(1000) NOT NULL
);

-- Table for regions
CREATE TABLE dbo.dim_regions
(
 regions_id INT IDENTITY(1,1) PRIMARY KEY , 
 regions_name NVARCHAR(100) NOT NULL
);
GO

INSERT INTO dbo.dim_tracks(track_id , track_title)
SELECT DISTINCT track_id , track_title 
FROM dbo.stg_charts 
WHERE track_id IS NOT NULL; 

INSERT INTO dbo.dim_artists (artist_name)
SELECT DISTINCT artist_name
FROM dbo.stg_charts
WHERE artist_name IS NOT NULL ;

INSERT INTO dbo.dim_regions (regions_name)
SELECT DISTINCT region
FROM dbo.stg_charts
WHERE region IS NOT NULL;

SELECT COUNT(*) FROM dbo.dim_tracks;
SELECT COUNT(*) FROM dbo.dim_artists;
SELECT COUNT(*) FROM dbo.dim_regions;
SELECT COUNT(*) FROM dbo.stg_charts;

SELECT DISTINCT track_title
FROM dbo.stg_charts
WHERE track_id = '0QFTjMGHWo7joBA5CUlIpd';

SELECT track_id, COUNT(DISTINCT track_title) AS title_variants
FROM dbo.stg_charts
WHERE track_id IS NOT NULL
GROUP BY track_id
HAVING COUNT(DISTINCT track_title) > 1;

INSERT INTO dbo.dim_tracks (track_id, track_title)
SELECT track_id, MIN(track_title) AS track_title
FROM dbo.stg_charts
WHERE track_id IS NOT NULL
GROUP BY track_id;

------------------------------------
-- FACT TABLE 
------------------------------------
CREATE TABLE fact_charts_table 
(
 entry_id  BIGINT IDENTITY(1,1) PRIMARY KEY ,
 track_id  NVARCHAR(50) NOT NULL REFERENCES dbo.dim_tracks(track_id),
 artist_id INT NOT NULL REFERENCES dbo.dim_artists(artist_id),
 region_id INT NOT NULL REFERENCES dbo.dim_regions(regions_id),
 chart_date DATE NOT NULL ,
 [rank] SMALLINT NOT NULL ,
 chart_type NVARCHAR(20) NULL,
 trend NVARCHAR(20) NULL,
 streams INT NULL ,
 source_url NVARCHAR(500) NULL
);

INSERT INTO dbo.fact_charts_table
( track_id , artist_id , region_id , chart_date , [rank] , chart_type , trend , streams , source_url )
SELECT 
s.track_id,
a.artist_id,
r.regions_id,
s.chart_date,
s.[rank],
s.chart_type,
s.trend,
s.streams,
s.source_url
FROM dbo.stg_charts s
JOIN dbo.dim_artists a 
 ON a.artist_name = s.artist_name
JOIN dbo.dim_regions r 
 ON r.regions_name = s.region
 WHERE s.track_id IS NOT NULL ;

 SELECT TOP 5 *
FROM dbo.fact_charts_table;






-------------------------------------
-- Starter Queries
-------------------------------------
-- a] Top 20 TRACKS by peak rank in 2018 [ across all regions ]
SELECT TOP 25
t.track_title,
ar.artist_name,
MIN(f.[rank]) as peak_rank,
COUNT(*) as chart_appearances 
FROM fact_charts_table f
JOIN dim_tracks t
  ON t.track_id = f.track_id
JOIN dim_artists ar 
  ON ar.artist_id = f.artist_id
WHERE YEAR(f.chart_date) = 2018
GROUP BY t.track_title , ar.artist_name 
ORDER BY peak_rank ASC , chart_appearances DESC ;

-- b] TOP 25 ARTISTS WITH THE MOST DISTINCT TRACKS CHARTING IN 2018 
SELECT TOP 25
ar.artist_name ,
COUNT(DISTINCT f.track_id) as distinct_track_charted
FROM fact_charts_table f
JOIN dim_artists ar 
 ON ar.artist_id = f.artist_id
WHERE YEAR(f.chart_date) = 2018
GROUP BY ar.artist_name
ORDER BY distinct_track_charted DESC ;

-- c] 2017 V 2018 did global charts artists change ?
SELECT 
YEAR(f.chart_date) as chart_year,
ar.artist_name ,
COUNT(*) AS Appearances
FROM fact_charts_table f
JOIN dim_artists ar
  ON ar.artist_id = f.artist_id
JOIN dim_regions r
  ON r.regions_id = f.region_id
WHERE r.regions_name = 'Global'
GROUP BY YEAR(f.chart_date) , ar.artist_name
ORDER BY chart_year ,  Appearances DESC;

--d] Regional spread — how many distinct regions did each 2018 track chart in?
SELECT TOP 25
t.track_title ,
ar.artist_name ,
COUNT(DISTINCT f.region_id) as regions_charted_in ,
COUNT(*) AS appearances_on_charts
FROM fact_charts_table f
JOIN dim_tracks t
 ON t.track_id = f.track_id
JOIN dim_artists ar
 ON ar.artist_id = f.artist_id
WHERE YEAR(f.chart_date) = 2018
GROUP BY t.track_title , ar.artist_name 
ORDER BY regions_charted_in DESC , appearances_on_charts DESC ;

-----------------------------------------------------------------------------
-- CORE INSIGHTS
-----------------------------------------------------------------------------

--a] TOP200 Vs Viral50 entry volume and distinct tracks by charts type in 2018 
SELECT 
f.chart_type ,
COUNT(*) AS total_entries ,
COUNT(DISTINCT f.track_id ) AS distinct_tracks
FROM dbo.fact_charts_table f
WHERE YEAR(f.chart_date) = 2018 
GROUP BY f.chart_type;

--b] Regional footprint - total chart entries per region in 2018 
SELECT 
r.regions_name,
COUNT(*)  AS Appearences ,
COUNT( DISTINCT f.track_id) AS distinct_tracks 
FROM fact_charts_table f 
JOIN dim_regions r 
  ON r.regions_id = f.region_id
  WHERE YEAR(f.chart_date) = 2018
  GROUP BY r.regions_name
  ORDER BY Appearences DESC;


--c]  Longest MOVE_UP streak before peak, per track/region (2018, top200 only)
WITH ranked AS (
 SELECT 
       f.track_id ,
       f.artist_id,
       f.region_id,
       f.chart_date,
       ROW_NUMBER() OVER (PARTITION BY f.track_id , f.region_id ORDER BY f.chart_date) AS rn,
       ROW_NUMBER() OVER (PARTITION BY f.track_id , f.region_id , f.trend ORDER BY f.chart_date ) AS rn_trend 
       FROM fact_charts_table f
       WHERE f.chart_type = 'top200'
       AND YEAR(f.chart_date) = '2018'
       AND f.trend = 'MOVE_UP'
 ),
 streaks AS (
   SELECT 
         track_id ,
         artist_id , 
         region_id ,
         (rn - rn_trend ) AS streaks_group,
         COUNT(*) AS streak_length ,
         MIN(chart_date) AS streak_start,
         MAX(chart_date) AS streak_end
         FROM ranked 
         GROUP BY track_id , artist_id , region_id , (rn - rn_trend)
   )
 SELECT TOP 20 
   t.track_title,
   ar.artist_name,
   r.regions_name,
   s.streak_length,
   s.streak_start,
   s.streak_end
   FROM streaks s 
   JOIN dbo.dim_tracks t
     ON t.track_id = s.track_id
   JOIN dbo.dim_artists ar
     ON ar.artist_id = s.artist_id
   JOIN dbo.dim_regions r
     ON r.regions_id = s.region_id
   ORDER BY s.streak_length DESC ;


-- d] 'Album bomb' days ; Artists with more than 5 tracks in Top 200 
   SELECT TOP 20
   ar.artist_name ,
   f.chart_date ,
   COUNT( DISTINCT f.track_id ) AS tracks_in_charts 
   FROM fact_charts_table f
   JOIN dim_artists ar 
     ON ar.artist_id = f.artist_id
    WHERE f.chart_type = 'top200 '
    AND YEAR( f.chart_date) = 2018 
    GROUP BY ar.artist_name , f.chart_date 
    HAVING COUNT (DISTINCT f.track_id ) >= 5 
    ORDER BY tracks_in_charts DESC , f.chart_date ;

 -- e] Viral-only tracks ; charted on viral50 in 2018 but never cracked top200 (social buzz that never converted to real stream volume)
   SELECT TOP 20 
   t.track_title , 
   ar.artist_name 
   FROM fact_charts_table f
   JOIN dbo.dim_tracks t
     ON t.track_id = f.track_id
   JOIN dbo.dim_artists ar
     ON ar.artist_id = f.artist_id
    WHERE YEAR(f.chart_date) = 2018
      AND f.chart_type = 'viral50'
      AND NOT EXISTS (
                       SELECT*
                       FROM dbo.fact_charts_table f2
                       WHERE f2.track_id = f.track_id
                         AND f2.chart_type = 'top200'
                     );

-- f]  2017 -> 2018 movers ; artists whose top200 appearances grew or shrank the most year over year (flip ORDER BY to ASC for biggest declines)
      WITH yearly_count AS (
      SELECT 
      ar.artist_name,
      YEAR(f.chart_date) AS chart_year,
      COUNT(*) AS appearances 
      FROM fact_charts_table f
      JOIN dbo.dim_artists ar
        ON ar.artist_id = f.artist_id
        WHERE f.chart_type = 'top200'
        GROUP BY ar.artist_name , YEAR(f.chart_date)
    )
    SELECT 
    y2018.artist_name,
    ISNULL(y2017.appearances , 0) AS appearances2017,
    y2018.appearances             AS appearances2018,
    y2018.appearances - ISNULL(y2017.appearances , 0) AS [change] 
    FROM yearly_count y2018
    LEFT JOIN yearly_count y2017
    ON y2018.artist_name = y2017.artist_name AND y2017.chart_year = 2017
    WHERE y2018.chart_year = 2018
    ORDER BY [change] DESC ;











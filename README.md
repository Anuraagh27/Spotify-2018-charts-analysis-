# Spotify-2017/18-charts-analysis

A full analytics pipeline project . Python , SQL , power BI used . Project conducted to analyze Spotify charts data and to monitor hoe music performed during 2017 to 2018 .

# Overview 
  Analyses 9 million + real chart entries from Spotify's daily top 200 and viral 50 charts across 66 countries . This project takes a single raw 3.5GB , 26 million rows of CSV file and systematically narrows to down to the 9 million rows for analyzing the 2017 to 2018 music industry performance . Then this single file is taken to SQL and converted into a star schema table for further analysis .

# TECH Stack 
1. Python (pandas) : cleaning , data understanding , year filtering and ID extraction
2. SQL server : relational schema and analysis
3. POWER BI : DATA visualization

# Data sources :
[Spotify Charts](https://www.kaggle.com/datasets/dhruvildave/spotify-charts) — dhruvildave, Kaggle. Daily Top 200 and Viral 50 charts across 66 regions, Jan 2017–Dec 2021 (filtered here to 2017–2018).

# Pipeline :
  1. Stage 1 : raw charts.csv ( 3.5GB , 26 million rows )
1.1 pandas : chunked read . filtered to 2017 , 2018
1.2 extract TRACK_ID from Spotify URL
  2. Stage 2 : Analysis in SQL
2.1 staging table -> normalized into star schema 
2.2 conducting analysis 
  3. Stage 3 : Visualization ( BI )
3.1 Data visualization via POWER BI

# Schema :
 1. dbo.stg_charts : basic flat data file
 2. facts_charts_table  : one row per chart position, per day, per region
 3. dim_artists : one row per unique artist
 4. dim_tracks : one row per unique track
 5. dim_region : one row per unique region

# Findings :
 1. "streams" is displayed as null for 100% of Viral 50 rows . Spotify never published stream counts for that chart , because viral 50 streams are calculated by shares and likes on social media platforms . Hence , not a data quality issue .
 2. MENA markets (Saudi Arabia, Egypt, Morocco, UAE) show a sharp entry-count drop-off . Spotify didn't launch application in the respective countries until November 2018 .
 3. Real artist credit strings run up to 788 characters (large ensemble-cast releases), which drove two schema decisions: "nvarchar(max)" on the staging table, and no "UNIQUE" constraint on "dim_artists" (SQL Server's index size limit tops out around 450 characters .
 4. Each track's real Spotify ID is extracted directly from its chart URL and used as "dim_tracks" primary key, rather than matching on title text . 

-- ==============================================================================
-- CREDIT CARD FRAUD DETECTION — PHASE 2: SQL BUSINESS ANALYSIS
-- Author  : Rakesh Roy | Data Analyst
-- Tool    : MySQL 8.0+
-- Run     : After 01_Data_Cleaning.py produces creditcard_clean.csv
-- ==============================================================================

-- ==============================================================================
-- PART A — DATABASE & TABLE SETUP
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS fraud_detection
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE fraud_detection;

DROP TABLE IF EXISTS creditcard;

CREATE TABLE creditcard (
    id               INT           AUTO_INCREMENT PRIMARY KEY,
    Time             FLOAT         NOT NULL,
    Amount           FLOAT         NOT NULL,
    Class            TINYINT       NOT NULL COMMENT '0=Genuine 1=Fraud',
    V1               FLOAT,  V2  FLOAT,  V3  FLOAT,  V4  FLOAT,
    V5               FLOAT,  V6  FLOAT,  V7  FLOAT,  V8  FLOAT,
    V9               FLOAT,  V10 FLOAT,  V11 FLOAT,  V12 FLOAT,
    V13              FLOAT,  V14 FLOAT,  V15 FLOAT,  V16 FLOAT,
    V17              FLOAT,  V18 FLOAT,  V19 FLOAT,  V20 FLOAT,
    V21              FLOAT,  V22 FLOAT,  V23 FLOAT,  V24 FLOAT,
    V25              FLOAT,  V26 FLOAT,  V27 FLOAT,  V28 FLOAT,
    Hour             TINYINT  COMMENT '0-23',
    Day              TINYINT  COMMENT '1 or 2',
    Shift            VARCHAR(15),
    Amount_Category  VARCHAR(10),
    Amount_Log       FLOAT,
    Risk_Flag        VARCHAR(10)
);

-- ==============================================================================
-- PART B — IMPORT CSV
-- ==============================================================================
-- OPTION 1: LOAD DATA (fastest — update path to match your system)
-- ------------------------------------------------------------------------------
-- Windows path example  : 'C:/fraud_project/creditcard_clean.csv'
-- Mac/Linux path example: '/home/username/fraud_project/creditcard_clean.csv'
-- ------------------------------------------------------------------------------

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/fraud_project/creditcard_clean.csv'
INTO TABLE creditcard
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Time, Amount, Class,
 V1,  V2,  V3,  V4,  V5,  V6,  V7,  V8,  V9,  V10,
 V11, V12, V13, V14, V15, V16, V17, V18, V19, V20,
 V21, V22, V23, V24, V25, V26, V27, V28,
 Hour, Day, Shift, Amount_Category, Amount_Log, Risk_Flag);

-- ------------------------------------------------------------------------------
-- OPTION 2: Table Data Import Wizard (if LOAD DATA fails)
--   Right-click "creditcard" table in MySQL Workbench
--   → Table Data Import Wizard → browse creditcard_clean.csv → Finish
-- ------------------------------------------------------------------------------

-- Verify import
SELECT
    COUNT(*)       AS total_rows,      -- expected: 284,807
    SUM(Class)     AS fraud_count,     -- expected: 492
    ROUND(SUM(Class) * 100.0
          / COUNT(*), 3) AS fraud_rate -- expected: ~0.173
FROM creditcard;

-- ==============================================================================
-- PART C — 10 BUSINESS QUERIES (BASIC → ADVANCED)
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- Q1 | BASIC | Overall Fraud vs Genuine Breakdown
-- Business question: What is our baseline fraud rate?
-- SQL concepts: GROUP BY, aggregate functions, CASE WHEN
-- Tableau use: Page 1 — KPI cards + donut chart
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    CASE WHEN Class = 1
         THEN 'Fraud' ELSE 'Genuine' END    AS Transaction_Type,
    COUNT(*)                                AS Total_Count,
    ROUND(SUM(Amount), 2)                   AS Total_Amount,
    ROUND(AVG(Amount), 2)                   AS Avg_Amount,
    ROUND(MAX(Amount), 2)                   AS Max_Amount,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER()
    , 3)                                    AS Percentage
FROM creditcard
GROUP BY Class
ORDER BY Class DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q2 | BASIC | Fraud Rate by Shift
-- Business question: Which business shift has the most fraud activity?
-- SQL concepts: GROUP BY, ROUND, CASE WHEN, ORDER BY
-- Tableau use: Page 2 — Fraud Trend Analysis (shift bar chart)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Shift,
    COUNT(*)                                    AS Total_Txn,
    SUM(Class)                                  AS Fraud_Count,
    COUNT(*) - SUM(Class)                       AS Genuine_Count,
    ROUND(AVG(Amount), 2)                       AS Avg_Amount,
    ROUND(SUM(Class) * 100.0 / COUNT(*), 4)    AS Fraud_Rate_Pct,
    ROUND(SUM(CASE WHEN Class = 1
                   THEN Amount ELSE 0 END), 2)  AS Total_Fraud_Exposure
FROM creditcard
GROUP BY Shift
ORDER BY Fraud_Rate_Pct DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q3 | BASIC | Fraud Rate by Amount Category
-- Business question: Which spend bracket carries the highest fraud risk?
-- SQL concepts: GROUP BY, aggregate functions, ORDER BY
-- Tableau use: Page 3 — Amount vs Fraud Pattern
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Amount_Category,
    COUNT(*)                                    AS Total_Txn,
    SUM(Class)                                  AS Fraud_Count,
    COUNT(*) - SUM(Class)                       AS Genuine_Count,
    ROUND(MIN(Amount), 2)                       AS Min_Amount,
    ROUND(AVG(Amount), 2)                       AS Avg_Amount,
    ROUND(MAX(Amount), 2)                       AS Max_Amount,
    ROUND(SUM(Class) * 100.0 / COUNT(*), 4)    AS Fraud_Rate_Pct
FROM creditcard
GROUP BY Amount_Category
ORDER BY Fraud_Rate_Pct DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q4 | INTERMEDIATE | Hourly Fraud Trend with Risk Ranking
-- Business question: Which hours need enhanced fraud monitoring?
-- SQL concepts: GROUP BY + RANK() OVER window function
-- Tableau use: Page 4 — Time-based Heatmap (hourly line chart)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Hour,
    COUNT(*)                                              AS Total_Txn,
    SUM(Class)                                            AS Fraud_Count,
    COUNT(*) - SUM(Class)                                 AS Genuine_Count,
    ROUND(SUM(Class) * 100.0 / COUNT(*), 4)              AS Fraud_Rate_Pct,
    ROUND(SUM(CASE WHEN Class=1
                   THEN Amount ELSE 0 END), 2)            AS Fraud_Exposure,
    RANK() OVER(ORDER BY SUM(Class) DESC)                 AS Volume_Rank,
    RANK() OVER(
        ORDER BY SUM(Class) * 100.0 / COUNT(*) DESC
    )                                                     AS Rate_Rank
FROM creditcard
GROUP BY Hour
ORDER BY Hour;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q5 | INTERMEDIATE | Running Total Fraud Exposure by Hour
-- Business question: At which hour does cumulative fraud cross $10K, $50K?
-- SQL concepts: SUM() OVER(ORDER BY ... ROWS UNBOUNDED PRECEDING)
-- Tableau use: Page 2 — cumulative area chart
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Hour,
    SUM(CASE WHEN Class = 1 THEN 1     ELSE 0 END)   AS Hourly_Fraud_Count,
    ROUND(
        SUM(CASE WHEN Class = 1 THEN Amount ELSE 0 END)
    , 2)                                              AS Hourly_Fraud_Amount,
    SUM(SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END))
        OVER(ORDER BY Hour
             ROWS BETWEEN UNBOUNDED PRECEDING
                  AND CURRENT ROW)                    AS Running_Fraud_Count,
    ROUND(
        SUM(SUM(CASE WHEN Class=1 THEN Amount ELSE 0 END))
        OVER(ORDER BY Hour
             ROWS BETWEEN UNBOUNDED PRECEDING
                  AND CURRENT ROW)
    , 2)                                              AS Running_Fraud_Exposure
FROM creditcard
GROUP BY Hour
ORDER BY Hour;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q6 | INTERMEDIATE | Top 10 Highest Value Fraud Transactions
-- Business question: Which individual transactions represent peak exposure?
-- SQL concepts: RANK() OVER, NTILE() OVER, WHERE, LIMIT
-- Tableau use: Page 3 — top transactions table
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Hour,
    Day,
    Shift,
    ROUND(Amount, 2)                      AS Amount,
    Risk_Flag,
    RANK()   OVER(ORDER BY Amount DESC)   AS Exposure_Rank,
    NTILE(4) OVER(ORDER BY Amount DESC)   AS Quartile
FROM creditcard
WHERE Class = 1
ORDER BY Amount DESC
LIMIT 10;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q7 | ADVANCED | CTE — Hourly Risk Classification
-- Business question: Auto-classify each hour as High / Medium / Low risk
-- SQL concepts: WITH (CTE) chained × 2 + CASE WHEN scoring
-- Tableau use: Page 4 — heatmap color coding
-- ─────────────────────────────────────────────────────────────────────────────
WITH hourly_stats AS (
    SELECT
        Hour,
        COUNT(*)                                    AS total_txn,
        SUM(Class)                                  AS fraud_count,
        ROUND(SUM(Class) * 100.0 / COUNT(*), 4)    AS fraud_rate_pct,
        ROUND(SUM(CASE WHEN Class = 1
                       THEN Amount ELSE 0 END), 2)  AS fraud_exposure
    FROM creditcard
    GROUP BY Hour
),
risk_classified AS (
    SELECT
        Hour,
        total_txn,
        fraud_count,
        fraud_rate_pct,
        fraud_exposure,
        CASE
            WHEN fraud_rate_pct > 0.30 THEN 'High Risk'
            WHEN fraud_rate_pct > 0.15 THEN 'Medium Risk'
            ELSE                            'Low Risk'
        END                                         AS Risk_Level,
        RANK() OVER(ORDER BY fraud_rate_pct DESC)   AS Risk_Rank
    FROM hourly_stats
)
SELECT *
FROM risk_classified
ORDER BY fraud_rate_pct DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q8 | ADVANCED | CTE + LAG — Day-over-Day Fraud Comparison
-- Business question: Did fraud increase or decrease from Day 1 to Day 2?
-- SQL concepts: CTE + LAG() window function + computed % change
-- Tableau use: Page 2 — day comparison bar + trend arrow
-- ─────────────────────────────────────────────────────────────────────────────
WITH daily_base AS (
    SELECT
        Day,
        COUNT(*)                                        AS total_txn,
        SUM(Class)                                      AS fraud_count,
        ROUND(SUM(Class) * 100.0 / COUNT(*), 4)        AS fraud_rate_pct,
        ROUND(SUM(CASE WHEN Class = 1
                       THEN Amount ELSE 0 END), 2)      AS fraud_exposure,
        ROUND(AVG(CASE WHEN Class = 1
                       THEN Amount END), 2)             AS avg_fraud_amount
    FROM creditcard
    GROUP BY Day
),
daily_comparison AS (
    SELECT
        Day,
        total_txn,
        fraud_count,
        fraud_rate_pct,
        fraud_exposure,
        avg_fraud_amount,
        LAG(fraud_count)
            OVER(ORDER BY Day)                          AS prev_day_count,
        LAG(fraud_exposure)
            OVER(ORDER BY Day)                          AS prev_day_exposure,
        fraud_count -
            LAG(fraud_count)
            OVER(ORDER BY Day)                          AS count_change,
        ROUND(
            (fraud_count -
             LAG(fraud_count) OVER(ORDER BY Day))
            * 100.0
            / NULLIF(LAG(fraud_count) OVER(ORDER BY Day), 0)
        , 2)                                            AS pct_change
    FROM daily_base
)
SELECT * FROM daily_comparison;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q9 | ADVANCED | CTE — Amount Percentile Distribution
-- Business question: What is the statistical profile of fraud amounts?
-- SQL concepts: NTILE(100) OVER PARTITION BY + pivot with MAX(CASE WHEN)
-- Tableau use: Page 3 — percentile comparison chart
-- ─────────────────────────────────────────────────────────────────────────────
WITH base AS (
    SELECT
        Class,
        Amount,
        NTILE(100) OVER(
            PARTITION BY Class
            ORDER BY Amount
        )                   AS pct
    FROM creditcard
),
pivoted AS (
    SELECT
        CASE WHEN Class = 1
             THEN 'Fraud' ELSE 'Genuine' END        AS Type,
        ROUND(MAX(CASE WHEN pct = 25
                       THEN Amount END), 2)          AS P25,
        ROUND(MAX(CASE WHEN pct = 50
                       THEN Amount END), 2)          AS Median_P50,
        ROUND(MAX(CASE WHEN pct = 75
                       THEN Amount END), 2)          AS P75,
        ROUND(MAX(CASE WHEN pct = 90
                       THEN Amount END), 2)          AS P90,
        ROUND(MAX(CASE WHEN pct = 95
                       THEN Amount END), 2)          AS P95,
        ROUND(MAX(CASE WHEN pct = 99
                       THEN Amount END), 2)          AS P99,
        ROUND(MAX(Amount), 2)                        AS Max_Amount
    FROM base
    GROUP BY Class
)
SELECT * FROM pivoted
ORDER BY Type DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q10 | ADVANCED | CTE + Window Stats — Rule-Based Risk Scoring Engine
-- Business question: Flag and score every fraud transaction automatically
-- SQL concepts: CROSS JOIN stats + nested CTEs + STDDEV() + CASE scoring
-- Tableau use: Page 5 — Risk Intelligence treemap + exposure table
-- INTERVIEW NOTE: This mirrors a real production fraud scoring pipeline
-- ─────────────────────────────────────────────────────────────────────────────
WITH global_stats AS (
    SELECT
        ROUND(AVG(Amount), 4)    AS global_avg,
        ROUND(STDDEV(Amount), 4) AS global_std
    FROM creditcard
),
scored AS (
    SELECT
        c.Hour,
        c.Day,
        c.Shift,
        c.Amount_Category,
        ROUND(c.Amount, 2)      AS Amount,
        c.Class,
        g.global_avg,
        g.global_std,
        ROUND(g.global_avg + 2 * g.global_std, 2) AS critical_threshold,
        CASE
            WHEN c.Class = 1
                 AND c.Amount > g.global_avg + 2 * g.global_std
                                            THEN 'Critical'
            WHEN c.Class = 1
                 AND c.Amount > g.global_avg THEN 'High'
            WHEN c.Class = 1                THEN 'Medium'
            ELSE                                 'Genuine'
        END                     AS Computed_Risk
    FROM creditcard c
    CROSS JOIN global_stats g
),
risk_summary AS (
    SELECT
        Computed_Risk,
        COUNT(*)                              AS Txn_Count,
        ROUND(AVG(Amount), 2)                 AS Avg_Amount,
        ROUND(MIN(Amount), 2)                 AS Min_Amount,
        ROUND(MAX(Amount), 2)                 AS Max_Amount,
        ROUND(SUM(Amount), 2)                 AS Total_Exposure,
        ROUND(
            COUNT(*) * 100.0
            / SUM(COUNT(*)) OVER()
        , 2)                                  AS Pct_of_All_Fraud
    FROM scored
    WHERE Class = 1
    GROUP BY Computed_Risk
)
SELECT *
FROM risk_summary
ORDER BY Avg_Amount DESC;

-- ==============================================================================
-- PART D — EXPORT VIEWS FOR TABLEAU
-- Run each SELECT * and export as CSV from MySQL Workbench
-- ==============================================================================

-- VIEW 1 — Overview (for KPI cards + donut)
CREATE OR REPLACE VIEW vw_01_overview AS
SELECT
    CASE WHEN Class = 1 THEN 'Fraud' ELSE 'Genuine' END AS Type,
    COUNT(*)                                             AS Total_Count,
    ROUND(SUM(Amount), 2)                               AS Total_Amount,
    ROUND(AVG(Amount), 2)                               AS Avg_Amount,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 3)  AS Percentage
FROM creditcard
GROUP BY Class;

-- VIEW 2 — Hourly trend (for line chart + heatmap)
CREATE OR REPLACE VIEW vw_02_hourly AS
SELECT
    Hour, Day, Shift,
    COUNT(*)                                            AS Total_Txn,
    SUM(Class)                                          AS Fraud_Count,
    COUNT(*) - SUM(Class)                               AS Genuine_Count,
    ROUND(SUM(Class) * 100.0 / COUNT(*), 4)            AS Fraud_Rate,
    ROUND(SUM(CASE WHEN Class=1 THEN Amount ELSE 0 END),2) AS Fraud_Amount
FROM creditcard
GROUP BY Hour, Day, Shift;

-- VIEW 3 — Amount analysis (for amount charts)
CREATE OR REPLACE VIEW vw_03_amount AS
SELECT
    Amount_Category,
    CASE WHEN Class = 1 THEN 'Fraud' ELSE 'Genuine' END AS Type,
    COUNT(*)                                             AS Count,
    ROUND(AVG(Amount), 2)                               AS Avg_Amount,
    ROUND(SUM(Amount), 2)                               AS Total_Amount
FROM creditcard
GROUP BY Amount_Category, Class;

-- VIEW 4 — Risk flags (for treemap + risk table)
CREATE OR REPLACE VIEW vw_04_risk AS
SELECT
    Risk_Flag,
    COUNT(*)               AS Count,
    ROUND(AVG(Amount), 2)  AS Avg_Amount,
    ROUND(SUM(Amount), 2)  AS Total_Exposure
FROM creditcard
WHERE Class = 1
GROUP BY Risk_Flag;

-- VIEW 5 — Full fraud transactions (for scatter + detail table)
CREATE OR REPLACE VIEW vw_05_fraud_detail AS
SELECT
    Hour, Day, Shift, Amount_Category,
    ROUND(Amount, 2) AS Amount,
    Risk_Flag,
    Amount_Log
FROM creditcard
WHERE Class = 1;

-- Verify all views
SELECT 'vw_01_overview'     AS view_name, COUNT(*) AS rows FROM vw_01_overview
UNION ALL
SELECT 'vw_02_hourly',      COUNT(*) FROM vw_02_hourly
UNION ALL
SELECT 'vw_03_amount',      COUNT(*) FROM vw_03_amount
UNION ALL
SELECT 'vw_04_risk',        COUNT(*) FROM vw_04_risk
UNION ALL
SELECT 'vw_05_fraud_detail',COUNT(*) FROM vw_05_fraud_detail;

-- ==============================================================================
-- PHASE 2 COMPLETE
-- Next step: Open Tableau → Connect → MySQL
--            Or export each view as CSV and connect via Text File
-- ==============================================================================

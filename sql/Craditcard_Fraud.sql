Use Craditcard_Fraud
-- ─────────────────────────────────────────────────────────────────────────────
-- Q1 What is our baseline fraud rate?
-- Tableau use: Page 1 — KPI cards + donut chart
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    CASE
        WHEN Class = 1 THEN 'Fraud'
        ELSE 'Genuine'
    END AS Transaction_Type,
    COUNT(*) AS Total_Count,
    ROUND(SUM(Amount),2) AS Total_Amount,
    ROUND(AVG(Amount),2) AS Avg_Amount,
    ROUND(MAX(Amount),2) AS Max_Amount,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER(),3
    ) AS Percentage
FROM creditcard
GROUP BY Class;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q2 Which business shift has the most fraud activity?
-- Tableau use: Page 2 — Fraud Trend Analysis (shift bar chart)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Shift,
    COUNT(*) AS Total_Txn,
    SUM(Class) AS Fraud_Count,
    ROUND(AVG(Amount),2) AS Avg_Amount,
    ROUND(
        SUM(Class) * 100.0 / COUNT(*),4
    ) AS Fraud_Rate_Pct,
    ROUND(
        SUM(CASE WHEN Class=1 THEN Amount ELSE 0 END),2
    ) AS Fraud_Exposure
FROM creditcard
GROUP BY Shift
ORDER BY Fraud_Rate_Pct DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q3 Which spend bracket carries the highest fraud risk?
-- Tableau use: Page 3 — Amount vs Fraud Pattern
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Amount_Category,
    COUNT(*) AS Total_Txn,
    SUM(Class) AS Fraud_Count,
    ROUND(
        SUM(Class) * 100.0 / COUNT(*),4
    ) AS Fraud_Rate_Pct
FROM creditcard
GROUP BY Amount_Category
ORDER BY Fraud_Rate_Pct DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q4 Which hours need enhanced fraud monitoring?
-- Tableau use: Page 4 — Time-based Heatmap (hourly line chart)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Hour,
    COUNT(*) AS Total_Txn,
    SUM(Class) AS Fraud_Count,
    ROUND(
        SUM(Class) * 100.0 / COUNT(*),4
    ) AS Fraud_Rate_Pct,
    ROUND(
        SUM(CASE WHEN Class=1 THEN Amount ELSE 0 END),2
    ) AS Fraud_Exposure,
    RANK() OVER(
        ORDER BY SUM(Class) DESC
    ) AS Fraud_Rank
FROM creditcard
GROUP BY Hour
ORDER BY Hour;
-- ─────────────────────────────────────────────────────────────────────────────
-- Q5 At which hour does cumulative fraud cross $10K, $50K?
-- Tableau use: Page 2 — cumulative area chart
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Hour,
    SUM(CASE WHEN Class=1 THEN 1 ELSE 0 END) AS Fraud_Count,
    ROUND(
        SUM(CASE WHEN Class=1 THEN Amount ELSE 0 END),2
    ) AS Fraud_Amount,
    SUM(
        SUM(CASE WHEN Class=1 THEN Amount ELSE 0 END)
    ) OVER(
        ORDER BY Hour
    ) AS Running_Exposure
FROM creditcard
GROUP BY Hour
ORDER BY Hour;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q6 Which individual transactions represent peak exposure?
-- Tableau use: Page 3 — top transactions table
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Hour,
    Day,
    Shift,
    Amount,
    Risk_Flag
FROM creditcard
WHERE Class = 1
ORDER BY Amount DESC
LIMIT 10;
-- ─────────────────────────────────────────────────────────────────────────────
-- Q7 Auto-classify each hour as High / Medium / Low risk
-- Tableau use: Page 4 — heatmap color coding
-- ─────────────────────────────────────────────────────────────────────────────
WITH hourly_stats AS (
    SELECT
        Hour,
        SUM(Class) AS Fraud_Count,
        ROUND(
            SUM(Class) * 100.0 / COUNT(*),4
        ) AS Fraud_Rate
    FROM creditcard
    GROUP BY Hour
)

SELECT
    Hour,
    Fraud_Count,
    Fraud_Rate,
    CASE
        WHEN Fraud_Rate > 0.30 THEN 'High Risk'
        WHEN Fraud_Rate > 0.15 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS Risk_Level,
    RANK() OVER(
        ORDER BY Fraud_Rate DESC
    ) AS Risk_Rank
FROM hourly_stats;
-- ─────────────────────────────────────────────────────────────────────────────
-- Q8 Did fraud increase or decrease from Day 1 to Day 2?
-- Tableau use: Page 2 — day comparison bar + trend arrow
-- ─────────────────────────────────────────────────────────────────────────────
WITH daily_stats AS (
    SELECT
        Day,
        SUM(Class) AS Fraud_Count,
        ROUND(SUM(CASE WHEN Class=1 THEN Amount ELSE 0 END),2) AS Fraud_Exposure
    FROM creditcard
    GROUP BY Day
)
SELECT
    Day,
    Fraud_Count,
    Fraud_Exposure,
    LAG(Fraud_Count) OVER(ORDER BY Day) AS Prev_Day_Fraud
FROM daily_stats;

-- ─────────────────────────────────────────────────────────────────────────────
-- Q9 What is the statistical profile of fraud amounts?
-- Tableau use: Page 3 — percentile comparison chart
-- ─────────────────────────────────────────────────────────────────────────────
WITH pct_base AS (
    SELECT
        Class,
        Amount,
        NTILE(100) OVER(
            PARTITION BY Class
            ORDER BY Amount
        ) AS Percentile
    FROM creditcard
)

SELECT
    CASE
        WHEN Class=1 THEN 'Fraud'
        ELSE 'Genuine'
    END AS Type,
    ROUND(MAX(CASE WHEN Percentile=25 THEN Amount END),2) AS P25,
    ROUND(MAX(CASE WHEN Percentile=50 THEN Amount END),2) AS P50,
    ROUND(MAX(CASE WHEN Percentile=75 THEN Amount END),2) AS P75,
    ROUND(MAX(CASE WHEN Percentile=90 THEN Amount END),2) AS P90,
    ROUND(MAX(CASE WHEN Percentile=99 THEN Amount END),2) AS P99
FROM pct_base
GROUP BY Class;
-- ─────────────────────────────────────────────────────────────────────────────
-- Q10 Flag and score every fraud transaction automatically
-- Tableau use: Page 5 — Risk Intelligence treemap + exposure table
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    Risk_Flag,
    COUNT(*) AS Fraud_Count,
    ROUND(AVG(Amount),2) AS Avg_Amount,
    ROUND(SUM(Amount),2) AS Total_Exposure
FROM creditcard
WHERE Class=1
GROUP BY Risk_Flag
ORDER BY Total_Exposure DESC;
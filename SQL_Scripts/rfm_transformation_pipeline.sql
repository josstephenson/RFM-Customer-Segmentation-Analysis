/*
=========================================================================================
Joseph Stephenson
RFM Customer Segmentation Pipeline
This BigQuery script transforms raw monthly transaction data into a segmented customer 
database using Recency, Frequency, and Monetary (RFM) logic.
=========================================================================================
*/

-- 1: DATA CONSOLIDATION
-- Merging 12 monthly sales tables into a single source-of-truth for the year 2025.

CREATE OR REPLACE TABLE rfm555.sales.sales_2025 AS
SELECT * FROM `rfm555.sales.sales2025*`
WHERE _TABLE_SUFFIX BETWEEN '01' AND '12';

-- 2: CALCULATE RAW RFM METRICS
-- Defining the 'Analysis Date' and aggregating customer behavior.

CREATE OR REPLACE VIEW rfm555.sales.rfm_metrics AS
WITH `current_date` AS (
    SELECT DATE('2026-05-06') AS analysis_date 
),
rfm AS (
    SELECT
        CustomerID,
        MAX(OrderDate) AS last_order_date,
        -- Calculating days since last purchase
        DATE_DIFF((SELECT analysis_date FROM `current_date`), MAX(OrderDate), DAY) AS recency,
        -- Total transaction volume
        COUNT(*) AS frequency,
        -- Total spend value
        SUM(OrderValue) AS monetary
    FROM rfm555.sales.sales_2025
    GROUP BY CustomerID
)
SELECT
    rfm.*,
    ROW_NUMBER() OVER(ORDER BY recency ASC) AS r_rank, 
    ROW_NUMBER() OVER(ORDER BY frequency DESC) AS f_rank, 
    ROW_NUMBER() OVER(ORDER BY monetary DESC) AS m_rank 
FROM rfm;

-- 3: ASSIGN DECILES
-- Using NTILE to distribute customers into 10 equal groups for granular scoring.

CREATE OR REPLACE VIEW rfm555.sales.rfm_scores AS
SELECT
    *,
    NTILE(10) OVER(ORDER BY r_rank DESC) AS r_score,
    NTILE(10) OVER(ORDER BY f_rank DESC) AS f_score,
    NTILE(10) OVER(ORDER BY m_rank DESC) AS m_score
FROM rfm555.sales.rfm_metrics;

-- 4: CALCULATE AGGREGATED RFM SCORE

CREATE OR REPLACE VIEW rfm555.sales.rfm_total_scores AS
SELECT
    *,
    (r_score + f_score + m_score) AS rfm_total_score
FROM rfm555.sales.rfm_scores;

-- 5: FINAL BUSINESS SEGMENTATION
-- Mapping numerical scores to actionable marketing segments.

CREATE OR REPLACE VIEW rfm555.sales.rfm_segments_final AS
SELECT
    *,
    CASE
        WHEN rfm_total_score >= 28 THEN 'Champions'
        WHEN rfm_total_score >= 24 THEN 'Loyal VIPs'
        WHEN rfm_total_score >= 20 THEN 'Potential Loyalists'
        WHEN rfm_total_score >= 16 THEN 'Promising'
        WHEN rfm_total_score >= 12 THEN 'Engaged'
        WHEN rfm_total_score >= 8 THEN 'Requires Attention'
        WHEN rfm_total_score >= 4 THEN 'At Risk'
        ELSE 'Lost/Inactive'
    END AS rfm_segment
FROM rfm555.sales.rfm_total_scores
ORDER BY rfm_total_score DESC;

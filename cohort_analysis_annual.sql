-- Annual Cohort Spending View

SET search_path TO dtc;

CREATE OR REPLACE VIEW vw_cohort_activity_annual AS
WITH customer_cohort AS (
    SELECT
        c.customer_key,
        EXTRACT(YEAR FROM c.acquisition_date)::int AS cohort_year,
        ch.channel_name AS acquisition_channel
    FROM dim_customer c
    JOIN dim_channel ch ON c.acquisition_channel_key = ch.channel_key
),
cohort_size AS (
    SELECT cohort_year, acquisition_channel, COUNT(*) AS cohort_size
    FROM customer_cohort
    GROUP BY cohort_year, acquisition_channel
),
order_activity AS (
    SELECT
        cc.cohort_year,
        cc.acquisition_channel,
        EXTRACT(YEAR FROM d.date)::int AS activity_year,
        fo.customer_key,
        fo.order_id,
        fo.net_revenue
    FROM fact_orders fo
    JOIN dim_date d ON fo.date_key = d.date_key
    JOIN customer_cohort cc ON fo.customer_key = cc.customer_key
)
SELECT
    oa.cohort_year,
    oa.acquisition_channel,
    oa.activity_year,
    (oa.activity_year - oa.cohort_year) AS years_since_acquisition,
    cs.cohort_size,
    COUNT(DISTINCT oa.customer_key) AS active_customers,
    COUNT(DISTINCT oa.order_id) AS orders,
    ROUND(SUM(oa.net_revenue), 2) AS revenue,
    ROUND(SUM(oa.net_revenue) / COUNT(DISTINCT oa.customer_key), 2) AS avg_revenue_per_active_customer,
    ROUND(SUM(oa.net_revenue) / cs.cohort_size, 2) AS avg_revenue_per_cohort_customer,
    ROUND(COUNT(DISTINCT oa.customer_key)::numeric / cs.cohort_size, 4) AS retention_rate
FROM order_activity oa
JOIN cohort_size cs
    ON oa.cohort_year = cs.cohort_year AND oa.acquisition_channel = cs.acquisition_channel
GROUP BY oa.cohort_year, oa.acquisition_channel, oa.activity_year, cs.cohort_size
ORDER BY oa.cohort_year, oa.acquisition_channel, oa.activity_year;


-- Sanity check
SELECT cohort_year, acquisition_channel, cohort_size, activity_year,
       years_since_acquisition, active_customers, revenue, avg_revenue_per_active_customer
FROM vw_cohort_activity_annual
ORDER BY cohort_year, acquisition_channel, activity_year
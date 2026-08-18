-- ============================================================
-- CUSTOMER RETENTION ANALYSIS
-- STEP 1: CUSTOMER ORDER BASE
-- ============================================================
SELECT
    order_id,
    customer_id,
    product_id,
    category,
    price,
    discount,
    quantity,
    payment_method,
    STR_TO_DATE(order_date, '%d-%m-%Y') AS order_date,
    delivery_time_days,
    region,
    returned,
    total_amount,
    shipping_cost,
    profit_margin,
    customer_age,
    customer_gender
FROM ecommerce_sales
LIMIT 10;
-- ============================================================
-- STEP 2: CUSTOMER PURCHASE SUMMARY
-- ============================================================

SELECT
    customer_id,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_amount) AS total_spent,
    MIN(STR_TO_DATE(order_date, '%d-%m-%Y')) AS first_purchase_date,
    MAX(STR_TO_DATE(order_date, '%d-%m-%Y')) AS last_purchase_date
FROM ecommerce_sales
GROUP BY customer_id
ORDER BY total_spent DESC;
-- ============================================================
-- STEP 3: REPEAT PURCHASE RATE
-- ============================================================

WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS total_orders
    FROM ecommerce_sales
    GROUP BY customer_id
)

SELECT
    COUNT(*) AS total_customers,

    SUM(
        CASE
            WHEN total_orders > 1 THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    ROUND(
        SUM(
            CASE
                WHEN total_orders > 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS repeat_purchase_rate
FROM customer_orders;
-- ============================================================
-- STEP 4: DATASET REFERENCE DATE
-- ============================================================

SELECT
    MAX(STR_TO_DATE(order_date, '%d-%m-%Y')) AS analysis_date
FROM ecommerce_sales;
-- ============================================================
-- STEP 5: CUSTOMER RECENCY & AT-RISK CUSTOMERS
-- ============================================================

WITH customer_summary AS (
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(total_amount) AS total_spent,
        MIN(STR_TO_DATE(order_date, '%d-%m-%Y')) AS first_purchase_date,
        MAX(STR_TO_DATE(order_date, '%d-%m-%Y')) AS last_purchase_date
    FROM ecommerce_sales
    GROUP BY customer_id
)

SELECT
    customer_id,
    total_orders,
    ROUND(total_spent, 2) AS total_spent,
    first_purchase_date,
    last_purchase_date,

    DATEDIFF(
        '2025-09-11',
        last_purchase_date
    ) AS recency_days,

    CASE
        WHEN DATEDIFF('2025-09-11', last_purchase_date) > 90
        THEN 'At Risk'
        ELSE 'Active'
    END AS customer_status

FROM customer_summary
ORDER BY recency_days DESC;
-- ============================================================
-- STEP 6: CUSTOMER RETENTION STATUS
-- ============================================================

WITH customer_summary AS (
    SELECT
        customer_id,
        MAX(STR_TO_DATE(order_date, '%d-%m-%Y')) AS last_purchase_date
    FROM ecommerce_sales
    GROUP BY customer_id
)

SELECT
    CASE
        WHEN DATEDIFF(
            '2025-09-11',
            last_purchase_date
        ) > 90
        THEN 'At Risk'
        ELSE 'Active'
    END AS customer_status,

    COUNT(*) AS customers,

    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM customer_summary),
        2
    ) AS percentage

FROM customer_summary

GROUP BY customer_status
ORDER BY customers DESC;
-- ============================================================
-- STEP 7: REVENUE AT RISK
-- ============================================================

WITH customer_summary AS (
    SELECT
        customer_id,
        SUM(total_amount) AS total_spent,
        MAX(STR_TO_DATE(order_date, '%d-%m-%Y')) AS last_purchase_date
    FROM ecommerce_sales
    GROUP BY customer_id
),

customer_status AS (
    SELECT
        customer_id,
        total_spent,

        CASE
            WHEN DATEDIFF(
                '2025-09-11',
                last_purchase_date
            ) > 90
            THEN 'At Risk'
            ELSE 'Active'
        END AS customer_status

    FROM customer_summary
)

SELECT
    customer_status,
    COUNT(*) AS customers,
    ROUND(SUM(total_spent), 2) AS revenue,
    ROUND(
        SUM(total_spent) * 100.0 /
        (SELECT SUM(total_spent) FROM customer_status),
        2
    ) AS revenue_percentage

FROM customer_status

GROUP BY customer_status
ORDER BY revenue DESC;
-- ============================================================
-- STEP 8: RETENTION BY REGION
-- ============================================================

WITH customer_summary AS (
    SELECT
        customer_id,
        MAX(region) AS region,
        MAX(STR_TO_DATE(order_date, '%d-%m-%Y')) AS last_purchase_date
    FROM ecommerce_sales
    GROUP BY customer_id
),

customer_status AS (
    SELECT
        customer_id,
        region,

        CASE
            WHEN DATEDIFF(
                '2025-09-11',
                last_purchase_date
            ) > 90
            THEN 'At Risk'
            ELSE 'Active'
        END AS customer_status

    FROM customer_summary
)

SELECT
    region,
    COUNT(*) AS total_customers,

    SUM(
        CASE
            WHEN customer_status = 'At Risk'
            THEN 1
            ELSE 0
        END
    ) AS at_risk_customers,

    ROUND(
        SUM(
            CASE
                WHEN customer_status = 'At Risk'
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS at_risk_percentage

FROM customer_status

GROUP BY region

ORDER BY at_risk_percentage DESC;
-- ============================================================
-- STEP 9: RFM CUSTOMER ANALYSIS
-- ============================================================

WITH customer_rfm AS (

    SELECT
        customer_id,

        DATEDIFF(
            '2025-09-11',
            MAX(STR_TO_DATE(order_date, '%d-%m-%Y'))
        ) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,

        ROUND(
            SUM(total_amount),
            2
        ) AS monetary

    FROM ecommerce_sales

    GROUP BY customer_id
)

SELECT
    customer_id,
    recency_days,
    frequency,
    monetary
FROM customer_rfm
ORDER BY monetary DESC;
-- ============================================================
-- STEP 10: RFM SCORING
-- ============================================================

WITH customer_rfm AS (

    SELECT
        customer_id,

        DATEDIFF(
            '2025-09-11',
            MAX(STR_TO_DATE(order_date, '%d-%m-%Y'))
        ) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,

        ROUND(
            SUM(total_amount),
            2
        ) AS monetary

    FROM ecommerce_sales

    GROUP BY customer_id
),

rfm_scores AS (

    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS r_score,

        NTILE(5) OVER (
            ORDER BY frequency ASC
        ) AS f_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM customer_rfm
)

SELECT *
FROM rfm_scores
ORDER BY monetary DESC;
-- ============================================================
-- STEP 11: RFM CUSTOMER SEGMENTATION
-- ============================================================

WITH customer_rfm AS (

    SELECT
        customer_id,

        DATEDIFF(
            '2025-09-11',
            MAX(STR_TO_DATE(order_date, '%d-%m-%Y'))
        ) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,

        ROUND(SUM(total_amount), 2) AS monetary

    FROM ecommerce_sales

    GROUP BY customer_id
),

rfm_scores AS (

    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS r_score,

        NTILE(5) OVER (
            ORDER BY frequency ASC
        ) AS f_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM customer_rfm
)

SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,

    CASE

        WHEN r_score >= 4
             AND f_score >= 4
             AND m_score >= 4
        THEN 'Champions'

        WHEN r_score >= 3
             AND f_score >= 3
        THEN 'Loyal Customers'

        WHEN r_score >= 4
             AND f_score <= 2
        THEN 'New Customers'

        WHEN r_score <= 2
             AND f_score >= 3
        THEN 'At Risk'

        WHEN r_score <= 2
             AND f_score <= 2
        THEN 'Lost Customers'

        ELSE 'Potential Loyalists'

    END AS rfm_segment

FROM rfm_scores
ORDER BY monetary DESC;
-- ============================================================
-- STEP 12: RFM SEGMENT SUMMARY
-- ============================================================

WITH customer_rfm AS (

    SELECT
        customer_id,

        DATEDIFF(
            '2025-09-11',
            MAX(STR_TO_DATE(order_date, '%d-%m-%Y'))
        ) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,

        ROUND(SUM(total_amount), 2) AS monetary

    FROM ecommerce_sales

    GROUP BY customer_id
),

rfm_scores AS (

    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS r_score,

        NTILE(5) OVER (
            ORDER BY frequency ASC
        ) AS f_score,

        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score

    FROM customer_rfm
),

segmented_customers AS (

    SELECT
        customer_id,
        monetary,

        CASE
            WHEN r_score >= 4
                 AND f_score >= 4
                 AND m_score >= 4
            THEN 'Champions'

            WHEN r_score >= 3
                 AND f_score >= 3
            THEN 'Loyal Customers'

            WHEN r_score >= 4
                 AND f_score <= 2
            THEN 'New Customers'

            WHEN r_score <= 2
                 AND f_score >= 3
            THEN 'At Risk'

            WHEN r_score <= 2
                 AND f_score <= 2
            THEN 'Lost Customers'

            ELSE 'Potential Loyalists'
        END AS rfm_segment

    FROM rfm_scores
)

SELECT
    rfm_segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(monetary), 2) AS total_revenue,
    ROUND(AVG(monetary), 2) AS avg_customer_value
FROM segmented_customers
GROUP BY rfm_segment
ORDER BY total_revenue DESC;
-- ============================================================
-- STEP 13: COHORT RETENTION ANALYSIS
-- ============================================================

WITH first_purchase AS (

    SELECT
        customer_id,
        DATE_FORMAT(
            MIN(STR_TO_DATE(order_date, '%d-%m-%Y')),
            '%Y-%m-01'
        ) AS cohort_month

    FROM ecommerce_sales

    GROUP BY customer_id
),

orders_with_cohort AS (

    SELECT
        o.customer_id,
        f.cohort_month,

        DATE_FORMAT(
            STR_TO_DATE(o.order_date, '%d-%m-%Y'),
            '%Y-%m-01'
        ) AS order_month

    FROM ecommerce_sales o

    JOIN first_purchase f
        ON o.customer_id = f.customer_id
)

SELECT
    cohort_month,

    TIMESTAMPDIFF(
        MONTH,
        cohort_month,
        order_month
    ) AS month_number,

    COUNT(DISTINCT customer_id) AS active_customers

FROM orders_with_cohort

GROUP BY
    cohort_month,
    month_number

ORDER BY
    cohort_month,
    month_number;
-- ============================================================
-- STEP 14: CUSTOMER CHURN / AT-RISK ANALYSIS
-- ============================================================

SELECT
    customer_id,

    MAX(
        STR_TO_DATE(order_date, '%d-%m-%Y')
    ) AS last_purchase_date,

    DATEDIFF(
        '2025-09-11',
        MAX(STR_TO_DATE(order_date, '%d-%m-%Y'))
    ) AS recency_days,

    COUNT(DISTINCT order_id) AS total_orders,

    ROUND(
        SUM(total_amount),
        2
    ) AS total_spent,

    CASE
        WHEN DATEDIFF(
            '2025-09-11',
            MAX(STR_TO_DATE(order_date, '%d-%m-%Y'))
        ) > 90
        THEN 'At Risk'

        ELSE 'Active'
    END AS customer_status

FROM ecommerce_sales

GROUP BY customer_id

ORDER BY recency_days DESC;
-- ============================================================
-- STEP 15: RETENTION SUMMARY
-- ============================================================

WITH customer_summary AS (

    SELECT
        customer_id,

        MAX(
            STR_TO_DATE(order_date, '%d-%m-%Y')
        ) AS last_purchase_date,

        COUNT(DISTINCT order_id) AS total_orders,

        ROUND(
            SUM(total_amount),
            2
        ) AS total_spent

    FROM ecommerce_sales

    GROUP BY customer_id
),

customer_status AS (

    SELECT
        customer_id,
        total_orders,
        total_spent,

        DATEDIFF(
            '2025-09-11',
            last_purchase_date
        ) AS recency_days,

        CASE
            WHEN DATEDIFF(
                '2025-09-11',
                last_purchase_date
            ) > 90
            THEN 'At Risk'
            ELSE 'Active'
        END AS status

    FROM customer_summary
)

SELECT

    COUNT(*) AS total_customers,

    SUM(
        CASE
            WHEN total_orders > 1 THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN total_orders > 1 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS repeat_purchase_rate,

    SUM(
        CASE
            WHEN status = 'At Risk' THEN 1
            ELSE 0
        END
    ) AS at_risk_customers,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN status = 'At Risk' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS at_risk_rate,

    ROUND(
        SUM(
            CASE
                WHEN status = 'At Risk'
                THEN total_spent
                ELSE 0
            END
        ),
        2
    ) AS revenue_at_risk

FROM customer_status;
WITH check_balance AS (
    SELECT
        month_id,
        MAX(starting_mrr) AS starting_mrr,
        MAX(ending_mrr) AS ending_mrr,
        SUM(mrr_change_amount) AS total_mrr_change
    FROM {{ ref('monthly_revenue_waterfall') }}
    GROUP BY month_id
)

SELECT
    *
FROM check_balance
WHERE ABS((starting_mrr + total_mrr_change) - ending_mrr) > 0.01
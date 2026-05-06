WITH monthly_account_mrr AS (
    SELECT
        active_month,
        account_id,
        SUM(mrr_amount) AS current_mrr,
        COUNT(DISTINCT subscription_id) AS active_subscription_count
    FROM {{ ref('fact_monthly_subscription_mrr') }}
    GROUP BY active_month, account_id
)

SELECT
    *
FROM monthly_account_mrr
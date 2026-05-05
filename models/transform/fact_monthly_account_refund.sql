WITH monthly_refund_amount AS (
    SELECT
        churn_month,
        account_id,
        ROUND(SUM(refund_amount_usd), 2) AS refund_amount
    FROM (
        SELECT
            account_id,
            CAST(DATE_TRUNC('MONTH', churn_date) AS DATE) AS churn_month,
            refund_amount_usd
        FROM {{ ref('stg__churn_events') }}
        WHERE refund_amount_usd > 0
    )
    GROUP BY churn_month, account_id
)

SELECT
    *
FROM monthly_refund_amount
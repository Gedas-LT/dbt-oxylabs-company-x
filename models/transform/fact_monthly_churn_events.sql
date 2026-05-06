WITH monthly_churn_events AS (
    SELECT
        churn_month,
        account_id,
        COUNT(*) AS churn_event_count,
        ROUND(SUM(refund_amount_usd), 2) AS refund_amount_usd
    FROM (
        SELECT
            CAST(DATE_TRUNC('MONTH', churn_date) AS DATE) AS churn_month,
            account_id,
            refund_amount_usd
        FROM {{ ref('stg__churn_events') }}
    )
    GROUP BY churn_month, account_id
)

SELECT
    *
FROM monthly_churn_events
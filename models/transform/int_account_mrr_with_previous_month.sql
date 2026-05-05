WITH date_bounds AS (
    SELECT
        MIN(month) AS min_month,
        MAX(month) AS max_month
    FROM {{ ref('fact_monthly_account_mrr') }}
),
months_sequence AS (
    SELECT
        CAST(gs.generate_series AS DATE) AS month
    FROM date_bounds,
    GENERATE_SERIES(min_month, max_month, INTERVAL '1 MONTH') AS gs
),
accounts AS (
    SELECT DISTINCT
        account_id
    FROM {{ ref('fact_monthly_account_mrr') }}
)

SELECT
    *
FROM accounts
WITH date_bounds AS (
    SELECT
        MIN(active_month) AS min_month,
        MAX(active_month) AS max_month
    FROM {{ ref('fact_monthly_account_mrr') }}
),
months_sequence AS (
	SELECT 
		CAST(series.generate_series AS DATE) AS active_month
	FROM date_bounds,
	GENERATE_SERIES(min_month, max_month, INTERVAL '1 MONTH') AS series
),
accounts AS (
    SELECT DISTINCT
        account_id
    FROM {{ ref('fact_monthly_account_mrr') }}
),
account_month_combinations AS (
    SELECT
        months.active_month,
        accounts.account_id
    FROM months_sequence AS months
    CROSS JOIN accounts
),
mrr_filled AS (
    SELECT
        comb.*,
        COALESCE(mrr.current_mrr, 0) AS current_mrr,
        COALESCE(mrr.active_subscription_count, 0) AS active_subscription_count,
    FROM account_month_combinations AS comb
    LEFT JOIN {{ ref('fact_monthly_account_mrr') }} AS mrr
        ON comb.active_month = mrr.active_month
            AND comb.account_id = mrr.account_id
),
with_previous_month AS (
    SELECT
        *,
        LAG(current_mrr) OVER (
            PARTITION BY account_id
            ORDER BY active_month
        ) AS previous_mrr,
        MAX(
            CASE
                WHEN current_mrr > 0 THEN 1
                ELSE 0
            END
        ) OVER (
            PARTITION BY account_id
            ORDER BY active_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS had_mrr_before
    FROM mrr_filled
),
final_output AS (
    SELECT
        active_month,
        account_id,
        current_mrr,
        previous_mrr,
        current_mrr - previous_mrr AS mrr_movement,
        active_subscription_count,
        COALESCE(had_mrr_before, 0) AS had_mrr_before
    FROM with_previous_month
)

SELECT
    *
FROM final_output
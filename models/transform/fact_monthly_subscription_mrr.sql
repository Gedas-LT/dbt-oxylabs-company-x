WITH date_bounds AS (
	SELECT
		CAST(DATE_TRUNC('MONTH', MIN(start_date)) AS DATE) AS start_month,
		CAST(DATE_TRUNC('MONTH', CURRENT_DATE()) AS DATE) AS max_month
    FROM {{ ref('stg__subscriptions') }}
),
months_sequence AS (
	SELECT 
		CAST(series.generate_series AS DATE) AS month_start,
		(CAST(series.generate_series AS DATE) + INTERVAL '1 MONTH' - INTERVAL '1 DAY') AS month_end
	FROM date_bounds,
	GENERATE_SERIES(start_month, max_month, INTERVAL '1 MONTH') AS series
),
active_months AS (
	SELECT
		months.month_start AS month,
		subs.subscription_id,
		subs.account_id,
		subs.mrr_amount,
		subs.upgrade_flag,
		subs.downgrade_flag
	FROM months_sequence AS months
	INNER JOIN {{ ref('stg__subscriptions') }} AS subs
		ON subs.start_date <= months.month_end
			AND (
				subs.end_date IS NULL
					OR subs.end_date > months.month_end
			)
	WHERE subs.is_trial = FALSE
)

SELECT
	*
FROM active_months
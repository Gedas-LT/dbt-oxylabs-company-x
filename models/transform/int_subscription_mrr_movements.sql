WITH date_bounds AS (
    SELECT
        MIN(active_month) AS min_month,
        MAX(active_month) AS max_month
    FROM {{ ref('fact_monthly_subscription_mrr') }}
),
months_sequence AS (
	SELECT 
		CAST(series.generate_series AS DATE) AS active_month
	FROM date_bounds,
	GENERATE_SERIES(min_month, max_month, INTERVAL '1 MONTH') AS series
),
subscriptions AS (
    SELECT DISTINCT
        subscription_id,
        account_id
    FROM {{ ref('stg__subscriptions') }}
),
subscription_month_combinations AS (
    SELECT
        months.active_month,
        subs.subscription_id,
        subs.account_id
    FROM months_sequence AS months
    CROSS JOIN subscriptions AS subs
),
mrr_filled AS (
    SELECT
        comb.*,
        COALESCE(mrr.mrr_amount, 0) AS current_subscription_mrr,
        COALESCE(mrr.upgrade_flag, FALSE) AS source_upgrade_flag,
        COALESCE(mrr.downgrade_flag, FALSE) AS source_downgrade_flag,
        COALESCE(mrr.churn_flag, FALSE) AS source_churn_flag,
        mrr.start_date,
        mrr.end_date
    FROM subscription_month_combinations AS comb
    LEFT JOIN {{ ref('fact_monthly_subscription_mrr') }} AS mrr
        ON comb.active_month = mrr.active_month
            AND comb.subscription_id = mrr.subscription_id
),
with_previous_month AS (
    SELECT
        *,
        LAG(current_subscription_mrr) OVER (
            PARTITION BY subscription_id
            ORDER BY active_month
        ) AS previous_subscription_mrr
    FROM mrr_filled
),
classified AS (
    SELECT
        active_month,
        account_id,
        subscription_id,
        previous_subscription_mrr,
        current_subscription_mrr,
        current_subscription_mrr - previous_subscription_mrr AS subscription_mrr_movement,
        source_upgrade_flag,
        source_downgrade_flag,
        source_churn_flag,
        start_date,
        end_date,
        CASE
            WHEN previous_subscription_mrr = 0 AND current_subscription_mrr > 0 THEN TRUE
            ELSE FALSE
        END AS is_first_active_month,
        CASE
            WHEN previous_subscription_mrr > 0 AND current_subscription_mrr = 0 THEN TRUE
            ELSE FALSE
        END AS is_subscription_churn_month,
        CASE
            WHEN current_subscription_mrr > previous_subscription_mrr THEN TRUE
            ELSE FALSE
        END AS is_positive_mrr_movement,
        CASE
            WHEN current_subscription_mrr < previous_subscription_mrr THEN TRUE
            ELSE FALSE
        END AS is_negative_mrr_movement,
        CASE
            WHEN previous_subscription_mrr = 0 AND current_subscription_mrr > 0 AND source_upgrade_flag = TRUE THEN 'upgrade'
            WHEN previous_subscription_mrr = 0 AND current_subscription_mrr > 0 THEN 'new_subscription'
            WHEN previous_subscription_mrr > 0 AND current_subscription_mrr = 0 THEN 'subscription_churn'
            WHEN current_subscription_mrr > previous_subscription_mrr THEN 'upgrade'
            WHEN current_subscription_mrr < previous_subscription_mrr THEN 'downgrade'
            WHEN current_subscription_mrr = previous_subscription_mrr AND current_subscription_mrr > 0 THEN 'retained'
            ELSE 'no_mrr'
        END AS subscription_movement_type
    FROM with_previous_month
)

SELECT
    *
FROM classified
WHERE subscription_movement_type != 'no_mrr'
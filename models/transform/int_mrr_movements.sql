WITH account_mrr AS (
    SELECT
        *
    FROM {{ ref('int_account_mrr_with_previous_month') }}
),
subscription_movement AS (
    SELECT
        *
    FROM {{ ref('int_subscription_mrr_movements') }}
),
churn_events AS (
    SELECT
        *
    FROM {{ ref('fact_monthly_churn_events') }}
),
account_lifecycle AS (
    SELECT
        *,
        CASE
            WHEN previous_mrr = 0 AND current_mrr > 0 AND had_mrr_before = 0 THEN 'new_account'
            WHEN previous_mrr = 0 AND current_mrr > 0 AND had_mrr_before = 1 THEN 'returned'
            WHEN previous_mrr > 0 AND current_mrr = 0 THEN 'account_churn'
            ELSE 'existing_account'
        END AS account_lifecycle_type
    FROM account_mrr
),
subscription_components AS (
    SELECT
        *
    FROM subscription_movement
    WHERE subscription_movement_type != 'retained'
),
classified_components AS (
    SELECT
        acc.active_month,
        acc.account_id,
        sub.subscription_id,
        acc.previous_mrr,
        acc.current_mrr,
        acc.net_mrr_movement AS account_mrr_movement,
        acc.active_subscription_count,
        acc.had_mrr_before,
        acc.account_lifecycle_type,
        CASE
            WHEN acc.account_lifecycle_type = 'new_account' AND sub.subscription_mrr_movement > 0 THEN 'new_account'
            WHEN acc.account_lifecycle_type = 'returned' AND sub.subscription_mrr_movement > 0 THEN 'returned'
            WHEN acc.account_lifecycle_type = 'account_churn' AND sub.subscription_mrr_movement < 0 THEN 'account_churn'
            ELSE sub.subscription_movement_type
        END AS movement_type,
        sub.subscription_mrr_movement,
        sub.source_upgrade_flag,
        sub.source_downgrade_flag,
        sub.source_churn_flag,
        sub.is_first_active_month,
        sub.is_subscription_churn_month,
        TRUE AS is_mrr_movement
    FROM account_lifecycle AS acc
    INNER JOIN subscription_components AS sub
        ON acc.active_month = sub.active_month
            AND acc.account_id = sub.account_id
),
retained_components AS (
    SELECT
        active_month,
        account_id,
        NULL AS subscription_id,
        previous_mrr,
        current_mrr,
        net_mrr_movement AS account_mrr_movement,
        active_subscription_count,
        had_mrr_before,
        account_lifecycle_type,
        'retained' AS movement_type,
        current_mrr AS movement_mrr,
        FALSE AS source_upgrade_flag,
        FALSE AS source_downgrade_flag,
        FALSE AS source_churn_flag,
        FALSE AS is_first_active_month,
        FALSE AS is_subscription_churn_month,
        FALSE AS is_mrr_movement
    FROM account_lifecycle
    WHERE current_mrr = previous_mrr
        AND current_mrr > 0
),
combined_movements AS (
    SELECT * FROM classified_components
        UNION ALL
    SELECT * FROM retained_components
),
with_churn_events AS (
    SELECT
        moves.*,
        CASE
            WHEN moves.movement_type IN ('account_churn', 'subscription_churn') THEN COALESCE(churn.churn_event_count, 0)
            ELSE 0
        END AS churn_event_count,
        CASE
            WHEN moves.movement_type IN ('account_churn', 'subscription_churn') THEN COALESCE(churn.refund_amount_usd, 0)
            ELSE 0
        END AS refund_amount_usd
    FROM combined_movements AS moves
    LEFT JOIN churn_events AS churn
        ON moves.active_month = churn.churn_month
            AND moves.account_id = churn.account_id
)

SELECT
    *
FROM with_churn_events
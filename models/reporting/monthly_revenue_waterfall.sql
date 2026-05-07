WITH movements AS (
    SELECT
        *
    FROM {{ ref('int_mrr_movements') }}
),
monthly_movements AS (
    SELECT
        active_month AS month_id,
        movement_type,
        COUNT(DISTINCT account_id) AS account_count,
        SUM(subscription_mrr_movement) AS mrr_movement,
        SUM(
            CASE
                WHEN is_mrr_movement THEN subscription_mrr_movement
                ELSE 0
            END
        ) AS mrr_change_amount,
        SUM(churn_event_count) AS churn_event_count,
        SUM(refund_amount_usd) AS refund_amount_usd
    FROM movements
    GROUP BY active_month, movement_type
),
monthly_totals AS (
    SELECT
        month_id,
        SUM(previous_mrr) AS starting_mrr,
        SUM(current_mrr) AS ending_mrr,
        SUM(account_mrr_movement) AS total_account_mrr_movement
    FROM (
        SELECT DISTINCT
            active_month AS month_id,
            account_id,
            previous_mrr,
            current_mrr,
            account_mrr_movement
        FROM movements
    )
    GROUP BY month_id
),
final_output AS (
    SELECT
        moves.month_id,
        moves.movement_type,
        moves.account_count,
        moves.mrr_movement,
        moves.mrr_change_amount,
        totals.starting_mrr,
        totals.ending_mrr,
        totals.total_account_mrr_movement,
        moves.churn_event_count,
        moves.refund_amount_usd
    FROM monthly_movements AS moves
    LEFT JOIN monthly_totals AS totals
        ON moves.month_id = totals.month_id
    ORDER BY
        moves.month_id,
        CASE moves.movement_type 
            WHEN 'new_account' THEN 1
            WHEN 'reactivation' THEN 2
            WHEN 'new_subscription' THEN 3
            WHEN 'upgrade' THEN 4
            WHEN 'downgrade' THEN 5
            WHEN 'subscription_churn' THEN 6
            WHEN 'account_churn' THEN 7
            WHEN 'retained' THEN 8
            ELSE 99
        END
)

SELECT
    *
FROM final_output
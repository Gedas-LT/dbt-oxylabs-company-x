SELECT
    *
FROM {{ ref('raw__churn_events') }}
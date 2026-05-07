## Project overview

This dbt project builds a monthly MRR revenue waterfall for Company X. The goal is to help the CFO and analysts to understand how recurring revenue changes from one month to the next.

The final reporting model explains monthly MRR movement accross categories such as:

- new account
- returned
- new subscription
- upgrade
- downgrade
- subscription churn
- account churn
- retained MRR

## Core business assumptions

A single account can have multiple concurrent subscriptions. Therefore, account MRR is calculated by summing MRR across all active subscriptions for the account in each month.

Annual billing frequency does not cause the MRR movement to repeat for 12 months. For MRR reporting, annual contracts are represented as monthly recurring revenue. A movement is recognized in the month where the MRR changes, and the resulting MRR is retained in the following active months.

The waterfall uses a month-end MRR snapshot approach. A subscription is considered active in a month if it is active at the end of that month. This means a subscription contributes MRR to a month only if it is active on the last day of that month.

The subscriptions source contains flags: upgrade_flag, downgrade_flag, churn_flag. These flags are treated as source attributes, not recurring monthly events. Because subscriptions are projected across active months, a flag stored on the subscription row may appear in multiple active months. The model therefore does not treat the flag as an event by itself.

## Revenue waterfall methodology

The project calculates MRR movements using a hybrid account-level and subscription-level approach.

The waterfall is reported at account/month level, but movement classification uses subscription-level chnages to explain what happened inside each account.

This is important because one account can have multiple subscriptions. For example, an account could have one subscription upgrade and another subscription churn in the same month. A pure account-level comparison could hide those offsetting movements.
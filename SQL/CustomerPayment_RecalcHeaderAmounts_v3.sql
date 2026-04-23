-- Recalculate CustomerPayment.PaymentApplied and CustomerPayment.UnappliedAmount
-- from committed unified CustomerPaymentDetail truth.
--
-- Use this after unified-detail rollout, or anytime header amounts drift.

;WITH HeaderSource AS
(
    SELECT
        cp.CustomerPaymentId,
        cp.PaymentAmount,
        ISNULL(cp.AsIncome, 0) AS AsIncome,
        SourceUseRefundSelf = ISNULL((
            SELECT SUM(ISNULL(pd.PaymentApplied, 0))
            FROM dbo.CustomerPaymentDetail pd
            WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
              AND pd.DetailRole = 'AsRefund'
              AND ISNULL(pd.SourceCustomerPaymentId, 0) = cp.CustomerPaymentId
        ), 0),
        SourceUseAsIncome = ISNULL((
            SELECT SUM(ISNULL(pd.PaymentApplied, 0))
            FROM dbo.CustomerPaymentDetail pd
            WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
              AND pd.DetailRole = 'AsIncome'
              AND ISNULL(pd.SourceCustomerPaymentId, 0) <> cp.CustomerPaymentId
        ), 0),
        OwnCashApplied = ISNULL((
            SELECT SUM(ISNULL(pd.PaymentApplied, 0))
            FROM dbo.CustomerPaymentDetail pd
            WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
              AND pd.DetailRole IN ('Invoice', 'DebitMemo', 'CCFee')
              AND ISNULL(pd.SourceCustomerPaymentId, 0) = 0
        ), 0),
        CreditMemoUsed = ISNULL((
            SELECT SUM(CASE WHEN pd.PaymentApplied < 0 THEN ISNULL(pd.PaymentApplied, 0) * -1 ELSE 0 END)
            FROM dbo.CustomerPaymentDetail pd
            WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
              AND pd.IsCreditMemo = 1
        ), 0),
        ConsumedByOthers = ISNULL((
            SELECT SUM(ISNULL(pd.PaymentApplied, 0))
            FROM dbo.CustomerPaymentDetail pd
            WHERE pd.SourceCustomerPaymentId = cp.CustomerPaymentId
              AND pd.CustomerPaymentId != cp.CustomerPaymentId
        ), 0)
    FROM dbo.CustomerPayment cp
)
UPDATE cp
SET
    PaymentApplied = hs.OwnCashApplied - hs.CreditMemoUsed,
    UnappliedAmount = hs.PaymentAmount - hs.OwnCashApplied + hs.CreditMemoUsed - (hs.AsIncome - hs.SourceUseAsIncome) - hs.SourceUseRefundSelf - hs.ConsumedByOthers
FROM dbo.CustomerPayment cp
INNER JOIN HeaderSource hs
    ON hs.CustomerPaymentId = cp.CustomerPaymentId;

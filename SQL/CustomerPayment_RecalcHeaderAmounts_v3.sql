-- Recalculate CustomerPayment.PaymentApplied and CustomerPayment.UnappliedAmount
-- from committed detail truth.
--
-- Use this after deploying v3 source-credit fixes, or anytime header amounts drift
-- from CustomerPaymentDetail / SourcePaymentNumber reality.

;WITH HeaderSource AS
(
    SELECT
        cp.CustomerPaymentId,
        cp.PaymentAmount,
        ISNULL(cp.AsIncome, 0) AS AsIncome,
        SourceUseAsIncome = ISNULL((
            SELECT SUM(ISNULL(su.Amount, 0))
            FROM dbo.CustomerPaymentSourceUse su
            WHERE su.CustomerPaymentId = cp.CustomerPaymentId
              AND su.UseType = 'AsIncome'
        ), 0),
        OwnCashApplied = ISNULL((
            SELECT SUM(ISNULL(pd.PaymentApplied, 0))
            FROM dbo.CustomerPaymentDetail pd
            WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
              AND pd.IsCreditMemo = 0
              AND pd.SourcePaymentNumber IS NULL
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
            WHERE pd.SourcePaymentNumber = cp.PaymentNumber
              AND pd.CustomerPaymentId != cp.CustomerPaymentId
        ), 0)
    FROM dbo.CustomerPayment cp
)
UPDATE cp
SET
    PaymentApplied = hs.OwnCashApplied - hs.CreditMemoUsed,
    UnappliedAmount = hs.PaymentAmount - hs.OwnCashApplied + hs.CreditMemoUsed - (hs.AsIncome - hs.SourceUseAsIncome) - hs.ConsumedByOthers
FROM dbo.CustomerPayment cp
INNER JOIN HeaderSource hs
    ON hs.CustomerPaymentId = cp.CustomerPaymentId;

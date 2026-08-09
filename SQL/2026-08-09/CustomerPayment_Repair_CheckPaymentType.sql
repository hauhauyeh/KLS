-- CustomerPayment_Repair_CheckPaymentType
-- Repairs legacy customer payments created from the Sales Manager shortcut.
-- CHECK is a payment method, not a customer payment type.
-- Scope: only not-yet-deposited payments (IsLocked = 0) with known payment methods.

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExpectedCount INT = 11;
DECLARE @ActualCount INT;

SELECT
    CustomerPaymentId,
    PaymentNumber,
    PaymentType,
    PaymentMethod,
    PaymentDate,
    ReferenceId,
    PaymentAmount,
    IsLocked
FROM dbo.CustomerPayment
WHERE PaymentType = 'CHECK'
  AND IsLocked = 0
ORDER BY PaymentDate, PaymentNumber;

IF EXISTS
(
    SELECT 1
    FROM dbo.CustomerPayment
    WHERE PaymentType = 'CHECK'
      AND IsLocked = 0
      AND
      (
          PaymentMethod IS NULL
          OR PaymentMethod NOT IN ('CHECK', 'CASH', 'E-CHECK', 'ACH', 'WIRE', 'ZELLE')
      )
)
BEGIN
    THROW 50001, 'Unexpected unlocked CHECK payment type rows found. Review PaymentMethod before repair.', 1;
END;

SELECT @ActualCount = COUNT(*)
FROM dbo.CustomerPayment
WHERE PaymentType = 'CHECK'
  AND IsLocked = 0
  AND PaymentMethod IN ('CHECK', 'CASH', 'E-CHECK', 'ACH', 'WIRE', 'ZELLE');

IF @ActualCount <> @ExpectedCount
BEGIN
    THROW 50002, 'Repair candidate count changed. Re-preview before running repair.', 1;
END;

BEGIN TRANSACTION;

UPDATE dbo.CustomerPayment
SET PaymentType = 'Actual Payment'
WHERE PaymentType = 'CHECK'
  AND IsLocked = 0
  AND PaymentMethod IN ('CHECK', 'CASH', 'E-CHECK', 'ACH', 'WIRE', 'ZELLE');

IF @@ROWCOUNT <> @ExpectedCount
BEGIN
    THROW 50003, 'Repair update row count mismatch.', 1;
END;

COMMIT TRANSACTION;

SELECT
    PaymentType,
    PaymentMethod,
    IsLocked,
    COUNT(*) AS PaymentRowCount,
    SUM(ISNULL(PaymentAmount, 0)) AS PaymentAmount
FROM dbo.CustomerPayment
WHERE PaymentType IN ('CHECK', 'Actual Payment')
GROUP BY PaymentType, PaymentMethod, IsLocked
ORDER BY PaymentType, PaymentMethod, IsLocked;

SELECT
    CustomerPaymentId,
    PaymentNumber,
    PaymentType,
    PaymentMethod,
    PaymentDate,
    ReferenceId,
    PaymentAmount,
    IsLocked
FROM dbo.CustomerPayment
WHERE PaymentType = 'CHECK'
  AND IsLocked = 0
ORDER BY PaymentDate, PaymentNumber;

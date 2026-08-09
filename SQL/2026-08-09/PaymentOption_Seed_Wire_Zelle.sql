-- PaymentOption_Seed_Wire_Zelle
-- Adds WIRE and ZELLE as customer payment methods.
-- These are payment methods, not customer payment types.

SET NOCOUNT ON;

SELECT PaymentOptionId, MethodName, DefaultAccountId
FROM dbo.PaymentOption
WHERE MethodName IN ('WIRE', 'ZELLE')
ORDER BY MethodName;

IF NOT EXISTS (SELECT 1 FROM dbo.PaymentOption WHERE MethodName = 'WIRE')
BEGIN
    INSERT INTO dbo.PaymentOption(MethodName, DefaultAccountId)
    VALUES ('WIRE', NULL);
END

IF NOT EXISTS (SELECT 1 FROM dbo.PaymentOption WHERE MethodName = 'ZELLE')
BEGIN
    INSERT INTO dbo.PaymentOption(MethodName, DefaultAccountId)
    VALUES ('ZELLE', NULL);
END

SELECT PaymentOptionId, MethodName, DefaultAccountId
FROM dbo.PaymentOption
WHERE MethodName IN ('WIRE', 'ZELLE')
ORDER BY MethodName;

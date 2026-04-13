SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- One-time legacy data normalization.
UPDATE dbo.CustomerPayment
SET PaymentType = 'Bad Debt'
WHERE PaymentType = 'Bad Debit';
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Fix: Add VendorPayment_UpdatePurchase call after clearing IsVoid
-- Bug 2: UnVoidCheck previously only set IsVoid=0 and deleted void journal
--         but did NOT recalculate Purchase.PaymentApplied

CREATE OR ALTER PROCEDURE [dbo].[VendorPayment_UnVoidCheck]

	@VendorPaymentId INT

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @PaymentNumber INT

	SELECT @PaymentNumber=PaymentNumber FROM VendorPayment WHERE VendorPaymentId=@VendorPaymentId

	UPDATE VendorPayment SET IsVoid=0,UpdatedAt=GETUTCDATE() WHERE VendorPaymentId=@VendorPaymentId

	DELETE FROM TransactionJournal WHERE SourceDocNumber=@PaymentNumber AND SourceDocType='Outgoing Check Void'

	-- FIX: Recalculate Purchase.PaymentApplied now that IsVoid=0
	-- UpdatePurchase sums VPD with IsVoid=0 filter + handles PayNow via cursor
	EXEC [VendorPayment_UpdatePurchase] @VendorPaymentId, 0
END
GO


CREATE   PROCEDURE [dbo].[Deposit_ExportDetail] -- EXEC dbo.Deposit_ExportDetail @Search=NULL, @StartDate=NULL, @EndDate=NULL, @ToAccountId=NULL, @Filterby=NULL, @SortField=NULL, @SortOrder=NULL, @Uncleared=0
    @Search nvarchar(100) = NULL,
    @StartDate date = NULL,
    @EndDate date = NULL,
    @ToAccountId int = NULL,
    @Filterby nvarchar(50) = NULL,
    @SortField nvarchar(50) = NULL,
    @SortOrder nvarchar(50) = NULL,
    @Uncleared bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SearchAmount decimal(18, 2) = TRY_CONVERT(decimal(18, 2), @Search);
    DECLARE @SearchNumber int = TRY_CONVERT(int, @Search);
    DECLARE @FilterPaymentId int = TRY_CONVERT(int, @Filterby);
    DECLARE @SafeSortField nvarchar(50) = CASE
        WHEN @SortField IN ('TFNumber', 'TFDate', 'ToAccount', 'TransferAmount', 'CashBackAccount', 'CCFeeAmount', 'IsLocked') THEN @SortField
        ELSE NULL
    END;
    DECLARE @SafeSortOrder nvarchar(4) = CASE
        WHEN LOWER(ISNULL(@SortOrder, '')) = 'asc' THEN 'asc'
        WHEN LOWER(ISNULL(@SortOrder, '')) = 'desc' THEN 'desc'
        ELSE 'desc'
    END;

    SELECT
        T.TFId,
        T.TFNumber,
        T.TFDate,
        ToAcct.AccountName AS ToAccount,
        T.TransferAmount,
        CashBackAcct.AccountName AS CashBackAccount,
        T.CashbackAmount AS CashBackAmount,
        T.CCFeeAmount,
        T.IsLocked,
        TFD.TFDetailId,
        TFD.CustomerPaymentId,
        CPD.PaymentDetailId,
        CP.PaymentNumber,
        CP.PaymentDate,
        CP.PaymentMethod,
        CP.ReferenceId AS PaymentReference,
        P.PayeeName AS Customer,
        CP.PaymentAmount,
        TFD.DepositAmount AS DepositDetailAmount,
        S.SalesNumber AS InvoiceNumber,
        S.SalesDate AS InvoiceDate,
        S.SalesTotal AS InvoiceTotal,
        CPD.PaymentApplied,
        CPD.DiscountApplied,
        CPD.PaymentDiscount,
        CPD.ShortDiscount,
        CPD.OtherDiscount,
        CPD.DetailRole,
        TFD.Notes AS DetailNotes
    FROM dbo.TransferFund AS T
    LEFT JOIN dbo.Account AS ToAcct ON ToAcct.AccountId = T.ToAccountId
    LEFT JOIN dbo.Account AS CashBackAcct ON CashBackAcct.AccountId = T.CashbackAccountId
    LEFT JOIN dbo.TransferFundDetail AS TFD ON TFD.TFId = T.TFId
    LEFT JOIN dbo.CustomerPayment AS CP ON CP.CustomerPaymentId = TFD.CustomerPaymentId
    LEFT JOIN dbo.CustomerPaymentDetail AS CPD ON CPD.CustomerPaymentId = CP.CustomerPaymentId
    LEFT JOIN dbo.Sales AS S ON S.SalesId = CPD.SalesId
    LEFT JOIN dbo.Payee AS P ON P.PayeeId = CP.PayeeId
    WHERE T.TFType = 'DEPOSIT'
      AND (@Search IS NULL OR (@SearchNumber IS NOT NULL AND T.TFNumber = @SearchNumber) OR (@SearchAmount IS NOT NULL AND T.TransferAmount = @SearchAmount))
      AND (@StartDate IS NULL OR T.TFDate >= @StartDate)
      AND (@EndDate IS NULL OR T.TFDate <= @EndDate)
      AND (@ToAccountId IS NULL OR T.ToAccountId = @ToAccountId)
      AND (@Filterby IS NULL OR (@FilterPaymentId IS NOT NULL AND EXISTS (
            SELECT 1
            FROM dbo.TransferFundDetail AS FilterTFD
            WHERE FilterTFD.TFId = T.TFId
              AND FilterTFD.CustomerPaymentId = @FilterPaymentId
      )))
      AND (@Uncleared = 0 OR T.IsLocked = 0)
    ORDER BY
        CASE WHEN @SafeSortField = 'TFNumber' AND @SafeSortOrder = 'asc' THEN T.TFNumber END ASC,
        CASE WHEN @SafeSortField = 'TFNumber' AND @SafeSortOrder = 'desc' THEN T.TFNumber END DESC,
        CASE WHEN @SafeSortField = 'TFDate' AND @SafeSortOrder = 'asc' THEN T.TFDate END ASC,
        CASE WHEN @SafeSortField = 'TFDate' AND @SafeSortOrder = 'desc' THEN T.TFDate END DESC,
        CASE WHEN @SafeSortField = 'ToAccount' AND @SafeSortOrder = 'asc' THEN ToAcct.AccountName END ASC,
        CASE WHEN @SafeSortField = 'ToAccount' AND @SafeSortOrder = 'desc' THEN ToAcct.AccountName END DESC,
        CASE WHEN @SafeSortField = 'TransferAmount' AND @SafeSortOrder = 'asc' THEN T.TransferAmount END ASC,
        CASE WHEN @SafeSortField = 'TransferAmount' AND @SafeSortOrder = 'desc' THEN T.TransferAmount END DESC,
        CASE WHEN @SafeSortField = 'CashBackAccount' AND @SafeSortOrder = 'asc' THEN CashBackAcct.AccountName END ASC,
        CASE WHEN @SafeSortField = 'CashBackAccount' AND @SafeSortOrder = 'desc' THEN CashBackAcct.AccountName END DESC,
        CASE WHEN @SafeSortField = 'CCFeeAmount' AND @SafeSortOrder = 'asc' THEN T.CCFeeAmount END ASC,
        CASE WHEN @SafeSortField = 'CCFeeAmount' AND @SafeSortOrder = 'desc' THEN T.CCFeeAmount END DESC,
        CASE WHEN @SafeSortField = 'IsLocked' AND @SafeSortOrder = 'asc' THEN CONVERT(int, T.IsLocked) END ASC,
        CASE WHEN @SafeSortField = 'IsLocked' AND @SafeSortOrder = 'desc' THEN CONVERT(int, T.IsLocked) END DESC,
        T.TFDate DESC,
        T.TFNumber DESC,
        CP.PaymentDate DESC,
        CP.PaymentNumber DESC,
        CPD.PaymentDetailId ASC;
END
CREATE PROCEDURE [dbo].[TempPurchase_GetList] --[TempPurchase_GetList] 100001,200002,0,null,null,null 
	
	@EmpId INT,
	@PayeeId INT,
	@PurchaseId INT,
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(10),
	@Id INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX)

	SET @Qry = '
    SELECT *
    FROM (
        SELECT t.*,
               i.ItemName,
               i.ItemCode,
               i.CaseWeight,
               p.LandedCostPerCase,
               p.BaseFinalQty
        FROM TempPurchase t
        INNER JOIN Item i ON t.ItemId = i.ItemId
        LEFT JOIN View_PurchaseHistory p 
               ON p.PurchaseId = t.PurchaseId 
              AND p.PurchaseDetailId = t.PurchaseDetailId

        UNION ALL

        SELECT t.*,
               a.AccountName,
               a.AccountCode,
               NULL,
               NULL,
               NULL
        FROM TempPurchase t
        INNER JOIN Account a ON t.AccountId = a.AccountId
    ) x
    WHERE x.EmpId = ' + CONVERT(VARCHAR,@EmpId) + '
      AND x.PurchaseId = ' + CONVERT(VARCHAR,@PurchaseId) + '
      AND x.PayeeId = ' + CONVERT(VARCHAR,@PayeeId) + ''

    IF @Id IS NOT NULL
        SET @Qry += ' AND x.TempPurchaseId='+CONVERT(VARCHAR,@Id)

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry += ' ORDER BY x.LineId'

	EXEC (@Qry)
END


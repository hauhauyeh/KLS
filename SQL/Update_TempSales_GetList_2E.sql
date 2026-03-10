-- Phase 2E: TempSales_GetList — Sort by DisplaySort
-- Changes:
--   1. Two-level sort: owner groups DESC by LineId, then MAIN before PROMO_REWARD within each group
--      This ensures newest items appear first and reward lines appear directly after their owner

ALTER PROCEDURE [dbo].[TempSales_GetList] --[TempSales_GetList] 100001,200002,0,null,null,null
	@EmpId INT,
	@PayeeId INT,
	@SalesId INT,
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
               i.PackSize
        FROM TempSales t
        INNER JOIN Item i ON t.ItemId = i.ItemId

        UNION ALL

        SELECT t.*,
               a.AccountName,
               a.AccountCode,
               NULL,
               NULL
        FROM TempSales t
        INNER JOIN Account a ON t.AccountId = a.AccountId
    ) x
    WHERE x.EmpId = ' + CONVERT(VARCHAR,@EmpId) + '
      AND x.SalesId = ' + CONVERT(VARCHAR,@SalesId) + '
      AND x.PayeeId = ' + CONVERT(VARCHAR,@PayeeId) + '
      AND ISNULL(x.ChangeStatus, '''') <> ''D'''

    IF @Id IS NOT NULL
        SET @Qry += ' AND x.TempSalesId='+CONVERT(VARCHAR,@Id)

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry += ' ORDER BY ISNULL(x.DisplaySort, x.LineId) DESC, CASE WHEN x.CartLineType = ''MAIN'' THEN 0 ELSE 1 END ASC, x.LineId ASC'

	EXEC (@Qry)
END

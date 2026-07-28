-- Live baseline captured 2026-07-28 before R3A old temp SQL cleanup draft.
-- Object: dbo.TempItemQuote_GetList
-- Live modify_date at capture: 2026-05-06 11:09:52.890
-- This procedure was only used by retired TempItemQuoteService list plumbing.

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[TempItemQuote_GetList]
	
	@EmpId INT,
	@PayeeId INT,
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(10),
	@TempId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX)

	SET @Qry = '
    SELECT t.*,
               i.ItemName,
               i.ItemCode,
			   iu.Unit,
			   iu.RecentCost,
			   iu.P1,
			   ISNULL(c.BaseMarkup,0) AS BaseMarkup,
			   c.IsBaseToRecentCost
    FROM TempItemQuote t
    INNER JOIN Item i ON t.ItemId = i.ItemId
	INNER JOIN ItemUnit iu ON t.ItemUnitId = iu.ItemUnitId
	LEFT JOIN Customer c ON c.PayeeId=t.PayeeId
    WHERE t.EmpId = ' + CONVERT(VARCHAR,@EmpId) + '
      AND t.PayeeId = ' + CONVERT(VARCHAR,@PayeeId) + ''

    IF @TempId IS NOT NULL
        SET @Qry += ' AND t.TempQuoteId='+CONVERT(VARCHAR,@TempId)

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry += ' ORDER BY i.ItemName,iu.ItemUnitId'

	EXEC (@Qry)
END


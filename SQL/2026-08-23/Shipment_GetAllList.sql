SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[Shipment_GetAllList] -- EXEC dbo.Shipment_GetAllList @Pageno = 1, @Pagesize = 50, @Search = NULL, @StartDate = NULL, @EndDate = NULL, @PayeeId = NULL, @Filterby = 'open', @SortField = NULL, @SortOrder = NULL, @IsCount = 0, @TotalCount = NULL
	@Pageno int,
	@Pagesize int,
	@Search nvarchar(50),
	@StartDate date,
	@EndDate date,
	@PayeeId int,
	@Filterby nvarchar(100),	
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,
	@TotalCount int OUTPUT,
    @MatchPurchaseId int = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
 
	DECLARE @Qry NVARCHAR(MAX);
    DECLARE @MatchContainerNormalized NVARCHAR(100);

    SELECT @MatchContainerNormalized =
        NULLIF(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(p.ContainerNumber))), ' ', ''), '-', ''), '')
    FROM dbo.Purchase p
    WHERE p.PurchaseId = @MatchPurchaseId;
 
	IF @IsCount=1
		SET @Qry='SELECT @RCount=COUNT(*)'
	ELSE
		SET @Qry='SELECT s.ShipmentId
      ,s.ShipmentType
      ,s.ContainerNo
      ,s.ContainerType
      ,s.PayeeId
	  ,s.DocumentNo
      ,s.Origin
      ,s.Destination
      ,s.ETA
      ,s.Status
      ,s.Notes
	  ,p.PayeeName
	  ,ISNULL(ch.TotalCharges, 0) AS TotalCharges
      ,s.AreChargesComplete
      ,s.ChargesCompletedAt
      ,s.ChargesCompletedBy
      ,CAST(CASE
          WHEN @MatchContainerNormalized IS NOT NULL
           AND NULLIF(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(s.ContainerNo))), '' '', ''''), ''-'', ''''), '''') = @MatchContainerNormalized
          THEN 1 ELSE 0
      END AS bit) AS IsContainerMatch
      ,CASE
          WHEN @MatchContainerNormalized IS NOT NULL
           AND NULLIF(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(s.ContainerNo))), '' '', ''''), ''-'', ''''), '''') = @MatchContainerNormalized
          THEN 0 ELSE 1
      END AS ContainerMatchRank'
 
	SET @Qry += ' FROM Shipment AS s INNER JOIN Payee AS p on p.PayeeId=s.PayeeId
	OUTER APPLY (
		SELECT SUM(ISNULL(sc.ChargeAmount, 0)) AS TotalCharges
		FROM ShipmentCharge sc
		WHERE sc.ShipmentId = s.ShipmentId
	) ch
	WHERE 1=1 '

	IF @Search is not null
	BEGIN
		SET @Qry += ' AND s.ShipmentId = '''+@Search+''' OR s.ContainerNo='''+@Search+''''
	END
 
	IF @Filterby = 'open'
		SET @Qry += ' AND (s.Status!=''Closed'')'

	IF @PayeeId IS NOT NULL
		SET @Qry += ' AND s.PayeeId='+CONVERT(varchar,@PayeeId)+''

	IF @StartDate is not null
		SET @Qry += ' AND s.ETA>='''+CONVERT(VARCHAR,@StartDate)+''''

	IF @EndDate is not null
		SET @Qry += ' AND s.ETA<='''+CONVERT(VARCHAR,@EndDate)+''''

	IF @IsCount=1
	BEGIN
		EXEC sp_executesql @Qry,N'@MatchContainerNormalized nvarchar(100), @RCount int OUTPUT', @MatchContainerNormalized = @MatchContainerNormalized, @RCount=@TotalCount OUTPUT
		RETURN
	END

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
    ELSE IF @MatchContainerNormalized IS NOT NULL
        SET @Qry += ' ORDER BY ContainerMatchRank ASC, s.CreatedAt DESC'
	ELSE
		SET @Qry += ' ORDER BY s.CreatedAt DESC'
 
	SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS 
	FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '
 
	EXEC sp_executesql @Qry, N'@MatchContainerNormalized nvarchar(100)', @MatchContainerNormalized = @MatchContainerNormalized
END

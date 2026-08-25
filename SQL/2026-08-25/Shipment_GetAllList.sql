SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
-- 2026-08-24 PROD-HOTFIX: parameterize search and guard numeric ShipmentId search.
-- 2026-08-25 SORT-HOTFIX: do not append ShipmentId tiebreaker when ShipmentId is already the primary sort.
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
    DECLARE @S NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@Search)), '');
    DECLARE @SearchNumber INT = TRY_CONVERT(INT, @S);
    DECLARE @MatchContainerNormalized NVARCHAR(100);
    DECLARE @Direction NVARCHAR(4) = CASE WHEN UPPER(ISNULL(@SortOrder, '')) = 'DESC' THEN 'DESC' ELSE 'ASC' END;
    DECLARE @OrderBy NVARCHAR(100);

    SET @OrderBy =
        CASE @SortField
            WHEN 'ShipmentId' THEN 's.ShipmentId'
            WHEN 'ShipmentType' THEN 's.ShipmentType'
            WHEN 'ContainerNo' THEN 's.ContainerNo'
            WHEN 'ContainerType' THEN 's.ContainerType'
            WHEN 'PayeeName' THEN 'p.PayeeName'
            WHEN 'Origin' THEN 's.Origin'
            WHEN 'Destination' THEN 's.Destination'
            WHEN 'ETA' THEN 's.ETA'
            WHEN 'Status' THEN 's.Status'
            WHEN 'TotalCharges' THEN 'ISNULL(ch.TotalCharges, 0)'
            WHEN 'AreChargesComplete' THEN 's.AreChargesComplete'
            ELSE NULL
        END;

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
	WHERE 1=1
      AND (@S IS NULL
           OR (@SearchNumber IS NOT NULL AND s.ShipmentId = @SearchNumber)
           OR s.ContainerNo LIKE ''%'' + @S + ''%'')
      AND (@Filterby IS NULL OR LOWER(@Filterby) <> ''open'' OR s.Status <> ''Closed'')
      AND (@PayeeId IS NULL OR s.PayeeId = @PayeeId)
      AND (@StartDate IS NULL OR s.ETA >= @StartDate)
      AND (@EndDate IS NULL OR s.ETA <= @EndDate) '

	IF @IsCount=1
	BEGIN
		EXEC sp_executesql @Qry,
            N'@S nvarchar(50), @SearchNumber int, @StartDate date, @EndDate date, @PayeeId int, @Filterby nvarchar(100), @MatchContainerNormalized nvarchar(100), @RCount int OUTPUT',
            @S = @S,
            @SearchNumber = @SearchNumber,
            @StartDate = @StartDate,
            @EndDate = @EndDate,
            @PayeeId = @PayeeId,
            @Filterby = @Filterby,
            @MatchContainerNormalized = @MatchContainerNormalized,
            @RCount=@TotalCount OUTPUT
		RETURN
	END

	IF @OrderBy IS NOT NULL
    BEGIN
		SET @Qry += ' ORDER BY ' + @OrderBy + ' ' + @Direction
        IF @OrderBy <> 's.ShipmentId'
            SET @Qry += ', s.ShipmentId ASC'
    END
    ELSE IF @MatchContainerNormalized IS NOT NULL
        SET @Qry += ' ORDER BY ContainerMatchRank ASC, s.CreatedAt DESC'
	ELSE
		SET @Qry += ' ORDER BY s.CreatedAt DESC'
 
	SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS 
	FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '
 
	EXEC sp_executesql @Qry,
        N'@S nvarchar(50), @SearchNumber int, @StartDate date, @EndDate date, @PayeeId int, @Filterby nvarchar(100), @MatchContainerNormalized nvarchar(100)',
        @S = @S,
        @SearchNumber = @SearchNumber,
        @StartDate = @StartDate,
        @EndDate = @EndDate,
        @PayeeId = @PayeeId,
        @Filterby = @Filterby,
        @MatchContainerNormalized = @MatchContainerNormalized
END

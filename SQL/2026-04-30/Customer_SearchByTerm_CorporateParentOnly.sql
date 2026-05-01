SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Customer_SearchByTerm] --[Customer_SearchByTerm] 'a',0,null,0,0
	
	@SearchTerm NVARCHAR(100),
	@IsActiveOnly BIT,
	@EmpId INT,
	@IsSearchSales BIT,
	@IsCorporateParentOnly BIT = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF @IsSearchSales = 1
    BEGIN
        SELECT *
        FROM dbo.Payee p
        WHERE p.PayeeType = 'C'
            AND (@IsCorporateParentOnly = 0 OR EXISTS (
                SELECT 1
                FROM dbo.Customer c
                WHERE c.PayeeId = p.PayeeId
                    AND c.BillId = p.PayeeId
                    AND EXISTS (
                        SELECT 1
                        FROM dbo.Customer c2
                        WHERE c2.BillId = c.BillId
                            AND c2.PayeeId <> c.PayeeId
                    )
            ));
        RETURN;
    END;

    ;WITH cte AS
    (
        SELECT
            p.PayeeId,
            p.PayeeType,
            p.PayeeName,
            p.IsClosed,
      
            PayeeNameLoc = CHARINDEX(@SearchTerm, p.PayeeName),
            PayeeIdLoc   = CHARINDEX(@SearchTerm, CONVERT(NVARCHAR(50), p.PayeeId)),
            AddressLoc   = CHARINDEX(@SearchTerm, p.[Address]),

            Phone1Loc = CHARINDEX(@SearchTerm, ISNULL(CONVERT(VARCHAR(20), p.Phone1), '')),
            Phone2Loc = CHARINDEX(@SearchTerm, ISNULL(CONVERT(VARCHAR(20), p.Phone2), '')),
            Phone3Loc = CHARINDEX(@SearchTerm, ISNULL(CONVERT(VARCHAR(20), p.Phone3), '')),
            Phone4Loc = CHARINDEX(@SearchTerm, ISNULL(CONVERT(VARCHAR(20), p.Phone4), ''))
        FROM dbo.Payee p INNER JOIN Customer c ON p.PayeeId = c.PayeeId
        WHERE
            p.PayeeType = 'C'
            AND (@EmpId = 0 OR c.SalesRepId = @EmpId)
            AND (@IsActiveOnly = 0 OR p.IsClosed = 0)
            AND (
                @IsCorporateParentOnly = 0
                OR (
                    c.BillId = p.PayeeId
                    AND EXISTS (
                        SELECT 1
                        FROM dbo.Customer c2
                        WHERE c2.BillId = c.BillId
                            AND c2.PayeeId <> c.PayeeId
                    )
                )
            )
    ),
    ranked AS
    (
        SELECT
            *,
            MatchRank =
                CASE
                    WHEN PayeeNameLoc > 0 THEN 1
                    WHEN PayeeIdLoc   > 0 THEN 2
                    WHEN AddressLoc   > 0 THEN 3
                    WHEN (Phone1Loc > 0 OR Phone2Loc > 0 OR Phone3Loc > 0 OR Phone4Loc > 0) THEN 4
                    ELSE 99
                END,
            MatchLoc =
                CASE
                    WHEN PayeeNameLoc > 0 THEN PayeeNameLoc
                    WHEN PayeeIdLoc   > 0 THEN PayeeIdLoc
                    WHEN AddressLoc   > 0 THEN AddressLoc
                    ELSE
                        -- best phone position among 4 phones (smaller position = better)
                        (
                            SELECT MIN(v)
                            FROM (VALUES
                                    (NULLIF(Phone1Loc, 0)),
                                    (NULLIF(Phone2Loc, 0)),
                                    (NULLIF(Phone3Loc, 0)),
                                    (NULLIF(Phone4Loc, 0))
                                 ) AS x(v)
                        )
                END
        FROM cte
    )
    SELECT TOP (50) *
    FROM ranked
    WHERE MatchRank < 99
    ORDER BY
        MatchRank,
        MatchLoc,
        PayeeName
    OPTION (RECOMPILE);

END
GO

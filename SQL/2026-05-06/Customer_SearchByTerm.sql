-- Customer_SearchByTerm rev 2026-05-06
-- Adds optional invoice-number lookup. Caller passes @IsIncludeInvoiceSearch=1
-- (e.g. customer-payment-add-edit's customer picker) to also resolve a
-- numeric SalesNumber back to its Bill customer. The new branch only fires
-- for purely-numeric terms of length >= 4 with an exact SalesNumber match,
-- and is short-circuited (and pruned by the optimiser under RECOMPILE) when
-- the flag is 0, so existing call sites keep their current performance.

-- One-time baseline rename (skipped if _prev already exists).
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Customer_SearchByTerm')
   AND NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Customer_SearchByTerm_prev')
    EXEC sp_rename 'Customer_SearchByTerm', 'Customer_SearchByTerm_prev';
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Customer_SearchByTerm')
    DROP PROCEDURE dbo.Customer_SearchByTerm;
GO

-- Previous test invocation:
-- [Customer_SearchByTerm] 'a',0,null,0,0
CREATE PROCEDURE [dbo].[Customer_SearchByTerm] --[Customer_SearchByTerm] 'a',0,null,0,0,0

    @SearchTerm NVARCHAR(100),
    @IsActiveOnly BIT,
    @EmpId INT,
    @IsSearchSales BIT,
    @IsCorporateParentOnly BIT = 0,
    -- @IsIncludeInvoiceSearch: when 1, also try to interpret the search
    -- term as an invoice number (Sales.SalesNumber) and return the
    -- customer who pays that invoice (the Bill customer). Default is 0
    -- so existing call sites (item picker, AR list, etc.) keep their
    -- current behaviour. Customer-payment-add-edit's customer picker
    -- passes 1 because cashiers often have an invoice number in hand
    -- and want to find which customer to apply payment to.
    @IsIncludeInvoiceSearch BIT = 0
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
    ),
    -- ------------------------------------------------------------------
    -- Plain-English overview of the invoice_match CTE
    --
    -- This branch lets the caller find a customer by typing one of that
    -- customer's invoice numbers instead of the customer's name.
    --
    -- It looks up the Sales row whose SalesNumber matches the search
    -- term, follows the Sales.BillId foreign key to the Payee/Customer
    -- pair, and returns that customer as if it were a normal search hit.
    -- The columns mirror what the "ranked" CTE produces, so both result
    -- sets can be UNION'd together at the end.
    --
    -- Why so many guards in the WHERE clause:
    --   1. @IsIncludeInvoiceSearch = 1
    --        Caller has explicitly asked for the feature. When the flag
    --        is 0 the entire CTE is empty, and SQL Server (because we
    --        run with OPTION (RECOMPILE)) prunes the Sales join from
    --        the plan -- callers that never set the flag pay no cost.
    --   2. LEN(@SearchTerm) >= 4
    --        Real invoices in this system have at least 4 digits.
    --        Skipping shorter terms avoids running the Sales join for
    --        ambiguous fragments like "12" while the user is still
    --        typing.
    --   3. @SearchTerm NOT LIKE '%[^0-9]%'
    --        The term must be purely digits. SalesNumber is INT, so
    --        searching anything that contains a letter would never
    --        match -- skipping non-numeric input keeps this fast.
    --   4. s.SalesNumber = TRY_CONVERT(INT, @SearchTerm)
    --        Exact equality, not LIKE. This is intentional: we don't
    --        want typing "1234" to surface every invoice that contains
    --        "1234" anywhere in its number. TRY_CONVERT is a safety net
    --        in case guard 3 ever lets through something non-numeric.
    --   5. p.PayeeType = 'C', @IsActiveOnly, @EmpId
    --        Mirror the same filters the main "ranked" CTE applies, so
    --        an inactive customer or a customer outside the sales rep's
    --        scope is still hidden when the caller has asked for those
    --        restrictions.
    --
    -- All the *Loc columns are filled with 0 because there is no
    -- "position of the search term inside the customer name" for an
    -- invoice match -- the match isn't textual. MatchRank = 5 places
    -- invoice hits AFTER the name/id/address/phone hits in the final
    -- ORDER BY, so a customer found by both name and invoice still
    -- shows up under the more meaningful ranking.
    -- ------------------------------------------------------------------
    invoice_match AS
    (
        SELECT
            p.PayeeId,
            p.PayeeType,
            p.PayeeName,
            p.IsClosed,
            0 AS PayeeNameLoc, 0 AS PayeeIdLoc, 0 AS AddressLoc,
            0 AS Phone1Loc, 0 AS Phone2Loc, 0 AS Phone3Loc, 0 AS Phone4Loc,
            5 AS MatchRank, 1 AS MatchLoc
        FROM dbo.Sales s
        INNER JOIN dbo.Payee p ON p.PayeeId = s.BillId
        INNER JOIN dbo.Customer c ON c.PayeeId = p.PayeeId
        WHERE @IsIncludeInvoiceSearch = 1
            AND LEN(@SearchTerm) >= 4
            AND @SearchTerm NOT LIKE '%[^0-9]%'
            AND s.SalesNumber = TRY_CONVERT(INT, @SearchTerm)
            AND p.PayeeType = 'C'
            AND (@IsActiveOnly = 0 OR p.IsClosed = 0)
            AND (@EmpId = 0 OR c.SalesRepId = @EmpId)
    )
    -- ------------------------------------------------------------------
    -- Final result: combine the "ranked" hits and the "invoice_match"
    -- hits, drop duplicates, take the top 50.
    --
    -- Why this is wrapped in two layers of subquery instead of just
    -- "SELECT TOP (50) ... FROM ranked":
    --
    --   * UNION ALL of "ranked" + "invoice_match"
    --       Brings the two sources together. We use UNION ALL (not
    --       UNION) on purpose -- it is faster, and we handle dedupe
    --       ourselves below. With plain UNION, two rows for the same
    --       customer that differ only in MatchRank/Loc fields would
    --       NOT be considered duplicates, so it wouldn't help anyway.
    --
    --   * ROW_NUMBER() OVER (PARTITION BY PayeeId ORDER BY MatchRank, MatchLoc)
    --       For each PayeeId we rank the rows by best (lowest)
    --       MatchRank and MatchLoc and keep only rn = 1. This means if
    --       a customer is matched both by name (rank 1) AND by invoice
    --       (rank 5), the user sees ONE row -- the better-ranked name
    --       hit -- not two.
    --
    --   * TOP (50) ... ORDER BY MatchRank, MatchLoc, PayeeName
    --       Same final ordering as before: best ranks first, then
    --       earliest match position within the field, then alphabetical
    --       on PayeeName as a tiebreaker. We cap at 50 results so the
    --       autocomplete dropdown stays usable.
    --
    -- Previous final SELECT (kept for reference):
    --
    --     SELECT TOP (50) *
    --     FROM ranked
    --     WHERE MatchRank < 99
    --     ORDER BY MatchRank, MatchLoc, PayeeName
    --     OPTION (RECOMPILE);
    --
    -- It was replaced to fold in invoice_match and dedupe by PayeeId.
    -- ------------------------------------------------------------------
    SELECT TOP (50)
        PayeeId, PayeeType, PayeeName, IsClosed,
        PayeeNameLoc, PayeeIdLoc, AddressLoc,
        Phone1Loc, Phone2Loc, Phone3Loc, Phone4Loc,
        MatchRank, MatchLoc
    FROM (
        SELECT *,
            rn = ROW_NUMBER() OVER (PARTITION BY PayeeId ORDER BY MatchRank, MatchLoc)
        FROM (
            SELECT * FROM ranked WHERE MatchRank < 99
            UNION ALL
            SELECT * FROM invoice_match
        ) combined
    ) deduped
    WHERE rn = 1
    ORDER BY
        MatchRank,
        MatchLoc,
        PayeeName
    OPTION (RECOMPILE);

END
GO

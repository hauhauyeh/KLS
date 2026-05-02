SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CustomerPayment_GetEditEligibility]
    @CustomerPaymentId INT
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Plain-English purpose

        This procedure answers one question:

        "Can this customer payment still be edited safely?"

        Current rule:

        - editable only when no downstream payment still depends on this payment
        - "depends on" means another payment uses this payment as a source through
          CustomerPaymentDetail.SourceCustomerPaymentId

        This procedure is read-only.
        It does not reset anything or change any data.

        Why this exists:

        - the UI needs a precheck so it can open the payment in editable mode
          or read-only mode
        - the save path needs the same rule so a direct save cannot bypass the guard
        - long term, this procedure is meant to become the one shared rule owner

        What "downstream" means here:

        - start from the payment being checked
        - follow SourceCustomerPaymentId links to any child payment that used it
        - then keep following the same pattern for children of children
        - any payment reached that way is downstream in the dependency chain

        What "future" means here:

        - a downstream payment whose PaymentDate is later than the payment being checked

        Final decision rule:

        - if any downstream future payment exists in that chain, block edit
        - if traversal becomes unsafe because of a cycle or depth limit, block edit
        - otherwise allow edit
    */

    DECLARE @PaymentDate DATE;
    DECLARE @PaymentNumber INT;
    DECLARE @PaymentExists BIT = 0;
    DECLARE @BlockedReason NVARCHAR(255) = N'There are future payments that must be unused before you can edit this payment.';
    DECLARE @NotFoundReason NVARCHAR(255) = N'Payment not found.';
    DECLARE @IssuedRefundReason NVARCHAR(255) = N'This payment has an issued refund and is final in normal UI.';

    -- First confirm whether the payment exists and capture its payment date and number.
    -- Both are needed later because the current rule treats "future" as:
    --
    -- - later PaymentDate
    -- - or same PaymentDate but higher PaymentNumber
    SELECT
        @PaymentExists = 1,
        @PaymentDate = cp.PaymentDate,
        @PaymentNumber = cp.PaymentNumber
    FROM dbo.CustomerPayment cp
    WHERE cp.CustomerPaymentId = @CustomerPaymentId;

    -- If the payment row is missing entirely, return a safe blocked result.
    -- The caller should treat this like a read-only/not-found case.
    IF @PaymentExists = 0
    BEGIN
        SELECT
            CAST(0 AS BIT) AS CanEdit,
            CAST(1 AS BIT) AS IsReadOnly,
            @NotFoundReason AS Reason;
        RETURN;
    END;

    -- If this payment already has an issued refund execution linked to its
    -- self AsRefund row, treat it as final in the shared edit-eligibility rule.
    -- This keeps the database rule aligned with the current dialog read-only
    -- behavior and prevents direct save/edit paths from bypassing refund finality.
    IF EXISTS
    (
        SELECT 1
        FROM dbo.CustomerPaymentDetail pd
        WHERE pd.CustomerPaymentId = @CustomerPaymentId
          AND pd.DetailRole = 'AsRefund'
          AND pd.SourceCustomerPaymentId = @CustomerPaymentId
          AND (pd.RefundPaymentId IS NOT NULL OR pd.RefundedAt IS NOT NULL)
    )
    BEGIN
        SELECT
            CAST(0 AS BIT) AS CanEdit,
            CAST(1 AS BIT) AS IsReadOnly,
            @IssuedRefundReason AS Reason;
        RETURN;
    END;

    -- If the payment exists but has no date, block edit safely.
    -- The current rule depends on comparing downstream dates, so a missing date
    -- makes the decision ambiguous. First rollout chooses the safe result.
    IF @PaymentDate IS NULL
    BEGIN
        SELECT
            CAST(0 AS BIT) AS CanEdit,
            CAST(1 AS BIT) AS IsReadOnly,
            @BlockedReason AS Reason;
        RETURN;
    END;

    /*
        #DependencyChain

        This temp table stores every downstream payment we can reach from the
        starting payment by following:

        source payment -> child payment

        using CustomerPaymentDetail.SourceCustomerPaymentId.

        Example:

        - Payment A is the payment being checked
        - Payment B used A as a source payment
        - Payment C used B as a source payment

        Then this temp table will contain:

        - B
        - C

        Path is stored for two reasons:

        - detect cycles safely
        - make the traversal logic easier to reason about
    */
    CREATE TABLE #DependencyChain
    (
        CustomerPaymentId INT PRIMARY KEY,
        Depth INT NOT NULL,
        Path NVARCHAR(MAX) NOT NULL
    );

    -- UsageEdges is the basic dependency graph.
    -- Each row means:
    --
    -- "ParentCustomerPaymentId was used as source credit by ChildCustomerPaymentId."
    --
    -- Self-links are excluded because they are not downstream dependency for edit guard.
    ;WITH UsageEdges AS
    (
        SELECT DISTINCT
            ParentCustomerPaymentId = pd.SourceCustomerPaymentId,
            ChildCustomerPaymentId = pd.CustomerPaymentId
        FROM dbo.CustomerPaymentDetail pd
        WHERE pd.SourceCustomerPaymentId IS NOT NULL
          AND pd.CustomerPaymentId <> pd.SourceCustomerPaymentId
    ),
    DependencyChain AS
    (
        -- Seed step:
        -- find direct children that used the starting payment as source credit.
        SELECT
            e.ChildCustomerPaymentId AS CustomerPaymentId,
            1 AS Depth,
            CAST(',' + CAST(@CustomerPaymentId AS NVARCHAR(20)) + ',' + CAST(e.ChildCustomerPaymentId AS NVARCHAR(20)) + ',' AS NVARCHAR(MAX)) AS Path
        FROM UsageEdges e
        WHERE e.ParentCustomerPaymentId = @CustomerPaymentId

        UNION ALL

        -- Recursive step:
        -- from each child already found, keep walking to later children that depend on it.
        --
        -- The CHARINDEX check prevents revisiting a payment already in the path,
        -- which is the first level of cycle protection.
        SELECT
            e.ChildCustomerPaymentId,
            dc.Depth + 1,
            CAST(dc.Path + CAST(e.ChildCustomerPaymentId AS NVARCHAR(20)) + ',' AS NVARCHAR(MAX))
        FROM DependencyChain dc
        INNER JOIN UsageEdges e
            ON e.ParentCustomerPaymentId = dc.CustomerPaymentId
        WHERE dc.Depth < 50
          AND CHARINDEX(',' + CAST(e.ChildCustomerPaymentId AS NVARCHAR(20)) + ',', dc.Path) = 0
    )
    INSERT INTO #DependencyChain(CustomerPaymentId, Depth, Path)
    SELECT
        CustomerPaymentId,
        MIN(Depth) AS Depth,
        MIN(Path) AS Path
    FROM DependencyChain
    GROUP BY CustomerPaymentId
    OPTION (MAXRECURSION 50);

    -- These flags are the final safety summary:
    --
    -- @HasDependencyCycle:
    --     a loop was detected in the dependency graph
    -- @HitDependencyDepthLimit:
    --     traversal reached the chosen safety depth limit
    -- @HasFutureDependentUsage:
    --     at least one downstream payment in the chain is later than the payment being checked
    DECLARE @HasDependencyCycle BIT = 0;
    DECLARE @HitDependencyDepthLimit BIT = 0;
    DECLARE @HasFutureDependentUsage BIT = 0;

    -- After the recursive insert, check for two unsafe conditions:
    --
    -- 1. cycle:
    --    a child points back to a payment already in the current path
    -- 2. depth limit:
    --    the chain is so deep that we reached the maximum allowed traversal depth
    --
    -- In either case, we block edit for safety instead of trying to guess.
    ;WITH UsageEdges AS
    (
        SELECT DISTINCT
            ParentCustomerPaymentId = pd.SourceCustomerPaymentId,
            ChildCustomerPaymentId = pd.CustomerPaymentId
        FROM dbo.CustomerPaymentDetail pd
        WHERE pd.SourceCustomerPaymentId IS NOT NULL
          AND pd.CustomerPaymentId <> pd.SourceCustomerPaymentId
    )
    SELECT
        @HasDependencyCycle =
            CASE WHEN EXISTS
            (
                SELECT 1
                FROM #DependencyChain dc
                INNER JOIN UsageEdges e
                    ON e.ParentCustomerPaymentId = dc.CustomerPaymentId
                WHERE CHARINDEX(',' + CAST(e.ChildCustomerPaymentId AS NVARCHAR(20)) + ',', dc.Path) > 0
            )
            THEN 1 ELSE 0 END,
        @HitDependencyDepthLimit =
            CASE WHEN EXISTS
            (
                SELECT 1
                FROM #DependencyChain
                WHERE Depth >= 50
            )
            THEN 1 ELSE 0 END;

    IF @HasDependencyCycle = 1 OR @HitDependencyDepthLimit = 1
    BEGIN
        SELECT
            CAST(0 AS BIT) AS CanEdit,
            CAST(1 AS BIT) AS IsReadOnly,
            @BlockedReason AS Reason;
        RETURN;
    END;

    /*
        If there are no downstream rows in #DependencyChain, then nothing depends
        on this payment as a source payment.

        That means the payment is editable under the current rule.
    */
    IF NOT EXISTS (SELECT 1 FROM #DependencyChain)
    BEGIN
        SELECT
            CAST(1 AS BIT) AS CanEdit,
            CAST(0 AS BIT) AS IsReadOnly,
            CAST(NULL AS NVARCHAR(255)) AS Reason;
        RETURN;
    END;

    /*
        Now apply the actual business rule.

        We do not block just because another later payment exists somewhere.
        We only block if:

        - the other payment is already in this dependency chain
        - and it is considered future compared with the payment being checked

        Current future rule:

        - later PaymentDate
        - or same PaymentDate and higher PaymentNumber

        So:

        - unrelated later payments do not matter
        - dependent downstream future payments do matter
    */
    SELECT
        @HasFutureDependentUsage =
            CASE WHEN EXISTS
            (
                SELECT 1
                FROM #DependencyChain dc
                INNER JOIN dbo.CustomerPayment cp
                    ON cp.CustomerPaymentId = dc.CustomerPaymentId
                WHERE cp.PaymentDate IS NOT NULL
                  AND (
                        cp.PaymentDate > @PaymentDate
                     OR (cp.PaymentDate = @PaymentDate AND cp.PaymentNumber > @PaymentNumber)
                  )
            )
            THEN 1 ELSE 0 END;

    IF @HasFutureDependentUsage = 1
    BEGIN
        SELECT
            CAST(0 AS BIT) AS CanEdit,
            CAST(1 AS BIT) AS IsReadOnly,
            @BlockedReason AS Reason;
        RETURN;
    END;

    -- If we got this far:
    --
    -- - the payment exists
    -- - traversal did not become unsafe
    -- - no future downstream dependency was found
    --
    -- So the payment is editable.
    SELECT
        CAST(1 AS BIT) AS CanEdit,
        CAST(0 AS BIT) AS IsReadOnly,
        CAST(NULL AS NVARCHAR(255)) AS Reason;
END
GO

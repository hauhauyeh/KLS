-- =====================================================================
-- PalmdaleOil_Bills_Insert.sql  (2026-08-15)
-- Inserts 60 vendor bills for Palmdale Oil Company, Inc. (PayeeId 200917)
-- from PALMDALE.xlsx into Bill Manager (Purchase / PurchaseDetail).
--
-- HOW IT WORKS
--   Each bill is posted through the same engine the UI uses:
--   stage one account line (LineType='A', @EGASP AccountId 276) in
--   TempPurchase, then EXEC dbo.Purchase_Insert. The SP creates the
--   Purchase header, PurchaseDetail, TransactionJournal (@AP + @EGASP),
--   queues Recalc_AfterInsert, and runs Purchase_CalcTotalAndPercent.
--   No hand-written journal rows.
--
--   Field pattern matches existing Palmdale bills (e.g. SI-241530):
--   single 'A' line, all qtys = 1, BillPrice = FinalPrice = amount,
--   FactorToBase = 1, StageId = 6, PurchaseDate = ArrivalDate =
--   InvoiceDate, DueDate = InvoiceDate + 30 (Term 24 NET30).
--
--   EmpId 100110 (Rajni) is used only for the TempPurchase cart scope.
--   Verified 2026-08-15: no TempPurchase rows exist for PayeeId 200917,
--   so no live cart can be touched.
--
--   Each Purchase_Insert commits its own transaction. If a bill fails,
--   the script stops there; already-posted bills remain valid (same as
--   entering them one at a time in the UI). Re-running is safe: the SP
--   rejects duplicate VendorDocNumber per payee, and the preflight
--   below skips bills already posted.
--
-- EXPECTED RESULT: 60 bills, total 66,032.94
--
-- Deploy: sqlcmd -S "RAJNI\SQLEXPRESS" -d "KLS-2026" ... -C -b -i PalmdaleOil_Bills_Insert.sql
-- =====================================================================
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @PayeeId INT = 200917;   -- Palmdale Oil Company, Inc.
DECLARE @AccountId INT = 276;    -- @EGASP GAS & OIL EXPENSE - PALMDALE
DECLARE @EmpId INT = 100110;     -- Rajni (cart scope only)
DECLARE @StageId INT = 6;

DECLARE @Bills TABLE (
    Seq INT PRIMARY KEY,
    BillNo NVARCHAR(100) NOT NULL,
    InvDate DATE NOT NULL,
    Amount DECIMAL(18,2) NOT NULL
);

INSERT INTO @Bills (Seq, BillNo, InvDate, Amount) VALUES
(1,'SI-245804','2026-05-14',2195.12),
(2,'SI-246732','2026-05-15',1486.47),
(3,'SI-246912','2026-05-16',366.76),
(4,'SI-247045','2026-05-17',233.62),
(5,'SI-247391','2026-05-18',1360.73),
(6,'SI-247706','2026-05-19',477.50),
(7,'SI-247815','2026-05-21',2379.38),
(8,'SI-248286','2026-05-22',931.32),
(9,'SI-248786','2026-05-24',187.85),
(10,'SI-249139','2026-05-26',308.69),
(11,'SI-249346','2026-05-23',698.48),
(12,'SI-251903','2026-05-27',2371.10),
(13,'SI-253007','2026-05-29',1695.73),
(14,'SI-253366','2026-05-30',415.12),
(15,'SI-256397','2026-06-02',1755.71),
(16,'SI-256425','2026-06-02',769.63),
(17,'SI-257528','2026-06-04',1384.30),
(18,'SI-257741','2026-06-05',991.26),
(19,'SI-259109','2026-06-06',421.33),
(20,'SI-259227','2026-06-08',314.94),
(21,'SI-260137','2026-06-09',2205.48),
(22,'SI-261534','2026-06-12',472.00),
(23,'SI-261800','2026-06-13',466.86),
(24,'SI-262447','2026-06-11',1457.57),
(25,'SI-262786','2026-06-15',1675.36),
(26,'SI-265088','2026-06-18',1735.62),
(27,'SI-267421','2026-06-22',483.39),
(28,'SI-268201','2026-06-23',940.88),
(29,'SI-269852','2026-06-19',748.28),
(30,'SI-269897','2026-06-20',794.71),
(31,'SI-271048','2026-06-29',320.94),
(32,'SI-272793','2026-06-28',1405.07),
(33,'SI-273641','2026-06-29',1091.34),
(34,'SI-273820','2026-06-30',967.88),
(35,'SI-274705','2026-07-05',431.83),
(36,'SI-274832','2026-07-02',1569.70),
(37,'SI-276846','2026-07-03',618.35),
(38,'SI-277011','2026-07-06',1034.74),
(39,'SI-277749','2026-07-07',511.08),
(40,'SI-278671','2026-07-09',1454.18),
(41,'SI-278909','2026-07-10',1843.21),
(42,'SI-282252','2026-07-13',1366.97),
(43,'SI-282933','2026-07-14',1038.97),
(44,'SI-283646','2026-07-16',1563.06),
(45,'SI-284302','2026-07-18',1216.79),
(46,'SI-284359','2026-07-17',473.04),
(47,'SI-286283','2026-07-21',1717.65),
(48,'SI-288175','2026-07-23',1695.36),
(49,'SI-288811','2026-07-25',1766.18),
(50,'SI-290524','2026-07-28',2294.83),
(51,'SI-291861','2026-07-29',931.49),
(52,'SI-292143','2026-07-30',657.34),
(53,'SI-292230','2026-07-31',946.72),
(54,'SI-294129','2026-08-01',862.05),
(55,'SI-294328','2026-08-03',308.06),
(56,'SI-294541','2026-08-03',1603.52),
(57,'SI-296044','2026-08-04',1037.56),
(58,'SI-298060','2026-08-07',2466.48),
(59,'SI-298087','2026-08-08',358.05),
(60,'SI-299253','2026-08-09',755.31);

-- ---------------------------------------------------------------------
-- Preflight: environment must match what this script was authored for.
-- ---------------------------------------------------------------------
IF (SELECT COUNT(*) FROM @Bills) <> 60 OR (SELECT SUM(Amount) FROM @Bills) <> 66032.94
BEGIN
    RAISERROR('Preflight: bill list corrupted (count/total mismatch).', 16, 1);
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM Payee WHERE PayeeId = @PayeeId AND PayeeName LIKE 'Palmdale Oil%')
BEGIN
    RAISERROR('Preflight: PayeeId 200917 is not Palmdale Oil on this server.', 16, 1);
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM Account WHERE AccountId = @AccountId AND AccountCode = '@EGASP')
BEGIN
    RAISERROR('Preflight: AccountId 276 is not @EGASP on this server.', 16, 1);
    RETURN;
END

IF EXISTS (SELECT 1 FROM TempPurchase WHERE PayeeId = @PayeeId)
BEGIN
    RAISERROR('Preflight: a live TempPurchase cart exists for Palmdale. Finish or clear it first.', 16, 1);
    RETURN;
END

-- Already-posted bills are skipped (makes the script safely re-runnable).
DECLARE @Skipped INT;
SELECT @Skipped = COUNT(*)
FROM @Bills b
WHERE EXISTS (SELECT 1 FROM Purchase p WHERE p.PayeeId = @PayeeId AND p.VendorDocNumber = b.BillNo);

IF @Skipped > 0
    PRINT CONCAT('Preflight: ', @Skipped, ' bill(s) already posted - will be skipped.');

-- ---------------------------------------------------------------------
-- Post each bill through Purchase_Insert.
-- ---------------------------------------------------------------------
DECLARE @Seq INT = 0;
DECLARE @BillNo NVARCHAR(100), @InvDate DATE, @Amount DECIMAL(18,2);
DECLARE @DueDate DATE, @NewPurchaseId INT;
DECLARE @Posted INT = 0;

WHILE 1 = 1
BEGIN
    -- reset scalar vars each iteration (stale-var guard)
    SELECT @BillNo = NULL, @InvDate = NULL, @Amount = NULL,
           @DueDate = NULL, @NewPurchaseId = NULL;

    SELECT TOP 1 @Seq = Seq, @BillNo = BillNo, @InvDate = InvDate, @Amount = Amount
    FROM @Bills WHERE Seq > @Seq ORDER BY Seq;

    IF @BillNo IS NULL BREAK;

    IF EXISTS (SELECT 1 FROM Purchase WHERE PayeeId = @PayeeId AND VendorDocNumber = @BillNo)
    BEGIN
        PRINT CONCAT('SKIP  ', @BillNo, ' (already posted)');
        CONTINUE;
    END

    SET @DueDate = DATEADD(DAY, 30, @InvDate);  -- Term 24 NET30

    BEGIN TRY
        -- stage the single expense line exactly like the Bill Manager cart
        INSERT INTO TempPurchase
            (EmpId, PayeeId, PurchaseId, LineId, LineType, ItemId, AccountId,
             ItemUnitId, Unit, Notes, IsFree, IsOut, IsCRCG,
             OrdQty0, ShipQty, BillQty, OrdQty1, ReceiveQty, FinalQty,
             BillPrice, BillExtTotal, FinalPrice, FinalExtTotal, FactorToBase)
        VALUES
            (@EmpId, @PayeeId, 0, 1, 'A', NULL, @AccountId,
             NULL, NULL, NULL, 0, 0, 0,
             1, 1, 1, 1, 1, 1,
             @Amount, 0, @Amount, 0, 1);

        EXEC dbo.Purchase_Insert
            @PurchaseId = 0,
            @PayeeId = @PayeeId,
            @VendorDocNumber = @BillNo,
            @ContainerNumber = NULL,
            @PurchaseDate = @InvDate,
            @ArrivalDate = @InvDate,
            @InvoiceDate = @InvDate,
            @DueDate = @DueDate,
            @Notes = NULL,
            @StageId = @StageId,
            @PalletCount = NULL,
            @EmpId = @EmpId,
            @NewPurchaseId = @NewPurchaseId OUTPUT,
            @FactorPO = NULL;

        IF @NewPurchaseId IS NULL
        BEGIN
            RAISERROR('Purchase_Insert returned no PurchaseId.', 16, 1);
        END

        SET @Posted = @Posted + 1;
        PRINT CONCAT('OK    ', @BillNo, '  ', CONVERT(NVARCHAR(10), @InvDate, 120),
                     '  ', @Amount, '  -> PurchaseId ', @NewPurchaseId);
    END TRY
    BEGIN CATCH
        -- leave no orphan cart row, report, and stop
        DELETE FROM TempPurchase WHERE EmpId = @EmpId AND PayeeId = @PayeeId;
        PRINT CONCAT('FAIL  ', @BillNo, ': ', ERROR_MESSAGE());
        PRINT CONCAT('Stopped. ', @Posted, ' bill(s) posted before failure; they remain valid.');
        THROW;
    END CATCH
END

PRINT CONCAT('Done. Posted ', @Posted, ' bill(s).');

-- ---------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS BillCount,
       SUM(PurchaseTotal) AS Total,      -- expect 60 / 66032.94 on first run
       SUM(AmountDue) AS AmountDue
FROM Purchase
WHERE PayeeId = @PayeeId
  AND VendorDocNumber IN (SELECT BillNo FROM @Bills);

-- every journal must balance to 0
SELECT tj.TxId, tj.SourceDocNumber, SUM(tjd.CrDeAmount) AS CrDeSum
FROM TransactionJournal tj
JOIN TransactionJournalDetail tjd ON tjd.TxId = tj.TxId
JOIN Purchase p ON p.PurchaseNumber = tj.SourceDocNumber
WHERE tj.SourceDocType = 'Purchase'
  AND p.PayeeId = @PayeeId
  AND p.VendorDocNumber IN (SELECT BillNo FROM @Bills)
GROUP BY tj.TxId, tj.SourceDocNumber
HAVING SUM(tjd.CrDeAmount) <> 0;   -- expect zero rows

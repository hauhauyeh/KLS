# Database Changes — Promotion System (Cart Restructure → Checkout Persistence)

This document covers all database schema and stored procedure changes introduced by the promotion system, from cart restructuring through checkout persistence.

---

## Phase 1B: Cart Architecture — Parent/Child Line Grouping

**Script:** `SQL/AddParentChildColumns.sql`

Added 5 structural columns to both `TempSales` and `SalesDetail` to support parent/child line grouping (e.g., a promo reward line grouped under its owner item).

### TempSales — New Columns

| Column | Type | Nullable | Default | Purpose |
|--------|------|----------|---------|---------|
| `ParentTempSalesId` | INT | YES | NULL | FK to parent TempSales row (owner of this reward line) |
| `RootTempSalesId` | INT | YES | NULL | FK to root TempSales row (top-level ancestor) |
| `CartLineType` | NVARCHAR(30) | NO | `'MAIN'` | Line type: `'MAIN'` for normal items, `'PROMO_REWARD'` for reward lines |
| `IsSystemManaged` | BIT | NO | `0` | If `1`, line is read-only in the UI (user cannot edit qty, price, delete) |
| `DisplaySort` | INT | YES | NULL | Ordering hint — reward lines get a DisplaySort value to appear after their owner |

### SalesDetail — New Columns

| Column | Type | Nullable | Default | Purpose |
|--------|------|----------|---------|---------|
| `ParentSalesDetailId` | INT | YES | NULL | FK to parent SalesDetail row (mapped from ParentTempSalesId at checkout) |
| `RootSalesDetailId` | INT | YES | NULL | FK to root SalesDetail row (mapped from RootTempSalesId at checkout) |
| `CartLineType` | NVARCHAR(30) | NO | `'MAIN'` | Preserved from TempSales at checkout |
| `IsSystemManaged` | BIT | NO | `0` | Preserved from TempSales at checkout |
| `DisplaySort` | INT | YES | NULL | Preserved from TempSales at checkout |

### SQL

```sql
ALTER TABLE TempSales ADD
    ParentTempSalesId INT NULL,
    RootTempSalesId   INT NULL,
    CartLineType      NVARCHAR(30) NOT NULL DEFAULT 'MAIN',
    IsSystemManaged   BIT NOT NULL DEFAULT 0,
    DisplaySort       INT NULL;

ALTER TABLE SalesDetail ADD
    ParentSalesDetailId INT NULL,
    RootSalesDetailId   INT NULL,
    CartLineType        NVARCHAR(30) NOT NULL DEFAULT 'MAIN',
    IsSystemManaged     BIT NOT NULL DEFAULT 0,
    DisplaySort         INT NULL;
```

**Note:** `OrgPrice` already existed on both tables (used for storing original price before promo repricing).

---

## Phase 2A: TempSalesPromo Linking Table

**Script:** `SQL/CreateTempSalesPromo.sql`

New table that links an owner cart item to its promo reward line. Draft-only — cleaned up at checkout.

### TempSalesPromo — New Table

| Column | Type | Nullable | Purpose |
|--------|------|----------|---------|
| `TempSalesPromoId` | INT IDENTITY | PK | Auto-increment primary key |
| `OwnerTempSalesId` | INT | NOT NULL | FK → TempSales — the cart item that triggers the promo |
| `PromoTempSalesId` | INT | NOT NULL | FK → TempSales — the reward line (free item) |
| `PromotionId` | INT | NOT NULL | Which Promotion rule created this link |
| `PromotionBogoId` | INT | NOT NULL | Which PromotionBogo rule created this link |

### Constraints

| Constraint | Type | Description |
|------------|------|-------------|
| `FK_TempSalesPromo_Owner` | FK | `OwnerTempSalesId` → `TempSales(TempSalesId)` |
| `FK_TempSalesPromo_Promo` | FK | `PromoTempSalesId` → `TempSales(TempSalesId)` |
| `UQ_TempSalesPromo_OwnerBogo` | UNIQUE | `(OwnerTempSalesId, PromotionBogoId)` — prevents duplicate links for same owner + BOGO rule |

### Indexes

| Index | Columns |
|-------|---------|
| `IX_TempSalesPromo_Owner` | `OwnerTempSalesId` |
| `IX_TempSalesPromo_Promo` | `PromoTempSalesId` |

### SQL

```sql
CREATE TABLE TempSalesPromo (
    TempSalesPromoId INT IDENTITY(1,1) PRIMARY KEY,
    OwnerTempSalesId INT NOT NULL,
    PromoTempSalesId INT NOT NULL,
    PromotionId      INT NOT NULL,
    PromotionBogoId  INT NOT NULL,
    CONSTRAINT FK_TempSalesPromo_Owner FOREIGN KEY (OwnerTempSalesId) REFERENCES TempSales(TempSalesId),
    CONSTRAINT FK_TempSalesPromo_Promo FOREIGN KEY (PromoTempSalesId) REFERENCES TempSales(TempSalesId),
    CONSTRAINT UQ_TempSalesPromo_OwnerBogo UNIQUE (OwnerTempSalesId, PromotionBogoId)
);

CREATE INDEX IX_TempSalesPromo_Owner ON TempSalesPromo(OwnerTempSalesId);
CREATE INDEX IX_TempSalesPromo_Promo ON TempSalesPromo(PromoTempSalesId);
```

---

## Phase 2E: Checkout Persistence — Stored Procedure Changes

Three stored procedures modified to support promo reward lines surviving checkout and re-injecting correctly during edit.

### 1. `Sales_Insert` — Checkout (TempSales → SalesDetail)

**Script:** `SQL/Update_Sales_Insert_2E.sql`

**Changes:**
1. **Replaced `INSERT INTO SalesDetail` with `MERGE`** — uses `ON 1=0` pattern to capture `TempSalesId → SalesDetailId` mapping via `OUTPUT` clause into `@IdMap` table variable
2. **Added parent/root ID translation** — after MERGE, `UPDATE SalesDetail` sets `ParentSalesDetailId` and `RootSalesDetailId` by looking up the mapped SalesDetailId for each parent/root TempSalesId
3. **Added `TempSalesPromo` cleanup** — `DELETE FROM TempSalesPromo` (joined via TempSales) runs BEFORE `DELETE TempSales` to satisfy FK constraints

**Key SQL (ID mapping):**
```sql
DECLARE @IdMap TABLE (
    TempSalesId INT,
    SalesDetailId INT,
    ParentTempSalesId INT,
    RootTempSalesId INT
);

MERGE INTO [dbo].[SalesDetail] AS target
USING (
    SELECT TempSalesId, ParentTempSalesId, RootTempSalesId, ...
    FROM TempSales
    WHERE EmpId=@EmpId AND PayeeId=@PayeeId AND SalesId=0 AND IsStrike=0
) AS source
ON 1=0
WHEN NOT MATCHED THEN
    INSERT (...) VALUES (...)
OUTPUT source.TempSalesId, inserted.SalesDetailId,
       source.ParentTempSalesId, source.RootTempSalesId
INTO @IdMap (...);

-- Translate parent/root references
UPDATE sd
SET sd.ParentSalesDetailId = pmap.SalesDetailId,
    sd.RootSalesDetailId = ISNULL(rmap.SalesDetailId, pmap.SalesDetailId)
FROM SalesDetail sd
INNER JOIN @IdMap m ON m.SalesDetailId = sd.SalesDetailId
LEFT JOIN @IdMap pmap ON pmap.TempSalesId = m.ParentTempSalesId
LEFT JOIN @IdMap rmap ON rmap.TempSalesId = m.RootTempSalesId
WHERE m.ParentTempSalesId IS NOT NULL;
```

**Key SQL (TempSalesPromo cleanup):**
```sql
DELETE tsp
FROM TempSalesPromo tsp
INNER JOIN TempSales ts ON ts.TempSalesId = tsp.OwnerTempSalesId
WHERE ts.EmpId = @EmpId AND ts.PayeeId = @PayeeId;
```

### 2. `Sales_Inject` — Edit (SalesDetail → TempSales)

**Script:** `SQL/Update_Sales_Inject_2E.sql`

**Changes:**
1. **Added reverse parent/root ID translation** — after INSERT INTO TempSales, `UPDATE TempSales` sets `ParentTempSalesId` and `RootTempSalesId` by joining back to SalesDetail via `TempSales.SalesDetailId` (which stores the source SalesDetailId)

**Key SQL:**
```sql
UPDATE ts
SET ts.ParentTempSalesId = pts.TempSalesId,
    ts.RootTempSalesId = ISNULL(rts.TempSalesId, pts.TempSalesId)
FROM TempSales ts
INNER JOIN SalesDetail sd ON sd.SalesDetailId = ts.SalesDetailId
LEFT JOIN TempSales pts ON pts.SalesDetailId = sd.ParentSalesDetailId
    AND pts.EmpId = @EmpId AND pts.SalesId = @SalesId AND pts.PayeeId = @PayeeId
LEFT JOIN TempSales rts ON rts.SalesDetailId = sd.RootSalesDetailId
    AND rts.EmpId = @EmpId AND rts.SalesId = @SalesId AND rts.PayeeId = @PayeeId
WHERE ts.EmpId = @EmpId AND ts.SalesId = @SalesId AND ts.PayeeId = @PayeeId
    AND sd.ParentSalesDetailId IS NOT NULL;
```

### 3. `TempSales_GetList` — Cart Display Ordering

**Script:** `SQL/Update_TempSales_GetList_2E.sql`

**Changes:**
1. **Default ORDER BY changed** from `x.LineId` to `ISNULL(x.DisplaySort, x.LineId), x.LineId` — ensures promo reward lines appear directly after their owner item

**Before:**
```sql
SET @Qry += ' ORDER BY x.LineId'
```

**After:**
```sql
SET @Qry += ' ORDER BY ISNULL(x.DisplaySort, x.LineId), x.LineId'
```

### 4. `Sales_PartialUpdate` — Edit Save (TempSales → SalesDetail update)

**Script:** `SQL/Update_Sales_PartialUpdate.sql`

**Changes (applied in Phase 1B):**
- Reads `CartLineType`, `IsSystemManaged`, `DisplaySort` from TempSales
- Writes them to SalesDetail on INSERT (new lines) and UPDATE (modified lines)
- Parent/Root ID translation still deferred (NULL) for new lines added during edit

---

## Summary of All SQL Scripts (Execution Order)

| # | Script | Phase | Action |
|---|--------|-------|--------|
| 1 | `AddParentChildColumns.sql` | 1B | ALTER TABLE — adds 5 columns to TempSales + SalesDetail |
| 2 | `CreateTempSalesPromo.sql` | 2A | CREATE TABLE + indexes |
| 3 | `Update_Sales_Insert.sql` | 1B | ALTER PROC — adds new columns to SalesDetail INSERT (superseded by 2E) |
| 4 | `Update_Sales_PartialUpdate.sql` | 1B | ALTER PROC — adds new columns to SalesDetail INSERT/UPDATE |
| 5 | `Update_Sales_Insert_2E.sql` | 2E | ALTER PROC — MERGE for ID mapping + TempSalesPromo cleanup (replaces #3) |
| 6 | `Update_Sales_Inject_2E.sql` | 2E | ALTER PROC — reverse parent/root ID mapping |
| 7 | `Update_TempSales_GetList_2E.sql` | 2E | ALTER PROC — DisplaySort ordering |

**Note:** Script #5 supersedes #3. If running on a fresh database, run #5 instead of #3. If #3 was already applied, running #5 will overwrite it (both are ALTER PROCEDURE).

---

## Entity Relationship (Promo-Related)

```
TempSales (draft cart)
  ├── ParentTempSalesId → TempSales.TempSalesId  (reward → owner)
  ├── RootTempSalesId   → TempSales.TempSalesId  (reward → root owner)
  └── TempSalesPromo (linking table, draft-only)
        ├── OwnerTempSalesId → TempSales.TempSalesId
        ├── PromoTempSalesId → TempSales.TempSalesId
        ├── PromotionId      → Promotion.PromotionId
        └── PromotionBogoId  → PromotionBogo.PromotionBogoId

SalesDetail (persisted after checkout)
  ├── ParentSalesDetailId → SalesDetail.SalesDetailId  (mapped from ParentTempSalesId)
  └── RootSalesDetailId   → SalesDetail.SalesDetailId  (mapped from RootTempSalesId)
```

**TempSalesPromo is draft-only** — deleted at checkout. After checkout, the parent/child relationship is preserved structurally via `ParentSalesDetailId`/`RootSalesDetailId` on SalesDetail, but the specific promotion rule info (PromotionId, PromotionBogoId) is lost. This means edited orders show reward lines as read-only historical data but cannot toggle promos ON/OFF.

---

## Data Flow

### Checkout (new order)
```
TempSales → MERGE INTO SalesDetail (with @IdMap OUTPUT)
         → UPDATE SalesDetail parent/root from @IdMap
         → DELETE TempSalesPromo
         → DELETE TempSales
```

### Edit (existing order)
```
SalesDetail → INSERT INTO TempSales (with SalesDetailId preserved)
           → UPDATE TempSales parent/root from SalesDetail via SalesDetailId join
```

### Cart display
```
TempSales_GetList → ORDER BY ISNULL(DisplaySort, LineId), LineId
                  → Reward lines appear directly after owner
```

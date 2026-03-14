# Database Changes — `feature/cart-sorting` Branch

**Date:** 2026-03-12
**Branch:** `feature/cart-sorting`

---

## Overview

Two new stored procedures need to be created on `KLS_Latest`. No table schema changes — only new SPs.

---

## 1. `Item_ListActiveForKeybox`

**File:** `SQL/Item_ListActiveForKeybox.sql`
**Purpose:** Returns all active items with base unit and last order info for a given customer. Used by the frontend keybox cache to avoid multiple round-trips during item lookup.

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `@PayeeId` | INT | Customer's PayeeId |

### Returns

| Column | Source |
|--------|--------|
| `ItemId`, `ItemCode`, `ItemName`, `Inactive`, `ItemSearchTag` | `Item` |
| `BaseUnit` | `ItemUnit` (where `IsBaseUnit = 1`) |
| `LCloseQty` | `Item` |
| `LastOrderDate`, `LastOrderQty`, `LastOrderUnit` | Most recent `SalesDetail` row for this customer (ranked by `SalesId DESC`) |

### Dependencies
- Tables: `Item`, `ItemUnit`, `SalesDetail`, `Sales`
- No dependency on other SPs

### Deploy
```sql
-- Run SQL/Item_ListActiveForKeybox.sql
CREATE PROCEDURE [dbo].[Item_ListActiveForKeybox] ...
```

---

## 2. `TempSales_AddLine`

**File:** `SQL/TempSales_AddLine.sql`
**Purpose:** Consolidated SP that handles item/account lookup, unit resolution, pricing, INSERT into `TempSales`, and returns the new row — all in one round-trip. Replaces 5 separate DB calls that `TempSalesService.AddItem()` / `AddAccount()` previously made.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `@PayeeId` | INT | required | Customer PayeeId |
| `@SalesId` | INT | required | Sales order ID (0 for new) |
| `@EmpId` | INT | required | Employee ID (from JWT) |
| `@ItemId` | INT | NULL | Item ID (if known) |
| `@ItemCode` | NVARCHAR(100) | NULL | Item code or `@AccountCode` prefix for accounts |
| `@Qty` | DECIMAL(18,4) | required | Order quantity |
| `@UnitPrice` | DECIMAL(18,4) | NULL | Override price (NULL = use default pricing) |
| `@Unit` | NVARCHAR(10) | NULL | Unit string: explicit unit, `w` = wholesale/base, `r` = retail/non-base |
| `@Notes` | NVARCHAR(500) | NULL | Line notes |

### Routing Logic

- If `@ItemCode` starts with `@` → **Account path** (LineType `A`)
- Otherwise → **Item path** (LineType `I`)

### Account Path
1. Looks up `Account` by `AccountCode`, falls back to `AccountName`
2. Rejects Asset (`A`) and Expense (`X`) class accounts (error 50004)
3. Inserts into `TempSales` with `LineType = 'A'`, `CartLineType = 'MAIN'`
4. Returns the new row joined with `Account` for name/code

### Item Path
1. Resolves item by `@ItemId` or `@ItemCode` (code → name fallback)
2. Validates: not deleted (error 50001), not inactive (error 50002)
3. Resolves unit: `w` → base unit, `r` → non-base unit, explicit match, fallback to base
4. Calls `[Get_ItemPriceByCustomer]` for customer-specific pricing
5. Uses `@UnitPrice` override if provided and non-zero, else SP price
6. Inserts into `TempSales` with full pricing fields (`IsTaxable`, `OrgPrice`, `DiscountPercent`, `FactorToBase`)
7. Returns the new row joined with `Item` for name/code/CaseWeight/PackSize

### Error Codes

| Code | Message | When |
|------|---------|------|
| 50001 | `Product code not found` | Item not found or deleted |
| 50002 | `This product already discontinue` | Item is inactive |
| 50003 | `Account not found` | Account code/name not found |
| 50004 | `You can't add Expense/Asset account` | Account class is A or X |

### Dependencies
- Tables: `TempSales`, `Item`, `ItemUnit`, `Account`, `AccountCategory`
- SP: `[Get_ItemPriceByCustomer]` (must already exist)
- Trigger: `TRG_Insert_TempSalesSetLineId` (auto-assigns LineId on INSERT)

### Deploy
```sql
-- Run SQL/TempSales_AddLine.sql
CREATE PROCEDURE [dbo].[TempSales_AddLine] ...
```

---

## Deployment Checklist

1. [ ] Run `SQL/Item_ListActiveForKeybox.sql` on `KLS_Latest`
2. [ ] Run `SQL/TempSales_AddLine.sql` on `KLS_Latest`
3. [ ] Verify `[Get_ItemPriceByCustomer]` SP exists (dependency)
4. [ ] Test: `EXEC [Item_ListActiveForKeybox] @PayeeId = <any customer payee id>`
5. [ ] Test: `EXEC [TempSales_AddLine] @PayeeId=1, @SalesId=0, @EmpId=1, @ItemCode='<valid item code>', @Qty=1`

---

## Rollback

```sql
DROP PROCEDURE IF EXISTS [dbo].[TempSales_AddLine];
DROP PROCEDURE IF EXISTS [dbo].[Item_ListActiveForKeybox];
```

No table changes to revert.

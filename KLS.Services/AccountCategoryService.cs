using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class AccountCategoryService : BaseService, IAccountCategoryService
    {
        public AccountCategoryService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<AccountFlatTree> GetFlatTree()
        {
            var categories = Uow.AccountCategories.GetAll()
                .Include(c => c.Accounts)
                .ToList();

            var flatList = new List<AccountFlatTree>();

            foreach (var cat in categories)
            {
                // Add Category Node
                flatList.Add(new AccountFlatTree
                {
                    Id = cat.AccountCategoryId,
                    ParentId = cat.ParentId,
                    Name = cat.CategoryName,
                    AccountCode = "", // Categories don't have codes in the model shown, but Account has AccountCode.
                    Type = "Category",
                    ClassCode = cat.ClassCode,
                    NormalSide = cat.NormalSide,
                    SortOrder = cat.SortOrder,
                    IsAccountDebit = cat.NormalSide == "D",
                    HasChild = true
                });

                // Add Account Nodes for this category
                foreach (var acc in cat.Accounts)
                {
                    flatList.Add(new AccountFlatTree
                    {
                        Id = acc.AccountId,
                        ParentId = acc.AccountCategoryId, // This will map to the Category ID
                        Name = acc.AccountName,
                        AccountCode = acc.AccountCode,
                        Type = "Account",
                        ClassCode = cat.ClassCode, // Inherit? Not specified, but useful context
                        NormalSide = cat.NormalSide, // Inherit
                        SortOrder = acc.SortOrder,
                        IsAccountDebit = acc.IsAccountDebit,
                        IsDefaultAccount = acc.IsDefaultAccount,
                        HasChild = false
                    });
                }
            }

            return flatList.OrderBy(x => x.SortOrder).ThenBy(x => x.Name);
        }

        public IEnumerable<AccountFlatTree> GetRecursiveTree()
        {
            var flat = GetFlatTree(); // your current flat function
            return BuildTree(flat);
        }

        public IEnumerable<AccountFlatTree> BuildTree(IEnumerable<AccountFlatTree> flat)
        {
            // Convert all flat nodes into tree nodes
            var nodes = flat.Select(x => new AccountFlatTree
            {
                Id = x.Id,
                ParentId = x.ParentId,
                Name = x.Name,
                AccountCode = x.AccountCode,
                Type = x.Type,
                ClassCode = x.ClassCode,
                NormalSide = x.NormalSide,
                SortOrder = x.SortOrder,
                IsAccountDebit = x.IsAccountDebit,
                IsDefaultAccount = x.IsDefaultAccount,
                HasChild = x.HasChild
            }).ToList();

            // IMPORTANT:
            // If Category.Id and Account.Id can overlap, you must key by (Type + Id).
            // If they are guaranteed unique across both tables, you can key by Id only.
            var map = nodes.ToDictionary(n => (n.Type, n.Id));

            var roots = new List<AccountFlatTree>();

            foreach (var node in nodes)
            {
                if (node.ParentId.HasValue)
                {
                    // Accounts parent = Category, Categories parent = Category
                    var parentKey = ("Category", node.ParentId.Value);

                    if (map.TryGetValue(parentKey, out var parent))
                        parent.Children.Add(node);
                    else
                        roots.Add(node); // orphan fallback (optional)
                }
                else
                {
                    roots.Add(node);
                }
            }

            // Sort recursively (SortOrder then Name)
            SortTree(roots);

            return roots;
        }

        private static void SortTree(List<AccountFlatTree> list)
        {
            list.Sort((a, b) =>
            {
                var cmp = a.SortOrder.CompareTo(b.SortOrder);
                return cmp != 0 ? cmp : string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
            });

            foreach (var n in list)
                if (n.Children.Count > 0)
                    SortTree(n.Children);
        }


        public AccountCategory GetById(int categoryId)
        {
            return Uow.AccountCategories.GetById(categoryId);
        }

        public AccountCategory Create(AccountCategory category)
        {
            // Map ClassName from ClassCode
            category.ClassName = GetClassName(category.ClassCode);

            // If it's a sub-category, inherit values from parent
            if (category.ParentId.HasValue)
            {
                var parent = Uow.AccountCategories.Find(x => x.AccountCategoryId == category.ParentId.Value).FirstOrDefault();

                if (parent == null)
                    throw new InvalidOperationException("Parent category not found.");

                // Inherit from parent (do NOT allow child to change these)
                category.ClassCode = parent.ClassCode;
                category.ClassName = parent.ClassName;
                category.NormalSide = parent.NormalSide;
            }

            Uow.AccountCategories.Add(category);
            Uow.Commit();

            return category;
        }

        public AccountCategory Update(AccountCategory category)
        {
            var existing = GetById(category.AccountCategoryId);

            if (existing == null)
                throw new Exception("Category not found");

            bool classCodeChanged = existing.ClassCode != category.ClassCode;
            bool normalSideChanged = existing.NormalSide != category.NormalSide;

            existing.CategoryName = category.CategoryName;
            existing.ClassCode = category.ClassCode;
            // Update ClassName as well
            existing.ClassName = GetClassName(category.ClassCode);
            existing.NormalSide = category.NormalSide;
            existing.SortOrder = category.SortOrder;
            // ParentId change? "No move UI" so maybe not needed, but good to have.
            // existing.ParentId = category.ParentId; 

            Uow.AccountCategories.Update(existing);

            if (classCodeChanged || normalSideChanged)
            {
                PropagateChanges(existing);
            }

            Uow.Commit();
            return existing;
        }

        public void Delete(int categoryId)
        {
            // Check for children
            var hasChildren = Uow.AccountCategories.Exists(c => c.ParentId == categoryId);
            if (hasChildren) throw new Exception("Cannot delete category with child categories");

            var hasAccounts = Uow.Accounts.Exists(a => a.AccountCategoryId == categoryId);
            if (hasAccounts) throw new Exception("Cannot delete category with accounts");

            Uow.AccountCategories.RemoveById(categoryId);
            Uow.Commit();
        }

        public void ReorderNode(AccountNodeReorderReq dto)
        {
            // 1. Identify Parent ID
            int? parentId = null;
            if (dto.Type == "Category")
            {
                var cat = Uow.AccountCategories.GetById(dto.Id);
                if (cat == null) throw new Exception("Category not found");
                parentId = cat.ParentId;
            }
            else
            {
                var acc = Uow.Accounts.GetById(dto.Id);
                if (acc == null) throw new Exception("Account not found");
                parentId = acc.AccountCategoryId;
            }

            // 2. Fetch All Siblings (Mixed Types)
            var siblingCategories = Uow.AccountCategories.Find(c => c.ParentId == parentId).ToList();
            var siblingAccounts = new List<Account>();

            // If parentId is null, we are at root. Root cannot have accounts in this model?
            // "Accounts can ONLY be added to categories..." -> Root accounts impossible?
            // Let's assume parentId is NOT null for accounts.
            // But if parentId IS null (Root), we only have Categories.
            if (parentId.HasValue)
            {
                // Find accounts in this category
                // Note: parentId here IS the AccountCategoryId for accounts
                // BUT for Categories, parentId is the Parent Category ID.
                // Wait. 
                // If I am a Category, my ParentId is X. 
                // If I am an Account, my AccountCategoryId is X.
                // So all siblings share X.

                // If X is null (Root), then only Categories exist (as accounts must have a category).
                // If X is not null, we have sub-categories of X AND accounts of X.
                siblingAccounts = Uow.Accounts.Find(a => a.AccountCategoryId == parentId.Value).ToList();
            }

            // 3. Create a unified list to sort
            var siblings = new List<dynamic>();
            foreach (var c in siblingCategories) siblings.Add(new { Node = c, Type = "Category", SortOrder = c.SortOrder, Name = c.CategoryName, Id = c.AccountCategoryId });
            foreach (var a in siblingAccounts) siblings.Add(new { Node = a, Type = "Account", SortOrder = a.SortOrder, Name = a.AccountName, Id = a.AccountId });

            // 4. Sort by Current SortOrder, then Name
            siblings = siblings.OrderBy(x => x.SortOrder).ThenBy(x => x.Name).ToList();

            // 5. Normalize SortOrders (10, 20, 30...)
            for (int i = 0; i < siblings.Count; i++)
            {
                var item = siblings[i];
                if (item.Type == "Category") ((AccountCategory)item.Node).SortOrder = (i + 1) * 10;
                else ((Account)item.Node).SortOrder = (i + 1) * 10;
            }

            // 6. Find Current Index
            var currentIndex = siblings.FindIndex(x => x.Type == dto.Type && x.Id == dto.Id);
            if (currentIndex == -1) throw new Exception("Node not found in siblings");

            // 7. Determine Swap Target
            int targetIndex = -1;
            if (dto.Direction == "Up") targetIndex = currentIndex - 1;
            else if (dto.Direction == "Down") targetIndex = currentIndex + 1;

            if (targetIndex >= 0 && targetIndex < siblings.Count)
            {
                // 8. Swap SortOrder values
                var currentItem = siblings[currentIndex];
                var targetItem = siblings[targetIndex];

                int currentSort = 0;
                int targetSort = 0;

                if (currentItem.Type == "Category") currentSort = ((AccountCategory)currentItem.Node).SortOrder;
                else currentSort = ((Account)currentItem.Node).SortOrder;

                if (targetItem.Type == "Category") targetSort = ((AccountCategory)targetItem.Node).SortOrder;
                else targetSort = ((Account)targetItem.Node).SortOrder;

                // Swap
                if (currentItem.Type == "Category") ((AccountCategory)currentItem.Node).SortOrder = targetSort;
                else ((Account)currentItem.Node).SortOrder = targetSort;

                if (targetItem.Type == "Category") ((AccountCategory)targetItem.Node).SortOrder = currentSort;
                else ((Account)targetItem.Node).SortOrder = currentSort;
            }

            // 9. Save All Changes
            // Since we normalized, we updated ALL siblings.
            foreach (var item in siblings)
            {
                if (item.Type == "Category") Uow.AccountCategories.Update((AccountCategory)item.Node);
                else Uow.Accounts.Update((Account)item.Node);
            }
            Uow.Commit();
        }

        public void MoveAccount(AccountMoveReq dto)
        {
            var account = Uow.Accounts.GetById(dto.AccountId);
            if (account == null) throw new Exception("Account not found");

            var newCategory = Uow.AccountCategories.GetById(dto.NewCategoryId);
            if (newCategory == null) throw new Exception("Target Category not found");

            // Rule: Target Category must NOT have child categories
            bool hasChildCategories = Uow.AccountCategories.Exists(c => c.ParentId == dto.NewCategoryId);
            if (hasChildCategories)
            {
                throw new Exception("Cannot move account to a category that has sub-categories.");
            }

            // Rule: Check Duplicate AccountCode in NEW category?
            // Current rule is "Duplicate AccountCode values are NOT allowed" - implying globally?
            // "Account Code already exists" check in AddAccount uses `Uow.Accounts.Exists(a => a.AccountCode == ...)`
            // This suggests global uniqueness. If so, moving doesn't violate uniqueness (unless we were copying).
            // So we don't need to check uniqueness again, as the code itself doesn't change.

            // Logic: Update Parent
            account.AccountCategoryId = dto.NewCategoryId;

            // Logic: Update IsAccountDebit based on new Category NormalSide
            account.IsAccountDebit = newCategory.NormalSide == "D";

            account.TypeName = newCategory.CategoryName;

            // Logic: Update SortOrder (Append to end)
            // Get max sort order of items in new category
            var siblingAccounts = Uow.Accounts.Find(a => a.AccountCategoryId == dto.NewCategoryId).ToList();
            int maxSort = 0;
            if (siblingAccounts.Any())
            {
                maxSort = siblingAccounts.Max(a => a.SortOrder);
            }
            account.SortOrder = maxSort + 10;

            Uow.Accounts.Update(account);
            Uow.Commit();
        }



        private void PropagateChanges(AccountCategory parent)
        {
            // 1. Update direct accounts (IsAccountDebit)
            var accounts = Uow.Accounts.Find(a => a.AccountCategoryId == parent.AccountCategoryId).ToList();

            foreach (var acc in accounts)
            {
                bool newDebit = parent.NormalSide == "D";
                if (acc.IsAccountDebit != newDebit)
                {
                    acc.IsAccountDebit = newDebit;
                    Uow.Accounts.Update(acc);
                }
            }

            // 2. Update sub-categories (ClassCode, ClassName, NormalSide)
            var children = Uow.AccountCategories.Find(c => c.ParentId == parent.AccountCategoryId).ToList();

            foreach (var child in children)
            {
                child.ClassCode = parent.ClassCode;
                child.ClassName = parent.ClassName;
                child.NormalSide = parent.NormalSide;
                Uow.AccountCategories.Update(child);

                // Recurse
                PropagateChanges(child);
            }
        }

        private string GetClassName(string code)
        {
            return code switch
            {
                "A" => "Asset",
                "L" => "Liability",
                "Q" => "Equity",
                "I" => "Revenue",
                "X" => "Expense",
                "C" => "Cost of Goods Sold",
                _ => "Unknown"
            };
        }

    }
}

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
    public class HomeService : BaseService, IHomeService
    {
        private const int FeaturedCategoryLimit = 8;
        private const int NewArrivalsLimit = 10;
        private const int TopSellingLimit = 10;
        private const int TopCategoryGroupCount = 5;
        private const int ProductsPerGroup = 10;
        private const int ProductCandidateMultiplier = 4;

        private readonly ICategoryRollupHelper _categoryRollup;

        public HomeService(IUnitOfWork uow, ICategoryRollupHelper categoryRollup) : base(uow)
        {
            _categoryRollup = categoryRollup;
        }

        public HomePageData GetHomePageData(string baseUrl)
        {
            var rollup = BuildCategoryRollup();

            var featuredCategories = GetFeaturedCategories(baseUrl, rollup);
            var topSelling = GetTopSellingProducts(baseUrl);
            var newArrivals = GetNewArrivals(baseUrl);
            var topCategoryGroups = GetTopCategoryGroups(baseUrl, featuredCategories, rollup);

            return new HomePageData
            {
                FeaturedCategories = featuredCategories,
                NewArrivals = newArrivals,
                TopSellingProducts = topSelling,
                TopCategoryGroups = topCategoryGroups,

                // Legacy fields — populated for backward compatibility with B2C and any
                // existing consumers. Remove in Phase 2 after B2C migrates.
                Categories = featuredCategories,
                Products = topSelling
            };
        }

        // Precomputed once per request. Item counts on top-level categories must include
        // items in descendant sub-categories, otherwise top-level groups like "Meat" show
        // zero products when all SKUs live under children like "Beef" / "Pork". The tree
        // walk is shared with PromoHelperService via ICategoryRollupHelper.
        private CategoryRollup BuildCategoryRollup()
        {
            var directCounts = Uow.Items.Find(i => !i.Inactive)
                .Where(i => i.CategoryId != null)
                .GroupBy(i => i.CategoryId!.Value)
                .Select(g => new { CategoryId = g.Key, Count = g.Count() })
                .ToDictionary(x => x.CategoryId, x => x.Count);

            var descendantIds = _categoryRollup.GetDescendantMap();

            var rolledUpCounts = descendantIds.ToDictionary(
                kvp => kvp.Key,
                kvp => kvp.Value.Sum(id => directCounts.GetValueOrDefault(id))
            );

            return new CategoryRollup
            {
                RolledUpCounts = rolledUpCounts,
                DescendantIds = descendantIds
            };
        }

        private List<HomeCategory> GetFeaturedCategories(string baseUrl, CategoryRollup rollup)
        {
            var categories = Uow.ItemCategories
                .Find(c => c.ParentId == null && !c.Inactive)
                .OrderBy(c => c.SortOrder)
                .ThenBy(c => c.CategoryName)
                .AsNoTracking()
                .Take(FeaturedCategoryLimit)
                .ToList();

            var fallbackImageMap = BuildCategoryImageFallbackMap(categories, rollup, baseUrl);

            return categories
                .Select(c => new HomeCategory
                {
                    CategoryId = c.CategoryId,
                    CategoryName = c.CategoryName,
                    DisplayName = c.DisplayName,
                    ImageUrl = ResolveImageUrl(c.ImageUrl, baseUrl) ?? fallbackImageMap.GetValueOrDefault(c.CategoryId),
                    ItemCount = rollup.RolledUpCounts.GetValueOrDefault(c.CategoryId)
                })
                .ToList();
        }

        private List<HomeProduct> GetNewArrivals(string baseUrl)
        {
            var items = Uow.Items
                .Find(i => !i.Inactive)
                .OrderByDescending(i => i.CreatedAt)
                .ThenByDescending(i => i.ItemId)
                .Take(NewArrivalsLimit * ProductCandidateMultiplier)
                .AsNoTracking()
                .ToList();

            var imageMap = BuildImageMap(items, baseUrl);
            var categoryNameMap = BuildCategoryNameMap(items);

            return items
                .Select(i => MapToHomeProduct(i, imageMap, categoryNameMap, baseUrl, "New"))
                .OrderByDescending(p => !string.IsNullOrWhiteSpace(p.PrimaryImageUrl))
                .Take(NewArrivalsLimit)
                .ToList();
        }

        private List<HomeProduct> GetTopSellingProducts(string baseUrl)
        {
            var items = Uow.Items
                .Find(i => !i.Inactive && i.Last3M > 0)
                .OrderByDescending(i => i.Last3M)
                .Take(TopSellingLimit * ProductCandidateMultiplier)
                .AsNoTracking()
                .ToList();

            var imageMap = BuildImageMap(items, baseUrl);
            var categoryNameMap = BuildCategoryNameMap(items);

            return items
                .Select(i => MapToHomeProduct(i, imageMap, categoryNameMap, baseUrl))
                .OrderByDescending(p => !string.IsNullOrWhiteSpace(p.PrimaryImageUrl))
                .Take(TopSellingLimit)
                .ToList();
        }

        private List<HomeCategoryProductGroup> GetTopCategoryGroups(string baseUrl, List<HomeCategory> featuredCategories, CategoryRollup rollup)
        {
            // Skip featured categories that have no items anywhere in their subtree.
            var groupCategories = featuredCategories
                .Where(c => c.ItemCount > 0)
                .Take(TopCategoryGroupCount)
                .ToList();

            if (groupCategories.Count == 0) return new List<HomeCategoryProductGroup>();

            // Reverse map: any descendant CategoryId -> its featured-category root.
            // Built only for the seeds we actually need.
            var descendantToRoot = new Dictionary<int, int>();
            foreach (var cat in groupCategories)
            {
                if (!rollup.DescendantIds.TryGetValue(cat.CategoryId, out var descendants)) continue;
                foreach (var id in descendants)
                {
                    descendantToRoot[id] = cat.CategoryId;
                }
            }

            var descendantIdList = descendantToRoot.Keys.ToList();
            if (descendantIdList.Count == 0) return new List<HomeCategoryProductGroup>();

            // Single products query across all 5 subtrees.
            var allProducts = Uow.Items
                .Find(i => !i.Inactive && i.Last3M > 0 && i.CategoryId.HasValue && descendantIdList.Contains(i.CategoryId.Value))
                .OrderByDescending(i => i.Last3M)
                .AsNoTracking()
                .ToList();

            // Single batched image query for all items across all groups.
            var imageMap = BuildImageMap(allProducts, baseUrl);

            var productsByRoot = allProducts
                .Where(i => i.CategoryId.HasValue && descendantToRoot.ContainsKey(i.CategoryId.Value))
                .GroupBy(i => descendantToRoot[i.CategoryId!.Value])
                .ToDictionary(g => g.Key, g => g.Take(ProductsPerGroup).ToList());

            return groupCategories
                .Select(cat =>
                {
                    productsByRoot.TryGetValue(cat.CategoryId, out var groupItems);
                    groupItems ??= new List<Item>();

                    return new HomeCategoryProductGroup
                    {
                        CategoryId = cat.CategoryId,
                        CategoryName = cat.CategoryName,
                        DisplayName = cat.DisplayName,
                        ImageUrl = cat.ImageUrl,
                        ItemCount = cat.ItemCount,
                        Products = groupItems.Select(i => MapToHomeProduct(i, imageMap, null, baseUrl)).ToList()
                    };
                })
                .ToList();
        }

        private Dictionary<int, string> BuildImageMap(IReadOnlyCollection<Item> items, string baseUrl)
        {
            if (items.Count == 0) return new Dictionary<int, string>();

            var itemIds = items.Select(i => i.ItemId).ToList();

            return Uow.ItemImages
                .Find(img => itemIds.Contains(img.ItemId) && img.IsPrimary && img.Has300)
                .AsNoTracking()
                .ToDictionary(img => img.ItemId, img => $"{baseUrl}/Images/items/{img.ItemId}/{img.ImageIndex}-300.png");
        }

        private Dictionary<int, string> BuildCategoryImageFallbackMap(
            IReadOnlyCollection<ItemCategory> categories,
            CategoryRollup rollup,
            string baseUrl)
        {
            if (categories.Count == 0) return new Dictionary<int, string>();

            var descendantToRoot = new Dictionary<int, int>();
            foreach (var category in categories)
            {
                if (!string.IsNullOrWhiteSpace(category.ImageUrl)) continue;
                if (!rollup.DescendantIds.TryGetValue(category.CategoryId, out var descendants)) continue;

                foreach (var id in descendants)
                {
                    descendantToRoot[id] = category.CategoryId;
                }
            }

            if (descendantToRoot.Count == 0) return new Dictionary<int, string>();

            var descendantIds = descendantToRoot.Keys.ToList();
            var candidateItems = Uow.Items
                .Find(i => !i.Inactive && i.Last3M > 0 && i.CategoryId.HasValue && descendantIds.Contains(i.CategoryId.Value))
                .OrderByDescending(i => i.Last3M)
                .AsNoTracking()
                .ToList();

            var imageMap = BuildImageMap(candidateItems, baseUrl);
            var result = new Dictionary<int, string>();

            foreach (var item in candidateItems)
            {
                if (!item.CategoryId.HasValue) continue;
                if (!descendantToRoot.TryGetValue(item.CategoryId.Value, out var rootCategoryId)) continue;
                if (result.ContainsKey(rootCategoryId)) continue;
                if (imageMap.TryGetValue(item.ItemId, out var imageUrl))
                {
                    result[rootCategoryId] = imageUrl;
                }
            }

            return result;
        }

        private static string? ResolveImageUrl(string? imageUrl, string baseUrl)
        {
            if (string.IsNullOrWhiteSpace(imageUrl)) return null;
            if (Uri.TryCreate(imageUrl, UriKind.Absolute, out _)) return imageUrl;

            return imageUrl.StartsWith("/")
                ? baseUrl + imageUrl
                : $"{baseUrl}/{imageUrl}";
        }

        private Dictionary<int, string?> BuildCategoryNameMap(IReadOnlyCollection<Item> items)
        {
            if (items.Count == 0) return new Dictionary<int, string?>();

            var categoryIds = items
                .Where(i => i.CategoryId.HasValue)
                .Select(i => i.CategoryId!.Value)
                .Distinct()
                .ToList();

            if (categoryIds.Count == 0) return new Dictionary<int, string?>();

            return Uow.ItemCategories
                .Find(c => categoryIds.Contains(c.CategoryId))
                .AsNoTracking()
                .ToDictionary(c => c.CategoryId, c => c.DisplayName ?? c.CategoryName);
        }

        private static HomeProduct MapToHomeProduct(
            Item item,
            Dictionary<int, string> imageMap,
            Dictionary<int, string?>? categoryNameMap,
            string baseUrl,
            string? badgeText = null)
        {
            imageMap.TryGetValue(item.ItemId, out var imagePath);
            string? categoryName = null;
            if (categoryNameMap != null && item.CategoryId.HasValue)
            {
                categoryNameMap.TryGetValue(item.CategoryId.Value, out categoryName);
            }

            return new HomeProduct
            {
                ItemId = item.ItemId,
                ItemName = item.ItemName,
                ItemName2 = item.ItemName2,
                SetPacking = item.SetPacking,
                PackSize = item.PackSize,
                PrimaryImageUrl = imagePath,
                CategoryId = item.CategoryId,
                CategoryName = categoryName,
                BadgeText = badgeText
            };
        }

        private class CategoryRollup
        {
            public Dictionary<int, int> RolledUpCounts { get; set; } = new();
            public Dictionary<int, List<int>> DescendantIds { get; set; } = new();
        }
    }
}

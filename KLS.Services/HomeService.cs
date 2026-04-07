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
        public HomeService(IUnitOfWork uow) : base(uow)
        {
        }

        public HomePageData GetHomePageData(string baseUrl)
        {
            return new HomePageData
            {
                Categories = GetCategories(baseUrl),
                Products = GetProducts(baseUrl)
            };
        }

        private IEnumerable<HomeCategory> GetCategories(string baseUrl)
        {
            var itemCounts = Uow.Items.Find(i => !i.Inactive)
                .Where(i => i.CategoryId != null)
                .GroupBy(i => i.CategoryId!.Value)
                .Select(g => new { CategoryId = g.Key, Count = g.Count() })
                .ToDictionary(x => x.CategoryId, x => x.Count);

            return Uow.ItemCategories
                .Find(c => c.ParentId == null && !c.Inactive)
                .OrderBy(c => c.SortOrder)
                .ThenBy(c => c.CategoryName)
                .AsNoTracking()
                .ToList()
                .Select(c => new HomeCategory
                {
                    CategoryId = c.CategoryId,
                    CategoryName = c.CategoryName,
                    DisplayName = c.DisplayName,
                    ImageUrl = string.IsNullOrEmpty(c.ImageUrl) ? null : baseUrl + c.ImageUrl,
                    ItemCount = itemCounts.GetValueOrDefault(c.CategoryId)
                });
        }

        private IEnumerable<HomeProduct> GetProducts(string baseUrl)
        {
            var items = Uow.Items.Find(i => !i.Inactive && i.Last3M > 0)
                .OrderByDescending(i => i.Last3M)
                .Take(10)
                .AsNoTracking()
                .ToList();

            var itemIds = items.Select(i => i.ItemId).ToList();

            var primaryImages = Uow.ItemImages
                .Find(img => itemIds.Contains(img.ItemId) && img.IsPrimary && img.Has300)
                .AsNoTracking()
                .ToDictionary(img => img.ItemId, img => $"/Images/items/{img.ItemId}/{img.ImageIndex}-300.png");

            return items.Select(i =>
            {
                primaryImages.TryGetValue(i.ItemId, out var imagePath);

                return new HomeProduct
                {
                    ItemId = i.ItemId,
                    ItemName = i.ItemName,
                    ItemName2 = i.ItemName2,
                    SetPacking = i.SetPacking,
                    PackSize = i.PackSize,
                    PrimaryImageUrl = string.IsNullOrEmpty(imagePath) ? null : baseUrl + imagePath
                };
            });
        }
    }
}

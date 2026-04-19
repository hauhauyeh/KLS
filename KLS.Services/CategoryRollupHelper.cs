using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using Microsoft.EntityFrameworkCore;

namespace KLS.Services
{
    public class CategoryRollupHelper : ICategoryRollupHelper
    {
        private readonly IUnitOfWork _uow;

        public CategoryRollupHelper(IUnitOfWork uow)
        {
            _uow = uow;
        }

        // Single DB query for the category tree; in-memory DFS to build the
        // descendant map. Inactive categories are filtered out at the query
        // level so they never appear in keys or descendant lists.
        public Dictionary<int, List<int>> GetDescendantMap()
        {
            var allCategories = _uow.ItemCategories.Find(c => !c.Inactive)
                .AsNoTracking()
                .Select(c => new { c.CategoryId, c.ParentId })
                .ToList();

            var childrenByParent = allCategories
                .Where(c => c.ParentId.HasValue)
                .GroupBy(c => c.ParentId!.Value)
                .ToDictionary(g => g.Key, g => g.Select(x => x.CategoryId).ToList());

            var result = new Dictionary<int, List<int>>();
            foreach (var cat in allCategories)
            {
                var collected = new List<int>();
                var stack = new Stack<int>();
                stack.Push(cat.CategoryId);
                while (stack.Count > 0)
                {
                    var id = stack.Pop();
                    collected.Add(id);
                    if (childrenByParent.TryGetValue(id, out var kids))
                    {
                        foreach (var k in kids) stack.Push(k);
                    }
                }
                result[cat.CategoryId] = collected;
            }

            return result;
        }
    }
}

using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.Extensions.Caching.Memory;

namespace KLS.Services
{
    public class PermissionService : BaseService, IPermissionService
    {
        private readonly IMemoryCache _cache;
        private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

        public PermissionService(IUnitOfWork uow, IMemoryCache cache) : base(uow)
        {
            _cache = cache;
        }

        public HashSet<string> GetPermissionKeys(int roleId)
        {
            var cacheKey = $"perm:{roleId}";

            if (_cache.TryGetValue(cacheKey, out HashSet<string>? cached) && cached != null)
                return cached;

            var keys = (from rp in Uow.RolePermissions.GetAll()
                        join p in Uow.Permissions.GetAll() on rp.PermissionId equals p.PermissionId
                        where rp.SystemRoleId == roleId && p.IsActive
                        select p.PermissionKey)
                       .ToHashSet(StringComparer.OrdinalIgnoreCase);

            _cache.Set(cacheKey, keys, new MemoryCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = CacheDuration
            });

            return keys;
        }

        public ICollection<PermissionGroup> GetGroupedByRole(int roleId)
        {
            var allPermissions = Uow.Permissions.GetAll()
                .Where(p => p.IsActive)
                .OrderBy(p => p.SortOrder)
                .ToList();

            var grantedIds = Uow.RolePermissions.GetAll()
                .Where(rp => rp.SystemRoleId == roleId)
                .Select(rp => rp.PermissionId)
                .ToHashSet();

            return allPermissions
                .GroupBy(p => p.Module)
                .Select(g => new PermissionGroup
                {
                    Module = g.Key,
                    Permissions = g.Select(p => new PermissionNode
                    {
                        PermissionId = p.PermissionId,
                        PermissionKey = p.PermissionKey,
                        DisplayName = p.DisplayName,
                        PermissionType = p.PermissionType,
                        ParentPermissionId = p.ParentPermissionId,
                        SortOrder = p.SortOrder,
                        IsGranted = grantedIds.Contains(p.PermissionId)
                    }).ToList()
                })
                .ToList();
        }

        public void SaveRolePermissions(int roleId, List<int> permissionIds, int grantedBy)
        {
            var existing = Uow.RolePermissions.GetAll()
                .Where(rp => rp.SystemRoleId == roleId)
                .ToList();

            foreach (var rp in existing)
                Uow.RolePermissions.Remove(rp);

            foreach (var permId in permissionIds)
            {
                Uow.RolePermissions.Add(new RolePermission
                {
                    SystemRoleId = roleId,
                    PermissionId = permId,
                    GrantedBy = grantedBy
                });
            }

            Uow.Commit();
            InvalidateCache(roleId);
        }

        public ICollection<Permission> GetAll()
        {
            return Uow.Permissions.GetAll()
                .Where(p => p.IsActive)
                .OrderBy(p => p.SortOrder)
                .ToList();
        }

        public void InvalidateCache(int roleId)
        {
            _cache.Remove($"perm:{roleId}");
        }
    }
}

using KLS.Common;
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
        private const int ObfuscationKey = 48731;

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

        public ICollection<PermissionModuleDTO> GetGroupedByRole(int roleId)
        {
            var allPermissions = Uow.Permissions.GetAll()
                .Where(p => p.IsActive)
                .OrderBy(p => p.SortOrder)
                .ToList();

            var grantedIds = Uow.RolePermissions.GetAll()
                .Where(rp => rp.SystemRoleId == roleId)
                .Select(rp => rp.PermissionId)
                .ToHashSet();

            // Build resource display name map from 'resource'-type permissions
            var resourceDisplayMap = allPermissions
                .Where(p => p.PermissionType == "resource")
                .ToDictionary(
                    p => $"{p.Module}.{GetResourceKey(p)}",
                    p => new { p.DisplayName, p.SortOrder });

            // Group actionable permissions (page + button) by Module then Resource
            return allPermissions
                .Where(p => p.PermissionType == "page" || p.PermissionType == "button")
                .GroupBy(p => p.Module)
                .Select(moduleGroup => new PermissionModuleDTO
                {
                    Module = moduleGroup.Key,
                    Resources = moduleGroup
                        .GroupBy(p => GetResourceKey(p))
                        .Select(resGroup =>
                        {
                            var lookupKey = $"{moduleGroup.Key}.{resGroup.Key}";
                            var resourceInfo = resourceDisplayMap.GetValueOrDefault(lookupKey);
                            return new PermissionResourceDTO
                            {
                                Resource = resourceInfo?.DisplayName ?? resGroup.Key,
                                SortOrder = resourceInfo?.SortOrder ?? 0,
                                Actions = resGroup
                                    .OrderBy(p => p.SortOrder)
                                    .Select(p => new PermissionActionDTO
                                    {
                                        Id = EncodeId(p.PermissionId),
                                        DisplayName = p.DisplayName,
                                        IsGranted = grantedIds.Contains(p.PermissionId)
                                    }).ToList()
                            };
                        })
                        .OrderBy(r => r.SortOrder)
                        .ToList()
                })
                .ToList();
        }

        public void SaveRolePermissions(int roleId, List<string> permissionTokens)
        {
            // Decode opaque tokens to permission IDs
            var permissionIds = permissionTokens
                .Select(DecodeId)
                .Where(id => id > 0)
                .Distinct()
                .ToList();

            // Validate all IDs exist in the Permission table
            var validIds = Uow.Permissions.GetAll()
                .Where(p => p.IsActive && permissionIds.Contains(p.PermissionId))
                .Select(p => p.PermissionId)
                .ToHashSet();

            permissionIds = permissionIds.Where(id => validIds.Contains(id)).ToList();

            // Auto-include menu permissions for modules that have any granted action
            var grantedModules = Uow.Permissions.GetAll()
                .Where(p => p.IsActive && permissionIds.Contains(p.PermissionId))
                .Select(p => p.Module)
                .Distinct()
                .ToList();

            var menuPermissionIds = Uow.Permissions.GetAll()
                .Where(p => p.IsActive && p.PermissionType == "menu" && grantedModules.Contains(p.Module))
                .Select(p => p.PermissionId)
                .ToList();

            permissionIds.AddRange(menuPermissionIds);
            permissionIds = permissionIds.Distinct().ToList();

            // Remove existing and save new
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
                    GrantedBy = UserContext.EmpId
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

        private static string GetResourceKey(Permission p)
        {
            var parts = p.PermissionKey.Split('.');
            return parts.Length >= 2 ? parts[1] : p.PermissionKey;
        }

        private static string EncodeId(int permissionId)
            => Convert.ToBase64String(BitConverter.GetBytes(permissionId ^ ObfuscationKey));

        private static int DecodeId(string token)
        {
            try
            {
                return BitConverter.ToInt32(Convert.FromBase64String(token)) ^ ObfuscationKey;
            }
            catch
            {
                return 0;
            }
        }
    }
}

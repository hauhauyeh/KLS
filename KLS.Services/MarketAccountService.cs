using KLS.Common;
using KLS.Contract.Dtos;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class MarketAccountService : BaseService, IMarketAccountService
    {
        public MarketAccountService(IUnitOfWork uow) : base(uow) { }

        public IEnumerable<MarketAccountDto> GetAll()
        {
            return Uow.MarketAccounts.GetAll()
                .OrderByDescending(a => a.IsActive).ThenBy(a => a.AccountName)
                .ToList()
                .Select(ToDto);
        }

        public IEnumerable<MarketAccountDto> GetActive()
        {
            return Uow.MarketAccounts.Find(a => a.IsActive)
                .OrderBy(a => a.AccountName)
                .ToList()
                .Select(ToDto);
        }

        public MarketAccountDto? GetById(int id)
        {
            var account = Uow.MarketAccounts.GetById(id);
            return account == null ? null : ToDto(account);
        }

        public bool NameExists(string accountName, int excludeId = 0)
        {
            return Uow.MarketAccounts.Exists(a => a.AccountName == accountName && a.MarketAccountId != excludeId);
        }

        public MarketAccountDto Save(MarketAccountSaveReq req)
        {
            MarketAccount account;

            if (req.MarketAccountId == 0)
            {
                account = new MarketAccount
                {
                    MarketType = req.MarketType,
                    AccountName = req.AccountName,
                    StoreCode = req.StoreCode,
                    RegionCode = req.RegionCode,
                    ApiBaseUrl = req.ApiBaseUrl,
                    Notes = req.Notes,
                    IsActive = req.IsActive,
                };
                if (!string.IsNullOrEmpty(req.SettingsJson))
                    account.SettingsJson = CredentialEncryptor.Encrypt(req.SettingsJson);
                Uow.MarketAccounts.Add(account);
            }
            else
            {
                account = Uow.MarketAccounts.GetById(req.MarketAccountId);
                if (account == null) throw new Exception("Market account not found");
                account.MarketType = req.MarketType;
                account.AccountName = req.AccountName;
                account.StoreCode = req.StoreCode;
                account.RegionCode = req.RegionCode;
                account.ApiBaseUrl = req.ApiBaseUrl;
                account.Notes = req.Notes;
                account.IsActive = req.IsActive;
                if (!string.IsNullOrEmpty(req.SettingsJson))
                    account.SettingsJson = CredentialEncryptor.Encrypt(req.SettingsJson);
                account.UpdatedAt = DateTime.UtcNow;
                Uow.MarketAccounts.Update(account);
            }
            Uow.Commit();
            return ToDto(account);
        }

        public string? DecryptSettings(int id)
        {
            var account = Uow.MarketAccounts.GetById(id);
            if (string.IsNullOrEmpty(account?.SettingsJson)) return null;
            return CredentialEncryptor.Decrypt(account.SettingsJson);
        }

        public void Delete(int id)
        {
            Uow.MarketAccounts.RemoveById(id);
            Uow.Commit();
        }

        public void ToggleActive(int id)
        {
            var account = Uow.MarketAccounts.GetById(id);
            if (account == null) return;
            account.IsActive = !account.IsActive;
            account.UpdatedAt = DateTime.UtcNow;
            Uow.MarketAccounts.Update(account);
            Uow.Commit();
        }

        private static bool HasActiveWebhooks(MarketAccount a)
        {
            if (!string.Equals(a.MarketType, "ShipStation", StringComparison.OrdinalIgnoreCase))
                return false;
            if (string.IsNullOrEmpty(a.SettingsJson))
                return false;
            try
            {
                var settings = ShipStationSettings.FromEncrypted(a.SettingsJson);
                return settings.OrderNotifyWebhookId.HasValue || settings.ShipNotifyWebhookId.HasValue;
            }
            catch
            {
                return false;
            }
        }

        private static MarketAccountDto ToDto(MarketAccount a)
        {
            return new MarketAccountDto
            {
                MarketAccountId = a.MarketAccountId,
                MarketType = a.MarketType,
                AccountName = a.AccountName,
                StoreCode = a.StoreCode,
                RegionCode = a.RegionCode,
                ApiBaseUrl = a.ApiBaseUrl,
                HasCredentials = !string.IsNullOrEmpty(a.SettingsJson),
                IsActive = a.IsActive,
                LastSyncAt = a.LastSyncAt,
                LastSyncStatus = a.LastSyncStatus,
                LastError = a.LastError,
                Notes = a.Notes,
                CreatedAt = a.CreatedAt,
                UpdatedAt = a.UpdatedAt,
                HasWebhookSubscription = HasActiveWebhooks(a),
            };
        }
    }
}

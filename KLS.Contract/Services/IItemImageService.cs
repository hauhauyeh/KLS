using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IItemImageService
    {
        IEnumerable<ItemImageList>? GetList(int itemId);

        ItemImageList? GetPrimary(int itemId);

        void Upload(ImageUploadReq uploadReq);

        void Delete(int imageId);

        Task<ImageProcessResult> ProcessBgLocal(int imageId);

        Task<ImageProcessResult> ProcessBgApi(int imageId);

        Task Finalize(ImageFinalizeReq req);

        MigrationResult MigrateLegacyImages(string sourceFolder, bool dryRun = false, int limit = 0);

        MigrationResult BackfillVersionFlags();
    }
}

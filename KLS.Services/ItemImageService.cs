using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ItemImageService : BaseService, IItemImageService
    {
        private readonly IWebHostEnvironment _env;
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ItemImageService(IUnitOfWork uow, IWebHostEnvironment env, IHttpContextAccessor httpContextAccessor) : base(uow)
        {
            _env = env;
            _httpContextAccessor = httpContextAccessor;
        }

        public IEnumerable<ItemImageList>? GetList(int itemId)
        {
            var request = _httpContextAccessor.HttpContext?.Request;

            string baseUrl = "";
            if (request != null)
                baseUrl = $"{request.Scheme}://{request.Host}";

            var images = Uow.ItemImages
                .Find(c => c.ItemId == itemId)
                .OrderBy(c => c.SortOrder)
                .Select(c => new ItemImageList
                {
                    ImageId = c.ImageId,
                    ItemId = c.ItemId,
                    RelativeUrl = string.IsNullOrEmpty(c.RelativePath)
                        ? null
                        : baseUrl + c.RelativePath,
                    ThumbnailUrl = string.IsNullOrEmpty(c.ThumbnailPath)
                        ? null
                        : baseUrl + c.ThumbnailPath,
                    SortOrder = c.SortOrder,
                    IsPrimary = c.IsPrimary
                })
                .ToList();

            return images;
        }

        public ItemImageList? GetPrimary(int itemId)
        {
            return GetList(itemId)?.Where(c => c.IsPrimary).FirstOrDefault();
        }

        public ItemImage GetById(int imageId)
        {
            return Uow.ItemImages.GetById(imageId);
        }

        public void Upload(ImageUploadReq uploadReq)
        {
            var imagesFolder = Path.Combine(_env.WebRootPath, "Images", "items");
            var thumbsFolder = Path.Combine(_env.WebRootPath, "Images", "items", "thumbnails");

            Directory.CreateDirectory(imagesFolder);
            Directory.CreateDirectory(thumbsFolder);

            // Load current DB images for item (after any immediate deletes)
            var dbImages = Uow.ItemImages
                .Find(x => x.ItemId == uploadReq.ItemId)
                .ToList();

            var order = uploadReq.Order ?? new List<int>();
            var files = uploadReq.files ?? new List<IFormFile>();

            // If UI didn’t send order, fallback: keep DB order + append new at end
            if (order.Count == 0)
            {
                order = dbImages.OrderBy(x => x.SortOrder).Select(x => x.ImageId).ToList();
                // append zeros for all new files
                for (int i = 0; i < files.Count; i++) order.Add(0);
            }

            int zeroCount = order.Count(x => x == 0);
            if (zeroCount != files.Count)
                throw new Exception("Order placeholders (0) count must match uploaded files count.");

            // Validate all ids in order belong to this item
            var validIds = dbImages.Select(x => x.ImageId).ToHashSet();
            if (order.Any(id => id > 0 && !validIds.Contains(id)))
                throw new Exception("Invalid image id found in order list for this item.");

            // Decide primary index
            int primaryIndex;
            if (uploadReq.PrimaryOrderIndex.HasValue &&
                uploadReq.PrimaryOrderIndex.Value >= 0 &&
                uploadReq.PrimaryOrderIndex.Value < order.Count)
            {
                primaryIndex = uploadReq.PrimaryOrderIndex.Value;
            }
            else
            {
                // If not provided: keep existing primary if still present; otherwise first item is primary
                var existingPrimary = dbImages.FirstOrDefault(x => x.IsPrimary);
                if (existingPrimary != null)
                {
                    int idx = order.FindIndex(x => x == existingPrimary.ImageId);
                    primaryIndex = idx >= 0 ? idx : 0;
                }
                else
                {
                    primaryIndex = 0;
                }
            }

            // Clear primary for all existing DB images (primary will be set by final state)
            foreach (var img in dbImages.Where(x => x.IsPrimary))
            {
                img.IsPrimary = false;
                Uow.ItemImages.Update(img);
            }
            Uow.Commit();

            int fileCursor = 0;

            // Apply final order (existing + new) in one pass
            for (int i = 0; i < order.Count; i++)
            {
                int sort = i + 1;
                bool isPrimary = (i == primaryIndex);

                if (order[i] > 0)
                {
                    // Existing DB image
                    int id = order[i];
                    var entity = dbImages.First(x => x.ImageId == id);

                    bool changed = false;

                    if (entity.SortOrder != sort)
                    {
                        entity.SortOrder = sort;
                        changed = true;
                    }

                    if (entity.IsPrimary != isPrimary)
                    {
                        entity.IsPrimary = isPrimary;
                        changed = true;
                    }

                    if (changed)
                        Uow.ItemImages.Update(entity);

                    continue;
                }

                // New file placeholder -> insert + save file
                var file = files[fileCursor++];
                var entityNew = new ItemImage
                {
                    ItemId = uploadReq.ItemId,
                    SortOrder = sort,
                    IsPrimary = isPrimary,
                    FileName = null,
                    RelativePath = null,
                    ThumbnailPath = null
                };

                Uow.ItemImages.Add(entityNew);
                Uow.Commit(); // generate ImageId for filename

                var fileName = $"{entityNew.ImageId}.webp";
                var imageFullPath = Path.Combine(imagesFolder, fileName);

                try
                {
                    using (var image = Image.Load(file.OpenReadStream()))
                    {
                        image.Save(imageFullPath, new WebpEncoder { Quality = 75 });
                    }

                    var thumbFileName = $"thumb_{entityNew.ImageId}.webp";
                    var thumbFullPath = Path.Combine(thumbsFolder, thumbFileName);

                    using (var thumbImage = Image.Load(imageFullPath))
                    {
                        thumbImage.Mutate(x => x.Resize(new ResizeOptions
                        {
                            Mode = ResizeMode.Max,
                            Size = new Size(300, 300)
                        }));

                        thumbImage.Save(thumbFullPath, new WebpEncoder { Quality = 75 });
                    }

                    entityNew.FileName = fileName;
                    entityNew.RelativePath = $"/Images/items/{fileName}";
                    entityNew.ThumbnailPath = $"/Images/items/thumbnails/{thumbFileName}";

                    Uow.ItemImages.Update(entityNew);
                    Uow.Commit();
                }
                catch
                {
                    Uow.ItemImages.Remove(entityNew);
                    Uow.Commit();

                    if (File.Exists(imageFullPath)) File.Delete(imageFullPath);

                    var maybeThumb = Path.Combine(thumbsFolder, $"thumb_{entityNew.ImageId}.webp");
                    if (File.Exists(maybeThumb)) File.Delete(maybeThumb);

                    throw;
                }
            }

            // Final commit for any pending updates to existing images
            Uow.Commit();
        }

        public void Delete(int imageId)
        {
            var image = GetById(imageId);

            // 1️ Delete physical image
            if (!string.IsNullOrEmpty(image.RelativePath))
            {
                var imagePath = Path.Combine(_env.WebRootPath, image.RelativePath.TrimStart('/'));
                if (File.Exists(imagePath))
                    File.Delete(imagePath);
            }

            // 2️ Delete thumbnail
            if (!string.IsNullOrEmpty(image.ThumbnailPath))
            {
                var thumbPath = Path.Combine(_env.WebRootPath, image.ThumbnailPath.TrimStart('/'));
                if (File.Exists(thumbPath))
                    File.Delete(thumbPath);
            }

            // 3️ Remove from DB
            Uow.ItemImages.Remove(image);

            // 4️ If deleted image was primary → assign new primary
            if (image.IsPrimary)
            {
                var nextImage = Uow.ItemImages.Find(c => c.ImageId != imageId).OrderBy(c => c.SortOrder).FirstOrDefault();

                if (nextImage != null)
                {
                    nextImage.IsPrimary = true;
                    Uow.ItemImages.Update(nextImage);
                }
            }

            Uow.Commit();
        }

        public void UpdateSort(ItemImageSortReq req)
        {
            if (req.OrderedImageIds == null || req.OrderedImageIds.Count == 0)
                return;

            // Load all images for this item
            var images = Uow.ItemImages
                .Find(x => x.ItemId == req.ItemId)
                .ToList();

            if (images.Count == 0)
                return;

            // Validate: all ids must belong to this item
            var validIds = images.Select(x => x.ImageId).ToHashSet();
            if (req.OrderedImageIds.Any(id => !validIds.Contains(id)))
                throw new Exception("Invalid image id found for this item.");

            // Update SortOrder based on incoming order
            for (int i = 0; i < req.OrderedImageIds.Count; i++)
            {
                int id = req.OrderedImageIds[i];
                var img = images.First(x => x.ImageId == id);
                img.SortOrder = i + 1;
                Uow.ItemImages.Update(img);
            }

            Uow.Commit();
        }

        public void SetPrimary(int imageId)
        {
            var selected = Uow.ItemImages.GetById(imageId);
            if (selected == null)
                throw new Exception("Image not found.");

            // Get all images for the same item
            var images = Uow.ItemImages
                .Find(x => x.ItemId == selected.ItemId)
                .ToList();

            // Set all false
            foreach (var img in images)
            {
                bool shouldBePrimary = img.ImageId == imageId;
                if (img.IsPrimary != shouldBePrimary)
                {
                    img.IsPrimary = shouldBePrimary;
                    Uow.ItemImages.Update(img);
                }
            }

            Uow.Commit();
        }
    }
}

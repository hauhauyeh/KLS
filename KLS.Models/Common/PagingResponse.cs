using System;
using System.Collections.Generic;
using System.Linq;

namespace KLS.Models
{
    public class PagingResponse<T>
    {
        private const int DefaultPageSize = 50;
        private const int MaxPagesToShow = 10;

        public PagingResponse(int totalRecords, int pageNo = 1, int pageSize = DefaultPageSize)
        {
            int maxPages = 10;

            // calculate total pages
            var totalPages = (int)Math.Ceiling((decimal)totalRecords / (decimal)pageSize);

            // ensure current page isn't out of range
            if (pageNo < 1)
            {
                pageNo = 1;
            }
            else if (pageNo > totalPages)
            {
                pageNo = totalPages;
            }

            int startPage, endPage;
            if (totalPages <= maxPages)
            {
                // total pages less than max so show all pages
                startPage = 1;
                endPage = totalPages;
            }
            else
            {
                // total pages more than max so calculate start and end pages
                var maxPagesBeforeCurrentPage = (int)Math.Floor((decimal)maxPages / (decimal)2);
                var maxPagesAfterCurrentPage = (int)Math.Ceiling((decimal)maxPages / (decimal)2) - 1;
                if (pageNo <= maxPagesBeforeCurrentPage)
                {
                    // current page near the start
                    startPage = 1;
                    endPage = maxPages;
                }
                else if (pageNo + maxPagesAfterCurrentPage >= totalPages)
                {
                    // current page near the end
                    startPage = totalPages - maxPages + 1;
                    endPage = totalPages;
                }
                else
                {
                    // current page somewhere in the middle
                    startPage = pageNo - maxPagesBeforeCurrentPage;
                    endPage = pageNo + maxPagesAfterCurrentPage;
                }
            }

            // calculate start and end item indexes
            var startIndex = (pageNo - 1) * pageSize + 1;
            var endIndex = Math.Min(startIndex + pageSize - 1, totalRecords);

            // create an array of pages that can be looped over
            var pages = Enumerable.Range(startPage, (endPage + 1) - startPage);

            // update object instance with all pager properties required by the view
            TotalRows = totalRecords;
            PageNo = pageNo;
            PageSize = pageSize;
            TotalPages = totalPages;
            StartPage = startPage;
            EndPage = endPage;
            StartIndex = startIndex;
            EndIndex = endIndex;
            Pages = pages;
        }


        public int TotalRows { get; }
        public int PageNo { get; }
        public int PageSize { get; }
        public int TotalPages { get; }
        public int StartPage { get; private set; }
        public int EndPage { get; private set; }
        public int StartIndex { get; private set; }
        public int EndIndex { get; private set; }
        public IEnumerable<int> Pages { get; private set; }
        public IEnumerable<T>? RowData { get; set; }
    }
}

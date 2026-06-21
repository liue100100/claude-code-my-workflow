options(timeout = 60)

# Fetch the DATA directory listing for 202408 and look for BIDPEROFFER-related files
url_dir <- paste0(
  "https://nemweb.com.au/Data_Archive/Wholesale_Electricity/MMSDM/2024/",
  "MMSDM_2024_08/MMSDM_Historical_Data_SQLLoader/DATA/"
)
tmp <- tempfile(fileext = ".html")
suppressWarnings(try(download.file(url_dir, tmp, mode = "wb", quiet = TRUE), silent = TRUE))

if (file.exists(tmp) && file.info(tmp)$size > 100) {
  txt  <- readLines(tmp, warn = FALSE)
  hits <- grep("BIDPEROFFER|BIDOFFERPERIOD|BIDDAYOFFER|DUDETAILSUMMARY|DISPATCHPRICE", txt,
               value = TRUE, ignore.case = TRUE)
  if (length(hits)) {
    cat("=== 202408 BID/DUID/DISPATCH entries ===\n")
    # extract just the filename + size from HTML anchors
    for (h in hits) {
      m <- regmatches(h, gregexpr("[0-9]+ <A HREF[^>]+>[^<]+</A>", h))[[1]]
      if (length(m)) cat(gsub('<[^>]+>', '', m), "\n", sep = "  ")
    }
  }
} else {
  cat("Could not fetch directory listing\n")
}
unlink(tmp)

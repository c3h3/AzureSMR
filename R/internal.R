extractUrlArguments <- function(x) {
  ptn <- ".*\\?(.*?)"
  args <- grepl("\\?", x)
  z <- if (args) gsub(ptn, "\\1", x) else ""
  if (z == "") {
    ""
  } else {
    z <- strsplit(z, "&")[[1]]
    z <- sort(z)
    z <- paste(z, collapse = "\n")
    z <- gsub("=", ":", z)
    paste0("\n", z)
  }
}

callAzureStorageApi <- function(url, verb = "GET", storageKey, storageAccount,
                   headers = NULL, container = NULL, CMD, size = nchar(content), contenttype = NULL,
                   content = NULL,
                   verbose = FALSE) {
  dateStamp <- format(Sys.time(), "%a, %d %b %Y %H:%M:%S %Z", tz = "GMT")

  verbosity <- if (verbose) httr::verbose(TRUE) else NULL

  if (missing(CMD) || is.null(CMD)) CMD <- extractUrlArguments(url)

    sig <- createAzureStorageSignature(url = URL, verb = verb,
      key = storageKey, storageAccount = storageAccount, container = container,
      headers = headers, CMD = CMD, size = size,
      contenttype = contenttype, dateStamp = dateStamp, verbose = verbose)

  at <- paste0("SharedKey ", storageAccount, ":", sig)

  switch(verb, 
  "GET" = GET(url, add_headers(.headers = c(Authorization = at,
                                    `Content-Length` = "0",
                                    `x-ms-version` = "2015-04-05",
                                    `x-ms-date` = dateStamp)
                                    ),
    verbosity),
  "PUT" = PUT(url, add_headers(.headers = c(Authorization = at,
                                         `Content-Length` = nchar(content),
                                         `x-ms-version` = "2015-04-05",
                                         `x-ms-date` = dateStamp,
                                         `x-ms-blob-type` = "Blockblob",
                                         `Content-type` = "text/plain; charset=UTF-8")),
           body = content,
    verbosity)
  )
}


createAzureStorageSignature <- function(url, verb, 
  key, storageAccount, container = NULL,
  headers = NULL, CMD = NULL, size = NULL, contenttype = NULL, dateStamp, verbose = FALSE) {

  if (missing(dateStamp)) {
    dateStamp <- format(Sys.time(), "%a, %d %b %Y %H:%M:%S %Z", tz = "GMT")
  }

  arg1 <- if (length(headers)) {
    paste0(headers, "\nx-ms-date:", dateStamp, "\nx-ms-version:2015-04-05")
  } else {
    paste0("x-ms-date:", dateStamp, "\nx-ms-version:2015-04-05")
  }

  arg2 <- paste0("/", storageAccount, "/", container, CMD)

  SIG <- paste0(verb, "\n\n\n", size, "\n\n", contenttype, "\n\n\n\n\n\n\n",
                   arg1, "\n", arg2)
  if (verbose) message(paste0("TRACE: STRINGTOSIGN: ", SIG))
  base64encode(hmac(key = base64decode(key),
                    object = iconv(SIG, "ASCII", to = "UTF-8"),
                    algo = "sha256",
                    raw = TRUE)
                   )
}



getSig <- function(azureActiveContext, url, verb, key, storageAccount,
                   headers = NULL, container = NULL, CMD = NULL, size = NULL, contenttype = NULL,
                   dateSig, verbose = FALSE) {

  if (missing(dateSig)) {
    dateSig <- format(Sys.time(), "%a, %d %b %Y %H:%M:%S %Z", tz = "GMT")
  }

  arg1 <- if (length(headers)) {
    paste0(headers, "\nx-ms-date:", dateSig, "\nx-ms-version:2015-04-05")
  } else {
    paste0("x-ms-date:", dateSig, "\nx-ms-version:2015-04-05")
  }

  arg2 <- paste0("/", storageAccount, "/", container, CMD)

  SIG <- paste0(verb, "\n\n\n", size, "\n\n", contenttype, "\n\n\n\n\n\n\n",
                   arg1, "\n", arg2)
  if (verbose) message(paste0("TRACE: STRINGTOSIGN: ", SIG))
  base64encode(hmac(key = base64decode(key),
                    object = iconv(SIG, "ASCII", to = "UTF-8"),
                    algo = "sha256",
                    raw = TRUE)
                   )
  }


stopWithAzureError <- function(r){

  msg <- paste0(as.character(sys.call(1))[1], "()") # Name of calling fucntion
  addToMsg <- function(x){
    if(is.null(x)) x else paste(msg, x, sep = "\n")
  }
  if(inherits(content(r), "xml_document")){
    rr <- XML::xmlToList(XML::xmlParse(content(r)))
    msg <- addToMsg(rr$Code)
    msg <- addToMsg(rr$Message)
  } else {
    rr <- content(r)
    msg <- addToMsg(rr$code)
    msg <- addToMsg(rr$message)
  }
  msg <- addToMsg(paste0("Return code: ", status_code(r)))
  stop(msg, call. = FALSE)
}

extractResourceGroupname <- function(x) gsub(".*?/resourceGroups/(.*?)(/.*)*$",  "\\1", x)
extractSubscriptionID    <- function(x) gsub(".*?/subscriptions/(.*?)(/.*)*$",   "\\1", x)
extractStorageAccount    <- function(x) gsub(".*?/storageAccounts/(.*?)(/.*)*$", "\\1", x)

refreshStorageKey <- function(azureActiveContext, storageAccount, resourceGroup){
  if (length(azureActiveContext$storageAccountK) < 1 ||
      storageAccount != azureActiveContext$storageAccountK ||
      length(azureActiveContext$storageKey) <1
  ) {
    message("Fetching Storage Key..")
    azureSAGetKey(azureActiveContext, resourceGroup = resourceGroup, storageAccount = storageAccount)
  } else {
    azureActiveContext$storageKey
  }
}


updateAzureActiveContext <- function(x, storageAccount, storageKey, resourceGroup, container, blob, directory) {
  # updates the active azure context in place
  if (!is.azureActiveContext(x)) return(FALSE)
  if (!missing(storageAccount)) x$storageAccount <- storageAccount
  if (!missing(resourceGroup))  x$resourceGroup  <- resourceGroup
  if (!missing(storageKey))     x$storageKey     <- storageKey
  if (!missing(container)) x$container <- container
  if (!missing(blob)) x$blob <- blob
  if (!missing(directory)) x$directory <- directory
  TRUE
}

validateStorageArguments <- function(resourceGroup, storageAccount, container, storageKey) {
  msg <- character(0)
  pasten <- function(x, ...) paste(x, ..., collapse = "", sep = "\n")
  if (!missing(resourceGroup) && (is.null(resourceGroup) || length(resourceGroup) == 0)) {
    msg <- pasten(msg, "- No resourceGroup provided. Use resourceGroup argument or set in AzureContext")
  }
  if (!missing(storageAccount) && (is.null(storageAccount) || length(storageAccount) == 0)) {
    msg <- pasten(msg, "- No storageAccount provided. Use storageAccount argument or set in AzureContext")
  }
  if (!missing(container) && (is.null(container) || length(container) == 0)) {
    msg <- pasten(msg, "- No container provided. Use container argument or set in AzureContext")
  }
  if (!missing(storageKey) && (is.null(storageKey) || length(storageKey) == 0)) {
    msg <- pasten(msg, "- No storageKey provided. Use storageKey argument or set in AzureContext")
  }

  if (length(msg) > 0) {
    stop(msg, call. = FALSE)
  }
  msg
}

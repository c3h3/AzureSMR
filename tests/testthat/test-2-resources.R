if(interactive()) library("testthat")


settingsfile <- system.file("tests/testthat/config.json", package = "AzureSMR")
config <- read.AzureSMR.config(settingsfile)

#  ------------------------------------------------------------------------

context("Azure resources")

asc <- createAzureContext()
with(config,
     setAzureContext(asc, tenantID = tenantID, clientID = clientID, authKey = authKey)
)
azureAuthenticate(asc)


timestamp          <- format(Sys.time(), format = "%y%m%d%H%M")
resourceGroup_name <- paste0("_AzureSMtest_", timestamp)
sa_name            <- paste0("azuresmr", timestamp)


test_that("Can connect to azure resources", {
  skip_if_missing_config(settingsfile)

  res <- azureListAllResources(asc)
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 7)

  expect_error(AzureListAllRecources(asc)) # Deprecated function

  res <- azureListAllResources(asc)
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 7)

  res <- azureListRG(asc)
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 4)
})


test_that("Can create resource group", {
  skip_if_missing_config(settingsfile)

  res <- azureCreateResourceGroup(asc, location = "westeurope", resourceGroup = resourceGroup_name)
  expect_equal(res, "Create Request Submitted")

  wait_for_azure(
    resourceGroup_name %in% azureListRG(asc)$resourceGroup
  )
  expect_true(resourceGroup_name %in% azureListRG(asc)$resourceGroup)
})


test_that("Can connect to storage account", {
  skip_if_missing_config(settingsfile)

  res <- azureListSA(asc)
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 8)

  #sub_id  <<- res$storageAccount[1]
  #rg_temp <<- res$resourceGroup[1]
  #res <- azureSAGetKey(asc, storageAccount = sub_id, resourceGroup = rg_temp)
  #expect_is(res, "character")
})

test_that("Can create storage account", {
  skip_if_missing_config(settingsfile)

  res <- azureCreateStorageAccount(asc, storageAccount = sa_name, resourceGroup = resourceGroup_name)
  if(res == "Account already exists with the same name") skip("Account already exists with the same name")
  expect_equal(res, TRUE)

  wait_for_azure(
    sa_name %in% sort(azureListSA(asc)$storageAccount)
  )
  expect_true(sa_name %in% azureListSA(asc)$storageAccount)
})

test_that("Can connect to container", {
  skip_if_missing_config(settingsfile)
  sa <- azureListSA(asc)[1, ]
  res <- azureListStorageContainers(asc, storageAccount = sa$storageAccount[1],
                                    resourceGroup = sa$resourceGroup[1])
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 5)
  expect_equal(nrow(res), 0)
})

test_that("Can create container", {
  skip_if_missing_config(settingsfile)
  res <- azureCreateStorageContainer(asc, container = "tempcontainer")
  expect_true(grepl("OK", res))

  Sys.sleep(1)

  res <- azureListStorageContainers(asc)
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 5)

  expect_true("tempcontainer" %in% azureListStorageContainers(asc))

})

test_that("Can put, list, get and delete a blob", {
  skip_if_missing_config(settingsfile)
expect_warning({
  res <- azureListStorageBlobs(asc, container = "tempcontainer")
})
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 5)
  expect_equal(nrow(res), 0)

  res <- azurePutBlob(asc, blob = "iris", contents = "iris", container = "tempcontainer")
  expect_true(res)
  res <- azurePutBlob(asc, blob = "foo", contents = "foo", container = "tempcontainer")
  expect_true(res)

  res <- azureListStorageBlobs(asc, container = "tempcontainer")
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 5)
  expect_equal(nrow(res), 2)
  expect_equal(res$name, c("foo", "iris"))

  res <- azureDeleteBlob(asc, blob = "foo", container = "tempcontainer")
  res <- azureDeleteBlob(asc, blob = "iris", container = "tempcontainer")

  expect_warning({
    res <- azureListStorageBlobs(asc, container = "tempcontainer")
  }, "container is empty")
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 5)
  expect_equal(nrow(res), 0)

})


test_that("Can delete a container", {
  skip_if_missing_config(settingsfile)

  res <- azureListStorageContainers(asc)
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 5)
  expect_equal(nrow(res), 1)

  res <- azureDeleteStorageContainer(asc, container = "tempcontainer")
  expect_equal(res,  "container delete request accepted")

  res <- azureListStorageContainers(asc)
  expect_is(res, "data.frame")
  expect_equal(ncol(res), 5)
  expect_equal(nrow(res), 0)


})


test_that("Can delete storage account", {
  skip_if_missing_config(settingsfile)

  res <- azureDeletestorageAccount(asc, storageAccount = sa_name, resourceGroup = resourceGroup_name)
  expect_equal(res, TRUE)
  wait_for_azure(
    !(sa_name %in% azureListSA(asc)$storageAccount)
  )
  expect_false(sa_name %in% sort(azureListSA(asc)$storageAccount))
})

test_that("Can delete resource group", {
  skip_if_missing_config(settingsfile)

  res <- azureDeleteResourceGroup(asc, resourceGroup = resourceGroup_name)
  expect_equal(res, "Delete Request Submitted")
  wait_for_azure(
    !(resourceGroup_name %in% azureListRG(asc)$resourceGroup)
  )
  expect_false(resourceGroup_name %in% sort(azureListRG(asc)$resourceGroup))

})




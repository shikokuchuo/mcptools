test_that("mcp_tools works", {
  skip_if_not_installed("withr")
  skip_if(identical(Sys.getenv("GITHUB_PAT"), ""))
  skip_on_os(c("windows", "mac"))

  tmp_file <- withr::local_tempfile()

  # example configuration: official GitHub MCP server
  config <- list(
    mcpServers = list(
      github = list(
        command = "docker",
        args = c(
          "run",
          "-i",
          "--rm",
          "-e",
          "GITHUB_PERSONAL_ACCESS_TOKEN",
          "ghcr.io/github/github-mcp-server"
        ),
        env = list(GITHUB_PERSONAL_ACCESS_TOKEN = Sys.getenv("GITHUB_PAT"))
      )
    )
  )
  writeLines(jsonlite::toJSON(config), tmp_file)
  withr::local_options(.mcptools_config = tmp_file)

  res <- mcp_tools()
  expect_type(res, "list")
  expect_true(all(vapply(res, inherits, logical(1), "ellmer::ToolDef")))

  skip_if(identical(Sys.getenv("ANTHROPIC_API_KEY"), ""))
  ch <- ellmer::chat_openai("Be terse", model = "gpt-4.1-mini-2025-04-14")
  ch$set_tools(res)
  ch$chat("How many issues are there open on posit-dev/mcptools?")
  turns <- ch$get_turns()
  last_user_turn <- turns[[length(turns) - 1]]
  expect_true(inherits(
    last_user_turn@contents[[1]],
    "ellmer::ContentToolResult"
  ))
  expect_null(last_user_turn@contents[[1]]@error)
})

test_that("mcp_client_config() uses option when available", {
  withr::local_options(.mcptools_config = "/option/path")
  expect_equal(mcp_client_config(), "/option/path")
})

test_that("mcp_client_config() uses default when no option set", {
  withr::local_options(.mcptools_config = NULL)
  expect_equal(mcp_client_config(), default_mcp_client_config())
})

test_that("mcp_tools() errors informatively when file doesn't exist", {
  expect_snapshot(mcp_tools("nonexistent/file/"), error = TRUE)
})

test_that("mcp_tools() errors informatively with invalid JSON", {
  tmp_file <- withr::local_tempfile()
  writeLines("invalid json", tmp_file)
  expect_snapshot(mcp_tools(tmp_file), error = TRUE)
})

test_that("mcp_tools() errors informatively without mcpServers entry", {
  tmp_file <- withr::local_tempfile()
  config <- list(otherField = "value")
  writeLines(jsonlite::toJSON(config), tmp_file)
  expect_snapshot(mcp_tools(tmp_file), error = TRUE)
})

test_that("mcp_tools() returns mcpServers when valid", {
  tmp_file <- withr::local_tempfile()
  config <- list(
    mcpServers = list(
      server1 = list(command = "test", args = c("arg1"))
    )
  )
  writeLines(jsonlite::toJSON(config), tmp_file)
  result <- read_mcp_config(tmp_file)
  expect_equal(result, config$mcpServers)
})

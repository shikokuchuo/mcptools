# nocov start
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @import rlang
## usethis namespace: end
NULL

utils::globalVariables(c("packageVersion", "setNames"))

.onLoad <- function(libname, pkgname) {
  the$socket_url <- switch(
    Sys.info()[["sysname"]],
    Linux = "abstract://mcptools-socket",
    Windows = "ipc://mcptools-socket",
    "ipc:///tmp/mcptools-socket"
  )
}
# nocov end

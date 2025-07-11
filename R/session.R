#' @rdname server
#' @export
mcp_session <- function() {
  # HACK: If a session is already available from another session via `.Rprofile`,
  # `mcp_session()` will be called again when the client runs the command
  # Rscript -e "mcptools::mcp_server()" and the existing session connection
  # will be wiped. Returning early in this case allows for the desired R
  # session to be running already before the client initiates the server.
  if (!interactive()) {
    return(invisible())
  }

  the$session_socket <- nanonext::socket("poly")
  i <- 1L
  while (i < 1024L) {
    # prevent indefinite loop
    nanonext::listen(
      the$session_socket,
      url = sprintf("%s%d", the$socket_url, i),
      fail = "none"
    ) ||
      break
    i <- i + 1L
  }
  the$session <- i

  schedule_handle_message_from_server()
}

handle_message_from_server <- function(data) {
  pipe <- nanonext::pipe_id(the$raio)
  schedule_handle_message_from_server()

  if (length(data) == 0) {
    return(
      nanonext::send_aio(
        the$session_socket,
        describe_session(),
        mode = "raw",
        pipe = pipe
      )
    )
  }

  if (data$method == "tools/call") {
    body <- execute_tool_call(data)
  } else {
    body <- jsonrpc_response(
      data$id,
      error = list(code = -32601, message = "Method not found")
    )
  }
  # cat("SEND:", to_json(body), "\n", sep = "", file = stderr())

  nanonext::send_aio(
    the$session_socket,
    to_json(body),
    mode = "raw",
    pipe = pipe
  )
}

as_tool_call_result <- function(data, result) {
  is_error <- FALSE
  if (inherits(result, "ellmer::ContentToolResult")) {
    is_error <- !is.null(result@error)
    result <- result@value %||% result@error
  }

  jsonrpc_response(
    data$id,
    list(
      content = list(
        list(
          type = "text",
          text = paste(result, collapse = "\n")
        )
      ),
      isError = is_error
    )
  )
}

schedule_handle_message_from_server <- function() {
  the$raio <- nanonext::recv_aio(the$session_socket, mode = "serial")
  promises::as.promise(the$raio)$then(handle_message_from_server)$catch(
    \(e) {
      # no op but ensures promise is never rejected
    }
  )
}

# Create a jsonrpc-structured response object.

# Given a vector or list, drop all the NULL items in it
drop_nulls <- function(x) {
  x[!vapply(x, is.null, FUN.VALUE = logical(1))]
}

# Enough information for the user to be able to identify which
# session is which when using `list_r_sessions()` (#18)
describe_session <- function() {
  sprintf("%d: %s (%s)", the$session, basename(getwd()), infer_ide())
}

infer_ide <- function() {
  first_cmd_arg <- commandArgs()[1]
  switch(
    first_cmd_arg,
    ark = "Positron",
    RStudio = "RStudio",
    first_cmd_arg
  )
}

# assign NULL for mocking in testing
basename <- NULL
getwd <- NULL
commandArgs <- NULL

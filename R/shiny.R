#' Open a live chat application
#'
#' @description
#'
#' * `live_console()` lets you chat interactively in the console.
#' * `live_browser()` lets you chat interactively in a browser.
#'
#' Note that these functions will mutate the input `chat` object as
#' you chat because your turns will be appended to the history.
#'
#' @param chat A chat object created by [chat_openai()] or friends.
#' @param quiet If `TRUE`, suppresses the initial message that explains how
#'   to use the console.
#' @export
#' @returns (Invisibly) The input `chat`.
live_console <- function(chat, quiet = FALSE) {
  if (!is_interactive()) {
    cli::cli_abort("The chat console is only available in interactive mode.")
  }

  if (!isTRUE(quiet)) {
    cli::cat_boxx(
      c(
        "Entering chat console. Use \"\"\" for multi-line input.",
        "Press Ctrl+C to quit."
      ),
      padding = c(0, 1, 0, 1),
      border_style = "double"
    )
  }

  tryCatch(
    repeat {
      # Prompt for user input
      user_input <- readline(prompt = ">>> ")

      if (!grepl("\\S", user_input)) {
        next
      }

      if (grepl('^\\s*"""', user_input)) {
        repeat {
          next_input <- readline(prompt = '... ')
          user_input <- paste0(user_input, "\n", next_input)
          if (grepl('"""\\s*$', next_input)) {
            break
          }
        }
        # Strip leading and trailing """, using regex
        user_input <- gsub('^\\s*"""\\s*', '', user_input)
        user_input <- gsub('\\s*"""\\s*$', '', user_input)
      }

      # Process the input using the provided LLM function
      chat$chat(user_input, echo = TRUE)
      cat("\n")
    },
    interrupt = function(cnd) NULL
  )

  invisible(chat)
}

#' @export
#' @rdname live_console
live_browser <- function(chat, quiet = FALSE) {
  check_installed(c("bslib", "shiny", "shinychat"))

  ui <- bslib::page_fillable(
    shinychat::chat_ui("chat", height = "100%"),
    shiny::actionButton(
      "close_btn", "",
      class = "btn-close",
      style = "position: fixed; top: 6px; right: 6px;"
    )
  )
  server <- function(input, output, session) {
    for (turn in chat$get_turns()) {
      shinychat::chat_append_message("chat", list(
        role = turn@role,
        content = turn@text
      ))
    }

    shiny::observeEvent(input$chat_user_input, {
      stream <- chat$stream_async(input$chat_user_input)
      shinychat::chat_append("chat", stream)
    })

    shiny::observeEvent(input$close_btn, {
      shiny::stopApp()
    })
  }

  if (!isTRUE(quiet)) {
    cli::cat_boxx(
      c("Entering interactive chat", "Press Ctrl+C to quit."),
      padding = c(0, 1, 0, 1),
      border_style = "double"
    )
  }

  tryCatch(
    shiny::runGadget(shiny::shinyApp(ui, server, options = list(quiet = TRUE))),
    interrupt = function(cnd) NULL
  )
  invisible(chat)
}

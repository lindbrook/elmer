
<!-- README.md is generated from README.Rmd. Please edit that file -->

# elmer

<!-- badges: start -->

[![R-CMD-check](https://github.com/hadley/elmer/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/hadley/elmer/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of elmer is to provide a user friendly wrapper over the most
common APIs for calling llm’s. Major design goals include support for
streaming and making it easy to register and call R functions.

## Installation

You can install the development version of elmer from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("hadley/elmer")
```

## Prerequisites

To use elmer, you need an OpenAI API key. You can get one from [your
developer console](https://platform.openai.com/account/api-keys). Then
you should save that value as the `OPENAI_API_KEY` environment variable
in your `~/.Renviron` (an easy way to open that file is to call
`usethis::use_renviron()`).

## Using elmer

You chat with elmer in several different ways, depending on whether you
are working interactively or programmatically. They all start with
creating a new chat object:

``` r
library(elmer)

chat <- new_chat_openai(
  model = "gpt-4o-mini",
  system_prompt = "You are a friendly but terse assistant."
)
```

Chat objects are stateful: they retain the context of the conversation,
so each new query can build on the previous ones. This is true
regardless of which of the various ways of chatting you use.

### Interactive chat console

The most interactive, least programmatic way of using elmer is to chat
with it directly in your R console.

    > chat$console()
    ╔════════════════════════════════════════════════════════╗
    ║  Entering chat console. Use """ for multi-line input.  ║
    ║  Press Ctrl+C to quit.                                 ║
    ╚════════════════════════════════════════════════════════╝
    >>> Who were the original creators of R?
    R was originally created by Ross Ihaka and Robert Gentleman at the University of
    Auckland, New Zealand.

    >>> When was that?
    R was initially released in 1995. Development began a few years prior to that,
    in the early 1990s.

The chat console is useful for quickly exploring the capabilities of the
model, especially when you’ve customized the chat object with tool
integrations (see below).

Again, keep in mind that the chat object retains state, so when you
enter the chat console, any previous interactions with that chat object
are still part of the conversation, and any interactions you have in the
chat console will persist even after you exit back to the R prompt.

### Interactive method call

The second most interactive way to chat using elmer is to call the
`chat()` method.

    > chat$chat("What preceding languages most influenced R?")
    R was primarily influenced by the S programming language, particularly S-PLUS.
    Other languages that had an impact include Scheme and various data analysis
    languages.

By default, the `chat` method streams the response to the console as it
arrives. When the entire response is received, it is returned as a
character vector (invisibly, so it’s not printed twice).

This mode is useful when you want to see the response as it arrives, but
you don’t want to enter the chat console.

### Programmatic chat

If you don’t want to see the response as it arrives, you can use the
`quiet` argument to suppress output. You can either pass `quiet=TRUE` as
an argument to `chat$chat()`, or as an argument to `new_chat_openai()`
if you want all interactions to be quiet by default.

**The remaining examples on this page will use a chat object created
with `quiet = TRUE`.**

    > chat <- new_chat_openai(
    +   model = "gpt-4o-mini",
    +   system_prompt = "You are a friendly but terse assistant.",
    +   quiet = TRUE
    + )
    > chat$chat("Is R a functional programming language?")
    [1] "Yes, R supports functional programming concepts. It allows functions to be first-class objects, supports higher-order functions, and encourages the use of functions as core components of code. However, it also supports procedural and object-oriented programming styles."

When called with `quiet=TRUE`, the `chat` method still returns the
entire response as a character vector, but without making it invisible.

This mode is useful for programming using elmer, when the result is
either not intended for human consumption or when you want to process
the response before displaying it.

### Streaming results

The `chat()` method does not return any results until the entire
response has been received. (It can *print* the streaming results to the
console, but it *returns* the result only when the response is
complete.)

If you want to process the response as it arrives, you can use the
`stream()` method. This may be useful when you want to display the
response in realtime, but somewhere other than the R console (like
writing to a file, or an HTTP response, or a Shiny chat window); or when
you want to manipulate the response before displaying it, without giving
up the immediacy of streaming.

The `stream()` method returns a
[generator](https://coro.r-lib.org/articles/generator.html) from the
[coro package](https://coro.r-lib.org/), which you can loop over to
process the response as it arrives.

    > stream <- chat$stream("What are some common uses of R?")
    > coro::loop(for (chunk in stream) {
    +   cat(toupper(chunk))
    + })
    R IS COMMONLY USED FOR:

    1. **STATISTICAL ANALYSIS**: PERFORMING COMPLEX STATISTICAL TESTS AND ANALYSES.
    2. **DATA VISUALIZATION**: CREATING GRAPHS, CHARTS, AND PLOTS USING PACKAGES LIKE GGPLOT2.
    3. **DATA MANIPULATION**: CLEANING AND TRANSFORMING DATA WITH PACKAGES LIKE DPLYR AND TIDYR.
    4. **MACHINE LEARNING**: BUILDING PREDICTIVE MODELS WITH LIBRARIES LIKE CARET AND RANDOMFOREST.
    5. **BIOINFORMATICS**: ANALYZING BIOLOGICAL DATA AND GENOMIC STUDIES.
    6. **ECONOMETRICS**: PERFORMING ECONOMIC DATA ANALYSIS AND MODELING.
    7. **REPORTING**: GENERATING DYNAMIC REPORTS AND DASHBOARDS WITH R MARKDOWN.
    8. **TIME SERIES ANALYSIS**: ANALYZING TEMPORAL DATA AND FORECASTING.

    THESE USES MAKE R A POWERFUL TOOL FOR DATA SCIENTISTS, STATISTICIANS, AND RESEARCHERS.

## Async usage (Advanced)

elmer also supports async usage, which is useful when you want to run
multiple chat sessions concurrently. This is primarily useful in Shiny
applications, where using the methods described above would block the
Shiny app for other users for the duration of each response.

To use async chat, instead of `chat()`/`stream()`, call
`chat_async()`/`stream_async()`. The `_async` variants take the same
arguments for construction, but return promises instead of the actual
response.

Remember that chat objects are stateful, maintaining the conversation
history as you interact with it. Note that this means it doesn’t make
sense to issue multiple chat/stream operations on the same chat object
concurrently, as the conversation history could become corrupted with
interleaved conversation fragments. If you need to run multiple chat
sessions concurrently, create multiple chat objects.

### Asynchronous chat

For asynchronous, non-streaming chat, you use the `chat()` method as
before, but handle the result as a promise instead of a string.

    > chat$chat_async("How's your day going?") %...>% print()
    >
    I'm just a computer program, so I don't have feelings, but I'm here to help you with any questions you have.

TODO: Shiny example

### Asynchronous streaming

For asynchronous streaming, you use the `stream()` method as before, but
the result is a [async
generator](https://coro.r-lib.org/reference/async_generator.html) from
the [coro package](https://coro.r-lib.org/). This is the same as a
regular [generator](https://coro.r-lib.org/articles/generator.html),
except instead of giving you strings, it gives you promises that resolve
to strings.

    > stream <- chat$stream_async("What are some common uses of R?")
    > coro::async(function() {
    +   for (chunk in await_each(stream)) {
    +     cat(toupper(chunk))
    +   }
    + })()
    <Promise [pending]>
    >
    R IS COMMONLY USED FOR:

    1. **STATISTICAL ANALYSIS**: PERFORMING VARIOUS STATISTICAL TESTS AND MODELS.
    2. **DATA VISUALIZATION**: CREATING PLOTS AND GRAPHS TO VISUALIZE DATA.
    3. **DATA MANIPULATION**: CLEANING AND TRANSFORMING DATA WITH PACKAGES LIKE DPLYR.
    4. **MACHINE LEARNING**: BUILDING PREDICTIVE MODELS AND ALGORITHMS.
    5. **BIOINFORMATICS**: ANALYZING BIOLOGICAL DATA, ESPECIALLY IN GENOMICS.
    6. **TIME SERIES ANALYSIS**: ANALYZING TEMPORAL DATA FOR TRENDS AND FORECASTS.
    7. **REPORT GENERATION**: CREATING DYNAMIC REPORTS WITH R MARKDOWN.
    8. **GEOSPATIAL ANALYSIS**: MAPPING AND ANALYZING GEOGRAPHIC DATA.

Async generators are very advanced, and require a good understanding of
asynchronous programming in R. They are also the only way to present
streaming results in Shiny without blocking other users. Fortunately,
Shiny will soon have chat components that will make this easier, where
you can simply hand the result of `stream_async()` to a chat output.

## Tool integrations

TODO

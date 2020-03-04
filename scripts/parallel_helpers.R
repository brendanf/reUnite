#### what is our logfile called?
get_logfile <- function(default) {
  if (interactive()) {
    return(file.path("logs", paste0(default, ".log")))
  } else if (exists("snakemake")) {
    return(file(snakemake@log[[1]], open = "at"))
  } else {
    return(file(file.path(Sys.getenv("LOGDIR"), paste0(default, ".log"))))
  }
}

#### Start logging ####
setup_log <- function(default) {
  logfile <- get_logfile(default)
  invisible(flog.appender(appender.tee(logfile)))
}

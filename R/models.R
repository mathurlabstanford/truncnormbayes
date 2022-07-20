#' Estimates the posterior modes for the parameters of the underlying normal
#' distribution, given truncated data
#'
#' @param x Vector of observations from truncated normal
#' @param mean_start Initial value for mu.
#' @param sd_start Initial value for sigma.
#' @param ci_level Number between 0.5 and 1. Gives a 100(ci_level)% confidence
#'   interval.
#' @param a Left truncation limit.
#' @param b Right truncation limit.
#' @param ... Parameters to pass to sampling()
#'
#' @export
#'
#' @examples
#' x <- truncnorm::rtruncnorm(100, a = 0, b = 2, mean = 0.5, sd = 0.5)
#' trunc_est(x, a = 0, b = 2)
#'
#' @references
#' https://mc-stan.org/rstan/reference/stanmodel-method-sampling.html
trunc_est <- function(x,
                      mean_start = 0,
                      sd_start = 1,
                      ci_level = 0.95,
                      a,
                      b,
                      ...) {
  stopifnot(a < b)
  stopifnot(sd_start > 0)
  stopifnot(all(x >= a))
  stopifnot(all(x <= b))

  # set start values for sampler
  init_fcn <- function() list(mean = mean_start, sd = sd_start)

  stan_fit <- rstan::sampling(stanmodels$trunc_est,
                              cores = 1,
                              init = init_fcn,
                              data = list(n = length(x), a = a, b = b, y = x),
                              ...)

  stan_extract <- rstan::extract(stan_fit)
  stan_summary <- as.data.frame(
    rstan::summary(stan_fit)$summary[c("mu", "sigma"), ]
  )
  means <- stan_summary$mean
  ses <- stan_summary$se_mean
  rhats <- stan_summary$Rhat

  medians <- c(median(stan_extract$mu), median(stan_extract$sigma))

  index_maxlp <- which.max(stan_extract$log_post)
  maxlps <- c(stan_extract$mu[index_maxlp], stan_extract$sigma[index_maxlp])

  stan_ci <- function(param, q) as.numeric(quantile(stan_extract[[param]], q))
  cil <- c(stan_ci("mu", 1 - ci_level), stan_ci("sigma", 1 - ci_level))
  ciu <- c(stan_ci("mu", ci_level), stan_ci("sigma", ci_level))

  stan_stats <- data.frame(param = c("mean", "sd"), mean = means,
                           median = medians, maxlp = maxlps, se = ses,
                           ci_lower = cil, ci_upper = ciu, rhat = rhats)

  return(list(stats = stan_stats, fit = stan_fit))
}
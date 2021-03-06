
# load packages
library(tidyverse)
library(forcats)

# set seed
set.seed(8764)

# set simulation paramters
n <- 100  # sample size
x <- rnorm(n)  # single explanatory variable
n_qi <- 100  # number of points at which to calculate the marginal effect
x0 <- seq(-3, 3, length.out = n_qi)  # points at which to calculate the marginal effect
beta <- c(-2, 1)  # true coefficients
lambda <- exp(beta[1] + beta[2]*x)  # implied mean
n_sims <- 10000  # number of mc simulations

# do the simulations
tau_hat_mle <- tau_hat_avg <- matrix(NA, nrow = n_sims, ncol = n_qi)  # holders
beta_hat <- matrix(NA, nrow = n_sims, ncol = length(beta))  # holder
for (i in 1:n_sims) {
  # simulate outcome
  y <- rpois(n, lambda = lambda)  
  # fit poisson regression
  fit <- glm(y ~ x, family = poisson)  
  # extract and store beta-hats
  beta_hat[i, ] <- coef(fit)
  # extract Sigma-hat
  Sigma_hat <- vcov(fit)  
  # simulate beta-tildes
  beta_tilde <- MASS::mvrnorm(1000, mu = beta_hat[i, ], Sigma = Sigma_hat)  
  # convert beta-hats to tau-hats
  tau_tilde <- t(exp(cbind(1, x0)%*%t(beta_tilde)))*beta_tilde[, 2]  
  # estimate the marginal effect as the average of simulations
  tau_hat_avg[i, ] <- apply(tau_tilde, 2, mean)
  # estimate the marginal effect with maximum likelihood
  tau_hat_mle[i, ] <- exp(beta_hat[i, 1] + beta_hat[i, 2]*x0)*beta_hat[i, 2]
}

# calcuate ti-bias
e_beta_hat <- apply(beta_hat, 2, mean)
sims_df <- data.frame(x = x0, 
                      true_qi = exp(beta[1] + beta[2]*x0)*beta[2],
                      tau_e_beta_hat = exp(e_beta_hat[1] + e_beta_hat[2]*x0)*e_beta_hat[2], 
                      mle = apply(tau_hat_mle, 2, mean),
                      avg = apply(tau_hat_avg, 2, mean)) %>%
  gather(method, ev, mle, avg) %>%
  mutate(ti_bias = ev - tau_e_beta_hat) %>%
  mutate(method = fct_recode(method, `Average of Simulations` = "avg", `Maximum Likelihood` = "mle"))

# plot the ti-bias compared to the true value
ggplot(sims_df, aes(x = true_qi, y = ti_bias, linetype = method, color = method)) + 
  geom_line(size = .9) + 
  scale_linetype_manual(values = c("dotted", "solid")) + 
  scale_color_manual(values = c("#1b9e77", "#d95f02")) +
  theme_minimal() + 
  labs(title = expression(paste(tau, "-Bias in Estimates of Poisson Marginal Effects")),
       x = "True Marginal Effect",
       y = expression(paste(tau, "-Bias")),
       linetype = "Method", 
       color = "Method") + 
  guides(linetype = guide_legend(keywidth = 2, keyheight = 1))
ggsave("doc/figs/poisson-mcs.pdf", height = 3, width = 8)

# compute discriptive for a subset of the data
mean(sims_df$true_qi > 0.5)  # proportion of data in condition
descr_df <- sims_df %>%
  filter(true_qi > 0.5) %>%
  select(x, true_qi, method, ti_bias) %>%
  spread(method, ti_bias) %>%
  mutate(ratio_avg_mle = `Average of Simulations`/`Maximum Likelihood`,
         ratio_mle_true = `Maximum Likelihood`/true_qi,
         ratio_avg_true = `Average of Simulations`/true_qi) %>%
  gather(quantity, ratio, starts_with("ratio")) %>%
  group_by(quantity) %>%
  summarize(avg = mean(ratio)) %>%
  glimpse()

# a slightly different version of the plot
## note: this plot has teh expected axes, but makes the comparison less clear imo.
sims_df %>%
  rename(expected_estimate = ev, true_value = true_qi) %>%
  gather(quantity, me, true_value, expected_estimate) %>%
  ggplot(aes(x = x, y = me, color = quantity)) + 
    facet_wrap(~ method) +
    geom_line(size = .9) 

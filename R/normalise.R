#' @title Waggoner & Zha (2003) row signs normalisation of the posterior draws for matrix \eqn{B}
#'
#' @description Normalises the sign of rows of matrix \eqn{B} MCMC draws 
#' Markov state-by-state and S5 component-by-component, 
#'  provided as the first argument \code{posterior_B}, relative to the matrices in
#'  \code{B_hat}, provided as the second argument of the function. If the second argument 
#'  is not provided, the function creates its own benchmark matrix. The implemented
#'  procedure proposed by Waggoner, Zha (2003) normalises the MCMC output in an
#'  optimal way leading to the unimodal posterior. Only normalised MCMC output is 
#'  suitable for the computations of the posterior characteristics of the \eqn{B}
#'  matrix elements and their functions such as the impulse response functions and other 
#'  economically interpretable values. 
#' 
#' @param posterior posterior estimation outcome - an object of either of classes: 
#' "PosteriorBSVARSVMSS5", "PosteriorBSVARSVMS", or "PosteriorBSVARSVS5"
#' containing, amongst other draws, the \code{S} draws from the posterior 
#' distribution of the \code{NxN} matrix of contemporaneous relationships \eqn{B}. 
#' These draws are to be normalised with respect to:
#' @param VB the list with matrices determining identification, including S5 identification
#' 
#' @return An object of class corresponding to the class of the first argument \code{posterior} 
#' with normalised draws of matrix \eqn{B}.
#'
#' @author Tomasz Woźniak \email{wozniak.tom@pm.me}
#' 
#' @references 
#' Waggoner, D.F., and Zha, T., (2003) Likelihood Preserving Normalization in Multiple Equation Models. 
#' \emph{Journal of Econometrics}, \bold{114}(2), 329--47, \doi{https://doi.org/10.1016/S0304-4076(03)00087-3}.
#'
#' @export
normalise <- function(posterior, VB) {
  
  # check the args
  stopifnot("Argument posterior must contain estimation output from the estimate function." = any(class(posterior)[1] == c("PosteriorBSVARSVMSS5", "PosteriorBSVARSVMS", "PosteriorBSVARSVS5")))
  stopifnot("Argument VB must be a list." = is.list(VB))
  
  # call method
  UseMethod("normalise", posterior)
}




#' @inherit normalise
#' @inheritParams normalise
#' 
#' @method normalise PosteriorBSVARSVS5
#' 
#' @export
normalise.PosteriorBSVARSVS5 <- function(posterior, VB) {
  
  S5_equation = 3
  
  M             = 1
  N             = dim(posterior$posterior$A)[1]
  comp          = VB[length(VB)][[1]]
  
  S5_indicator  = posterior$posterior$S4_indicator
  B_hat         = array(NA, c(N, N, comp[S5_equation]))
  
  for (component in 1:comp[S5_equation]) {
    S5_indices    = which(S5_indicator[S5_equation, ] == component) 
    
    if ( length(S5_indices) == 0 ) next
    
    B_hat_tmp                 = posterior$posterior$B[,,utils::tail(S5_indices,1)]
    B_hat[,,component]        = diag(sign(diag(B_hat_tmp))) %*% B_hat_tmp
    B_to_normalise            = posterior$posterior$B[,,S5_indices]
    
    B_to_normalise            = .Call(`_bsvarTVPs_bsvars_normalisation_wz2003`, B_to_normalise, B_hat[,,component])
    
    posterior$posterior$B[,,S5_indices] = B_to_normalise
    
    # last_draw
    if ( component == posterior$last_draw$S4_indicator[S5_equation,] ) {
      posterior$last_draw$B   = .Call(`_bsvarTVPs_bsvars_normalisation_wz20031`, posterior$last_draw$B, B_hat[,,component])
    }
  } # END component loop
  
  return(posterior)
}
 

#' @inherit normalise
#' @inheritParams normalise
#' 
#' @method normalise PosteriorBSVARSVMS
#' 
#' @export
normalise.PosteriorBSVARSVMS <- function(posterior, VB) {
  
  M             = dim(posterior$posterior$xi)[1]
  N             = dim(posterior$posterior$A)[1]
  S             = dim(posterior$posterior$A)[3]
  
  B_hat         = array(NA, c(N, N, M))
  
  for (m in 1:M) {
    
    B_hat_tmp             = posterior$last_draw$B[,,m]
    B_hat[,,m]            = diag(sign(diag(B_hat_tmp))) %*% B_hat_tmp
    
    B_to_normalise        = array(NA, c(N, N, S))
    for (i in 1:S) {
      B_to_normalise[,,i] = posterior$posterior$B[i,1][[1]][,,m]
    }
    
    B_to_normalise        = .Call(`_bsvarTVPs_bsvars_normalisation_wz2003`, B_to_normalise, B_hat[,,m])
    
    for (i in 1:S) {
      posterior$posterior$B[i,1][[1]][,,m] = B_to_normalise[,,i]
    }
    
    # last_draw
    posterior$last_draw$B[,,m]  = .Call(`_bsvarTVPs_bsvars_normalisation_wz20031`, posterior$last_draw$B[,,m], B_hat[,,m])
    
  } # END m loop
  
  return(posterior)
}




#' @inherit normalise
#' @inheritParams normalise
#' 
#' @method normalise PosteriorBSVARSVMSS5
#' 
#' @export
normalise.PosteriorBSVARSVMSS5 <- function(posterior, VB) {
  
  S5_equation = 3
  
  M             = dim(posterior$posterior$xi)[1]
  N             = dim(posterior$posterior$A)[1]
  comp          = VB[length(VB)][[1]]
  S5_indicator  = posterior$posterior$S4_indicator
  B_hat         = array(NA, c(N, N, M, comp[S5_equation]))
  
  for (m in 1:M) {
    for (component in 1:comp[S5_equation]) {
      
      S5_indices    = which(S5_indicator[S5_equation, m, ] == component) #
      if ( length(S5_indices) == 0 ) next
      
      B_hat_tmp               = posterior$posterior$B[utils::tail(S5_indices,1),1][[1]][,,m] #
      B_hat[,,m,component]    = diag(sign(diag(B_hat_tmp))) %*% B_hat_tmp
      
      B_to_normalise = array(NA, c(N, N, length(S5_indices)))
      for (i in 1:length(S5_indices)) {
        B_to_normalise[,,i]   = posterior$posterior$B[S5_indices[i],1][[1]][,,m] # this is ridiculus!
      }
      
      B_to_normalise          = .Call(`_bsvarTVPs_bsvars_normalisation_wz2003`, B_to_normalise, B_hat[,,m,component])
      
      for (i in 1:length(S5_indices)) {
        posterior$posterior$B[S5_indices[i],1][[1]][,,m] = B_to_normalise[,,i]
      }
      
      # last_draw
      if ( component == posterior$last_draw$S4_indicator[S5_equation,m] ) {
        posterior$last_draw$B[,,m]    = .Call(`_bsvarTVPs_bsvars_normalisation_wz20031`, posterior$last_draw$B[,,m], B_hat[,,m,component])
      }
      
    } # END component loop
  } # END m loop
  
  return(posterior)
}


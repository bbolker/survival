print.survfit <- function(x, scale=1, 
			  digits = max(options()$digits - 4, 3), 
                          print.rmean = getOption('survfit.print.rmean'),
                          rmean = getOption('survfit.rmean'), ...) {

    if (!is.null(cl<- x$call)) {
	cat("Call: ")
	dput(cl)
	cat("\n")
        }	
    omit <- x$na.action
    if (length(omit)) cat("  ", naprint(omit), "\n")

    savedig <- options(digits=digits)
    on.exit(options(savedig))

    #   x <- survfit32(x)
    # The print.rmean option is depreciated, with the more general
    #   rmean option taking its place.  But if someone specifically
    #   uses print.rmean in the call, or has it as an option without
    #   the rmean option, listen to them.
    if (!missing(print.rmean) && is.logical(print.rmean) && missing(rmean)) {
        if (print.rmean) rmean <- 'common'
        else             rmean <- 'none'
        }

    else {
        if (is.null(rmean)) {
            if (is.logical(print.rmean)) {
                if (print.rmean) rmean <- 'common'
                else             rmean <- 'none'
            }
            else rmean <- 'none'  #no option set
        }

        # Check validity: it can be numeric or character
        if (is.numeric(rmean)) {
            if (is.null(x$start.time)) {
                if (rmean < min(x$time)) 
                    stop("Truncation point for the mean is < smallest survival")
            }
            else if (rmean < x$start.time)
                stop("Truncation point for the mean is < smallest survival")
        }
        else {
            rmean <- match.arg(rmean, c('none', 'common', 'individual'))
            if (length(rmean)==0) stop("Invalid value for rmean option")
        }
    }
    
    temp <- survmean(x, scale=scale, rmean)
    # If the first columns of survmean are identical, suppress duplicates
    #
    mtemp <- if (is.matrix(temp$matrix)) temp$matrix  
             else matrix(temp$matrix, nrow=1, 
                         dimnames=list(NULL, names(temp$matrix)))
    if (dimnames(mtemp)[[2]][2] == "n.id") {
        mtemp <- mtemp[,-3, drop=FALSE]   # no need for n.start
        dimnames(mtemp)[[2]][2] <- "n"
    }
    else { # older path
        if (all(mtemp[,2] == mtemp[,3])){  
            cname <- dimnames(mtemp)[[2]]
            mtemp <- mtemp[,-3, drop=FALSE]
            cname <-cname[-3]
            cname[2] <- "n"
            dimnames(mtemp)[[2]] <- cname
        }

        if (all(mtemp[,1] == mtemp[,2])) 
            mtemp <- mtemp[,-1, drop=FALSE]
    }
    # for printing, put a footnote on the rmean label
    if (rmean != 'none') {
        dd <- dimnames(mtemp)
        dd[[2]] <- ifelse(dd[[2]]=="rmean", "rmean*", dd[[2]])
        dimnames(mtemp) <- dd
        print(mtemp)

        if (rmean == 'individual') 
            cat("   * restricted mean with variable upper limit\n")
        else cat("    * restricted mean with upper limit = ", 
                 format(temp$end.time[1]), "\n")
        }
    else print(mtemp)

    invisible(x)
    }


#
# The function that does all of the actual work -- output is a matrix
#   Used by both print.survfit and summary.survfit
#

survmean <- function(x, scale=1, rmean) {

    # The starting point for the integration of the AUC
    if (!is.null(x$t0)) start.time <- x$t0
    else                start.time <- min(0, x$time)
    #
    # The function below is called once for each line of output,
    #  i.e., once per curve.  It creates the line of output
    #
    pfun <- function(nused, time, surv, n.risk, n.event, lower, upper, 
		      start.time, end.time, nid) {
        #
        # Start by defining a small utility function
        # Multiple times, we need to find the x corresponding to the first
        #    y that is <.5.  (The y's are in decreasing order, but may have
        #    duplicates). 
        # Nuisance 1: if one of the y's is exactly .5, we want the mean of
        #    the corresponding x and the first x for which y<.5.  We need to
        #    use the equivalent of all.equal to check for a .5 however:
        #    survfit(Surv(1:100)~1) gives a value of .5 + 1.1e-16 due to 
        #    roundoff error.
        # Nuisance 2: there may by an NA in the y's
        # Nuisance 3: if no y's are <=.5, then we should return NA
        # Nuisance 4: the obs (or many) after the .5 may be censored, giving
        #   a stretch of values = .5 +- epsilon
        # 
        minmin <- function(y, x) {
            tolerance <- .Machine$double.eps^.5   #same as used in all.equal()
            keep <- (!is.na(y) & y <(.5 + tolerance))
            if (!any(keep)) NA
            else {
                x <- x[keep]
                y <- y[keep]
                if (abs(y[1]-.5) <tolerance  && any(y< y[1])) 
                    (x[1] + x[min(which(y<y[1]))])/2
                else x[1]
                }
            }

	# compute the mean of the curve, with "start.time" as 0
	#   start by drawing rectangles under the curve
        # Lining up the terms for "varmean" is tricky -- the easiest 
        #   check is to look at the homework solution on page 195-196
        #   of Miller, Survival Analysis, Wiley, 1981.
        # Computing the mean sojourn time for a multi-state curve is
        #  a completely different task.
        if (!is.na(end.time)) {
            hh <- ifelse((n.risk-n.event)==0, 0, 
		       n.event /(n.risk *(n.risk -n.event)))
            keep <- which(time <= end.time)

            if (length(keep) ==0) { # the cutoff is before the first event
                temptime <- end.time
                tempsurv <- 1
                hh <- 0
            }
            else {
                temptime <- c(time[keep], end.time)
                tempsurv <- c(surv[keep], surv[max(keep)])
                hh <- c(hh[keep], 0)
            }
            n <- length(temptime)
            delta <- diff(c(start.time, temptime))     #width of rectangles
            rectangles <- delta * c(1, tempsurv[-n])   #area of rectangles
            varmean <- sum( cumsum(rev(rectangles[-1]))^2 * rev(hh)[-1])
            mean <- sum(rectangles) 
            }
        else { 
            mean <- 0
            varmean <- 0  #placeholders 
            }   

        if (is.null(nid)) maxn= max(n.risk) else maxn = nid
        #compute the median  and ci(median)
	med <- minmin(surv, time)
	if (!is.null(upper)) {
	    upper <- minmin(upper, time)
	    lower <- minmin(lower, time)
	    c(nused, maxn, n.risk[1], 
              sum(n.event), sum(mean), sqrt(varmean), med, lower, upper)
	    }
	else
		c(nused, maxn, n.risk[1], sum(n.event), 
                  sum(mean), sqrt(varmean), med, 0, 0)
	}


    # Now to the actual work
    #  We create an output matrix with all 9 columns, and then trim some
    #  out at the end.
    #  If rmean='none' for instance, pfun above returns dummy values for
    #    the mean and var(mean).  Similar for CI of the median.
    # 
    stime <- x$time/scale
    if (is.numeric(rmean)) rmean <- rmean/scale
    surv <- x$surv
    plab <- c("records", "n.max", "n.start", "events", 
                  "rmean", "se(rmean)", "median",
              paste(x$conf.int, c("LCL", "UCL"), sep=''))  #col labels
    ncols <- 9    #number of columns in the output
    if (!is.null(x$n.id)) plab[2] <- "n.id"

    #Four cases: strata Y/N  by  ncol(surv)>1 Y/N
    #  Repeat the code, with minor variations, for each one
    if (is.matrix(surv) && !is.matrix(x$n.event))  #make it easier
        x$n.event <- matrix(rep(x$n.event, ncol(surv)), ncol=ncol(surv))

    if (is.null(x$strata)) {
        if (rmean=='none') end.time <- NA
        else if (is.numeric(rmean)) end.time <- rmean
        else end.time <- max(stime)

	if (is.matrix(surv)) {
	    out <- matrix(0, ncol(surv), ncols)
	    for (i in 1:ncol(surv)) {
		if (is.null(x$conf.int))
		     out[i,] <- pfun(x$n, stime, surv[,i], x$n.risk, 
                                     x$n.event[,i],
				      NULL, NULL, start.time, end.time, x$n.id)
		else out[i,] <- pfun(x$n, stime, surv[,i], x$n.risk, 
                                     x$n.event[,i],
                                     x$lower[,i], x$upper[,i], start.time,
                                     end.time, x$n.id)
		}
	    dimnames(out) <- list(dimnames(surv)[[2]], plab)
	    }
	else {
	    out <- matrix(pfun(x$n, stime, surv, x$n.risk, x$n.event, x$lower, 
			x$upper, start.time, end.time, x$n.id), nrow=1)
	    dimnames(out) <- list(NULL, plab)
 	    }
        }
    else {   #strata case
	nstrat <- length(x$strata)
	stemp <- rep(1:nstrat,x$strata)  # the index vector for strata1, 2, etc

        last.time <- (rev(stime))[match(1:nstrat, rev(stemp))]
        if (rmean=='none') end.time <- rep(NA, nstrat)
        else if (is.numeric(rmean)) end.time <- rep(rmean, nstrat)
        else if (rmean== 'common')  end.time <- rep(max(last.time), nstrat)
        else end.time <- last.time
	if (is.matrix(surv)) {
	    ns <- ncol(surv)
	    out <- matrix(0, nstrat*ns, ncols)
            if (is.null(dimnames(surv)[[2]]))
                dimnames(out) <- list(rep(names(x$strata), ns), 
                                      plab)
            else {
                cname <- outer(names(x$strata), dimnames(surv)[[2]], paste,
                               sep=", ")
                dimnames(out) <- list(c(cname), plab)
                }
	    k <- 0
	    for (j in 1:ns) {
 		for (i in 1:nstrat) {
                    who <- (stemp==i)
		    k <- k+1
		    if (is.null(x$lower))
		         out[k,] <- pfun(x$n[i], stime[who], surv[who,j],
					 x$n.risk[who], x$n.event[who,j],
					 NULL, NULL, start.time, end.time[i],
                                         x$n.id[j])
		    else out[k,] <- pfun(x$n[i], stime[who], surv[who,j],
					 x$n.risk[who], x$n.event[who,j],
					 x$lower[who,j], x$upper[who,j], 
					 start.time, end.time[i], x$n.id[j])
		    }
		}
	    }
	else { #non matrix case
	    out <- matrix(0, nstrat, ncols)
	    dimnames(out) <- list(names(x$strata), plab)
	    for (i in 1:nstrat) {
		who <- (stemp==i)
		if (is.null(x$lower))
		     out[i,] <- pfun(x$n[i], stime[who], surv[who], 
				     x$n.risk[who], x$n.event[who], 
				     NULL, NULL, start.time, end.time[i], 
                                     x$n.id[i])
		else out[i,] <- pfun(x$n[i], stime[who], surv[who], 
				     x$n.risk[who], x$n.event[who], 
				     x$lower[who], x$upper[who], start.time,
                                     end.time[i], x$n.id[i])
		}
	    }
	}

    if (is.null(x$lower)) out <- out[,1:7, drop=F]   #toss away the limits
    if (rmean=='none') out <- out[,-(5:6), drop=F]   #toss away the mean & sem
    list(matrix=out[,,drop=T], end.time=end.time)
    }



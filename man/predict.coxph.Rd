\name{predict.coxph}
\alias{predict.coxph}
\alias{predict.coxph.penal}
\title{
  Predictions for a Cox model 
}
\description{
  Compute fitted values and regression terms for a model fitted by
  \code{\link{coxph}}
}
\usage{
\method{predict}{coxph}(object, newdata,
type=c("lp", "risk", "expected", "terms", "survival"),
se.fit=FALSE, na.action=na.pass, terms=names(object$assign), collapse,
reference=c("strata", "sample", "zero"),  ...)
}
\arguments{
\item{object}{
the results of a coxph fit. 
}
\item{newdata}{
  Optional new data at which to do predictions.
  If absent, predictions are for the  data frame used in the original
  fit. 
  When coxph has been called with a formula argument created in another
  context, i.e., coxph has been called within another function and the
  formula was passed as an argument to that function, there can be
  problems finding the data set.  See the note below.
}
\item{type}{
the type of predicted value. 
Choices are the linear predictor (\code{"lp"}), the risk score exp(lp)
(\code{"risk"}), 
the expected number of events given the covariates and follow-up time 
(\code{"expected"}), and the terms of the linear predictor
(\code{"terms"}).
The survival probability for a subject is equal to exp(-expected).
}
\item{se.fit}{
if TRUE, pointwise standard errors are produced for the predictions. 
}
\item{na.action}{
  applies only when the \code{newdata} argument is present, and defines
  the missing value action for the new data.  The default is to include
  all observations.
  When there is no newdata, then the behavior of missing is dictated by
  the na.action option of the original fit.}
\item{terms}{
if type="terms", this argument can be used to specify which terms should be 
included; the default is all. 
}
\item{collapse}{
optional vector of subject identifiers.  
If specified, the output will contain one entry per subject rather than one 
entry per observation. 
}
\item{reference}{reference for centering predictions, see details below}
\item{\dots}{For future methods}
}
\value{
a vector or matrix of predictions, or a list containing the predictions 
(element "fit") and their standard errors (element "se.fit") if the se.fit 
option is TRUE. 
}
\details{
  The Cox model is a \emph{relative} risk model; predictions
of type "linear predictor", "risk", and "terms" are all
relative to the sample from which they came.  By default, the reference
value for each of these is the mean covariate within strata.
The underlying reason is both statistical and practical.
First, a Cox model only predicts relative risks
between pairs of subjects within the same strata, and hence the addition
of a constant to any covariate, either overall or only within a
particular stratum, has no effect on the fitted results.
Second, downstream calculations depend on the risk score exp(linear
predictor), which will fall prey to numeric overflow for a linear
predictor greater than \code{.Machine$double.max.exp}.
The \code{coxph} routines try to approximately center the predictors out
of self protection.  
Using the \code{reference="strata"} option is the safest centering,
since strata occasionally have different means.
When the results of \code{predict} are used in further calculations it
may be desirable to use a single reference level for all observations.
Use of \code{reference="sample"} will use \code{object$means}, which agrees
with the \code{linear.predictors} component of the coxph object.
Predictions of \code{type="terms"} are almost invariably passed
forward to further calculation, so for these we default to using
the sample as the reference.
A reference of \code{"zero"} causes no centering to be done.

Predictions of type "expected" or "survival" incorporate the baseline
hazard and are thus absolute instead of relative; the
\code{reference} option has no effect on these.
These values depend on the follow-up time for the subjects as
well as covariates so the \code{newdata} argument needs to include both
the right and \emph{left} hand side variables from the formula.
(The status variable will not be used, but is required since the
underlying code needs to reconstruct the entire formula.)

Models that contain a \code{frailty} term are a special case: due
to the technical difficulty, when there is a \code{newdata} argument the
predictions will always be for a random effect of zero.

For predictions of type expected a user will normally want to use
\eqn{\Lambda(t_i)}{H(t[i])}, i.e., the cumulative hazard at the individual
follow-up time \eqn{t_i}{t[i]}of each individual subject.
This is E in the martingale residual O-E and plays a natural role in
assessments of model validation (Crowson 2016).
For predictions of type survival, on the other hand, a user
will normally want S(tau), where tau is a single pre-specified time
point which is the same for all subjects, e.g., predicted 5 year
survival.  The \code{newdata} data set should contain actual survival
time(s) for each subject for the first case, as the survival time variable(s),
and the target time tau in the second case; (0, tau) for (time1, time2)
data.

For counting process data with (time1, time2) form, residuals of
type \code{expected} estimate the increment in hazard over said interval, and
those of type \code{survival} the probability of an event at time2 given
that the observation is still alive at time1.  The estimated hazards
over two intervals (t1, t2) and (t2, t3) add to the total hazard over
the interval (t1, t3), and the variances also add: the formulas treat these as
independent increments, given the covariates.
Estimated survivals multiply, but variances do not add.
}
\note{
Some predictions can be obtained directly from the coxph object, and for
others it is necessary for the routine to have the entirety of the
original data set, e.g., for type = \code{terms} or if standard errors
are requested.
This extra information is saved in the coxph object if
\code{model=TRUE}, if not the original data is reconstructed.
If it is known that such residuals will be required overall execution will be
slightly faster if the model information is saved. 

In some cases the reconstruction can fail.
The most common is when coxph has been called inside another function
and the formula was passed as one of the arguments to that enclosing
function.  Another is when the data set has changed between the original
call and the time of the prediction call.
In each of these the simple solution is to add \code{model=TRUE} to the
original coxph call.
}

\seealso{
\code{\link{predict}},\code{\link{coxph}},\code{\link{termplot}} }

\examples{
options(na.action=na.exclude) # retain NA in predictions
fit <- coxph(Surv(time, status) ~ age + ph.ecog + strata(inst), lung)
#lung data set has status coded as 1/2
mresid <- (lung$status-1) - predict(fit, type='expected') #Martingale resid 
predict(fit,type="lp")
predict(fit,type="expected")
predict(fit,type="risk",se.fit=TRUE)
predict(fit,type="terms",se.fit=TRUE)

# For someone who demands reference='zero'
pzero <- function(fit)
  predict(fit, reference="sample") + sum(coef(fit) * fit$means, na.rm=TRUE)
}
\references{
  C Crowson, E Atkinson and T Therneau, 
    Assessing calibration of prognostic risk scores,
    Stat Methods Med Res, 2016.
}
\keyword{survival}

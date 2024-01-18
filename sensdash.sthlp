{smcl}
{* *! version 1.1  17jan2024 Gunther Bensch}{...}
{findalias asfradohelp}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] help" "help help"}{...}
{viewerjumpto "Syntax" "sensdash##syntax"}{...}
{viewerjumpto "Description" "sensdash##description"}{...}
{viewerjumpto "Options" "sensdash##options"}{...}
{viewerjumpto "Remarks" "sensdash##remarks"}{...}
{viewerjumpto "Examples" "sensdash##examples"}{...}
{hi:help sensdash}{...}
{right:}
{hline}

{title:Title}

{phang}
{bf:sensdash} {hline 2} Plot sensitivity dashboard for multiverse of replication estimates

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:sensd:ash}
{it:outcome}
{ifin}
{cmd:,} beta({it:varname}) beta_orig({it:varname}) [{it:semi-optional parameters}] [{it:optional parameters}]


{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:semi-optional parameters}
{synopt:{opt se(varname)}}standard errors of beta coefficients for individual replication specifications{p_end}
{synopt:{opt se_orig(varname)}}standard errors of the original beta coefficient for respective outcome{p_end}
{synopt:{opt pval(varname)}}{it:p}-values on statistical significance of estimates in individual replication specifications{p_end}
{synopt:{opt pval_orig(varname)}}{it:p}-values on statistical significance of original estimate for respective outcome{p_end}
		
{syntab:optional parameters}
{synopt:{opt shorttitle_orig(string)}}short tile of original results{p_end}
{synopt:{opt siglevel(#)}}significance level{p_end}
{synopt:{opt extended(0/1)}}show extended set of replication indicators in the dashboard{p_end}
{synopt:{opt aggregation(0/1)}}show outcomes in the dashboard aggregated across outcomes instead of individually{p_end}
{synopt:{opt mean(varname)}}mean of the outcome variables in the replication specifications{p_end}
{synopt:{opt mean_orig(varname)}}mean of the outcome variables in the original study{p_end}
{synopt:{opt ivarweight(0/1)}}show indicators across all outcomes weighted by the inverse variance{p_end}
{synopt:{opt ivF(varname)}}first-stage {it:F}-Statistics, if IV/2SLS estimations{p_end}
{synopt:{opt signfirst(varname)}}share of first stages with wrong sign{p_end}			
{synoptline}
{p2colreset}{...}

{p 4 6 2}
{cmd:outcome} is the variable name of the outcome variable, which should be numeric and with value labels.{p_end}
{p 4 6 2}
{cmd:beta({it:varname})} specifies the variable {it:varname} that includes the beta coefficients for individual replication specifications.{p_end}
{p 4 6 2}
{cmd:beta_orig({it:varname})} specifies the variable {it:varname} that includes the original beta coefficient for the respective outcome.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:sensdash} plots sensitivity dashboards across {it:outcome} to compare multiple replication estimates, beta({it:varname}),
to the original estimate, beta_orig({it:varname}).{p_end}


{marker options}{...}
{title:Options}

{dlgtab:semi-optional parameters}

{phang}
The commands requires that either both {cmd:se()} and {cmd:se_orig()} are specified or both {cmd:pval()} and {cmd:pval_orig()}.

{phang}
{opt se(varname)} specifies the variable {it:varname} that includes the standard errors of beta coefficients for individual replication specifications;
if {cmd:se()} is not specified, it is calculated based on {cmd:beta()} and {cmd:pval()}.

{phang}
{opt se_orig(varname)} specifies the variable {it:varname} that includes the standard errors of the original beta coefficient for the respective outcome;
if {cmd:se_orig()} is not specified, it is calculated based on {cmd:beta_orig()} and {cmd:pval_orig()}.

{phang}
{opt pval(varname)} specifies the variable {it:varname} that includes the {it:p}-values on statistical significance of estimates
in individual replication specifications; if {cmd:pval()} is not specified, it is calculated based on {cmd:beta()} and {cmd:se()}
in a two-sided test assuming an approximately normal distribution.

{phang}
{opt pval_orig(varname)} specifies the variable {it:varname} that includes the {it:p}-value on statistical significance of the original estimate
for the respective outcome; if {cmd:pval_orig()} is not specified, it is calculated based on {cmd:beta_orig()} and {cmd:se_orig()}
in a two-sided test assuming an approximately normal distribution.


{dlgtab:optional parameters}

{phang}
{opt shorttitle_orig(string)} provides a short title for the original results, for example "[first letters of original authors] (year)";
default is {cmd shorttitle_orig("original estimate")}.

{phang}
{opt siglevel(#)} gives the significance level (e.g. 1,5,10); default is siglevel(10) (i.e. 10% level). In that case,
indicators on the 5% level will also be included in the Sensitivity Dashboard.

{phang}
{opt extended(0/1)} is a binary indicator on whether to show the extended set of replication indicators in the dashboard (yes=1, no=0);
default is {cmd:extended(0)}.

{phang}
{opt aggregation(0/1)} is a binary indicator on whether to show outcomes in the dashboard individually (=0) or aggregated across outcomes (=1);
default is {cmd:aggregation(0)}.

{phang}
{opt mean(varname)} specifies the variable {it:varname} that includes the mean of the outcome variables in the replication specifications,
ideally being the baseline mean in the control group.

{phang}
{opt mean_orig(varname)} specifies the variable {it:varname} that includes the mean of the outcome variables in the original study,
ideally being the baseline mean in the control group; if {cmd:mean_orig()} is not specified, it is assumed to be equal to {cmd:mean()}.

{phang}
{opt ivarweight(0/1)} is a binary indicator on whether to show indicators across all outcomes weighted by the inverse variance (yes=1, no=0);
default is {cmd:ivarweight(0)}.

{phang}
{opt ivF(varname)} specifies the variable {it:varname} that includes the first-stage {it:F}-Statistics,
if estimates are based on IV/2SLS estimations.

{phang}
{opt signfirst(varname)} specifies the (uniform) variable {it:varname} that includes the share of first stages with wrong sign in a range between 0 and 1,
if IV/2SLS estimations (cf. Angrist and Kolesár (2024)). This option should only be used if the share is identical for all outcomes.	


{marker examples}{...}
{title:Examples}

{phang}	
{bf:Data preparation}

{p 8 12}{stata "use http://fmwww.bc.edu/ec-p/data/hayashi/griliches76.dta" : . use http://fmwww.bc.edu/ec-p/data/hayashi/griliches76.dta}{p_end}
{p 8 12}(Wages of Very Young Men, Zvi Griliches, J.Pol.Ec. 1976)

{p 8 12}({stata "sensdash_gendata":{it:click to generate multiverse dataset}})

{phang}	
{bf:Basic sensitivity dashboard using beta and se information}

{p 8 12}{stata "sensdash outcome, beta(beta_iqiv) beta_orig(beta_iqiv_orig)  se(se_iqiv) se_orig(se_iqiv_orig)" : . sensdash outcome, beta(beta_iqiv) beta_orig(beta_iqiv_orig)  se(se_iqiv) se_orig(se_iqiv_orig)}
{p_end}

{phang}
{bf:Example of sensitivity dashboard that aggregates across outcomes}

{p 8 12}{stata "sensdash outcome, beta(beta_iqiv) beta_orig(beta_iqiv_orig)  se(se_iqiv) se_orig(se_iqiv_orig) aggregation(1)" : . sensdash outcome, beta(beta_iqiv) beta_orig(beta_iqiv_orig)  se(se_iqiv) se_orig(se_iqiv_orig) aggregation(1)}
{p_end}

{phang}
The graph can then be exported, for example via -{help graph export} [...], replace-



{title:References}

{p 4 8 2}
Angrist, J., & Kolesár, M. (2024). One instrument to rule them all: The bias and coverage of just-ID IV. {it:Journal of Econometrics}.


{title:Authors}

      Gunther Bensch, bensch@rwi-essen.de
      RWI

	  
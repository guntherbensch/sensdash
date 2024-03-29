/*
*** PURPOSE:	
	This Stata do-file runs multiple specifications for a multiverse analysis and stores the estimates as a dataset 
	including information on
		- the outcome
		- the beta coefficient of the multiple analysis paths
		- the related standard error (se)
		- the various decision choices taken (beyond the outcome, if applicable), for example on the iv and the covariates
		- additional parameters, such as the number of observations, the outcome mean, and IV-related statistics

	sensdash_gendata requires version 12.0 of Stata or newer.
					
***  AUTHOR:	Gunther Bensch, RWI - Leibniz Institute for Economic Research, gunther.bensch@rwi-essen.de
*/	




cap program drop sensdash_gendata

program define sensdash_gendata
	version 14.0
		
	syntax
	
	
	*** Install packages from SSC
			local ssc_packages "ivreg2 ranktest"
			
			// avoid re-installing if already present
			if !missing("`ssc_packages'") {
				foreach pkg of local ssc_packages {
					quietly which `pkg'
					if _rc == 111 {                 
						dis "Installing `pkg'"
						quietly ssc install `pkg', replace
					}
				}
			}
			quietly ssc install estout, replace
			
	
	*** Run multiverse analysis
	local panel_list   iv cov1 cov2 cov3 cov4 cov5 
	local m_max = 2*(2^5*3^1)
	local n_max = 14		// # entries for each of the estimation results: outcome - IVest (yes/no) - beta_iqiv - se_iqiv - outcome_mean - N (outcome var) - FStat (IV) - iv - cov1 - cov2 - cov3 - cov4 - cov5 - neg_first
	matrix R = J(`m_max', `n_max', .)   				
	local R_matrix_col outcome IVest beta_iqiv se_iqiv outcome_mean N IVFStat `panel_list' neg_first 
	matrix coln R =  `R_matrix_col'
	
		
	local i = 1
	local j = 1

	qui foreach outcome in lw lw80 {
		foreach iv in "med kww age mrt" "med kww age" "med kww mrt" {
			foreach cov1 in "" "s" {
				foreach cov2 in "" "expr" {
					foreach cov3 in "" "tenure" {
						foreach cov4 in "" "rns" {
							foreach cov5 in "" "smsa" {
								ivreg2 `outcome' `cov1' `cov2' `cov3' `cov4' `cov5' i.year (iq=`iv')
						
								foreach var of local panel_list {
									qui estadd scalar `var' = 0
								}
								
								if "`iv'"=="med kww age" {
									qui estadd scalar iv = 1, replace
								}	
								if "`iv'"=="med kww mrt" {
									qui estadd scalar iv = 2, replace
								}
								if "`cov1'"=="s" {
									qui estadd scalar cov1 = 1, replace
								}	
								if  "`cov2'"=="expr" {
									qui estadd scalar cov2 = 1, replace
								}
								if  "`cov3'"=="tenure" {
									qui estadd scalar cov3 = 1, replace
								}
								if  "`cov4'"=="rns" {
									qui estadd scalar cov4 = 1, replace
								}
								if  "`cov5'"=="smsa" {
									qui estadd scalar cov5 = 1, replace
								}
								
								qui sum `outcome' if e(sample)==1
								matrix R[`i',1] = `j', 1, _b[iq], _se[iq], r(mean), r(N), e(widstat), e(iv), e(cov1), e(cov2), e(cov3), e(cov4), e(cov5), e(neg_first)
								local i = `i' + 1								
								
							}
						}
					}
				}
			}			
		}
		local j = `j' + 1
	}
	
	
	*** Create multiverse dataset
	svmat R, names(col)
	keep `R_matrix_col'
	
	label define outcome    1 "log wage" 2 "log wage 80"
	label val outcome outcome   	
	
	egen nmiss=rmiss(*)
	drop if nmiss==`n_max'	
	drop nmiss

	gen beta_iqiv_orig_x = beta_iqiv if outcome==1 & iv==0 & cov1==0 & cov2==0 & cov3==0 & cov4==0 & cov5==0 
	egen beta_iqiv_orig = mean(beta_iqiv_orig_x)
	gen se_iqiv_orig_x = se_iqiv if outcome==1 & iv==0 & cov1==0 & cov2==0 & cov3==0 & cov4==0 & cov5==0 
	egen se_iqiv_orig = mean(se_iqiv_orig_x)
	drop *_x
	
end
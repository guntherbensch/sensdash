/*
*** PURPOSE:	
	This Stata do-file contains the program sensdash to create Sensitivity Dashboards.
	sensdash requires version 14.0 of Stata or newer.


*** OUTLINE:	PART 1.  INITIATE PROGRAM SENSDASH AND INSTALL PACKAGES
			
				PART 2.  DASHBOARD-SPECIFIC SETTINGS 
				
				PART 3.  AUXILIARY VARIABLE GENERATION

				PART 4.  INDICATOR DEFINITIONS
				
				PART 5.  DASHBOARD VISUALIZATION

					
***  AUTHOR:	Gunther Bensch, RWI - Leibniz Institute for Economic Research, gunther.bensch@rwi-essen.de
*/	




********************************************************************************
*****  PART 1  INITIATE PROGRAM SENSDASH AND INSTALL PACKAGES
********************************************************************************

cap prog drop sensdash
prog def sensdash, sortpreserve


#delimit ;

syntax varlist(numeric max=1) [if] [in], 
beta(varname numeric) beta_orig(varname numeric)   
[se(varname numeric) se_orig(varname numeric)] [pval(varname numeric) pval_orig(varname numeric)]   
[shorttitle_orig(string)] [siglevel(numlist max=1 integer)] [extended(numlist max=1 integer)] [aggregation(numlist max=1 integer)]   
[mean(varname numeric)] [mean_orig(varname numeric)]   
[ivarweight(numlist max=1 integer)]   [ivF(varname numeric)]  [signfirst(varname numeric)]

#delimit cr


qui {
	
*** Install packages from SSC
	capture which colrspace.sthlp 
	if _rc == 111 {                 
		noi dis "Installing colrspace"
		quietly ssc install colrspace, replace
	}
	capture which labmask
	if _rc == 111 {                 
		noi dis "Installing labutil"
		quietly ssc install labutil, replace
	}
	capture which colorpalette
	if _rc == 111 {                 
		noi dis "Installing palettes"
		quietly ssc install palettes, replace
	}
	capture which schemepack.sthlp
	if _rc == 111 {                 
		noi dis "Installing schemepack"
		quietly ssc install schemepack, replace
	}
			
		
	preserve
	  
		

		
********************************************************************************
*****  PART 2  DASHBOARD-SPECIFIC SETTINGS 
********************************************************************************
			
*** implement [if] condition
	marksample to_use
	qui keep if `to_use' == 1
  
*** keep variables needed for the dashboard
	keep `varlist' `beta' `beta_orig'   `se' `se_orig' `pval' `pval_orig'   `mean' `mean_orig' `ivF' `signfirst' 

			
	
	
********************************************************************************
*****  PART 3  AUXILIARY VARIABLE GENERATION
********************************************************************************			
		
*** add _j suffix to beta_orig (and below to se_orig) to make explicit that this is information at the outcome level 
		// the suffix _j refers to the outcome level, _i to the specification level
	gen beta_orig_j = `beta_orig'
	drop `beta_orig'  			

*** semi-optional syntax components
	if (("`se'"=="" & "`se_orig'"!="") | ("`se'"!="" & "`se_orig'"=="")) | (("`pval'"=="" & "`pval_orig'"!="") | ("`pval'"!="" & "`pval_orig'"=="")) {
		noi dis "{red: Please specify both se() and se_orig() and/or both pval() and pval_orig(), but not only one of them, respectively}"	
		exit
	}
	
	if "`se'"=="" {
		gen     se_i   		= (`beta')/(invnormal(`pval'/2)*-1) if `beta'>=0
		replace se_i   		= (`beta')/(invnormal(`pval'/2))    if `beta'<0
	}
	else {
		gen se_i        =  `se'	
		drop `se'
	}
	if "`se_orig'"=="" {
	    gen     se_orig_j   = (beta_orig_j)/(invnormal(`pval_orig'/2)*-1) if beta_orig_j>=0
		replace se_orig_j   = (beta_orig_j)/(invnormal(`pval_orig'/2))    if beta_orig_j<0		
	}
	else {
		gen se_orig_j   =  `se_orig'	
		drop `se_orig'
	}
	if "`pval'"=="" {
		gen pval_i = 2*(1 - normal(abs(`beta'/se_i)))
	}
	else {
		gen pval_i = `pval'
		drop `pval'
	}
	if "`pval_orig'"=="" {
		gen pval_orig_j = 2*(1 - normal(abs(beta_orig_j/se_orig_j)))
	}
	else {
		gen pval_orig_j = `pval_orig'
		drop `pval_orig'
	}
	
*** optional syntax components
	if "`shorttitle_orig'"!="" {
		local ytitle_row0 `shorttitle_orig'
	}
	else {
		local ytitle_row0 "original estimate"			
	}
	
	if "`siglevel'"=="" {
		local siglevel 10
	}
	if "`siglevel'"!="" {
		local siglevelnum = "`siglevel'"
		
		if `siglevelnum'<10 {
			local sigdigits 0`siglevel'
		}
		if `siglevelnum'>=10 {
			local sigdigits `siglevel'
		}
		if `siglevelnum'<0 | `siglevelnum'>100 {
			noi dis "{red: Please specify a significance level (siglevel) between 0 and 100}"
			exit
		}
	}
	
	if "`extended'"=="" {
		local extended = 0
	}
	
	if "`aggregation'"=="" {
		local aggregation = 0
	}
	
	if "`mean'"=="" {
		gen mean_j = .
	}
	else {
	    gen mean_j = `mean'
		drop `mean'
	}
	if "`mean_orig'"=="" {
		gen mean_orig_j = mean_j
	}
	else {
	    gen mean_orig_j = `mean_orig'
		drop `mean_orig'
	}

	if "`ivarweight'"=="" {
		local ivarweight = 0
	}
	
		
*** main variable generation, e.g. on the effect direction and the relative effect size based on the adjusted raw dataset	
	gen beta_dir_i        = (`beta'>=0)
	recode beta_dir_i (0 = -1)
	gen beta_rel_i        = `beta'/mean_j*100
	gen se_rel_i          = se_i/mean_j
	
	gen beta_orig_dir_j = (beta_orig_j>=0)
	recode beta_orig_dir_j (0 = -1)
	gen beta_rel_orig_j = beta_orig_j/mean_orig_j*100
	gen se_rel_orig_j   = se_orig_j/mean_orig_j
	
	gen x_beta_abs_orig_p`sigdigits'_j =  se_orig_j*invnormal(1-0.`sigdigits'/2)
	gen x_se_orig_p`sigdigits'_j       =  abs(beta_orig_j)/invnormal(1-0.`sigdigits'/2)
	foreach var in beta_abs se {
		bysort `varlist': egen `var'_orig_p`sigdigits'_j = min(x_`var'_orig_p`sigdigits'_j)
	}	


*** tF Standard Error Adjustment - based on lookup Table from Lee et al. (2022)
	if "`ivF'"!="" {
		global tFinclude  1
		
		matrix tF_c05 = (4,4.008,4.015,4.023,4.031,4.04,4.049,4.059,4.068,4.079,4.09,4.101,4.113,4.125,4.138,4.151,4.166,4.18,4.196,4.212,4.229,4.247,4.265,4.285,4.305,4.326,4.349,4.372,4.396,4.422,4.449,4.477,4.507,4.538,4.57,4.604,4.64,4.678,4.717,4.759,4.803,4.849,4.897,4.948,5.002,5.059,5.119,5.182,5.248,5.319,5.393,5.472,5.556,5.644,5.738,5.838,5.944,6.056,6.176,6.304,6.44,6.585,6.741,6.907,7.085,7.276,7482,7.702,7.94,8.196,8.473,8.773,9.098,9.451,9.835,10.253,10.711,11.214,11.766,12.374,13.048,13.796,14.631,15.566,16.618,17.81,19.167,20.721,22.516,24.605,27.058,29.967,33.457,37.699,42.93,49.495,57.902,68.93,83.823,104.68,100000\9.519,9.305,9.095,8.891,8.691,8.495,8.304,8.117,7.934,7.756,7.581,7.411,7.244,7.081,6.922,6.766,6.614,6.465,6.319,6.177,6.038,5.902,5.77,5.64,5.513,5.389,5.268,5.149,5.033,4.92,4.809,4.701,4.595,4.492,4.391,4.292,4.195,4.101,4.009,3.919,3.83,3.744,3.66,3.578,3.497,3.418,3.341,3.266,3.193,3.121,3.051,2.982,2.915,2.849,2.785,2.723,2.661,2.602,2.543,2.486,2.43,2.375,2.322,2.27,2.218,2.169,2.12,2.072,2.025,1.98,1.935,1.892,1.849,1.808,1.767,1.727,1.688,1.65,1.613,1.577,1.542,1.507,1.473,1.44,1.407,1.376,1.345,1.315,1.285,1.256,1.228,1.2,1.173,1.147,1.121,1.096,1.071,1.047,1.024,1,1)
			
		foreach b in lo hi {
			gen IVF_`b' = .
			gen adj_`b' = .
		}
		forvalues i = 1(1)100 {
			local j = `i'+1
			qui replace IVF_lo = tF_c05[1,`i'] if `ivF' >= tF_c05[1,`i'] & `ivF' < tF_c05[1,`j']
			qui replace IVF_hi = tF_c05[1,`j'] if `ivF' >= tF_c05[1,`i'] & `ivF' < tF_c05[1,`j']
			qui replace adj_hi = tF_c05[2,`i'] if `ivF' >= tF_c05[1,`i'] & `ivF' < tF_c05[1,`j']
			qui replace adj_lo = tF_c05[2,`j'] if `ivF' >= tF_c05[1,`i'] & `ivF' < tF_c05[1,`j']
		}
		local IVF_inf = 4 // to be precise, this value - the threshold where the standard error adjustment factor turn infinite - should be ivF=3.8416, but the matrix from Lee et al. only delivers adjustment values up to 4  ("tends to infinity as F approaches 3.84")
	
		gen     tF_adj = adj_lo + (IVF_hi  - `ivF')/(IVF_hi  - IVF_lo)  * (adj_hi - adj_lo)  //  "tF Standard Error Adjustment value, according to Lee et al. (2022)" 
			
		label var tF_adj "tF Standard Error Adjustment value, according to Lee et al. (2022)"
		drop IVF_* adj_* 						
				
				
		** tF-adjusted SE and p-val
		gen     se_tF = se_i*tF_adj
						
		gen     pval_tF = 2*(1 - normal(abs(`beta'/se_tF)))
		replace pval_tF = 1 if `ivF'<`IVF_inf' 
	}
	else {
		global tFinclude  0
	}


*** information presented in figure note on the number of specifications that are captured by the dashboard 
	qui tab `varlist' 
	local N_outcomes = `r(r)'
	
	bysort `varlist': gen N_specs_by_outcome = _N
	qui sum N_specs_by_outcome
	local N_specs_min = `r(min)'
	local N_specs_max = `r(max)'
	
	egen x_N_outcomes_min = group(outcome) if N_specs_by_outcome==`N_specs_min'
	egen x_N_outcomes_max = group(outcome) if N_specs_by_outcome==`N_specs_max'
	egen N_outcomes_min = max(x_N_outcomes_min)
	egen N_outcomes_max = max(x_N_outcomes_max)
	
	decode `varlist', gen(outcome_str)
	gen spec_min_outcome = outcome_str if N_specs_by_outcome==`N_specs_min'
	gen spec_max_outcome = outcome_str if N_specs_by_outcome==`N_specs_max'	
	gsort -spec_min_outcome
	local spec_min = spec_min_outcome
	if N_outcomes_min>1 {
		local spec_min "multiple outcomes"
	}
	gsort -spec_max_outcome
	local spec_max = spec_max_outcome
	if N_outcomes_max>1 {
		local spec_max "multiple outcomes"
	}


*** information on share of outcomes with originally sig./ insig. estimates
	bysort `varlist': gen x_n_j = _n
	gen x_pval_osig_d_j = (pval_orig_j<0.`sigdigits') if x_n_j==1
	egen x_pval_osig_d  = total(x_pval_osig_d_j)
	local shareosig  "`: display x_pval_osig_d  "`=char(47)'"  `N_outcomes' '"    
	gen x_pval_onsig_d_j = (pval_orig_j>=0.`sigdigits') if x_n_j==1
	egen x_pval_onsig_d  = total(x_pval_onsig_d_j)
	local shareonsig "`: display x_pval_onsig_d  "`=char(47)'"  `N_outcomes' '"
	
	drop x_* spec_min_outcome spec_max_outcome  N_outcomes_min N_outcomes_max
	
	
	
	
********************************************************************************
*****  PART 4  INDICATOR DEFINITIONS 
********************************************************************************
			
************************************************************
***  PART 4.A  INDICATORS BY OUTCOME
************************************************************	
		
*** Indicators by outcome and by column of the dashboard
	
	** column 1
	// beta_orig_j  pval_orig_j 
	
	
	** column 2
	                  gen x_d_pval_insigrep_i 	= abs(pval_i-pval_orig_j)					if pval_i>=0.`sigdigits'
	bysort `varlist': egen  d_pval_insigrep_j 	= mean(x_d_pval_insigrep_i)
	
	
					   gen x_b_op`sigdigits'_insigrep_i  = (abs(`beta')<=beta_abs_orig_p`sigdigits'_j)*100	if pval_i>=0.`sigdigits'		// multiples of 0.1 cannot be held exactly in binary in Stata -> shares converted to range from 1/100, not from 0.01 to 1.00
	bysort `varlist': egen   b_op`sigdigits'_insigrep_j	 = mean(x_b_op`sigdigits'_insigrep_i)
	                   gen x_se_op`sigdigits'_insigrep_i = (se_i>=se_orig_p`sigdigits'_j)*100					if pval_i>=0.`sigdigits'
	bysort `varlist': egen   se_op`sigdigits'_insigrep_j = mean(x_se_op`sigdigits'_insigrep_i)

	
	** column 3
	                   gen x_sig`sigdigits'ndir_i		= (pval_i<0.`sigdigits' & beta_dir_i!=beta_orig_dir_j)*100
	bysort `varlist': egen   sig`sigdigits'ndir_j      	= mean(x_sig`sigdigits'ndir_i) 
			
	
	** column 4
					   gen x_sig`sigdigits'dir_i		= (pval_i<0.`sigdigits' & beta_dir_i==beta_orig_dir_j)*100
	bysort `varlist': egen   sig`sigdigits'dir_j    	= mean(x_sig`sigdigits'dir_i)    			

	if "$tFinclude"=="1" {
						   gen x_sig05tFdir_i			= (pval_tF<0.05 & beta_dir_i==beta_orig_dir_j)*100
		bysort `varlist': egen   sig05tFdir_j  			= mean(x_sig05tFdir_i)	
	}
	
	if `siglevelnum'!=5  {
					       gen x_sig05dir_i				= (pval_i<0.05  & beta_dir_i==beta_orig_dir_j)*100
		bysort `varlist': egen   sig05dir_j  			= mean(x_sig05dir_i)
	}
	
	                   gen x_b_up`sigdigits'_sig`sigdigits'rep_i  = (abs(`beta')>beta_abs_orig_p`sigdigits'_j)*100	if beta_dir_i==beta_orig_dir_j & pval_i<0.`sigdigits'
	bysort `varlist': egen   b_up`sigdigits'_sig`sigdigits'rep_j  = mean(x_b_up`sigdigits'_sig`sigdigits'rep_i)
					   gen x_se_up`sigdigits'_sig`sigdigits'rep_i = (se_i<se_orig_p`sigdigits'_j)*100				if beta_dir_i==beta_orig_dir_j & pval_i<0.`sigdigits'
	bysort `varlist': egen   se_up`sigdigits'_sig`sigdigits'rep_j = mean(x_se_up`sigdigits'_sig`sigdigits'rep_i)

	
	bysort `varlist': egen x_b_rlmd_sig`sigdigits'rep_j2 = median(`beta')							if beta_dir_i==beta_orig_dir_j & pval_i<0.`sigdigits'
					   gen x_b_rlmd_sig`sigdigits'rep_j  =   x_b_rlmd_sig`sigdigits'rep_j2/beta_orig_j 
					   gen   b_rlmd_sig`sigdigits'rep_j  = ((x_b_rlmd_sig`sigdigits'rep_j) - 1)*100
	

					   gen x_d_b_rlmd_sig`sigdigits'rep_i = abs(`beta'-x_b_rlmd_sig`sigdigits'rep_j2) 	    	
	bysort `varlist': egen x_d_b_rlmd_sig`sigdigits'rep_j = mean(x_d_b_rlmd_sig`sigdigits'rep_i)    if beta_dir_i==beta_orig_dir_j & pval_i<0.`sigdigits'
		               gen   d_b_rlmd_sig`sigdigits'rep_j = (x_d_b_rlmd_sig`sigdigits'rep_j/abs(beta_orig_j))*100
					   		   
	local collapselast  d_b_rlmd_sig`sigdigits'rep_j
	

	** Weights for inverse-variance weighting 
	if `ivarweight'==1 {
		bysort `varlist': egen x_se_rel_mean_j  = mean(se_rel_i)	
						   gen        weight_j  = 1/(x_se_rel_mean_j^2)
	
						   gen    weight_orig_j = 1/(se_rel_orig_j^2)
			
		local collapselast weight_orig_j
	}
						   
	drop x_*
	

*** Collapse indicator values to one obs per outcome
	ds d_pval_insigrep_j - `collapselast'
	foreach var in `r(varlist)' {
		bysort `varlist': egen c`var' = min(`var') 
		drop `var'
		rename c`var' `var'
	}
	
	bysort `varlist': gen n_j = _n
	
	keep if n_j==1
	drop n_j  `beta' se_i pval_i beta_dir_i beta_rel_i se_rel_i   // drop information at a different level than the aggregated level
	capture drop `ivF' tF_adj se_tF pval_tF
	if `aggregation'==1 {
		drop mean_j mean_orig_j N_specs_by_outcome
	}

	
	
************************************************************
***  PART 4.B  INDICATORS OVER ALL OUTCOMES
************************************************************
	
*** different indicators to be shown depending on whether IV/ tF is included
	if "$tFinclude"=="1" {
		if `siglevelnum'!=5 {
			local sig05dir        sig05dir        sig05tFdir
			local sig05dir_j      sig05dir_j      sig05tFdir_j
			local sig05dir_`sigdigits'o    sig05dir_`sigdigits'o    sig05tFdir_`sigdigits'o
			local sig05dir_insigo sig05dir_insigo sig05tFdir_insigo
		}
		if `siglevelnum'==5 {
			local sig05dir        sig05tFdir
			local sig05dir_j      sig05tFdir_j
			local sig05dir_`sigdigits'o    sig05tFdir_`sigdigits'o
			local sig05dir_insigo sig05tFdir_insigo
		}
	}
	if "$tFinclude"!="1" {
		if `siglevelnum'!=5 {
			local sig05dir        sig05dir
			local sig05dir_j      sig05dir_j
			local sig05dir_`sigdigits'o    sig05dir_`sigdigits'o
			local sig05dir_insigo sig05dir_insigo
		}
		if `siglevelnum'==5 {
			local sig05dir        
			local sig05dir_j      
			local sig05dir_`sigdigits'o    
			local sig05dir_insigo 
		}
	}

	
*** Indicators over all outcomes
	if `aggregation'==1 {
		if `ivarweight'==1 {
			egen x_total_weight 	   			= total(weight_j)
			egen x_total_`sigdigits'o_weight    = total(weight_j) 			if pval_orig_j<0.`sigdigits'
			egen x_total_insigo_weight 			= total(weight_j) 			if pval_orig_j>=0.`sigdigits'
		}
		
		** original indicator sig, revised indicator sig at `sigdigits'% level
		foreach o_inds in d_pval_insigrep b_op`sigdigits'_insigrep  se_op`sigdigits'_insigrep   sig`sigdigits'dir sig`sigdigits'ndir   b_rlmd_sig`sigdigits'rep d_b_rlmd_sig`sigdigits'rep		`sig05dir' {
			if `ivarweight'==0 {
				egen `o_inds'_`sigdigits'o_all  = mean(`o_inds'_j) 											if pval_orig_j<0.`sigdigits'
			}
			if `ivarweight'==1 {				
				egen `o_inds'_`sigdigits'o_all  = total(`o_inds'_j*weight_j/x_total_`sigdigits'o_weight)   	if pval_orig_j<0.`sigdigits'
			}
		}			
		
		** original indicator insig, revised indicator sig at `sigdigits'% level
		foreach o_indi in d_pval_insigrep b_up`sigdigits'_sig`sigdigits'rep se_up`sigdigits'_sig`sigdigits'rep  sig`sigdigits'dir sig`sigdigits'ndir   b_rlmd_sig`sigdigits'rep d_b_rlmd_sig`sigdigits'rep 	`sig05dir' {
			if `ivarweight'==0 {
				egen `o_indi'_insigo_all = mean(`o_indi'_j) 		if pval_orig_j>=0.`sigdigits'
			}
			if `ivarweight'==1 {		
				egen `o_indi'_insigo_all = total(`o_indi'_j*weight_j/x_total_insigo_weight) if pval_orig_j>=0.`sigdigits'
			}
		}
			
		** any original indicator sig level, revised indicator sig at `sigdigits'% level
		foreach o_indi in                                                                 				   b_rlmd_sig`sigdigits'rep d_b_rlmd_sig`sigdigits'rep                       {
			if `ivarweight'==0 {
				egen `o_indi'_anyo_all = mean(`o_indi'_j)
			}
			if `ivarweight'==1 {
				egen `o_indi'_anyo_all = total(`o_indi'_j*weight_j/x_total_weight)
			}
		}
		if `ivarweight'==0 {
			egen anyrep_o`sigdigits'_all = mean(pval_orig_j<0.`sigdigits')
		}
		if `ivarweight'==1 {
			gen  x_anyrep_o`sigdigits'_j  = (pval_orig_j<0.`sigdigits')
			egen   anyrep_o`sigdigits'_all = total(x_anyrep_o`sigdigits'_j*weight_j/x_total_weight)		
		}
		
		** copy information to all outcomes
		ds *_all
		foreach var in `r(varlist)' {
			egen c`var' = mean(`var') 
			drop `var'
			rename c`var' `var'
		}
	}	
					

		
	
********************************************************************************
*****  PART 5  DASHBOARD VISUALIZATION 
********************************************************************************

************************************************************
***  PART 5.A  PREPARE DASHBOARD GRAPH DATA
************************************************************
		
*** Prepare data structure and y- and x-axis

	if `aggregation'==1 {
		keep if inlist(`varlist',1)       	// keep one observation across outcomes
		drop `varlist' outcome_str *_j		// drop variables at outcome level 
		expand 2
		gen y = _n
		local yset_n = 2 
		global ylab 1 `" "significant" " " "{sup:`shareosig' outcomes}" "' 2 `" "insignificant" "({it:p}{&ge}0.`sigdigits')" " " "{sup:`shareonsig' outcomes}" "'	// first y entry shows up at bottom of y-axis of the dashboard	
	}
	else { 
		sort `varlist'
		egen y = group(`varlist')    // make sure that varlist is numbered consecutively from 1 on
		local yset_n = `N_outcomes'			// # of items shown on y-axis = # of outcomes
		
		** reverse order of outcome numbering as outcomes are presented in reverse order on the y-axis of the dashboard
		tostring `varlist', replace
		labmask y, values(outcome_str) lblname(ylab)	
		
		if `N_outcomes'==2 | `N_outcomes'==3 {
			recode y (1=`N_outcomes') (`N_outcomes'=1)
			global ylab `"   `=y[1]' "`=outcome_str[1]'" `=y[2]' "`=outcome_str[2]'"  "'
		}
		if `N_outcomes'==3 {
			global ylab `"   `=y[1]' "`=outcome_str[1]'" `=y[2]' "`=outcome_str[2]'" `=y[3]' "`=outcome_str[3]'" "'
		}	
		if `N_outcomes'==4 {
			recode y (1=4) (4=1) (2=3) (3=2)
			global ylab `"   `=y[1]' "`=outcome_str[1]'" `=y[2]' "`=outcome_str[2]'" `=y[3]' "`=outcome_str[3]'" `=y[4]' "`=outcome_str[4]'"  "'
		}
		if `N_outcomes'==5 {
			recode y (1=5) (5=1) (2=4) (4=2)
			global ylab `"   `=y[1]' "`=outcome_str[1]'" `=y[2]' "`=outcome_str[2]'" `=y[3]' "`=outcome_str[3]'" `=y[4]' "`=outcome_str[4]'" `=y[5]' "`=outcome_str[5]'"  "'
		}
		
		if `N_outcomes'>5 {
			noi dis "{red: Please use option -sensdash, [...] aggregation(1)- with more than five outcomes to be displayed}"				
			exit
		}									
		drop `varlist' outcome_str
	}
	
	local xset  insig  sig_ndir  sig_dir
	local xlab 1 `" "insignificant" "({it:p}{&ge}0.`sigdigits')" "' 2 `" "significant," "opposite sign" "' 3 `" "significant," "same sign" "'
	local xset_n : word count `xset'
	
	expand `xset_n'
	bysort y: gen x = _n
	
	
	** labelling of y-axis 
	if `aggregation'==1 {
		local aux `" "Original" "results" "'
		local ytitle  ytitle(`aux', orient(horizontal))
	}
	else {
		local ytitle ytitle("") // empty global, no ytitle to show up
	}
	

*** Calculate sensitivity indicators
	if `aggregation'==1 {
		// in order to calculate the shares in ALL original results [and not differentiated by originally sig or insig] multiply x_share_2x and `styper'_insigo_all by (1 - anyrep_o`sigdigits'_all) and x_share_1x and `styper'_`sigdigits'o_all by anyrep_o`sigdigits'_all
		gen x_share_21 =  (100 - sig`sigdigits'dir_insigo_all - sig`sigdigits'ndir_insigo_all)	if y==2 & x==1	// top left     (insig orig & insig rev)            = (100 - sig rev)
		gen x_share_22 =                               			sig`sigdigits'ndir_insigo_all	if y==2 & x==2	// top middle   (insig orig & sig   rev, diff sign) =      sig rev not dir
		gen x_share_23 =         sig`sigdigits'dir_insigo_all						 			if y==2 & x==3	// top right    (insig orig & sig   rev, same sign) = sig rev     dir
		
		gen x_share_11 =  (100 - sig`sigdigits'dir_`sigdigits'o_all - sig`sigdigits'ndir_`sigdigits'o_all)  if y==1 & x==1  // bottom left   (sig & insig)			 			=      (100 - sig rev)
		gen x_share_12 =                            			sig`sigdigits'ndir_`sigdigits'o_all 		if y==1 & x==2	// bottom middle (sig & sig, diff sign)				=      (100 - sig rev not dir)
		gen x_share_13 =         sig`sigdigits'dir_`sigdigits'o_all 				    if y==1 & x==3	// bottom right  (sig & sig, same sign)				=      (100 - sig rev     dir)
  	    
		for num 1/3: replace x_share_1X = 0 											if y==1 & x==X & anyrep_o`sigdigits'_all==0 & x_share_1X==.			// replace missing by zero if none of the original estimates was sig
		for num 1/3: replace x_share_2X = 0 											if y==2 & x==X & anyrep_o`sigdigits'_all==1 & x_share_2X==.   		// replace missing by zero if all of the original estimates were sig
		 
		 
		foreach styper in `sig05dir' {
			replace `styper'_insigo_all 		= `styper'_insigo_all  // top right  (insig orig & sig rev)
			replace `styper'_`sigdigits'o_all   = `styper'_`sigdigits'o_all     // bottom right (sig orig & sig rev)
		}
	}		
	else {
		for num 1/`yset_n': gen x_share_X1 = 100 - sig`sigdigits'dir_j - sig`sigdigits'ndir_j  	if y==X		// insig outcome X
		for num 1/`yset_n': gen x_share_X2 =       sig`sigdigits'ndir_j  						if y==X		//   sig outcome X, not dir
		for num 1/`yset_n': gen x_share_X3 =       sig`sigdigits'dir_j  						if y==X		//   sig outcome X, same dir
	
		foreach var in beta_orig_j beta_rel_orig_j pval_orig_j sig`sigdigits'dir_j `sig05dir_j'  d_pval_insigrep_j   se_op`sigdigits'_insigrep_j b_op`sigdigits'_insigrep_j   b_up`sigdigits'_sig`sigdigits'rep_j se_up`sigdigits'_sig`sigdigits'rep_j      b_rlmd_sig`sigdigits'rep_j d_b_rlmd_sig`sigdigits'rep_j {
			for num 1/`yset_n': gen   x_`var'X = `var' if y==X
			for num 1/`yset_n': egen    `var'X = mean(x_`var'X)	
		}
	}
	

*** Format indicators for presentation in the dashboard
	forval qy = 1/`yset_n' {
		forval qx = 1/3 {
			egen    share_`qy'`qx' = min(x_share_`qy'`qx')
			gen x_share_`qy'`qx'_2 = floor(share_`qy'`qx')			
			gen x_sharerounder_`qy'`qx' = x_share_`qy'`qx' - x_share_`qy'`qx'_2	// these variables contain information on the third+ digit and guarantee below that shares add up to 1 (i.e. 100%) 
			replace share_`qy'`qx' = round(share_`qy'`qx')
		}
	}
	
	foreach shvar in share x_sharerounder {		
		gen     `shvar' = `shvar'_11 if y==1 & x==1
		for num 2/3: replace `shvar' = `shvar'_1X if y==1 & x==X
		for num 2/`yset_n': replace `shvar' = `shvar'_X1 if y==X & x==1
		for num 2/`yset_n': replace `shvar' = `shvar'_X2 if y==X & x==2
		for num 2/`yset_n': replace `shvar' = `shvar'_X3 if y==X & x==3
	}
	
	
	*if `aggregation'==1 {
	*		gen share_roundingdiff = (100-(share_21 + share_22 + share_23 + share_11 + share_12 + share_13))
	*}
	*else {
			gen     share_roundingdiff = (100-(share_11 + share_12 + share_13)) if y==1
			for num 2/`yset_n': replace share_roundingdiff = (1-(share_X1 + share_X2 + share_X3))*100 if y==X
	*}
	
	if share_roundingdiff<0 {		// sum of shares exceeds 100%
			egen sharerounder = rank(x_sharerounder) if x_sharerounder>=0.5, unique
			replace share = share - 1 if sharerounder<=abs(share_roundingdiff)    // the X shares with the lowest digits are reduced in cases where the sum of shares is 10X
	} 
	if share_roundingdiff>0 {		// sum of shares falls below 100%
			egen sharerounder = rank(x_sharerounder) if x_sharerounder<0.5, field
			replace share = share + 1 if sharerounder<=share_roundingdiff		// the X shares with the highest digits are increased in cases where the sum of shares is 100 - X
	} 
	
	drop x_* share_roundingdiff
	capture drop sharerounder
	
	
		  
************************************************************
***  PART 5.B  PREPARE PLOTTING OF DASHBOARD GRAPH DATA
************************************************************
	  
*** Colouring of circles: lighter colour if non-confirmatory revised result, darker colour if confirmatory revised result
	if (c(version)>=14.2) {
		colorpalette lin fruit, nograph
		local col p3
		local col_lowint  0.35
		local col_highint 0.8
	}
	else {	
		colorpalette9, nograph
		local col p1
		local col_lowint  0.25
		local col_highint 0.55
	}
	
	gen     colorname_nonconfirm = "`r(`col')'*`col_lowint'"		// definition of colour used for non-fonfirmatory and confirmatory results - required for legend to dashboard graph
	gen     colorname_confirm    = "`r(`col')'*`col_highint'"
	
	gen     colorname   = colorname_nonconfirm
	if `aggregation'==1 {
		replace colorname = colorname_confirm  if (y==2 & x==1) | (y==1 & x==3)
	}
	if `aggregation'==0 {
		forval k = 1/`yset_n' {
			replace colorname = colorname_confirm  if y==`k' & x==3 & pval_orig_j`k'<0.`sigdigits'
			replace colorname = colorname_confirm  if y==`k' & x==1 & pval_orig_j`k'>=0.`sigdigits'
		}
	}
	

*** Saving the plotting codes in locals
	local slist ""
	forval i = 1/`=_N' {
		local slist "`slist' (scatteri `=y[`i']' `=x[`i']' "`: display %3.0f =share[`i'] "%" '", mlabposition(0) mlabsize(medsmall) msize(`=share[`i']*0.5*(0.75^(`yset_n'-2))') mcolor("`=colorname[`i']'"))"     // msize defines the size of the circles
	}
		  
	if "`signfirst'"=="" {
		local yx0b   // empty local
	}
	else {
		local yx0b	`" "wrong-sign" "first stages:"  "`: display %3.0f `signfirst'*100 "%" '" "'	 
	}
	
	
	** aggregation across outcomes
	if `aggregation'==1 {			
		foreach r0 in  b_rlmd_sig`sigdigits'rep_`sigdigits'o d_b_rlmd_sig`sigdigits'rep_`sigdigits'o   b_rlmd_sig`sigdigits'rep_insigo d_b_rlmd_sig`sigdigits'rep_insigo   `sig05dir_10o'   `sig05dir_insigo' {
			replace   `r0'_all = round(`r0'_all)		
		}
		
		local sign_d_insig ""
		if b_rlmd_sig`sigdigits'rep_insigo_all>0 {
			local sign_d_insig "+"
		}
		if b_rlmd_sig`sigdigits'rep_insigo_all==0 {
			local sign_d_insig "+/-"
		}
		local sign_d_sig ""
		if b_rlmd_sig`sigdigits'rep_`sigdigits'o_all>0 {
			local sign_d_sig "+" 
		}
		if b_rlmd_sig`sigdigits'rep_`sigdigits'o_all==0 {
			local sign_d_sig "+/-" 
		}
		local xleft = 0.6
		
		local y2x0	""
		local y1x0	"" 			

		local y2x1	"" 
		if share_21>0 & anyrep_o`sigdigits'_all!=1 {
			local y2x1	`" "`: display "`=ustrunescape("\u0394\u0305\u0070")': " %3.2f d_pval_insigrep_insigo_all'" "'	 
		}
	
		if `extended'==0 {
			if share_23>0 & anyrep_o`sigdigits'_all!=1 {
				if "$tFinclude"=="1" {
					if `siglevelnum'!=5 {
					    local y2x3	`" "`: display "{it:p}<0.05: "  `=sig05dir_insigo_all' "% ({it:tF}: "  `=sig05tFdir_insigo_all' "%)" '" "'
					}
					if `siglevelnum'==5 {
					    local y2x3	`" "`: display "{it:tF}: "  `=sig05tFdir_insigo_all' "%)" '" "'
					}
				}
				if "$tFinclude"!="1" & `siglevelnum'!=5  {
					local y2x3	`" "`: display "{it:p}<0.05: "  `=sig05dir_insigo_all' "%" '"  "'
				}
			}
			if share_11>0 & anyrep_o`sigdigits'_all!=0 {
				local y1x1 	`" "`: display "`=ustrunescape("\u0394\u0305\u0070")': " %3.2f d_pval_insigrep_`sigdigits'o_all'"  "'
			}
			if share_13>0 & anyrep_o`sigdigits'_all!=0 {
				if "$tFinclude"=="1" {
				    if `siglevelnum'!=5 {
						local y1x3	`" "`: display "{it:p}<0.05: "  `=sig05dir_`sigdigits'o_all' "% ({it:tF}: "  `=sig05tFdir_`sigdigits'o_all' "%)" '"     "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig'" b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "%)" '"  "'
					}
					if `siglevelnum'==5 {
						local y1x3	`" "`: display "{it:tF}: "  `=sig05tFdir_`sigdigits'o_all' "%)" '"     "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig'" b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "%)" '"  "'
					}
				}
				if "$tFinclude"!="1" {
				    if `siglevelnum'!=5 {
						local y1x3	`" "`: display "{it:p}<0.05: "  `=sig05dir_`sigdigits'o_all' "%" '"                                            "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig'" b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "%)" '"  "'
					}
					if `siglevelnum'==5 {
						local y1x3	`" "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig'" b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "%)" '"  "'
					}
				}
			}	
		}
		else {
			if share_23>0 & anyrep_o`sigdigits'_all!=1 {
				if "$tFinclude"=="1" {
					if `siglevelnum'!=5 {
						local y2x3	`" "`: display "{it:p}<0.05: "  `=sig05dir_insigo_all' "% ({it:tF}: "  `=sig05tFdir_insigo_all' "%)" '"   "`: display "high |{&beta}|: " %3.0f b_up`sigdigits'_sig`sigdigits'rep_insigo_all "%" '"   "`: display "low se: " %3.0f se_up`sigdigits'_sig`sigdigits'rep_insigo_all "%" '" "'	 
					}
					if `siglevelnum'==5 {
						local y2x3	`" "`: display "{it:tF}: "  `=sig05tFdir_insigo_all' "%)" '"   "`: display "high |{&beta}|: " %3.0f b_up`sigdigits'_sig`sigdigits'rep_insigo_all "%" '"   "`: display "low se: " %3.0f se_up`sigdigits'_sig`sigdigits'rep_insigo_all "%" '" "'	 
					}
				}
				if "$tFinclude"!="1" {
					if `siglevelnum'!=5 {
						local y2x3	`" "`: display "{it:p}<0.05: "  `=sig05dir_insigo_all' "%" '"                                             "`: display "high |{&beta}|: " %3.0f b_up`sigdigits'_sig`sigdigits'rep_insigo_all "%" '"   "`: display "low se: " %3.0f se_up`sigdigits'_sig`sigdigits'rep_insigo_all "%" '" "'
					}
					if `siglevelnum'==5 {
						local y2x3	`" "`: display "high |{&beta}|: " %3.0f b_up`sigdigits'_sig`sigdigits'rep_insigo_all "%" '"   "`: display "low se: " %3.0f se_up`sigdigits'_sig`sigdigits'rep_insigo_all "%" '" "'
					}
				}
			}
			if share_11>0 & anyrep_o`sigdigits'_all!=0 {
				local y1x1 	`" "`: display "`=ustrunescape("\u0394\u0305\u0070")': " %3.2f d_pval_insigrep_`sigdigits'o_all'"    "`: display "low |{&beta}|: " %3.0f b_op`sigdigits'_insigrep_`sigdigits'o_all "%" '"   "`: display "high se: " %3.0f se_op`sigdigits'_insigrep_`sigdigits'o_all "%" '" "' 
			}
			if share_13>0 & anyrep_o`sigdigits'_all!=0 { 
				if "$tFinclude"=="1" {
				    if `siglevelnum'!=5 {
						local y1x3	`" "`: display "{it:p}<0.05: "  `=sig05dir_`sigdigits'o_all' "% ({it:tF}: "  `=sig05tFdir_`sigdigits'o_all' "%)" '"     "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig'" b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "%)" '"  "'
					}
					if `siglevelnum'==5 {
						local y1x3	`" "`: display "{it:tF}: "  `=sig05tFdir_`sigdigits'o_all' "%)" '"     "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig'" b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "%)" '"  "'
					}
				}
				if "$tFinclude"!="1" {
				    if `siglevelnum'!=5 {
						local y1x3	`" "`: display "{it:p}<0.05: "  `=sig05dir_`sigdigits'o_all' "%" '"                                            "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig'" b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "%)" '"  "'
					}
					if `siglevelnum'==5 {
						local y1x3	`" "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig'" b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_`sigdigits'o_all "%)" '"  "'
					}
				}
			}
		}
	}	
	** no aggregation across outcomes
	else {
		foreach var2 in  beta_rel_orig_j   sig`sigdigits'dir_j `sig05dir_j'   b_rlmd_sig`sigdigits'rep_j d_b_rlmd_sig`sigdigits'rep_j {
			for num 1/`yset_n': replace `var2'X = round(`var2'X)
		}
		
		local xleft = 0.0
		
		forval k = 1/`yset_n' {
			local sign_d_orig`k' ""
			if beta_orig_j`k'>0 {
				local sign_d_orig`k' "+" 
			}
			if beta_orig_j`k'==0 {
				local sign_d_orig`k' "+/-" 
			}
			
			local sign_d_sig`k' ""
			if b_rlmd_sig`sigdigits'rep_j`k'>0 {
				local sign_d_sig`k' "+" 
			}
			if b_rlmd_sig`sigdigits'rep_j`k'==0 {
				local sign_d_sig`k' "+/-" 
			}
			
			if beta_rel_orig_j==. {
				local y`k'x0		`" "`: display "{it:`ytitle_row0'}" '"	"`: display "{&beta}: " %3.2f beta_orig_j`k'[1]'"   	"`: display "{it:p}: " %3.2f pval_orig_j`k'[1]'" "'
			}
			else {
			    local y`k'x0		`" "`: display "{it:`ytitle_row0'}" '"	"`: display "{&beta}: " %3.2f beta_orig_j`k'[1] " [`sign_d_orig`k''" beta_rel_orig_j`k' "%]" '"   	"`: display "{it:p}: " %3.2f pval_orig_j`k'[1]'" "'
			}
			
			if `extended'==0 {
				if share_`k'1>0 {
					local y`k'x1  	`" "`: display "`=ustrunescape("\u0394\u0305\u0070")': " %3.2f d_pval_insigrep_j`k''"  "'				
				}
				if share_`k'3>0 {
					if pval_orig_j`k'<0.`sigdigits' {
						if "$tFinclude"=="1" {
						    if `siglevelnum'!=5 {
								local y`k'x3  	`" "`: display "{it:p}<0.05: "  `=sig05dir_j`k'' "% ({it:tF}: "  `=sig05tFdir_j`k'' "%)" '"    		"`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig`k''" b_rlmd_sig`sigdigits'rep_j`k' "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_j`k' "%)" '"  "'
							}
							if `siglevelnum'==5 {
								local y`k'x3  	`" "`: display "{it:tF}: "  `=sig05tFdir_j`k'' "%)" '"    		"`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig`k''" b_rlmd_sig`sigdigits'rep_j`k' "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_j`k' "%)" '"  "'
							}		
						}
						if "$tFinclude"!="1" {
						    if `siglevelnum'!=5 {
								local y`k'x3  	`" "`: display "{it:p}<0.05: "  `=sig05dir_j`k'' "%" '"    		                                    "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig`k''" b_rlmd_sig`sigdigits'rep_j`k' "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_j`k' "%)" '"  "'
							}
							if `siglevelnum'==5 {
								local y`k'x3  	`" "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig`k''" b_rlmd_sig`sigdigits'rep_j`k' "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_j`k' "%)" '"  "'
							}						
						}
					}
					if pval_orig_j`k'>=0.`sigdigits' {
						if "$tFinclude"=="1" {
						    if `siglevelnum'!=5 {
								local y`k'x3  	`" "`: display "{it:p}<0.05: "  `=sig05dir_j`k'' "% ({it:tF}: "  `=sig05tFdir_j`k'' "%)" '"  "'
							}
							if `siglevelnum'==5 {
								local y`k'x3  	`" "`: display "{it:tF}: "  `=sig05tFdir_j`k'' "%)" '"  "'
							}
						}
						if "$tFinclude"!="1" & `siglevelnum'!=5 {
							local y`k'x3  	`" "`: display "{it:p}<0.05: "  `=sig05dir_j`k'' "%" '" "'
						}
					}
				}				
			}
			else {
				if share_`k'1>0 {
					if pval_orig_j`k'<0.`sigdigits' {
						local y`k'x1  	`" "`: display "`=ustrunescape("\u0394\u0305\u0070")': " %3.2f d_pval_insigrep_j`k''"    "`: display "low |{&beta}|: " %3.0f b_op`sigdigits'_insigrep_j`k' "%" '"    "`: display "high se: " %3.0f se_op`sigdigits'_insigrep_j`k' "%" '" "'
					}
					if pval_orig_j`k'>=0.`sigdigits' {
						local y`k'x1  	`" "`: display "`=ustrunescape("\u0394\u0305\u0070")': " %3.2f d_pval_insigrep_j`k''"  "'
					}						
				}
				if share_`k'3>0 {
					if pval_orig_j`k'<0.`sigdigits' {
						if "$tFinclude"=="1" {
						    if `siglevelnum'!=5 {
								local y`k'x3  	`" "`: display "{it:p}<0.05: "  `=sig05dir_j`k'' "% ({it:tF}: "  `=sig05tFdir_j`k'' "%)" '"    		"`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig`k''" b_rlmd_sig`sigdigits'rep_j`k' "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_j`k' "%)" '"  "'
							}
							if `siglevelnum'==5 {
								local y`k'x3  	`" "`: display "{it:tF}: "  `=sig05tFdir_j`k'' "%)" '"    		"`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig`k''" b_rlmd_sig`sigdigits'rep_j`k' "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_j`k' "%)" '"  "'
							}
						}
						if "$tFinclude"!="1" {
						    if `siglevelnum'!=5 {
								local y`k'x3  	`" "`: display "{it:p}<0.05: "  `=sig05dir_j`k'' "%" '"    		                                    "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig`k''" b_rlmd_sig`sigdigits'rep_j`k' "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_j`k' "%)" '"  "'
							}
							if `siglevelnum'==5 {
								local y`k'x3  	`" "`: display "`=ustrunescape("\u03B2\u0303")': `sign_d_sig`k''" b_rlmd_sig`sigdigits'rep_j`k' "% (`=ustrunescape("\u0394\u0305\u03B2\u0303")': " d_b_rlmd_sig`sigdigits'rep_j`k' "%)" '"  "'
							}
						}
					}
					if pval_orig_j`k'>=0.`sigdigits' {
						if "$tFinclude"=="1" {
						    if `siglevelnum'!=5 {
								local y`k'x3  	`" "`: display "{it:p}<0.05: "  `=sig05dir_j`k'' "% ({it:tF}: "  `=sig05tFdir_j`k'' "%)" '"    		"`: display "high |{&beta}|: " %3.0f b_up`sigdigits'_sig`sigdigits'rep_j`k' "%" '"    "`: display "low se: " %3.0f se_up`sigdigits'_sig`sigdigits'rep_j`k' "%" '"  "'
							}
							if `siglevelnum'==5 {
								local y`k'x3  	`" "`: display "{it:tF}: "  `=sig05tFdir_j`k'' "%)" '"    		"`: display "high |{&beta}|: " %3.0f b_up`sigdigits'_sig`sigdigits'rep_j`k' "%" '"    "`: display "low se: " %3.0f se_up`sigdigits'_sig`sigdigits'rep_j`k' "%" '"  "'
							}
						}
						if "$tFinclude"!="1" {
						    if `siglevelnum'!=5 {
							local y`k'x3  	`" "`: display "{it:p}<0.05: "  `=sig05dir_j`k'' "%" '"    											"`: display "high |{&beta}|: " %3.0f b_up`sigdigits'_sig`sigdigits'rep_j`k' "%" '"    "`: display "low se: " %3.0f se_up`sigdigits'_sig`sigdigits'rep_j`k' "%" '"  "'
							}
							if `siglevelnum'==5 {
							local y`k'x3  	`" "`: display "high |{&beta}|: " %3.0f b_up`sigdigits'_sig`sigdigits'rep_j`k' "%" '"    "`: display "low se: " %3.0f se_up`sigdigits'_sig`sigdigits'rep_j`k' "%" '"  "'
							}
						}
					}
				}
			}	
		}
	}
	
			
*** Specifying content of figure note
	local tsize vsmall
	local specs specifications
	if (`N_specs_min'==`N_specs_max' & `N_specs_max'==1) {
	   local specs specification 
	}
	if  `N_specs_min'==`N_specs_max' {
		local N_specs `N_specs_max'
	}
	
	
	if `aggregation'==1 {
		local notes_spec 	based on `N_outcomes' outcomes with `N_specs' `specs' each
	}	
	if  `N_specs_min'!=`N_specs_max' {
		local N_specs "`N_specs_min' (`spec_min') to `N_specs_max' (`spec_max')"
		if `aggregation'==1 {
			local notes_spec 	based on `N_outcomes' outcomes with `N_specs' `specs'
		}
	}
	if `aggregation'==0 {
		local notes_spec 	based on `N_specs' `specs'
		if `N_outcomes'>1 &  `N_specs_min'==`N_specs_max' {
			local notes_spec 	based on `N_specs' `specs' for each outcome
		}
	}


*** Specifying location of indicators in dashboard depending on the number of outcomes/ y-axis entries presented
	local t_col0  ""
	if `aggregation'==1 {
		local t_col0b "text(`=1/2*`yset_n'+0.5'                      0.75 `yx0b' , size(`tsize'))"
	}
	else {
		local t_col0b "text(`=1/2*`yset_n'+0.5'                      0.6  `yx0b' , size(`tsize'))"
	}
	local t_col1  ""
	local t_col3  ""
	forval k = 1/`yset_n' {
		local t_col0  "`t_col0'  text(`k'                        0.2 `y`k'x0', size(`tsize'))"  
		local t_col1  "`t_col1'  text(`=`k'-0.2-(`yset_n'-2)*0.05' 1 `y`k'x1', size(`tsize'))"
		local t_col3  "`t_col3'  text(`=`k'-0.2-(`yset_n'-2)*0.05' 3 `y`k'x3', size(`tsize'))"
	}
	
	local yupper = 2.5 + (`yset_n'-2)*0.9
	

			
************************************************************
***  PART 5.C  PLOTTING OF THE DASHBOARD
************************************************************

	twoway (scatteri `=y[0]' `=x[0]', mcolor("`=colorname_confirm[1]'")) (scatteri `=y[0]' `=x[0]', mcolor("`=colorname_nonconfirm[1]'")) ///
		`slist', ///
		`ytitle' xtitle("Replication results") ///
		xscale(range(`xleft' 3.5) /*alt*/) yscale(range(0.5 `yupper')) ///
		xlabel(`xlab', labsize(2.5)) ylabel($ylab, labsize(2.5)) ///
		`t_col0' `t_col0b' `t_col1' `t_col3'  ///
		legend(rows(1) order(1 "confirmatory replication results" 2 "non-confirmatory replication results") size(2.5) position(6) bmargin(tiny))  ///
		graphregion(color(white)) scheme(white_tableau)  
			// first line of this twoway command does not show up in the dashboard but is required to make the legend show up with the correct colours 
		

			
************************************************************
***  PART 5.D  NOTES TO DASHBOARD IN STATA RESULTS WINDOW
************************************************************

	noi dis _newline(1) "{it:Notes:} graph shows shares of specifications - `notes_spec'"
	noi dis _newline(1) "`=ustrunescape("\u03B2")' = beta coefficient"
	noi dis             "{it:p} = {it:p}-value (default relies on two-sided test assuming an approximately normal distribution)" 
	noi dis				"`=ustrunescape("\u03B2\u0303")' = median beta coefficient in replication, measured as % deviation from original beta coefficient; generally, tildes indicate median values"
	noi dis 			"`=ustrunescape("\u0394\u0305")' = mean absolute deviation"
	if `aggregation'==0 {
		if beta_rel_orig_j!=. {
			noi dis 		"[+/-xx%] = Percentage in squared brackets refers to the original beta coefficient, expressed as % deviation from mean of the outcome"
		}
	}    
	if `extended'==1 {
		noi dis 		"low |`=ustrunescape("\u03B2")'| (high se) refers to the share of specifications where the revised absolute value of the beta coefficient (standard error) is sufficiently low (high) to turn the overall estimate insignificant at the `siglevelnum'% level" 
	}
	if "$tFinclude"=="1" {
		noi dis  		"{it:tF} indicates the share of statistically significant estimates at the {it:tF}-adjusted 5% level, using the {it:tF} adjustment proposed by Lee et al. (2022, AER)"
	}

	
	
	restore
}
end
*** End of file



use "$my_workdir/leases_$version_string.dta", clear

/* three small data corrections on date */
replace date_of_trade=mdy(11,19,2004) if transfer_id==815
replace date_of_trade=mdy(3,4,2005) if transfer_id==1902
replace date_of_trade=mdy(2,28,2005) if transfer_id==1859


gen price=dollar/quantity


/* Add in length and hp from MQRS
These are not baselines
 */

preserve 
tempfile seller buyer




 use "$my_workdir/mqrs_old_2018_09_26.dta", clear
replace date_cancelled=dofc(date_cancelled)
replace date_eligible=dofc(date_eligible)
format date_cancelled date_eligible %td

gen cph_seller=(strmatch(auth_type,"CPH") | strmatch(auth_type,"*HISTORY*"))

keep right_id len hp date_e date_c cph
rename right_id right_id_seller 
rename len len_seller
rename hp hp_seller
rename date_cancelled date_cancelled_seller
rename date_eligible date_eligible_seller

sort right_id
save `seller'


use "$my_workdir/mqrs_old_2018_09_26.dta", clear
replace date_cancelled=dofc(date_cancelled)
replace date_eligible=dofc(date_eligible)
format date_cancelled date_eligible %td

gen cph_buyer=(strmatch(auth_type,"CPH") | strmatch(auth_type,"*HISTORY*"))

rename right_id right_id_buyer
rename len len_buyer
rename hp hp_buyer
sort right_id
rename date_cancelled date_cancelled_buyer
rename date_eligible date_eligible_buyer

save `buyer'

restore
gen markorig=1

joinby right_id_seller using `seller', unmatched(master)
assert _merge==3

rename _merge m1
gen marksell=0
replace marksell=1 if date_of_trade>=date_eligible_seller & (date_of_trade<=date_cancelled_seller | date_cancelled_seller==.)

keep if marksell==1 

joinby right_id_buyer using `buyer', unmatched(master)
assert _merge==3
rename _merge m2
gen markbuy=0
replace markbuy=1 if date_of_trade>=date_eligible_buyer & (date_of_trade<=date_cancelled_buyer | date_cancelled_buyer==.)
keep if markbuy==1 



drop  date_cancelled_*  date_eligible_*
drop markbuy marksell m2 m1 


foreach var of varlist len_seller hp_seller len_buyer hp_buyer{
rename `var'  mqrs_`var'
}


preserve
/* Add in length and hp from Permit
These are not baselines
 */
tempfile perm_s perm_b
use "$my_workdir/permit_portfolio_2017_01_18.dta", clear
keep permit len vhp fishing_year
rename permit permit_seller
rename len len_seller
rename vhp hp_seller
save `perm_s'
rename permit permit_buyer
rename len len_buyer
rename hp hp_buyer
save `perm_b'

restore

merge m:1 permit_seller fishing_year using `perm_s', keep(1 3)
rename _merge  mps

merge m:1 permit_buyer fishing_year using `perm_b', keep(1 3)
rename _merge  mpb

foreach var of varlist len_seller hp_seller len_buyer hp_buyer{
rename `var'  perm_`var'
}


/* Add in length and hp from DAS.baselines
These are  baselines
 */
 preserve
global date_string "2018_10_03"

use "$my_workdir/right_id_baselines_$date_string.dta", replace
tempfile base_s base_b
rename right_id right_id_seller
rename hp hpb_s
rename len lenb_s
save `base_s'

rename right_id right_id_buyer
rename hp hpb_b
rename len lenb_b

save `base_b'
restore

joinby right_id_seller using `base_s', unmatched(master)
assert _merge==3

rename _merge m3
gen marksellbase=0
replace marksellbase=1 if date_of_trade>=start_date & (date_of_trade<=end_date | end_date==.)
keep if marksellbase==1 
drop start_date end_date




joinby right_id_buyer using `base_b', unmatched(master)
assert _merge==3
rename _merge m4
gen markbuybase=0
replace markbuybase=1 if date_of_trade>=start_date & (date_of_trade<=end_date | end_date==.)
keep if markbuybase==1 






/* construct a length variable for buyers based on baseline. If that match fails, construct it from MQRS. If that fails, construct it from the permit data 
repeat for sellers. repeat for horsepower */

order mps mpb , last
gen len_s=hpb_s

replace len_s=mqrs_len_seller if len_s==.
replace len_s=perm_len_seller if len_s==.


gen len_b=hpb_b
replace len_b=mqrs_len_b if len_b==.
replace len_b=perm_len_b if len_b==.



gen lens=len_s+len_b
gen lend=len_s-len_b



gen hp_s=hpb_s
replace hp_s=mqrs_hp_seller if hp_s==.
replace hp_s=perm_hp_seller if hp_s==.

gen hp_b=hpb_b
replace hp_b=mqrs_hp_b if hp_b==.
replace hp_b=perm_hp_b if hp_b==.



gen  hps=hp_s+hp_b
gen hpd=hp_s-hp_b

gen fystart=mdy(5,1,fishing_year)
gen elapsed=date_of_trade-fys

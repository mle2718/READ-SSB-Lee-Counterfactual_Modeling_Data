/*This file constructs a DAS available variable
The trade restrictions are 
	1.10  length
	1.20  HP
It produces two datasets 
buyers_days_left: right_id_buyer, date, daysleft. For this dataset, daysleft is the number of days left that the right_id_buyer could purchase from. This is the total A-DAS held by
	a vessel that is no smaller than (1/1.1)x the baseline length of right_id_buyer and no smaller than (1/1.2)x the baseline hp of the right_id_buyer
	
seller_days_left: right_id_seller, date, daysleft For this dataset, daysleft is the number of days left that the right_id_seller could sell to. This is the total A-DAS held by
	a vessel that is no larger than (1.1)x the baseline length of right_id_seler and no larger than (1.2)x the baseline hp of the right_id_seller
It 

*/







pause on


global version_string 2017_11_02



#delimit;
clear;

quietly do "/home/mlee/Documents/Workspace/technical folder/do file scraps/odbc_connection_macros.do";
global oracle_cxn "conn("$mysole_conn") lower";
local date: display %td_CCYY_NN_DD date(c(current_date), "DMY");
global today_date_string = subinstr(trim("`date'"), " " , "_", .);



/* extract and process the baselines and baseline changes through the end of 2009. */
odbc load,  exec("select * from mults_baseline;") $oracle_cxn;  
gen baseline=1;
tempfile initial_base;
save `initial_base';
clear;
odbc load,  exec("select * from mults_das_baseline_downgrade;") $oracle_cxn;  
replace start_date=dofc(start_date);
gen marker=1;

append using `initial_base';
format start_date %td;
sort right_id start_date marker;
gen end_date=.;
bysort right_id (start_date): replace end_date=start_date[_n-1]-1;
format end_date %td;
drop permit_number;
replace end_date=date(c(current_date), "DMY") if end_date==. & strmatch(downgraded,"");
replace start_date=mdy(1,1,1994) if start_date==.;
format start_date end_date %td;
drop marker downgraded baseline;


save "$my_workdir/right_id_baselines_$today_date_string.dta", replace;


/* construct permit-mri linkages */

/* The DAS and DAS2 allocations are affected by the AUTH_ID and RIGHT_ID fuck up. 
	For a set of "cleanedup up RIGHT_IDs" the appropriate thing to do is substitue the AUTH_ID for the RIGHT_ID.


AMS and beyond ARE NOT.  This includes SECTOR PARTICIPANTS.

I think the strategy is to pull forward the "broken" right id. all the way until I need to do AMS and Sector things. 

*/
/*two small programs that correct and reverse the cleanup Right IDs */
do "$my_codedir/auth_id_fixer.do";


clear;

odbc load,  exec("SELECT app_num,
		PER_NUM AS PERMIT,
		right_id,
		AUTH_ID,
		DATE_ELIGIBLE,
		DATE_CANCELLED,
		LEN as LENMQ,
		HP as HPMQ,
		AUTH_TYPE
	  FROM MQRS.MORT_ELIG_CRITERIA 
	WHERE AUTH_ID in (1179,1183,1187,1196,1219,1255,1261,1293,1296,1362,1374,2423,1174, 1184, 1176, 1209,1298,1358,1372,2423, 1192, 2101, 1205, 1181, 1259, 1315,1204, 1297, 1308 )
	  AND FISHERY = 'MULTISPECIES'
	  AND not ((TRUNC(DATE_ELIGIBLE) =  TRUNC(NVL(DATE_CANCELLED,SYSDATE+20000))) AND (CANCEL_REASON_CODE = 7 AND AUTH_TYPE = 'BASELINE'))
	  AND DATE_ELIGIBLE IS NOT NULL
	  AND (TRUNC(DATE_CANCELLED) >= '01-MAY-03' or DATE_CANCELLED IS NULL);") $oracle_cxn;  
tempfile new_old_mri;
keep right_id auth_id date_e date_c lenmq hpmq;
save `new_old_mri', replace;
clear;


tempfile p1 permit_mri;
odbc load,  exec("SELECT app_num,
		PER_NUM AS PERMIT,
		AUTH_ID,
		RIGHT_ID AS MRI,
		DATE_ELIGIBLE,
		DATE_CANCELLED,
		LEN as LENMQ,
		HP as HPMQ,
		AUTH_TYPE
	  FROM MQRS.MORT_ELIG_CRITERIA 
	  WHERE FISHERY = 'MULTISPECIES'
		AND AUTH_ID NOT in (1179,1183,1187,1196,1219,1255,1261,1293,1296,1362,1374,2423,1174, 1184, 1176, 1209,1298,1358,1372,2423)
		AND not ((TRUNC(DATE_ELIGIBLE) =  TRUNC(NVL(DATE_CANCELLED,SYSDATE+20000))) AND (CANCEL_REASON_CODE = 7 AND AUTH_TYPE = 'BASELINE'))
		AND DATE_ELIGIBLE IS NOT NULL
		AND (TRUNC(DATE_CANCELLED) >= '01-MAY-03' or DATE_CANCELLED IS NULL);") $oracle_cxn;  
save `p1', replace;
clear;
odbc load,  exec("SELECT app_num,
		PER_NUM AS PERMIT,
		AUTH_ID AS MRI,
		RIGHT_ID as BROKEN_MRI,
		DATE_ELIGIBLE,
		DATE_CANCELLED,
		LEN as LENMQ,
		HP as HPMQ,
		AUTH_TYPE
	  FROM MQRS.MORT_ELIG_CRITERIA 
	WHERE AUTH_ID in (1179,1183,1187,1196,1219,1255,1261,1293,1296,1362,1374,2423,1174, 1184, 1176, 1209,1298,1358,1372,2423)
	  AND FISHERY = 'MULTISPECIES'
	  AND not ((TRUNC(DATE_ELIGIBLE) =  TRUNC(NVL(DATE_CANCELLED,SYSDATE+20000))) AND (CANCEL_REASON_CODE = 7 AND AUTH_TYPE = 'BASELINE'))
	  AND DATE_ELIGIBLE IS NOT NULL
	  AND (TRUNC(DATE_CANCELLED) >= '01-MAY-03' or DATE_CANCELLED IS NULL);") $oracle_cxn;  
append using `p1';

#delimit cr

replace date_eligible=dofc(date_eligible)
replace date_cancelled=dofc(date_cancelled)

format date_e date_c %td

/* one duplicate entry in mqrs */
drop if app_num==1027271
drop app_num
replace auth_type="CPH" if auth_type=="HISTORY RETENTION"
dups , drop terse

/* This uses the DAS-style right_ids*/

save `permit_mri', replace


/* Fix the baselines */

























/****************************************************/
/****************************************************/
/* beginning  of leasing segment */
/* the leases are constructed on Right ids*/
/****************************************************/
/****************************************************/
tempfile leaseout leaseall

/* read in das-leasing dataset */
/* construct the lease-out subset*/
use "$my_workdir/leases_$version_string.dta", clear
keep permit_seller right_id_seller quantity date_of_trade fishing_year schema
rename date date
rename permit permit
rename right_id right_id
/* collapse to the right_id-date level, retain fishing year for convenience */
collapse (sum) quantity, by(date right_id fishing_year schema)
/* lease-outs are negative */
replace quantity=-1*quantity
/* usage marked as a negative */
assert quantity<=0

gen type="lease out"

save `leaseout', replace
/* read in das-leasing dataset */
/* construct the lease-in subset*/

use "$my_workdir/leases_$version_string.dta", clear
keep permit_buyer right_id_buyer quantity date_of_trade fishing_year schema
rename permit permit
rename date date
rename right_id right_id
/* collapse to the right_id-date level, retain fishing year for convenience */

collapse (sum) quantity, by(date right_id fishing_year schema)
gen type="lease in"


/* lease-ins are negative */

append using `leaseout'

/* after appending the leaseout data, collapse again to take care of permits that lease in and lease out on the same day */
collapse (sum) quantity, by(date right_id fishing_year schema)
gen type= "net lease"
rename right_id mri

/* use the permit-mri table to pull in length and hp from MQRS as the 2nd alternative to BASELINE HP and LEN*/
count
local start=r(N)
gen id=_n
tempfile tester
cleanout_right_ids mri

save `tester'


joinby mri using `permit_mri', unmatched(master)
format date %td

assert _merge==3
drop _merge
count if date>=date_eligible & (date<=date_cancelled | date_cancelled==.)

gen mark=0
replace mark=1 if date>=date_eligible & (date<=date_cancelled | date_cancelled==.)

bysort id: egen matched=total(mark)
order matched, after(mark)
count if match==0
/* need to make sure that there is exactly one id that doesn't match */ 
qui tab id if match==0
assert r(N)==r(r)

/* manually fix these */ 
replace mark=1 if inlist(mri,1179,1183,1187,1196,1219,1255,1261,1293,1296,1362,1374,2423,1174, 1184, 1176, 1209,1219,1298,1358,1372,2423) & match==0
keep if mark==1

 
/* there's still a couple double-matched. This happens if I have the bad luck for a trade to occur on the same day an MRI was switched
I will keep the record with the larger lenmq
*/
bysort id (lenmq): keep if _n==_N

 
count
local end=r(N)
assert `start'==`end'
drop id _expand mark matched
save `leaseall'

/* end of leasing segment */




/****************************************************/
/****************************************************/
/* beginning  of das usage segment */
/* these are built on permit numbers*/
/****************************************************/
/****************************************************/





/* read in das-usage dataset */
use "$my_workdir/das_usage_$version_string.dta",clear
keep permit date_sail date_land fishing_year charge schema
/* I'm going to use date_sail as date_used, unless date_sail is in april of the previous  FY . Then I will use dateland */

replace date_sail=dofc(date_sail)
replace date_land=dofc(date_land)
format date_sail date_land %td

rename date_sail date_used

replace date_used=mdy(9,25,2008) if date_used==mdy(9,25,3008)

/* cast to td and fix a data error */

gen fyhand=year(date_used)
replace fyhand=fyhand-1 if month(date_used)<=4


replace date_used=date_land if month(date_used)==4 & fishing_year>fyhand
drop fyhand 

gen fyhand=year(date_used)
replace fyhand=fyhand-1 if month(date_used)<=4
drop if fyhand~=fishing

gen type="used"
rename charge quantity

/* collapse to the permit-date level, retain fishing year and schema for convenience and error checking */
collapse (sum) quantity, by(permit date_used fishing_year schema)
/* usage marked as a negative */
replace quantity=-1*quantity
assert quantity<=0

rename date_used date
gen type= "trips"
gen id=_n
count
tempfile  all
save `all'


joinby permit using `permit_mri', unmatched(master)
rename _merge _jbm



count
/*  
1. Trip entries must match to 'valid' links using the date fields
2. If a trip matches to a CPH record, this is invalid
3. If there is a DAS used, but no MRI, this is invalid and an artifact of the MONK counting of A-Days

  */
/* deal with #1 */
keep if date>=date_eligible & (date<=date_cancelled | date_cancelled==.)
/* deal with #2 */
drop if auth_type=="CPH"
format date %td
bysort id: gen count=_N

/* fix the stupid auth_id/right_id bullshit */
gen tag=0
replace tag=1 if inlist(mri,1179,1183,1187,1196,1219,1255,1261,1293,1296,1362,1374,2423,1174, 1184, 1176, 1209,1219,1298,1358,1372,2423)
bysort id: egen tt=total(tag)
drop if count>=2 & tt==1 & tag==0
drop count
bysort id: gen count=_N
drop tag tt count _expand
/* if the trip matched to two right_ids, keep the one with the largest date_cancelled or where date_cancelled is null */

bysort id (date_cancelled): keep if _n==_N
count
desc

drop _jbm id
count

append using `leaseall'
notes: A little wrong because leased days cannot be subleased.






save "$my_workdir/DAS_counterparties_$today_date_string.dta", replace




/* work on initial allocations */

clear
use "$my_workdir/mqrs_annual_2018_10_05.dta", clear

/*zero out the permit numbers for the CPH vessels */
bysort permit fishing_year: gen tt=_N
replace permit=. if tt>=2 & type_auth=="CPH"
drop tt

/*recheck */
bysort permit fishing_year: gen tt=_N
/* the only entries with tt>1 should be for permit==.*/
drop tt
gen date=mdy(5,1,fishing_year)
gen tag_start=-1
rename mri right_id
gen schema="mqannual"
format date %td



cleanout_right_ids right_id



append using "$my_workdir/DAS_counterparties_$today_date_string.dta"
/* there may be duplicates here, if there were leases that were processed or trips that started on May 1  */


/*permit_mri allows me to associate permits with mris and mqrs lengths.  


there will be some entries in the DAS_Usage_lease that do not have MRIS. this is because of the MNK silliness.
So my joinby leaves out all mismatches*/

replace right_id=mri if right_id==.

drop mri date_e date_c type_auth auth_id

replace quantity=categoryA if quant==. & schema=="mqannual"
/*******************************************
ONE MORE THING TO DO.  THERE are "dupes" if there are 2 things happening on the same day.  

I think  You should

collapse (sum) quantity, by(right_id permit fishing_year date lenmq hpmq)

**************************************/





/*fillin missing hp and len from mq data */
gen n=date*-1


bysort right_id (date): replace hp=hp[_n-1] if hp==.
bysort right_id (n): replace hp=hp[_n-1] if hp==.


bysort right_id (date): replace len=len[_n-1] if len==.
bysort right_id (n): replace len=len[_n-1] if len==.

/* aggregate to the permit-right_id date level */
collapse (sum) quantity (first) lenmq hpmq, by(right_id permit fishing_year date)

keep fishing_year right_id permit  date len hp quantity
cleanout_right_ids right_id

count
gen id=_n





/* I need to retain any das usages that do not match to a baseline. Not sure why something wouldn't have a baseline, but whatver*/
joinby right_id using "$my_workdir/right_id_baselines_$today_date_string.dta" , unmatched(master)

count
keep if (date>=start_date & date<=end_date) | _merge==1
tsset id
local m=r(gaps)
assert `m'==0

/* this verifies  there's nothing missing*/
replace len=lenmq if len==.,
replace hp=hpmq if hp==.


drop lenmq hpmq


replace hp=450 if hp==. & right_id==3
replace hp=540 if hp==. & right_id==1880
replace hp=308 if hp==. & right_id==1917
replace hp=300 if hp==. & right_id==4295
replace len=35 if len==. & right_id==4295

replace hp=250 if permit==132200 & hp==.
replace len=23 if permit==132200 & len==.

replace hp=200 if permit==147512 & hp==.
replace len=25 if permit==147512 & len==.

replace hp=250 if permit==148652 & hp==.
replace len=24 if permit==148652 & len==.




replace hp=240 if permit==149065 & hp==.
replace len=25 if permit==149065 & len==.

replace hp=260  if permit==149603 & hp==.
replace len=24 if permit==149603 & len==.




replace hp=90 if permit==150558 & hp==.
replace len=21 if permit==150558 & len==.

replace hp=375 if permit==213369 & hp==.
replace len=35 if permit==213369 & len==.


replace hp=135 if permit==214072 & hp==.
replace len=31 if permit==214072 & len==.

replace hp=600 if permit==214351 & hp==.
replace len=31 if permit==214351 & len==.

replace hp=200  if permit==220227 & hp==.
replace len=34 if permit==220227 & len==.

replace hp=450 if permit==233204 & hp==.
replace len=36 if permit==233204 & len==.

replace hp=176 if permit==240278 & hp==.
replace len=45 if permit==240278 & len==.

replace hp=437 if permit==241948 & hp==.
replace len=39 if permit==241948 & len==.

replace hp=220 if permit==146603 & hp==.
replace len=30 if permit==146603 & len==.

replace hp=460 if permit==242611 & hp==.
replace len=42 if permit==242611 & len==.

replace hp=25 if permit==149793 & hp==.
replace len=17 if permit==242611 & len==.


replace hp=450 if right_id==2223& hp==.









drop _merge
drop start_date end_date
drop id


collapse (sum) quantity, by(right_id fishing_year date hp len)
drop if date<=mdy(4,30,2004)
tsset right_id date

tsfill, full
gen neg=date*-1

/* I want to fill in hp and len. */

bysort right_id (date): replace hp=hp[_n-1] if hp==.
bysort right_id (date): replace len=len[_n-1] if len==.


bysort right_id (neg): replace hp=hp[_n-1] if hp==.
bysort right_id (neg): replace len=len[_n-1] if len==.
replace fishing_year=year(date)
replace fishing_year=fishing_year-1 if month(date)<=4
replace quantity=0 if quantity==.

drop neg

bysort right fishing (date): gen daysleft=sum(quantity)
/* this is a little broken because there are some right id's that didn't get an allocation on may 1 that eventually leased or transferred in days and fished. 
So there's negative daysleft. this isn't abig deal -it should
be offset by right_ids that did get an allocation */

*bysort right_id (date): replace daysleft=daysleft[_n-1] if daysleft==.

keep if fishing_year<=2016

cleanout_right_ids right_id






/* need to work on this 
undo- the cleanout of right ids so it will merge correctly to the MQRS-derived sector data*/
reverse_cleanout right_id
merge m:1 right_id fishing_year using sector_year_roster_2017_10_23.dta
drop vp_num hull_id auth_type auth_id


/*I expect some 1's -- these are for before the sector system 
I expect some 2's these are vessels in the roster 
There's also some 1's that are in 2010-2016. These are weird.  These got no A days either
*/
drop if _merge==2
assert quantity==0 if _merge==1 & fishing_year>=2010
assert daysleft==0 if _merge==1 & fishing_year==2010
/*merge and then cast the DAS back to the DAS-style to do merges with  */
drop _merge

cleanout_right_ids right_id


save "$my_workdir/DAS_counterparties_$today_date_string.dta", replace


/*Two issues
1. During the post-period trades can only be sector-sector or cp-cp.
DAS Leases post-sectors can only be within sector vessels OR within CP
DAS TRANSFERS post-sectors can only be within A sector OR within CP. This is slightly different than the LEASE rules*/


/* The post-sample */


/* trading rules are a little different before and after sector implementation. 
Easiest to split the sample */
use "$my_workdir/DAS_counterparties_$today_date_string.dta", replace

/* trading rules are a little different before and after sector implementation. 
Easiest to split the sample */
keep if date>=mdy(5,1,2010)

replace sector=0 if sector==2
replace sector=1 if sector>=1


timer clear
tempfile joiner joiner2 sellers buyers

gen float df=float(round(daysleft,.01))

gen float len2=float(round(len,.1))
drop daysleft len

rename df daysleft
rename len2 len
compress
save `joiner', replace

/* build a dataset for the sellers...how many DAS are owned by entities that this seller can sell to 

A chunk of 50 right_ids takes about 240seconds to run. So about 90 minutes to run the counterparties. 23 loops.

*/




rename right_id right_id_seller
rename hp hp_seller
rename len len_seller
keep right_id_seller hp_seller len date sector
egen int myg=group(right_id)

/* how many groups to loop over */
bysort myg: gen byte nvals=_n==1
count if nvals
local distinct=r(N)
drop nvals


save `sellers'




use `joiner', replace


rename right_id right_id_buyer
rename hp hp_buyer
rename len len_buyer
keep right_id_buyer hp_buyer len_buyer date sector
gen len_low=len_buyer/1.1
egen int myg=group(right_id)

timer on 7


bysort myg: gen byte nvals=_n==1
count if nvals
local distinct=r(N)
drop nvals


save `buyers'

use `joiner', replace
drop if daysleft==0 
collapse (sum) daysleft, by(sector date)
save `joiner2', replace



use `buyers'
merge m:1 sector_id date using `joiner2'
assert _merge==3

drop _merge
save "$my_workdir/buyers_days_left_post$today_date_string.dta", replace



use `sellers'
merge m:1 sector_id date using `joiner2'
assert _merge==3
drop _merge

save "$my_workdir/seller_days_left_post$today_date_string.dta", replace




























/*  The rangejoins take a long time to run (12 hours or so total) on the full dataset*/
use "$my_workdir/DAS_counterparties_$today_date_string.dta", replace

/* trading rules are a little different before and after sector implementation. 
Easiest to split the sample */
keep if date<mdy(5,1,2010)

timer clear
tempfile joiner joiner2 sellers buyers

gen float df=float(round(daysleft,.01))

gen float len2=float(round(len,.1))
drop daysleft len

rename df daysleft
rename len2 len
compress
save `joiner', replace

/* build a dataset for the sellers...how many DAS are owned by entities that this seller can sell to 

A chunk of 50 right_ids takes about 240seconds to run. So about 90 minutes to run the counterparties. 23 loops.

*/




rename right_id right_id_seller
rename hp hp_seller
rename len len_seller
keep right_id_seller hp_seller len date
gen len_high=len_seller*1.1
egen int myg=group(right_id)

/* how many groups to loop over */
bysort myg: gen byte nvals=_n==1
count if nvals
local distinct=r(N)
drop nvals


save `sellers'




use `joiner', replace


rename right_id right_id_buyer
rename hp hp_buyer
rename len len_buyer
keep right_id_buyer hp_buyer len_buyer date
gen len_low=len_buyer/1.1
egen int myg=group(right_id)

timer on 7


bysort myg: gen byte nvals=_n==1
count if nvals
local distinct=r(N)
drop nvals


save `buyers'

use `joiner', replace
drop if daysleft==0
save `joiner2', replace








local loopnum 1

local chunk 19

local first=1
local last=`first'+`chunk'

while `last'<=`distinct'+`chunk'{
timer on 11
/*loop admin stuff */
	tempfile new
	local files `"`files'"`new'" "'  
	/*end loop admin stuff */

	use `sellers', clear
	keep if myg>=`first' & myg<=`last'
	noisily di "Now Joining  observations `first' to `last'"
	rangejoin len 0 len_high using `joiner2', by(date)
	noisily di "Finshed"

	drop if right_id_seller==right_id
	gen hp_high=hp_seller*1.2
	keep if hp<=hp_high
	collapse (sum) daysleft, by(right_id_seller date)
	replace daysleft=round(daysleft,.01)
	quietly save `new'
	clear
/* more loop admin stuff */
	local first=`last'+1
	local last=`first'+`chunk'
	local ++loopnum
/* end more loop admin stuff */
timer off 11
}
di "last is `last'"
di "loopnum is `loopnum'"
clear
dsconcat `files'
timer list
save "$my_workdir/seller_days_left_pre_$today_date_string.dta", replace


/*

You could probably run  this in parallel by splitting into 2 instances. But that's a pain.
*/


/* build a dataset for the buyers...how many DAS are owned by entities that this buyer could buy from

A chunk of 50 right_ids takes about 240seconds to run. So about 90 minutes to run the counterparties. 23 loops.

*/




local loopnum 1

local chunk 19

local first=1
local last=`first'+`chunk'

while `last'<=`distinct'+`chunk'{
timer on 22
/*loop admin stuff */
	tempfile new2
	local files2 `"`files2'"`new2'" "'  
	/*end loop admin stuff */

	use `buyers', clear
	keep if myg>=`first' & myg<=`last'
	noisily di "Now Joining  observations `first' to `last'"
rangejoin len len_low . using  `joiner2', by(date)
	noisily di "Finshed"
	drop if right_id_buyer==right_id
	gen hp_low=hp_buyer/1.2

	drop if hp<hp_low
	collapse (sum) daysleft, by(right_id_buyer date)
	replace daysleft=round(daysleft,.01)
	quietly save `new2'
	clear
/* more loop admin stuff */
	local first=`last'+1
	local last=`first'+`chunk'
	local ++loopnum
/* end more loop admin stuff */
timer off 22
}
di "last is `last'"
di "loopnum is `loopnum'"
clear
dsconcat `files2'
timer list

save "$my_workdir/buyers_days_left_pre$today_date_string.dta", replace
append using "$my_workdir/buyers_days_left_post$today_date_string.dta"
keep right_id_b date daysleft
save "$my_workdir/buyers_days_left_$today_date_string.dta"




use "$my_workdir/seller_days_left_pre_$today_date_string.dta", replace
append using "$my_workdir/seller_days_left_post$today_date_string.dta"
keep right_id date daysleft
save "$my_workdir/seller_days_left_$today_date_string.dta"

! rm "$my_workdir/buyers_days_left_pre$today_date_string.dta" "$my_workdir/buyers_days_left_post$today_date_string.dta"
! rm "$my_workdir/seller_days_left_pre_$today_date_string.dta" "$my_workdir/seller_days_left_post$today_date_string.dta"


use "$my_workdir/DAS_counterparties_$today_date_string.dta", replace
collapse (sum) daysleft, by(date)
compress
save "$my_workdir/all_DAS_left$today_date_string.dta", replace



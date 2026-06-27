/*an overwiew of our dataset*/
proc import datafile="/home/u64508851/in-vehicle-coupon-recommendation.csv"
out=mydata
dbms=csv
replace;
getnames=yes;
guessingrows=max;
run;
/*This dataset represents a marketing study about coupon acceptance behavior.
The goal is to analyze and predict whether a customer will accept a coupon (Y = 1)
or reject it (Y = 0) based on different personal, environmental, and situational factors.
Each row represents a single customer decision instance.
Destination: where the customer is going (e.g., No Urgent Place, Work, Home).
Passenger: who is accompanying the customer (Alone, Friends, Kids, etc.).
Weather: weather conditions during the decision (Sunny, Rainy, etc.).
Temperature: environmental temperature at the time of decision.
Time: time of day when the coupon is offered.
Coupon type: type of place offering the coupon (Coffee House, Restaurant, Bar, etc.).
Expiration: how long the coupon is valid (1 day or 2 hours).
Demographic features include gender, age, marital status, education, occupation, and income.
Behavioral features include travel direction, distance, and habits.

 info about data*/
proc contents data=mydata;
run;
*has rows =12684 , have both numerical & categorical features, has missing values,
can cosider y(coupon) as target value ;
/*Problem Definition:
The problem addressed in this study is to analyze customer behavior in response to promotional coupons 
and to predict whether a customer will accept or reject a coupon based on various contextual, 
demographic, and environmental factors.
These factors include destination, passenger type, weather conditions, temperature, time of day,
type of coupon, expiration time, and customer demographics such as age, gender, marital status, 
occupation, and income.
The objective is to build a predictive model that helps understand the key factors influencing coupon acceptance 
and supports better marketing decision-making by targeting the right customers at the right time.*/ 


/*missing values*/
proc means data=mydata n nmiss;
run;
/*first 10 observations*/
proc print data=mydata(obs=10);
run;
/*frequency for each column*/
proc freq data=mydata;
tables _all_ / missing;
run;


/* Data Exploring*/

/*Over view*/
proc contents data=mydata;
run;
/*number of duplicates*/
proc sort data=mydata out=mydata_sorted noduprecs dupout=dups_only;
    by _all_;
run;

proc print data=dups_only;
run;

/*Target Variable*/
proc freq data=mydata;
    tables Y;
run;

proc sgplot data=mydata;
    vbar Y / stat=percent datalabel;
    yaxis label="Percentage %";
    xaxis label="Y (0=Reject, 1=Accept)";
    title "Coupon Acceptance vs Rejection";
run;

/*Columns Type*/
proc contents data=mydata
out=cols(keep=name type) noprint;
run;

/* Split into numeric & categorical */
data num_cols cat_cols;
set cols;
if type=1 then output num_cols;
else output cat_cols;
run;

/* Summary statistics for numeric data */
proc means data=mydata mean std min max median;
    var temperature has_children 
        toCoupon_GEQ5min toCoupon_GEQ15min toCoupon_GEQ25min
        direction_same direction_opp;
run;

/* Histograms for all numeric */
proc univariate data=mydata;
    var temperature;
    histogram;
run;

proc freq data=mydata;
	tables Y has_children 
        toCoupon_GEQ5min toCoupon_GEQ15min toCoupon_GEQ25min
        direction_same direction_opp;
run;

/* Boxplots (Outliers detection) */
proc sgplot data=mydata;
    vbox temperature;
    title "Boxplot: Temperature";
run;

/* Numeric vs Target */
proc means data=mydata mean std;
class Y;
var _numeric_;
run;


/* Frequency for all categorical */
proc freq data=mydata;
    tables (destination passanger weather time coupon expiration
           gender age maritalStatus education occupation income
           Bar CoffeeHouse CarryAway RestaurantLessThan20 Restaurant20To50)
           / plots=freqplot;
run;

/* Categorical vs Target */
proc freq data=mydata;
tables _character_ * Y / chisq nocol nopercent;
run;

/* Correlation */
proc corr data=mydata plots=matrix(histogram);
var _numeric_;
run;

/* Categorical visualization with target */
proc sgplot data=mydata;
vbox temperature / category=Y;
run;

proc sgplot data=mydata;
    vbar weather / group=Y groupdisplay=cluster stat=percent;
    title "Weather vs Coupon Decision";
run;

proc sgplot data=mydata;
    vbar time / group=Y groupdisplay=cluster stat=percent;
    title "Time vs Coupon Decision";
run;

proc sgplot data=mydata;
    vbar coupon / group=Y groupdisplay=cluster stat=percent;
    title "Coupon Type vs Decision";
run;

proc sgplot data=mydata;
    vbar age / group=Y groupdisplay=cluster stat=percent;
    title "Age vs Coupon Decision";
run;




/*  Removing exact duplicate rows */
/* The 'noduprecs' option removes rows that are 100% identical across all columns. 
   Duplicates are stored in 'removed_dups' for verification. */
proc sort data=mydata 
          out=mydata_unique 
          noduprecs 
          dupout=removed_dups;
    by _all_; 
run;


/*  Verification of Data Reduction */
/* Comparing the row count before and after the removal process.
   Original: 12,684 records | After: 12,610 records (74 removed). */
  
proc sql;
    title "Data Integrity Check: Row Count Comparison";
    select 'Original Dataset' as Table_Name, count(*) as Total_Rows from mydata
    union all
    select 'Cleaned Dataset (Unique)' as Table_Name, count(*) as Total_Rows from mydata_unique;
quit;



/* DATA CLEANING */

data mydata_clean;
    set mydata_unique;


  /* 1. Using an Array to process all character variables efficiently */
    /* This prevents redundant categories like " Sunny" and "Sunny" 
       from being treated as different groups. */
    array char_cols _character_;
    
    do i = 1 to dim(char_cols);
        /* The STRIP function removes both leading and trailing blanks */
        char_cols[i] = strip(char_cols[i]);
    end;
    
    /* Drop the index variable 'i' as it is not needed in the final dataset */
    drop i;



    /* 2. DROP IRRELEVANT COLUMNS
       The 'car' variable is removed because it contains 99.15% missing values,
       making it statistically insignificant for the model. */
      
    drop car;
    
    
    /* 3. DROP ZERO-VARIANCE AND REDUNDANT COLUMNS
       'toCoupon_GEQ5min' is constant (always = 1) and adds no predictive value.
       'direction_opp' is the perfect inverse of direction_same (r = -1.00),
       keeping both causes multicollinearity in the logistic regression model. */
      
    drop toCoupon_GEQ5min direction_opp;




    /* 4. NUMERICAL CONVERSION & CLEANING (Variable: age)
       Age is stored as a character with strings like 'below21' and '50plus'.
       We convert it to numeric to allow statistical calculations (Mean/Correlation). */
    length age_num 8;
    
    if age = 'below21' then age_num = 20;
    else if age = '50plus' then age_num = 50;
    else if age ne ' ' then age_num = input(age, 8.);
    
    
    
    /* 5. MISSING VALUE IMPUTATION
       Any remaining missing values in age are replaced with the mean (approx. 32)
       to maintain the dataset size (12,684 rows) without bias. */
    if age_num = . then age_num = 32; 

    /* Replace the old character age with the new numeric version */
    drop age;
    rename age_num = age;
    
    
    
   /* 6. CLEANING CATEGORICAL BEHAVIORAL VARIABLES (Mode Imputation)
       Handling missing values for frequency-based variables by 
       replacing blanks with the 'Mode' (most frequent category) 
       to preserve the dataset size of 12,684 records. */

    /* Bar: Imputing with 'never' (Frequency: 40.97%) */
    if Bar = "" or Bar = "." then Bar = "never";

    /* CoffeeHouse: Imputing with 'less1' (Frequency: 26.69%) */
    if CoffeeHouse = "" then CoffeeHouse = "less1";

    /* CarryAway: Imputing with '1~3' (Frequency: 36.83%) */
    if CarryAway = "" then CarryAway = "1~3";

    /* RestaurantLessThan20: Imputing with '1~3' (Frequency: 42.38%) */
    if RestaurantLessThan20 = "" then RestaurantLessThan20 = "1~3";

    /* Restaurant20To50: Imputing with 'less1' (Frequency: 47.91%) */
    if Restaurant20To50 = "" then Restaurant20To50 = "less1";
run;



proc corr data=mydata_clean plots=matrix(histogram);
    var temperature age has_children toCoupon_GEQ15min toCoupon_GEQ25min direction_same Y;
    title "Correlation Matrix of Numerical Features";
run;
     /*Statistical Summary: Correlation analysis confirms that 'Distance' (toCoupon_GEQ25min) 
     is the strongest negative predictor of acceptance. 
     While 'Age' and 'Has_Children' are highly correlated with each other (0.442), 
     they have a minimal impact on the target variable 'Y'.*/


/* Visualization Row count before vs after cleaning */
data compare;
    Stage = "Before Cleaning"; Rows = 12684; output;
    Stage = "After Cleaning";  Rows = 12610; output;
run;


proc sgplot data=compare;
    vbar Stage / response=Rows datalabel;
    yaxis label="Number of Rows" min=12500;
    xaxis label="";
    title "Row Count: Before vs After Cleaning";
run;


/*frequency for each column*/
proc freq data=mydata_clean;
tables _all_ / missing;
run;


/* ============================================================
                   FEATURE ENGINEERING 
   ============================================================ */

/* ============================================================
   STEP 1: Build Lookup Table for Coupon_Social_Fit
   ============================================================ */

proc format;
    value $ social_fit_fmt
        "Restaurant(<20)|Friend(s)"       = 0.80
        "Restaurant(<20)|Partner"         = 0.77
        "Restaurant(<20)|Kid(s)"          = 0.72
        "Restaurant(<20)|Alone"           = 0.64
        "Carry out & Take away|Friend(s)" = 0.76
        "Carry out & Take away|Alone"     = 0.73
        "Carry out & Take away|Partner"   = 0.73
        "Carry out & Take away|Kid(s)"    = 0.70
        "Coffee House|Friend(s)"          = 0.60
        "Coffee House|Partner"            = 0.57
        "Coffee House|Kid(s)"             = 0.48
        "Coffee House|Alone"              = 0.44
        "Restaurant(20-50)|Partner"       = 0.63
        "Restaurant(20-50)|Friend(s)"     = 0.46
        "Restaurant(20-50)|Alone"         = 0.42
        "Restaurant(20-50)|Kid(s)"        = 0.37
        "Bar|Friend(s)"                   = 0.56
        "Bar|Alone"                       = 0.41
        "Bar|Partner"                     = 0.39
        "Bar|Kid(s)"                      = 0.21
        other                             = 0.50;
run;


/* ============================================================
   STEP 2: Create All New Features
   ============================================================ */

data mydata_fe;
    set mydata_clean;

	if toCoupon_GEQ25min = 1 then Distance_Level = "Far";
    else if toCoupon_GEQ15min = 1 then Distance_Level = "Medium";
    else Distance_Level = "Near";

	if passanger = "Friend(s)" then Social_Context = 2;
    else if passanger = "Partner" then Social_Context = 1;
    else Social_Context = 0;
    /* -------------------------------------------------------
       FEATURE 1: Income_Level  [BINNING]
       -------------------------------------------------------
       Groups 9 raw income text values into 3 economic tiers.
       Low / Medium / High
    ------------------------------------------------------- */
    if income in ("Less than $12500",
                  "$12500 - $24999",
                  "$25000 - $37499")      then Income_Level = "Low";
    else if income in ("$37500 - $49999",
                       "$50000 - $62499") then Income_Level = "Medium";
    else                                       Income_Level = "High";


    /* -------------------------------------------------------
       FEATURE 2: Family_Trip  [INTERACTION: has_children x passanger]
       -------------------------------------------------------
       Flags rows where the driver has children AND is
       currently traveling with kids — both must be true.
    ------------------------------------------------------- */
    if has_children = 1 and passanger = "Kid(s)" then Family_Trip = 1;
    else                                               Family_Trip = 0;


    /* -------------------------------------------------------
       FEATURE 3: Is_Free_Destination  [BINARY ENCODING]
       -------------------------------------------------------
       Converts the 3-value destination column into a binary
       flag: 1 if the driver has no urgent place to be.
    ------------------------------------------------------- */
    if destination = "No Urgent Place" then Is_Free_Destination = 1;
    else                                    Is_Free_Destination = 0;


    /* -------------------------------------------------------
       FEATURE 4: Urgency_Distance_Trap  [INTERACTION: expiration x distance]
       -------------------------------------------------------
       Flags the worst-case scenario: coupon expires in 2 hours
       AND the venue is more than 25 minutes away.
    ------------------------------------------------------- */
    if expiration = "2h" and toCoupon_GEQ25min = 1
        then Urgency_Distance_Trap = 1;
    else    Urgency_Distance_Trap = 0;


    /* -------------------------------------------------------
       FEATURE 5: Comfort_Score  [COMBINATION: weather + temperature]
       -------------------------------------------------------
       Combines weather and temperature into one numeric score
       (0 to 3) based on actual acceptance rates per combo.
    ------------------------------------------------------- */
    if      weather = "Sunny" and temperature = 80 then Comfort_Score = 3;
    else if weather = "Sunny" and temperature = 55 then Comfort_Score = 2;
    else if weather = "Sunny" and temperature = 30 then Comfort_Score = 2;
    else if weather = "Rainy" and temperature = 55 then Comfort_Score = 1;
    else if weather = "Snowy" and temperature = 30 then Comfort_Score = 0;
    else                                                Comfort_Score = 1;


    /* -------------------------------------------------------
       FEATURE 6: Income_Coupon_Match  [INTERACTION: income x coupon]
       -------------------------------------------------------
       Flags whether the coupon price range aligns with the
       driver's income level (uses Income_Level from Feature 1).
    ------------------------------------------------------- */
    if (Income_Level = "Low"    and coupon in ("Restaurant(<20)",
                                               "Carry out & Take away",
                                               "Coffee House"))
    or (Income_Level = "Medium" and coupon in ("Restaurant(<20)",
                                               "Coffee House",
                                               "Restaurant(20-50)"))
    or (Income_Level = "High"   and coupon in ("Restaurant(20-50)",
                                               "Bar",
                                               "Coffee House"))
        then Income_Coupon_Match = 1;
    else    Income_Coupon_Match = 0;


    /* -------------------------------------------------------
       FEATURE 7: Coupon_Social_Fit  [INTERACTION: coupon x passanger]
       -------------------------------------------------------
       Uses the lookup table defined in PROC FORMAT above.
       Creates a combined key from coupon + "|" + passanger,
       then maps it to the real observed acceptance rate score.
    ------------------------------------------------------- */
    _lookup_key = cats(coupon, "|", passanger);
    Coupon_Social_Fit = input(put(_lookup_key, $social_fit_fmt.), 8.);
    drop _lookup_key;
    
	/* Loyalty_Match: user visits place frequently → more likely to accept */
	if (coupon = "Coffee House" and CoffeeHouse in ("1~3", "4~8", "gt8")) then Loyalty_Match = 1;
	else if (coupon = "Bar" and Bar in ("1~3", "4~8", "gt8")) then Loyalty_Match = 1;
	else if (coupon = "Carry out & Take away" and CarryAway in ("1~3", "4~8", "gt8")) then Loyalty_Match = 1;
	else Loyalty_Match = 0;
	
	/* Good_Timing: coupon matches suitable time of day */
	if (time in ("10AM", "2PM") and coupon = "Coffee House") then Good_Timing = 1;
	else if (time = "6PM" and coupon in ("Restaurant(<20)", "Restaurant(20-50)")) then Good_Timing = 1;
	else if (time = "10PM" and coupon = "Bar") then Good_Timing = 1;
	else Good_Timing = 0;
	
	/* Effort_Too_High: far distance + low-value coupon --> less acceptance */
	if (toCoupon_GEQ25min = 1 and coupon in ("Coffee House", "Carry out & Take away")) then Effort_Too_High = 1;
	else Effort_Too_High = 0;
	
run;



/* ============================================================
   STEP 3: Verify the New Features
   ============================================================ */

/* Preview the first 10 rows */
proc print data=mydata_fe (obs=10);
    var income Income_Level has_children passanger Family_Trip
        destination Is_Free_Destination expiration
        toCoupon_GEQ25min Urgency_Distance_Trap
        weather temperature Comfort_Score
        coupon Income_Coupon_Match Coupon_Social_Fit Y;
    title "Feature Engineering - First 10 Rows Verification";
run;

/* Summary statistics for all new numeric features */
proc means data=mydata_fe mean std min max;
    var Family_Trip Is_Free_Destination Urgency_Distance_Trap
        Comfort_Score Income_Coupon_Match Coupon_Social_Fit;
    title "Descriptive Statistics: New Engineered Features";
run;

/* Frequency for Income_Level */
proc freq data=mydata_fe;
    tables Income_Level;
    title "Frequency Distribution: Income Level";
run;


/* ============================================================
   STEP 4: Prove Features Are Useful vs Target (Y)
   ============================================================ */

/* Compare means: accepted (Y=1) vs rejected (Y=0) */
proc means data=mydata_fe mean;
    class Y;
    var Coupon_Social_Fit Urgency_Distance_Trap
        Is_Free_Destination Comfort_Score
        Income_Coupon_Match Family_Trip;
    title "Mean of New Features: Coupon Accepted (1) vs Rejected (0)";
run;

/* Chi-square: Income Level vs Y */
proc freq data=mydata_fe;
    tables Income_Level * Y / chisq nopercent nocol;
    title "Chi-Square: Income Level vs Coupon Acceptance";
run;


/* ============================================================
   STEP 5: Visualizations 
   ============================================================ */

/*  Coupon Social Fit Score - the star feature */
proc sgplot data=mydata_fe;
    vbox Coupon_Social_Fit / category=Y;
    yaxis label="Coupon Social Fit Score";
    xaxis label="Y (0=Reject, 1=Accept)";
    title "Coupon-Social Fit Score vs Coupon Decision";
run;

/*  Urgency Distance Trap - strongest pattern */
proc sgplot data=mydata_fe;
    vbar Urgency_Distance_Trap / group=Y groupdisplay=cluster stat=percent;
    yaxis label="Percentage %";
    xaxis label="0=No Trap | 1=Short Expiry AND Far Venue";
    title "Urgency-Distance Trap vs Coupon Acceptance";
run;

/*  Comfort Score */
proc sgplot data=mydata_fe;
    vbar Comfort_Score / group=Y groupdisplay=cluster stat=percent;
    yaxis label="Percentage %";
    xaxis label="Comfort Score (0=Worst to 3=Best)";
    title "Environmental Comfort Score vs Coupon Acceptance";
run;


/* ============================================================
   STEP 6: Correlation - New Features vs Target (Y)
   ============================================================ */

proc corr data=mydata_fe;
    var Family_Trip Is_Free_Destination Urgency_Distance_Trap
        Comfort_Score Income_Coupon_Match Coupon_Social_Fit Y;
    title "Correlation: New Engineered Features vs Target (Y)";
run;





/* ============================================================
   TRAIN / TEST SPLIT (70% Train - 30% Test)
   ============================================================ */
/* Split data: 70% training, 30% testing */
proc surveyselect data=mydata_fe
    out=split_data
    samprate=0.7
    seed=123
    outall;

run;

/* Separate into train and test datasets */
data train test;
    set split_data;
    if selected = 1 then output train;
    else output test;
run;

/* ============================================================
   1. BASELINE MODEL
   ============================================================ */
/* Baseline Model: train logistic regression using basic features */
proc logistic data=train;
    class coupon passanger weather destination time Income_Level Distance_Level / param=ref;

    model Y(event='1') =
        coupon passanger weather destination time Income_Level Distance_Level;

    score data=test out=baseline_test;
run;

/* Convert predicted probabilities to class (0/1) */
data baseline_test;
    set baseline_test;
    predicted_base = (P_1 >= 0.5);
run;


/* ============================================================
   2. ENGINEERED MODEL (REPLACED WITH YOUR EXACT CODE)
   ============================================================ */

/* Engineered Model: logistic regression with new features + stepwise selection */
proc logistic data=train;

    class Income_Level Distance_Level passanger coupon / param=ref;

    model Y(event='1') =
        temperature
        has_children
        direction_same
        Family_Trip
        Is_Free_Destination
        Urgency_Distance_Trap
        Comfort_Score
        Income_Coupon_Match
        Coupon_Social_Fit
        Loyalty_Match
        Good_Timing
        Effort_Too_High
    / selection=stepwise slentry=0.05 slstay=0.05;

    output out=eng_train p=pred_eng;
run;

/* Feature importance using coefficients */
proc logistic data=train;
    class Income_Level Distance_Level passanger coupon / param=ref;

    model Y(event='1') =
        temperature has_children direction_same
        Family_Trip Is_Free_Destination Urgency_Distance_Trap
        Comfort_Score Income_Coupon_Match Coupon_Social_Fit
        Loyalty_Match Good_Timing Effort_Too_High;

    ods output ParameterEstimates=feat_imp;
run;

proc print data=feat_imp;
    title "Feature Importance (Logistic Regression Coefficients)";
run;


data eng_test;
    set eng_test;
    predicted_eng = (P_1 >= 0.5);
run;

proc logistic data=train;
    class Income_Level Distance_Level passanger coupon / param=ref;

    model Y(event='1') =
        temperature has_children direction_same
        Family_Trip Is_Free_Destination Urgency_Distance_Trap
        Comfort_Score Income_Coupon_Match Coupon_Social_Fit
        Loyalty_Match Good_Timing Effort_Too_High;

    score data=test out=eng_test;
run;

/* Convert probability to class (0/1) */
data eng_test;
    set eng_test;
    predicted_eng = (P_1 >= 0.5);
run;


/* ============================================================
   3. ACCURACY CALCULATION (DIRECT & CLEAN)
   ============================================================ */
proc sql;
    create table comparison as
    select "Baseline" as Model, mean(Y = predicted_base) as Accuracy from baseline_test
    union all
    select "Engineered" as Model, mean(Y = predicted_eng) as Accuracy from eng_test;
quit;

/* Display final comparison results */
proc print data=comparison;
    title "Final Comparison: Baseline vs Engineered Model";
run;


/* ============================================================
   MODEL EVALUATION (BASELINE + ENGINEERED)
   Confusion Matrix + ROC + AUC
   ============================================================ */

/* ---------------------------
   BASELINE CONFUSION MATRIX  
----------------------------*/
proc freq data=baseline_test;
    tables Y*predicted_base / norow nocol nopercent;
    title "Confusion Matrix - Baseline Model";
run;

/* ---------------------------
   ENGINEERED CONFUSION MATRIX
----------------------------*/
proc freq data=eng_test;
    tables Y*predicted_eng / norow nocol nopercent;
    title "Confusion Matrix - Engineered Model";
run;


/* ---------------------------
   BASELINE ROC CURVE
----------------------------*/
proc logistic data=train plots(only)=roc;
    class coupon passanger weather destination time Income_Level Distance_Level / param=ref;

    model Y(event='1') =
        coupon passanger weather destination time Income_Level Distance_Level;

    score data=test out=baseline_roc;
    title "ROC Curve - Baseline Model";
run;


/* ---------------------------
   ENGINEERED ROC + AUC
----------------------------*/
proc logistic data=train plots(only)=roc;
    class Income_Level Distance_Level passanger coupon / param=ref;

    model Y(event='1') =
        temperature has_children direction_same
        Family_Trip Is_Free_Destination Urgency_Distance_Trap
        Comfort_Score Income_Coupon_Match Coupon_Social_Fit
        Loyalty_Match Good_Timing Effort_Too_High;

    score data=test out=eng_roc;
    title "ROC Curve - Engineered Model";
run;


/* ---------------------------
   AUC TABLE (ENGINEERED MODEL)
----------------------------*/
proc logistic data=train;
    class Income_Level Distance_Level passanger coupon / param=ref;

    model Y(event='1') =
        temperature has_children direction_same
        Family_Trip Is_Free_Destination Urgency_Distance_Trap
        Comfort_Score Income_Coupon_Match Coupon_Social_Fit
        Loyalty_Match Good_Timing Effort_Too_High;

    ods output ROCAssociation=auc_eng;
run;

proc print data=auc_eng;
    title "AUC - Engineered Model";
run;

/* ============================================================
   4. FINAL OUTPUT
   ============================================================ */

proc print data=comparison;
    title "Final Comparison (Baseline vs Engineered Logistic Model)";
run;
data engineered_out;
    set engineered_out;
    predicted_eng = (pred_eng >= 0.5);
run;

/* ============================================================
   FINAL CONCLUSION
   ============================================================

   This project successfully analyzed customer coupon acceptance
   behavior using a real-world marketing dataset.

   Key steps included:
   - Understanding and exploring the dataset structure
   - Cleaning and preprocessing data (handling missing values,
     duplicates, and inconsistent categories)
   - Engineering meaningful features to capture behavioral,
     contextual, and economic influences
   - Building and comparing baseline and enhanced logistic
     regression models
   - Evaluating model performance using accuracy, confusion
     matrix, ROC curves, and AUC

   Results show that feature engineering slightly improved model
   performance, indicating that customer behavior is influenced
   more by contextual and social factors than raw attributes alone.

   The most influential factors include:
   - Social context (passenger type)
   - Distance and urgency of the coupon
   - Income and coupon compatibility
   - Timing and environmental conditions

   Overall, the model provides useful insights for targeted
   marketing strategies and can help optimize coupon delivery
   to increase acceptance rates in real-world applications.

   ============================================================
*

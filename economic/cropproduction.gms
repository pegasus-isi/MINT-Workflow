$TITLE SOUTH SUDAN PMP MODEL OF AGRICULTURAL PRODUCTION
* South Sudan agricultural production function PMP model, v.1
* Kelly M. Cobourn, June 2018
* Department of Forest Resources and Environmental Conservation
* Virginia Tech
* email: kellyc13@vt.edu

$offsymlist offsymxref
option limrow = 0;
option limcol = 0;
option nlp = CONOPT;
option solprint = off;

***************************************************************************
*********************  PART 1. SETS & PARAMETERS  *************************
***************************************************************************

sets
i        crops /cassava,maize,sorghum/
l        inputs /land,fertilizer/
cycles   cycles outputs /yieldN/;
alias (i,j);

******************** REMOTE SENSING INTEGRATION HERE **********************
** Link with remote sensing here via the size of the agricultural land base,
** b1, and the land area observed in each crop, xbar(i,'land'). Land units
** are hectares.

** To start, total land area set equal to area in cassava, maize, and sorghum
** production in 2016 for all of South Sudan (FAO 2018).
scalar
b1       agricultural land base /625275/

parameters
xbar1(i) reference land allocation /cassava 84453, maize 94308, sorghum 446514/

***************************************************************************

parameters
** Yield in kg per ha for South Sudan in 2016, prices in USD per kg (FAO 2018).
** Data used for South Sudan where possible, otherwise data from closest
** available country and year used. Supply elasticities based on economic
** estimates of short-run price elasticities.
ybar(i)  observed crop yields /cassava 1543.7, maize 1134.6, sorghum 1594.6/
p(i)     crop prices /cassava 0.3798, maize 0.2580, sorghum 0.4894/
eta(i)   exogenous supply elasticities /cassava 0.38, maize 0.49, sorghum 0.24/
qbar(i)  reference crop production
b(i)     land relative tot total production value;
qbar(i) = ybar(i)*xbar1(i);
b(i) = sqr(xbar1(i))/(p(i)*qbar(i));

** Production practices and costs of production from published literature
** for closest available country and year.
parameters
Napps(i) mean fertilizer applications in kg N per ha /cassava 32,
         maize 95, sorghum 76/
xbar2(i) reference fertilizer use in kg N;
xbar2(i) = Napps(i)*xbar1(i);
display xbar2;

** Costs of production in USD per ha for land and USD per kg for N fertilizer.
** All inputs other than land and fertilizer are assumed to be used in fixed
** proportion to land and are included in the cost per unit land.
table    c(i,l)  costs of production
               land          fertilizer
cassava        383.0           2.5
maize          175.0           1.0
sorghum        350.0           2.7;

************************* CYCLES INTEGRATION HERE ***********************
** Link with CYCLES by extracting the sensitivity of crop yield to nitrogen
** fertilizer applications (as percent change in yield divided by percent
** change in N applications).

** Values for safflower, corn, and wheat in U.S. used as temporary
** placeholders.

table  felast(i,cycles) yield elasticity with respect to N
$ondelim
$include yieldelast.csv
$offdelim
;

parameters
ybarN(i) yield elasticity with respect to N;
ybarN('cassava') = 0.25;
ybarN('maize') = 0.11;
ybarN('sorghum') = felast('sorghum','yieldN')*220;

***************************************************************************
**************  PART 2. PRODUCTION FUNCTION CALIBRATION  ******************
***************************************************************************

** Set elasticities of substitution between land and N for each crop.
parameters
sigma(i) substitution elasticity by crop and technology
rho(i)   production function elasticity parameter;
sigma(i) = 0.5;
rho(i) = (sigma(i)-1)/sigma(i);
display rho;

** Ensure that calibration criteria are satisfied. The first criterion
** requires that cc1 > 0 for all i. The second criterion requires that
** cc2 < 0 for all i.
parameters
cc1(i)   calibration criteria 1
flag1(i) flag violations of cc1
psi(i)   term inside cc2
cc2(i)   calibration criteria 2
flag2(i) flag violations of cc2;

cc1(i) = eta(i) - ybarN(i)/(1-ybarN(i));
flag1(i) = 1$(cc1(i) lt 0);
abort$(sum(i, flag1(i)) gt 0) "cc1 not satisfied";

psi(i) = sigma(i)*ybarN(i)/(eta(i)*(1-ybarN(i)));
cc2(i) = b(i)*eta(i)*(1 - psi(i)) - sum(j$(ord(j) ne ord(i)),
         b(j)*eta(j)*sqr(1 + (1/eta(j)))*(1 + psi(j) - ybarN(j)));
flag2(i) = 1$(cc2(i) gt 0);
abort$(sum(i,flag2(i)) gt 0) "cc2 not satisfied";

scalars
term     indicator equal to card(i) when all deltas converge /0/
toler    tolerance for convergence /0.001/;

parameters
delta0(i) myopic CES production function parameter
adj(i)    adjustment term using myopic delta
error(i)  absolute value of change in delta
converge(i) indicator equal to one when delta converges;
delta0(i) = eta(i)/(1+eta(i));
adj(i) = 1 - (b(i)/(delta0(i)*(1-delta0(i))))/(sum(j,
         (b(j)/(delta0(j)*(1-delta0(j)))) +
         (sigma(j)*b(j)*ybarN(j)/(delta0(j)*(delta0(j)
         - ybarN(j))))));

variables
delta(i)    production function homogeneity parameters
beta(i,l)   production function share parameters
dummy    dummy objective;
positive variables delta,beta;

equations
etacal(i)  calibration to exogenous supply elasticity
nresp(i)   calibration against agronomic yield response to N
betas(i)   summation constraint for share parameters
edummy   dummy objective function;
etacal(i).. eta(i) =e= (delta(i)/(1-delta(i)))*adj(i);
Nresp(i).. ybarN(i)*((beta(i,'land')*(xbar1(i)**rho(i))) +
          (beta(i,'fertilizer')*(xbar2(i)**rho(i)))) =e=
          delta.l(i)*beta(i,'fertilizer')*(xbar2(i)**rho(i));
betas(i).. sum(l, beta(i,l)) =e= 1;
edummy.. dummy =e= 0;

** Solve supply elasticity system of equations.
model selast /etacal,edummy/;
while(term lt card(i),
solve selast maximizing dummy using nlp;
*Test for convergence in the deltas
         error(i) = abs(delta0(i) - delta.l(i));
         converge(i)$(error(i) lt toler) = 1;
         term = sum(i, converge(i));
*Update values for delta in the adjustment term if convergence test fails
         delta0(i) = delta.l(i);
         adj(i) = 1 - (b(i)/(delta0(i)*(1-delta0(i))))/(sum(j,
                  (b(j)/(delta0(j)*(1-delta0(j)))) +
                  (sigma(j)*b(j)*ybarN(j)/(delta0(j)*(delta0(j) - ybarN(j))))));
);

** Solve system of equations for share parameters.
model nelast /nresp,betas,edummy/;
solve nelast maximizing dummy using nlp;
display delta.l,beta.l;

parameters
mu(i)    scale parameters
lbar1    initial shadow value of land
lambda(i,l) calibrated factor shadow values
soccost(i,l) social cost of inputs;

mu(i) =  qbar(i)/((beta.l(i,'land')*(xbar1(i)**rho(i))) +
          (beta.l(i,'fertilizer')*xbar2(i)**rho(i)))**(delta.l(i)/rho(i));
lbar1 = sum(i, (p(i)*qbar(i)*(delta.l(i) - ybarN(i))
        - c(i,'land')*xbar1(i))*xbar1(i))/sum(i, sqr(xbar1(i)));
lambda(i,'land') = p(i)*qbar(i)*(delta.l(i) - ybarN(i))/xbar1(i)
             - (c(i,'land') + lbar1);
lambda(i,'fertilizer') = p(i)*qbar(i)*ybarN(i)/xbar2(i)
             - c(i,'fertilizer');
soccost(i,l) = c(i,l) + lambda(i,l);
display rho,delta.l,beta.l,mu,lbar1,lambda;


***************************************************************************
****************  PART 3. CROP PRODUCTION SIMULATION  *********************
***************************************************************************

parameters
qbsim(i)         simulated production at baseline (in million kg)
qdiv(i)          MSE divergence from reference level;
qbsim(i) = mu(i)*((beta.l(i,'land')*(xbar1(i)**rho(i))) +
          (beta.l(i,'fertilizer')*xbar2(i)**rho(i)))**(delta.l(i)/rho(i))/1000000;
qdiv(i) = sqr(abs(qbsim(i) - qbar(i)));
display qbsim,qdiv;

variables
x(i,l)           simulated input use
q(i)             simulated production
qprofit(i)       quasi-profit function
tprofit          total profit;
positive variables x,q,qprofit;

equations
production(i)    production function
quasiprofit(i)   quasi-profit function
obj              objective function
resconl          land constraint
resconf          fertilizer constraint;

production(i).. q(i) =e= mu(i)*(sum(l, beta.l(i,l)*x(i,l)**rho(i)))**(delta.l(i)/rho(i));
quasiprofit(i).. qprofit(i) =e= p(i)*q(i) - sum(l, soccost(i,l)*x(i,l));
obj.. tprofit =e= sum(i, qprofit(i));
resconl.. sum(i, x(i,'land')) =e= b1;
resconf.. sum(i, x(i,'fertilizer')) =e= sum(i, xbar2(i));

x.lo(i,l) = 0.001;

model profitmax /production,quasiprofit,obj,resconl,resconf/;
solve profitmax maximizing tprofit using nlp;

parameters
crops(i)         crop production (in million kg)
landuse(i)       land use by crop (in thousand ha)
fertuse(i)       fertilizer applications by crop (in million kg);
crops(i) = q.l(i)/1000000;
landuse(i) = x.l(i,'land')/1000;
fertuse(i) = x.l(i,'fertilizer')/1000000;
display crops,landuse,xbar1,fertuse,xbar2;

file     MINTlanduse /MINTlanduse.csv/;
put      MINTlanduse;
put      'crop', @12, 'landuse (kha)', @36, 'fertuse (mkg)', @72, 'production (mkg)' /;
loop(i, put i.tl, @12, landuse(i):8:3, @36, fertuse(i):8:3, @72, crops(i):8:3 /);












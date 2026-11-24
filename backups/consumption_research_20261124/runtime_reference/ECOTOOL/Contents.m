% Econometric Toolbox (ECOTOOL).
% Version February 2019
%
% GUIs and main functions (also listed below)
%   toolTEST        - Exploratory, descriptive and diagnostic checking tool
%   toolFORECAST    - Forecasting tool
%   modelAUTO       - Automatic identification of ARIMA models
%   modelETS        - Exponential Smothing models
%   modelNAIVE      - Forecasting with several naive models
%   modelTF         - MISO Transfer Function analysis (estimation, prediction, interpolation, ...)
%   modelUC         - Unobserved Components models
%   modelVARX       - VAR model with eXogenous variables analysis
%
% Tools for data analysis and diagnostics.
%   toolTEST        - Graphical User Interface to acess all the functions below:
%      plotband     - Vector Time Series plot with confidence bands
%      vboxplot     - Vector Time Series boxplot
%      vtboxplot    - Vector Time Series transpose boxplot
%      vscatter     - Scatter plots
%      sumstats     - Summary descriptive statistics
%      vhist        - Histogram with gaussian distribution and non-parametric estimate
%      vqqplot      - Vector Quantile-Quantile plots
%      gausstest    - Gaussian tests
%      vident       - Sample autocorrelation and partial autocorrelation functions
%      vident2      - Vector version of vident
%      varsbc       - Identification criteria on VAR models
%      vgranger     - Granger causality tests on VAR models
%      vcusum       - CUSUM and CUSUM of squares tests
%      stdmean      - Standard Deviation vs Mean type of plots
%      testhet      - Heteroskedasticity tests
%      vboxcox      - Box-Cox homokedasticity family of transformations
%      ADFtest      - Augmented Dickey-Fuller Unit Roots tests
%      vphillips    - Phillips Perron Unit Roots tests
%      Johansentest - Johansen cointegration tests
%      NLtests      - Non Linear tests based on squares
%      vtsay        - Tsay non-linearity tests
%      varsbc2      - Non-linearity test based on Schwarz Criterion of squares
%      vbds         - Brock, Dechert & Scheinkman test for independence
%      vcumperiod   - Cumulative periodogram
%      vspectrum    - Spectrum
%      varspectrum  - AR Spectrum
%
% Tools for model estimation.
%   modelAUTO       - Automatic identification of ARIMA models
%   modelETS        - Exponential Smothing models
%   modelNAIVE      - Forecasting with several naive models
%   modelTF         - MISO Transfer Function analysis (estimation, prediction, interpolation, ...)
%   modelUC         - Unobserved Components models
%   modelVARX       - VAR model with eXogenous variables analysis
%
% Forecasting tools.
%   toolFORECAST    - Forecasting tool
%
% Time Series Intervention functions.
%   days            - Dummy variable for number of days in months or quarters 
%   easter          - General dummy Easter variables on monthly or quarterly data
%   leapy           - Dummy variable for leap year intervention 
%   trading         - Trading day variables on monthly or quarterly frequency
%
% General functions.
%   acft            - Theoretical power spectrum and simple and partial 
%                     auto correlation functions of ARMA(p, q) models
%   adjust          - Substracts two time series adjusting the size of the matrices
%   meda            - Median Absolute deviation with respect to the median
%   nancov          - Covariance matrix of vector variables with NaN values
%   nancumsum       - Cumulative sum of matrix in columns with NaN values
%   nanprod         - Product of matrices with NaN values
%   sortcol         - Sorting of a matrix by a column order
%   transform       - Standardisation or de-standardisation of a vector of variables
%   varstep         - Var impulse and step function analysis
%   vboxcoxinv      - Inverse of Box-Cox transformation
%   vConv           - Multiplication of vector polynomials
%   vdif            - Differenciation of a vector of variables
%   vfilter         - Filters a vector of inputs with a vector digital filter
%   vRoots          - Calculates the roots of a vector polynomial
%
% Demonstrations
%   ECOTOOLdemos    - ECOTOOL demos
%
% Copyright (c) 2019 by Diego J. Pedregal
% Universidad Castilla-La Mancha
%
% Functions bds.m and bdssig.m are taken from Ludwig Kanzler
%    See http://users.ox.ac.uk/~econlrk
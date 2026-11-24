function output= adfcritical(x, T, dist)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

% dist= 1: T distribution, no trend, no constant
% dist= 2: T distribution, no trend, constant
% dist= 3: T distribution, trend, constant
% dist= 4: F distribution, constant
% dist= 5: F distribution, constant, trend

if T> 500, T= 1000; end
if T< 25, T= 25; end

% Standard tables
pvalueF= repmat([1 0.99 0.975 0.95 0.9 0.1 0.05 0.025 0.01 0], 6, 1);
pvaluet= repmat([0 0.01 0.025 0.05 0.1 0.9 0.95 0.975 0.99 1], 6, 1);
samplesize= repmat([25 50 100 250 500 1000]', 1, 10);
t1= [-2.66 -2.62 -2.6  -2.58 -2.58 -2.58;
     -2.26 -2.25 -2.24 -2.23 -2.23 -2.23;
     -1.95 -1.95 -1.95 -1.95 -1.95 -1.95;
     -1.6  -1.61 -1.61 -1.62 -1.62 -1.62;
      0.92  0.91  0.9   0.89  0.89  0.89;
      1.33  1.31  1.29  1.29  1.28  1.28;
      1.7   1.66  1.64  1.63  1.62  1.62;
      2.16  2.08  2.03  2.01  2 2]';
t2= [-3.75 -3.58 -3.51 -3.46 -3.44 -3.43;
     -3.33 -3.22 -3.17 -3.14 -3.13 -3.12;
     -3    -2.93 -2.89 -2.88 -2.87 -2.86;
     -2.63 -2.6  -2.58 -2.57 -2.57 -2.57;
     -0.37 -0.4  -0.42 -0.42 -0.43 -0.44;
      0    -0.03 -0.05 -0.06 -0.07 -0.07;
      0.34  0.29  0.26  0.24  0.24  0.23;
      0.72  0.66  0.63  0.62  0.61  0.60]';
t3= [-4.38 -4.15 -4.04 -3.99 -3.98 -3.96;
     -3.95 -3.8  -3.73 -3.69 -3.68 -3.66;
     -3.6  -3.5  -3.45 -3.43 -3.42 -3.41;
     -3.24 -3.18 -3.15 -3.13 -3.13 -3.12;
     -1.14 -1.19 -1.22 -1.23 -1.24 -1.25;
     -0.8  -0.87 -0.9  -0.92 -0.93 -0.94;
     -0.5  -0.58 -0.62 -0.64 -0.65 -0.66;
     -0.15 -0.24 -0.28 -0.31 -0.32 -0.33]';
F1= [0.29 0.29 0.29 0.3  0.3  0.3;
     0.38 0.39 0.39 0.39 0.39 0.4;
     0.49 0.5  0.5  0.51 0.51 0.51;
     0.65 0.66 0.67 0.67 0.67 0.67;
     4.12 3.94 3.86 3.81 3.79 3.78;
     5.18 4.86 4.71 4.63 4.61 4.59;
     6.3  5.8  5.57 5.45 5.41 5.38;
     7.88 7.06 6.7  6.52 6.47 6.43]';
F2= [0.74 0.76 0.76 0.76 0.76 0.77;
     0.9  0.93 0.94 0.94 0.94 0.94;
     1.08 1.11 1.12 1.13 1.13 1.13;
     1.33 1.37 1.38 1.39 1.39 1.39;
     5.91 5.61 5.47 5.39 5.36 5.34;
     7.24 6.73 6.49 6.34 6.3  6.25;
     8.65 7.81 7.44 7.25 7.2  7.16;
    10.61 9.31 8.73 8.43 8.34 8.27]';

% Modified tables for extrapolation
t1= [[-2.92 -2.86 -2.84 -2.81 -2.81 -2.81]' t1 [2.47 2.36 2.29 2.26 2.25 2.25]'];
t2= [[-4.17 -3.94 -3.85 -3.78 -3.75 -3.74]' t2 [0.97 0.91 0.88 0.87 0.86 0.85]'];
t3= [[-4.81 -4.5 -4.35 -4.29 -4.28 -4.26]' t3 [0.08 -0.01 -0.05 -0.09 -0.1 -0.11]'];
F1= [[0.2 0.19 0.19 0.21 0.21 0.2]' F1 [8.93 7.9 7.45 7.23 7.18 7.13]'];
F2= [[0.58 0.59 0.58 0.58 0.58 0.6]' F2 [11.91 10.31 9.59 9.22 9.1 9.01]'];
switch dist
    case 1
        output= griddata(t1, samplesize, pvaluet, x, T)';
    case 2
        output= griddata(t2, samplesize, pvaluet, x, T)';
    case 3
        output= griddata(t3, samplesize, pvaluet, x, T)';
    case 4
        output= griddata(F1, samplesize, pvalueF, x, T)';
    case 5
        output= griddata(F2, samplesize, pvalueF, x, T)';
end

if dist< 4
    ind= find(isnan(output));
    output(ind)= zeros(size(ind));
    ind1= find(x(ind)> -0.5);
    output(ind(ind1))= ones(size(ind1));
else
    ind= find(isnan(output));
    output(ind)= ones(size(ind));
    ind1= find(x(ind)> 4);
    output(ind(ind1))= zeros(size(ind1));
end
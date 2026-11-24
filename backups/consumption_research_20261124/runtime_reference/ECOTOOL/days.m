function y= days(starting_date, N, S)
% days   Creates dummy variable to account for the number 
%        of days in period in monthly or quarterly data
%
%     I= days(starting_date, N, S)
%
% INPUTS:
%   starting_date: (*) Starting date of data [yyyy mm] or 
%                  [yyyy q] 
%   N:             (*) Number of monthly or quarterly 
%                  observations to simulate
%   S:             Seasonal period of data (12 or 4) (12)
% OUTPUTS:
%   I:             Dummy variable Nx1
%
% Examples:
%   I= days([1990 6], 148);
% 
% See Also: easter, trading, leapy

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 3, S= 12; end
if isempty(S), S= 12; end
if S~=12, S= 4; end
if S== 4
    starting_date(2)= starting_date(2)*3-2;
    N= N * 3;
end

% Days= 4*ones(N, 7);
Nyears= floor(N/12);
% Nm= N-Nyears*12;

% Days per month
dpm= [31 28 31 30 31 30 31 31 30 31 30 31]';
rub= [dpm(starting_date(2):end); repmat(dpm, Nyears+1, 1)];
days_per_month= rub(1 : N);
firstleap= rem(abs(starting_date(1)-2000), 4)+(starting_date(2)< 3);
if firstleap== 0, firstleap= firstleap+(starting_date(2)> 2)*3+1; end
febs= find(days_per_month== 28);
days_per_month(febs(firstleap) : 48 : end)= 29;

days_per_year= 365*ones(N, 1);
iii= find(days_per_month== 29);
ind= zeros(size(iii, 1), 12);
for i= 1 : size(iii, 1)
    ind(i, :)= [iii(i)-1 : iii(i)+10];
end
iii= [find(ind< 1) | find(ind> N)];
ind(iii)= [];
days_per_year(ind)= 366;

if S== 4
    days_per_month= [days_per_month; zeros(rem(size(days_per_month, 1), 3), 1)];
    days_per_quarter= sum(reshape(days_per_month, 3, size(days_per_month, 1)/3))';
    days_per_yearq= days_per_year(3 : 3 : end);
    y= days_per_quarter-days_per_yearq/4;
else
    y=days_per_month-days_per_year/12;
end

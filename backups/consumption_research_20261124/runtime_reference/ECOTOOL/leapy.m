function y= leapy(starting_date, N, ttype, S)
% leapy   Dummy variable for leap year intervention in either monthly 
%         or quarterly data
%
%     I= leapy(starting_date, N, ttype, S)
%
% INPUTS:
%   starting_date: (*) Starting date of data [yyyy mm] or [yyyy q] 
%   N:             (*) Number of monthly or quarterly observations to 
%                  simulate
%   ttype:         0 mark all februaries with 29 days
%                  1 consider year of 365.25 days
%   S:             Seasonal period of data (12 or 4) (12)
% OUTPUTS:
%   I:             Dummy variable Nx1
%
% Examples:
%   I= leapy([1990 6], 148);
% 
% See Also: easter, trading, days

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 3, ttype= 0; end
if isempty(ttype), ttype= 0; end

if nargin< 4, S= 12; end
if isempty(S), S= 12; end
if S~=12, S= 4; end

% Quarterly data
if S== 4
    starting_date(2)= starting_date(2)*3-2;
    N= N * 3;
end

% Days per month
Nyears= floor(N/12);
dpm= [31 28 31 30 31 30 31 31 30 31 30 31]';
rub= [dpm(starting_date(2):end); repmat(dpm, Nyears+1, 1)];
days_per_month= rub(1 : N);
firstleap= rem(abs(starting_date(1)-2000), 4)+(starting_date(2)< 3);
if firstleap== 0, firstleap= firstleap+(starting_date(2)> 2)*3+1; end
febs= find(days_per_month== 28);
days_per_month(febs(firstleap) : 48 : end)= 29;

ym= zeros(N, 1);
if ttype
    ym(find(days_per_month== 29))= 3;
    ym(find(days_per_month== 28))= -1;
else
    ym(find(days_per_month== 29))= 1;
end

if S== 4
    ym= [ym; zeros(rem(size(ym, 1), 3), 1)];
    y= sum(reshape(ym, 3, size(ym, 1)/3))';
else
    y= ym;
end


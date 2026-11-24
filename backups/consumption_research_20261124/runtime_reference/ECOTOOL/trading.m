function y= trading(starting_date, N, ttype, feast, S)
% trading   Creates dummy Trading day variables either on
%           monthly or quarterly frequency
%
%     I= trading(starting_date, N, ttype, feasts, S)
%
% INPUTS:
%   starting_date: (*) Starting date of data [yyyy mm] or [yyyy q] 
%   N:             (*) Number of monthly or quarterly observations to 
%                  simulate
%   ttype:         Type of dummies (0): 
%                        0 for just (5 weekday) vs (2 weekend days),
%                        1 for just (6 weekday) vs (1 weekend day),
%                        2 when all days are different
%   feasts:        Nx1 (if ttype= 0 or 1) or Nx6 (if ttype= 2) of 
%                  moving feastivals in weekdays
%   S:             Seasonal period of data (12 or 4) (12)
% OUTPUTS:
%   I:             Dummy variable Nx1 (ttype= 0 or ttype= 1) or Nx6 
%                  (ttype= 2)
% 
% Examples:
%   I= trading([1990 6], 148);
% See Also: easter, days, leapy
%

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
if ttype> 2, ttype= 2; end
if ttype< 0, ttype= 0; end

if nargin< 5, S= 12; end
if isempty(S), S= 12; end
if S~=12, S= 4; end
if S== 4
    starting_date(2)= starting_date(2)*3-2;
    N= N * 3;
end

if nargin< 4, feast= zeros(N, (ttype> 1)*5+1); end
if isempty(feast), feast= zeros(N, (ttype> 1)*5+1); end
if S== 4 & ttype< 2
    feast= [zeros(2, N); feast'];
    feast= feast(:);
elseif S== 4 & ttype== 2
    feast1= feast;
    feast= zeros(N*3, 6);
    for i= 1 : 6
        feasti= [zeros(2, N); feast1(:, i)'];
        feast(:, i)= feasti(:);        
    end
end

if length(feast)~=N, error('Input "feast" incorrect. Please revise.'); end

Days= 4*ones(N, 7);
Nyears= floor(N/12);
Nm= N-Nyears*12;

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
iii= [find(ind< 1); find(ind> N)];
ind(iii)= [];
days_per_year(ind)= 366;

% Number of types of days per month
months= ['Jan'; 'Feb'; 'Mar'; 'Apr'; 'May'; 'Jun'; 'Jul'; 'Aug'; 'Sep'; 'Oct'; 'Nov'; 'Dec'];
daytype= weekday(['1-' months(starting_date(2), :) '-' int2str(starting_date(1))])-1;
ind= rem((daytype : daytype+6), 7);
startingday= [daytype; zeros(N-1, 1)];
startingday(2 : end)= rem(daytype + cumsum(days_per_month(1 : end-1) - 28), 7);
startingday(find(startingday== 0))= 7;

for i= 1 : 7
    j= i;
    indi= find(startingday== j);
    
    iii= find(days_per_month(indi)> 28);
    Days(indi(iii), j)= Days(indi(iii), j)+1;
    j= j+1; if j> 7, j= 1; end
    iii= find(days_per_month(indi)> 29);
    Days(indi(iii), j)= Days(indi(iii), j)+1;
    j= j+1; if j> 7, j= 1; end
    iii= find(days_per_month(indi)> 30);
    Days(indi(iii), j)= Days(indi(iii), j)+1;
end

if ttype== 0
    Days(:, 1)= Days(: ,1) - feast;
%     Days(:, 7)= Days(:, 7) + feast;
    ym= sum(Days(:, 1:5)')'-sum(Days(:, 6:7)')'*2.5;
elseif ttype== 1
    Days(:, 1)= Days(: ,1) - feast;
%     Days(:, 7)= Days(:, 7) + feast;
    ym= sum(Days(:, 1:6)')'-Days(:, 7)*6;
else
    Days(:, 1 : 6)= Days(:, 1 : 6) - feast;
%     Days(:, 7)= Days(:, 7) + sum(feast')';
    ym= [Days(:, 1)-Days(:, 7) ...
        Days(:, 2)-Days(:, 7) ...
        Days(:, 3)-Days(:, 7) ...
        Days(:, 4)-Days(:, 7) ...
        Days(:, 5)-Days(:, 7) ...
        Days(:, 6)-Days(:, 7)];
end

if S== 4
    y= zeros(N/3, (ttype> 1)*5+1);
    for i= 1 : (ttype> 1)*5+1
        y(:, i)= sum(reshape(ym(:, i), 3, size(ym, 1)/3))';
    end
else
    y= ym;
end



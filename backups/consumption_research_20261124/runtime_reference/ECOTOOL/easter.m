function y= easter(starting_date, N, define, ttype, S)
% easter   Creates dummy Easter variables to test for Easter
%          effects on monthly or quarterly data
%
%    I= easter(starting_date, N, define, ttype, S)
%
% INPUTS:
%   starting_date: (*) Starting date of data [yyyy mm] or [yyyy q] 
%   N:             (*) Number of monthly or quarterly observations to 
%                  simulate
%   define:        ([0 5]) Matrix 1x2 1xANY ANYxANY that defines the 
%                  type of easter intervention
%                  reference_day is a positive or negative integer to 
%                  specify the reference day. 0: Easter Sunday
%                  [reference_day Number_of_days_to_and_including_Sunday] 
%                  all years equal 
%                  [reference_day W1 W2 W3 W4 ...] sum
%                  of weights should be 1. All years equal
%                  [r_d1 W1 W2 W3 W4; r_d2 A1 A2 0 0; ...] 
%                  One row for each year
%   ttype:         0 percentage of easter days in March/April 
%                  1 idem but compensating the increase in 
%                  one month with a decrease in the other
%   S:             Seasonal period of data (12 or 4) (12)
% OUTPUTS:
%   I:             Dummy easter variable of length N
%
% Examples:
%   I= easter([1990 6], 148, [0 8]);
%   I= easter([1990 6], 148, [0 8; -3 5]);
%   I= easter([1990 6], 148, [0 1/3 1/3 1/3 0 0; 3 1/5 1/5 1/5 1/5 1/5]);
% 
% See Also: trading, days, leapy

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 3, define= [0 5]; end
if isempty(define), define= [0 5]; end

if nargin< 4, ttype= 0; end
if isempty(ttype), ttype= 0; end

if nargin< 5, S= 12; end
if isempty(S), S= 12; end
if S~=12, S= 4; end

% Quarterly data
if S== 4
    starting_date(2)= starting_date(2)*3-2;
    N= N * 3;
end

% Sundays
easter_dates= [1900   4    4                                                                                                           
   1901   4    7                                                                                                           
   1902   3   30                                                                                                           
   1903   4   19                                                                                                           
   1904   4    3                                                                                                           
   1905   4   23                                                                                                           
   1906   4   15                                                                                                           
   1907   3   31                                                                                                           
   1908   4   19                                                                                                           
   1909   4   11                                                                                                           
   1910   3   27                                                                                                           
   1911   4   16                                                                                                           
   1912   4    7                                                                                                           
   1913   3   23                                                                                                           
   1914   4   12                                                                                                           
   1915   4    4                                                                                                           
   1916   4   23                                                                                                           
   1917   4    8                                                                                                           
   1918   3   31                                                                                                           
   1919   4   20                                                                                                           
   1920   4    4                                                                                                           
   1921   3   27                                                                                                           
   1922   4   16                                                                                                           
   1923   4    1                                                                                                           
   1924   4   20                                                                                                           
   1925   4   12                                                                                                           
   1926   4    4                                                                                                           
   1927   4   17                                                                                                           
   1928   4    8                                                                                                           
   1929   3   31                                                                                                           
   1930   4   20                                                                                                           
   1931   4    5                                                                                                           
   1932   3   27                                                                                                           
   1933   4   16                                                                                                           
   1934   4    1                                                                                                           
   1935   4   21                                                                                                           
   1936   4   12                                                                                                           
   1937   3   28                                                                                                           
   1938   4   17                                                                                                           
   1939   4    9                                                                                                           
   1940   3   24                                                                                                           
   1941   4   13                                                                                                           
   1942   4    5                                                                                                           
   1943   4   25                                                                                                           
   1944   4    9                                                                                                           
   1945   4    1                                                                                                           
   1946   4   21                                                                                                           
   1947   4    6                                                                                                           
   1948   3   28                                                                                                           
   1949   4   17                                                                                                           
   1950   4    9                                                                                                           
   1951   3   25                                                                                                           
   1952   4   13                                                                                                           
   1953   4    5                                                                                                           
   1954   4   18                                                                                                           
   1955   4   10                                                                                                           
   1956   4    1                                                                                                           
   1957   4   21                                                                                                           
   1958   4    6                                                                                                           
   1959   3   29                                                                                                           
   1960   4   17                                                                                                           
   1961   4    2                                                                                                           
   1962   4   22                                                                                                           
   1963   4   14                                                                                                           
   1964   3   29                                                                                                           
   1965   4   18                                                                                                           
   1966   4   10                                                                                                           
   1967   3   26                                                                                                           
   1968   4   14                                                                                                           
   1969   4    6                                                                                                           
   1970   3   29                                                                                                           
   1971   4   11                                                                                                           
   1972   4    2                                                                                                           
   1973   4   22                                                                                                           
   1974   4   14                                                                                                           
   1975   3   30                                                                                                           
   1976   4   18                                                                                                           
   1977   4   10                                                                                                           
   1978   3   26                                                                                                           
   1979   4   15                                                                                                           
   1980   4    6                                                                                                           
   1981   4   19                                                                                                           
   1982   4   11                                                                                                           
   1983   4    3                                                                                                           
   1984   4   22
   1985   4    7                                                                                                           
   1986   3   30                                                                                                           
   1987   4   19                                                                                                           
   1988   4    3                                                                                                           
   1989   3   26                                                                                                           
   1990   4   15                                                                                                           
   1991   3   31                                                                                                           
   1992   4   19                                                                                                           
   1993   4   11                                                                                                           
   1994   4    3                                                                                                           
   1995   4   16                                                                                                           
   1996   4    7                                                                                                           
   1997   3   30                                                                                                           
   1998   4   12                                                                                                           
   1999   4    4                                                                                                           
   2000   4   23                                                                                                           
   2001   4   15                                                                                                           
   2002   3   31                                                                                                           
   2003   4   20                                                                                                           
   2004   4   11                                                                                                           
   2005   3   27                                                                                                           
   2006   4   16                                                                                                           
   2007   4    8                                                                                                           
   2008   3   23                                                                                                           
   2009   4   12                                                                                                           
   2010   4    4                                                                                                           
   2011   4   24                                                                                                           
   2012   4    8                                                                                                           
   2013   3   31                                                                                                           
   2014   4   20                                                                                                           
   2015   4    5                                                                                                           
   2016   3   27                                                                                                           
   2017   4   16                                                                                                           
   2018   4    1                                                                                                           
   2019   3   24                                                                                                           
   2020   4   12
   2021   4    4                                                                                                           
   2022   4   17                                                                                                           
   2023   4    9                                                                                                           
   2024   3   31                                                                                                           
   2025   4   13                                                                                                           
   2026   4    5                                                                                                           
   2027   3   28                                                                                                           
   2028   4   16                                                                                                           
   2029   4    1                                                                                                           
   2030   4   21                                                                                                           
   2031   4   13                                                                                                           
   2032   3   28                                                                                                           
   2033   4   17                                                                                                           
   2034   4    9                                                                                                           
   2035   3   25                                                                                                           
   2036   4   13                                                                                                           
   2037   4    5                                                                                                           
   2038   4   25                                                                                                           
   2039   4   10                                                                                                           
   2040   4    1                                                                                                           
   2041   4   21                                                                                                           
   2042   4    6                                                                                                           
   2043   3   29                                                                                                           
   2044   4   17                                                                                                           
   2045   4    2                                                                                                           
   2046   3   25                                                                                                           
   2047   4   14                                                                                                           
   2048   4    5                                                                                                           
   2049   4   18                                                                                                           
   2050   4   10                                                                                                           
   2051   4    2                                                                                                           
   2052   4   21                                                                                                           
   2053   4    6                                                                                                           
   2054   3   29                                                                                                           
   2055   4   18                                                                                                           
   2056   4    2
   2057   4   22                                                                                                           
   2058   4   14                                                                                                           
   2059   3   30                                                                                                           
   2060   4   18                                                                                                           
   2061   4   10                                                                                                           
   2062   3   26                                                                                                           
   2063   4   15                                                                                                           
   2064   4    6                                                                                                           
   2065   3   22                                                                                                           
   2066   4   11                                                                                                           
   2067   4    3                                                                                                           
   2068   4   22                                                                                                           
   2069   4    7                                                                                                           
   2070   3   30                                                                                                           
   2071   4   19                                                                                                           
   2072   4   10                                                                                                           
   2073   3   26                                                                                                           
   2074   4   15                                                                                                           
   2075   3    7                                                                                                           
   2076   4   19                                                                                                           
   2077   4   11                                                                                                           
   2078   4    3                                                                                                           
   2079   4   23                                                                                                           
   2080   4    7                                                                                                           
   2081   3   30                                                                                                           
   2082   4   19                                                                                                           
   2083   4    4                                                                                                           
   2084   3   26                                                                                                           
   2085   4   15                                                                                                           
   2086   3   31                                                                                                           
   2087   4   20                                                                                                           
   2088   4   11                                                                                                           
   2089   3   27                                                                                                           
   2090   4   16                                                                                                           
   2091   4    8                                                                                                           
   2092   3   30
   2093   4   12                                                                                                           
   2094   4    4                                                                                                           
   2095   4   24                                                                                                           
   2096   4    8                                                                                                           
   2097   3   31                                                                                                           
   2098   4   20                                                                                                           
   2099   4   12];

% Re-defining variable define
Nyears= ceil(N/12);
[rdef, cdef]= size(define);
define= [define; repmat(define(end, :), Nyears-rdef, 1)];
if (cdef== 2 & define(1, 2)~= 1)
    cdef= define(:, 2);
    define= [define(:, 1) zeros(Nyears, max(cdef))];
    for i= 1 : Nyears
        define(i, 2 : cdef(i)+1)= repmat(1/cdef(i), 1, cdef(i));
    end
end
cdef= size(define, 2)-sum(define(:, 2:end)'== 0)'; rdef= Nyears;
if ~any(abs(sum(define(:, 2:end)')' - 1) < 1e-5)
    error('Input "define" wrong. Please revise.');
end

% Re-defining easter_dates according to input define
first= find(easter_dates(:, 1)== starting_date(1));
if starting_date(2)> easter_dates(first, 2), first= first+1; end
last= first + Nyears - 1;
for i= first : last
    j= i-first+1;
    easter_dates(i, 3)= easter_dates(i, 3) + define(j, 1);
    if easter_dates(i, 3)> 31
        easter_dates(i, 3)= easter_dates(i, 3) - 31;
        easter_dates(i, 2)= 4;
    end
    if easter_dates(i, 3)< 1
        easter_dates(i, 3)= easter_dates(i, 3) + 31;
        easter_dates(i, 2)= 3;
    end
end

% Weights
yt= ones(last-first+1, 1);
indapril= find(easter_dates(first : last, 2)== 4);
for i= 1 : size(indapril, 1)
    j= first+indapril(i)-1;
    if easter_dates(j, 3)< cdef(indapril(i))-1
        yt(indapril(i))= sum(define(indapril(i), cdef(indapril(i))-easter_dates(j, 3)+1 : cdef(indapril(i))));
    else
        yt(indapril(i))= 1;
    end
end

% output variable
ym= zeros(N, 1);
ending_date= [starting_date(1)+floor(N/12) ...
    rem(starting_date(2)+N-1,12)];
if ending_date(2)== 0, ending_date= [ending_date(1)-1 12]; end

% Creating dummy
last= find(easter_dates(:, 1)== ending_date(1));
if ending_date(2)< easter_dates(last, 2), last= last-1; end

if starting_date(1)< easter_dates(first, 1)
    ini= 12-starting_date(2)+easter_dates(first,2);
else
    ini= -starting_date(2)+easter_dates(first,2);
end
months= ini+cumsum([1; diff(easter_dates(first:last, 2))+12]);
% iii= find(months> N); months(iii)= [];
ym(months)= yt(1 : length(months));
iapril= months(find(easter_dates(first:last, 2)== 4));
if iapril(1)== 1, iapril(1)= []; end
% iii= find(iapril> N); iapril(iii)= [];
ym(iapril-1)= 1-ym(iapril);

% y= ym(1:N)-1/12;
y= ym;

%%% According to TRAMO
if ttype
    imarch= months(find(easter_dates(first:last, 2)== 3));
    iapril= months(find(easter_dates(first:last, 2)== 4));
    if imarch(end)== N, imarch(end)= []; end
    if iapril(1)== 1, iapril(1)= []; end
%     iii= find(iapril> N); iapril(iii)= [];
    ym(imarch+1)= -ym(imarch);
    ym(iapril-1)= -ym(iapril);
    ind= find(abs(ym(iapril))<= 0.5);
    ym(iapril(ind))= -ym(iapril(ind));
    ym(iapril(ind)-1)= -ym(iapril(ind)-1);
    y= ym;
end

if S== 4
    ym= [ym; zeros(rem(size(ym, 1), 3), 1)];
    y= sum(reshape(ym, 3, size(ym, 1)/3))'-1/4;
end


function ECOTOOLdemos(numdemo)
% ECOTOOLdemos   ECOTOOL demos
%    ECOTOOLdemos(number)
%
% INPUTS:
%   number: a number from 1 to 11
%           (1) Overview on Monthly Spanish electricity and gas demand
%           (2) Overview on hourly Spanish electricity demand and prices
%           (3) ARIMA modelling
%           (4) Unemployment in Spain
%           (5) Nile data
%           (6) US GDP and the Hodrick-Prescott filter
%           (7) Steel consumption in the UK
%           (8) SCC example
%           (9) Lydia Pynkham advertisement sales data
%          (10) Data interpolation and signal extraction
%          (11) Gas furnace data

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if numdemo== 1
    try echodemo('ecotooldemo1')
    catch me
        edit ecotooldemo1;
    end
elseif numdemo== 2
    try echodemo('ecotooldemo2')
    catch me
        edit ecotooldemo2;
    end
elseif numdemo== 3
    try echodemo('ecotooldemo3')
    catch me
        edit ecotooldemo3;
    end
elseif numdemo== 4
    try echodemo('ecotooldemo4')
    catch me
        edit ecotooldemo4;
    end
elseif numdemo== 5
    try echodemo('ecotooldemo5')
    catch me
        edit ecotooldemo5;
    end
elseif numdemo== 6
    try echodemo('ecotooldemo6')
    catch me
        edit ecotooldemo6;
    end
elseif numdemo== 7
    try echodemo('ecotooldemo7')
    catch me
        edit ecotooldemo7;
    end
elseif numdemo== 8
    try echodemo('ecotooldemo8')
    catch me
        edit ecotooldemo8;
    end
elseif numdemo== 9
    try echodemo('ecotooldemo9')
    catch me
        edit ecotooldemo9;
    end
elseif numdemo== 10
    try echodemo('ecotooldemo10')
    catch me
        edit ecotooldemo10;
    end
elseif numdemo== 11
    try echodemo('ecotooldemo11')
    catch me
        edit ecotooldemo11;
    end
end

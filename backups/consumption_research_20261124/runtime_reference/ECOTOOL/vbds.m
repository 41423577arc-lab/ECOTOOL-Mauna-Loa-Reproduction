function vbds(z, maxdim, distance, Names, win);
% VBDS   Brock, Dechert & Scheinkman test for independence
%    vbds(z, maxdim, distance)
%
% INPUTS:
%   z:        (*) Vector time series data (m x T or T x m)
%   maxdim:   Maximum dimension. The test is performed for dimensions from 2 to maxdim (1 x 1)
%   distance: Fraction of standard deviation of each series in z (1 x 1, default is 1.5)
%             This input is internally corrected if the distance supplied is too big
% 
% See Also: nltests, vtsay, varsbc2

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


% win= 0:  run independently
% win= 1:  run from testtool call
% win= 2:  run from Options menu

if nargin< 5, win= 0; end

if win> 0
    [z, Names, options, seriesval]= auxtestGUI;
    maxdim= options{22}{1}; distance= options{22}{2};
    seriesval= seriesval(1);
end    

[T, m]= size(z);
% if T<m, z= z'; [T, m]= size(z); end

defNames= [char(abs('#')*ones(m, 1)) int2str((1 : m)')];
if nargin< 4, Names= []; end
if isempty(Names), Names= defNames; end
sNames= size(Names, 1);
if (sNames< m & sNames== 1), Names= divstring(Names); end
sNames= size(Names, 1);
if sNames> m, Names= Names(1 : m, :); end
if sNames< m, Names= char(Names, defNames(sNames + 1 : end, :)); end
Names= [Names char(abs('@')*ones(m, 1))]';
Names= Names(:)'; Names= strrep(Names(1 : end-1), ' ', '');
Names= strrep(Names, '@', ' ');

if nargin< 2, maxdim= 2; end
if isempty(maxdim), maxdim= 2; end

if nargin< 3, distance= 1.5; end
if isempty(distance), distance= 1.5; end

maxdim= min(maxdim, T/2);
maxdim= min(maxdim);
distance= min(distance, min(0.9*(nanmax(z)-nanmean(z))));
distance= min(distance);

W= zeros(maxdim-1, m*2);
if m> 1, wwaitfor(m); end
for i= 1 : m
    [w, sig]= bds(z(find(~isnan(z(:, i))), i), maxdim, distance, 0);
    W(:, [(i-1)*2+1 i*2])= [w' sig'];
    if m> 1, wwaitfor; end
end
if m> 1, wwaitfor(0); end

dim= (2 : maxdim)';
Header= ['Dim ' strrep(Names, ' ', ' P-value ') ' P-value']; 
table= printwf([dim W], [0 4], Header);
textoutputWINDOW(charcat(' ', '-', 'Brock, Dechert & Scheinkman (BDS) Test ', '-', ...
    'H0: Process is linear and i.i.d. ', ...
    ['Distance as a fraction of the S.D.: ' num2str(distance) ' '], '-', ...
    table(1, :), '-', table(2 : end, :), '-'), ...
    'Brock, Dechert & Scheinkman (BDS) Test ');

delete(findall(gcf, 'label', '&Options'));
if win> 0
    uimenu(gcf, 'label', '&Options', ... 
        'callback', ['if optionsET({''Maximum Dimension [2, Num. data points/2):'', '...
            '''Distance as a fraction of the S.D. (0 Inf)''}, [2; 0.1], [22 1; 22 2]);' ...
            'vbds([], [], [], [], 2); end']);
end

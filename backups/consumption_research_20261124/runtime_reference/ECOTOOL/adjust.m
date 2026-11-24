function py= adjust(y, e)
% ADJUST    Substracts two time series adjusting the size of the matrices
%   PZ= adjust(z, e)
%
% INPUTS:
%   z:   (*) Vector time series data (m x T or T x m)
%   e:   (*) Residuals of model
%
% OUTPUTS:
%   PZ:  Fitted or forecast values
%        If the dimension of z is greater than e, the end of e is updated
%        to the end of z and viceversa

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[ry, cy]= size(y);
[re, ce]= size(e);

if ry< cy, y= y'; [ry, cy]= size(y); end
if re< ce, e= e'; [re, ce]= size(e); end

if ry> re
    py= [y(1 : ry-re, :); y(ry-re+1 : end, :)-e];
else
    py= y-e(re-ry+1 : end, :);
end
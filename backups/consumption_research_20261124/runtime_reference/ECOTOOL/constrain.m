function P= constrain(p, limits)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

p= p(:);
T= size(p, 1);

if nargin<2, limits= [0 1]; end
nlimits= size(limits, 1);
if nlimits< T, limits= [limits; repmat(limits(end, :), T-nlimits, 1)]; end

dlimits= limits(:, 2) - limits(:, 1);
if any(dlimits < 0), errorSSpace('Limits should be in ascending order.', 'constrain'); end

P= limits(:, 1)+(dlimits).*(exp(p)./(1 + exp(p)));

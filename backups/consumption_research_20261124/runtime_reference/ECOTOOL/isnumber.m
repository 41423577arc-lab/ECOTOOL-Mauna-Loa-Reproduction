function N= isnumber(str)
% Checks if the input is a number or a special character

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

Nstr= size(str, 2);
N= zeros(1, Nstr);
for i=1:Nstr
   stri= abs(str(i))*ones(1, 12);
   if any(stri== abs('0123456789_%')), N(i)= 1; end
end


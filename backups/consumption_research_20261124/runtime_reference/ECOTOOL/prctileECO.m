function p= prctileECO(z, value)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[rz, cz]= size(z);
if (rz== 1 | cz== 1), z= z(:); end
[rz, cz]= size(z);
z= sort(z);

value= value(:); lv= size(value, 1);

p= zeros(lv, cz);
for i= 1 : cz
    zi= z(find(~isnan(z(:, i))), i);
    rzi= size(zi, 1);
    if isempty(zi)
        p(:, i)= nan*ones(lv, 1);
    else
        x= [0 100*(0.5 : rzi - 0.5)./rzi 100];
        p(:, i)= interp1(x, [zi(1) zi' zi(end)], value);
    end
end

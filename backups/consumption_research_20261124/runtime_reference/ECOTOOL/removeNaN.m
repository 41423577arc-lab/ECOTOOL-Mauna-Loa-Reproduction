function [z, indY]= removeNaN(y)
% Remove NaNs from beginning and end of matrix y
% [z, ind]= removeNaN(y)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[N, m]= size(y);
trans= 0;
if N< m, y= y'; [N, m]= size(y); trans= 1; end

if m== 1
    ind= find(isnan(y')== m);
else
    ind= find(sum(isnan(y'))== m);
end
indY= [];
if isempty(ind)
    if trans
        z= y';
    else
        z= y;
    end
else
    i1= 1; i2= N;
    if ind(1)== 1   % NaNs at the beginning
        i1= min(find(diff(ind)-1))+1;
        if isempty(i1), i1= 2; end
    end
    if ind(end)== N   % NaNs at the end
        iii= max(find(diff(ind)-1))+1;
        if isempty(iii)
            i2= ind(1)-1;
        else
            i2= ind(iii)-1;
        end
    end
    if trans
        z= y(i1 : i2, :)';
    else
        z= y(i1 : i2, :);
    end
    indY= [i1 : i2]';
end



%%%%% AUXILIAR FUNCTION
function strnew= strrepwhole(S, S1, S2)
% Sustituye una string S2 por S1 en S, siempre que S1 sea una palabra entera

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

strnew= S;
ind= strfind(S, S1);
if ~isempty(ind)
    S= ['&' strrep(S, ' ', '&') '&'];
    ind= strfind(S, S1);
    lS1= length(S1);
    iii= [];
    for i= 1 : length(ind)
        c1= S(ind-1);
        c2= S(ind+lS1);
        if (~isletter(c1) & ~isletter(c2))
            iii= [iii ind(i)];
        end
    end
    for i= length(iii) : -1 : 1
        S= [S(1 : iii(i)-1) S2 S(iii(i)+lS1 : end)];
    end
    strnew= strrep(S(2 : end-1), '&', ' ');
end
% End of strrepwhole
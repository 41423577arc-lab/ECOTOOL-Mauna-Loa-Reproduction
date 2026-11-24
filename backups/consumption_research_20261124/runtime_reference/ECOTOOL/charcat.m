function table= charcat(varargin)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

N= zeros(nargin-1, 1);
table= [];
if nargin> 1
    for i= 1 : nargin
        if isnumeric(varargin{i})
            varargin{i}= printwf(varargin{i});
        end
        N(i)= size(varargin{i}, 2);
    end
    Nmax= max(N);
    for i= 1 : nargin
        if Nmax> N(i)
            table1= varargin{i};
            lastcol= table1(:, end);
            table1= [table1 lastcol(:, ones(1, Nmax-N(i)))];
            table= [table; table1];
        else
            table= [table; varargin{i}];
        end
    end
else
    table= varargin{1};
end

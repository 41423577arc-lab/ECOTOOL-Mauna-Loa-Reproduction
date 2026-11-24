function [inputs, tuplets] = checkInputs(INPUTS, varargin)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

nOptions = length(INPUTS);
nArgins = length(varargin);

% Checking correct varargin
tuplets = 0;
if rem(nArgins, 2) == 0
    areChar = zeros(nArgins / 2, 1);
    for i = 1 : 2 : nArgins
        areChar(i / 2 + 0.5) = ischar(varargin{i});
    end
    if all(areChar)
        tuplets = 1;
    end
end
% for i = 1 : 2 : nArgins
%     if ~ischar(varargin{i})
%         error('Incorrect inputs!!!');
%     end
% end
% Creating inputs struct
if tuplets
    values = cell(nOptions, 1);
    for i = 1 : 2 : nArgins
        iArgin = lower(varargin{i});
        nArgin = length(iArgin);
        candidates = zeros(nOptions, 1);
        for j = 1 : nOptions
            if nArgin <= length(INPUTS{j})  && strcmp(lower(INPUTS{j}(1 : nArgin)), iArgin)
                candidates(j) = 1;
            end
        end
        ind = find(candidates);
        if sum(candidates) == 0  % No matching
            error(['Input ' varargin{i} ' not valid!!!']);
        elseif sum(candidates) > 1
            error(['Ambiguous input ' varargin{i} '!!!']);
        else
            values{ind} = varargin{i + 1};
        end
    end
    inputs = cell2struct(values, INPUTS);
else
    inputs = cell2struct(cell(nOptions, 1), INPUTS);
end




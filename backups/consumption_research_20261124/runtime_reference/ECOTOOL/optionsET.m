function yes= optionsET(questions, ranges, menuoption)
% questions is a cell array of strings
% ranges is a matrix of ranges of allowed values for numerical variables (nan for text)
% menuoption is the item order in the Tests menu

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

yes= 1;

N= size(questions, 2);
if size(ranges, 2)== 1
    ranges(:, 2)= Inf*ones(size(ranges, 1), 1);
end

figh= get(gcf, 'Number');
if strcmp(get(gcf, 'name'), 'Text Output Window')
    figs= get(0, 'children');
    fighhandle= figs(2);  %get(0, 'CurrentFigure')-1;
    if isobject(figs)
        figh= fighhandle.Number;
    else
        figh= fighhandle;
    end
end

if figh> 0
    gcfuserdata= get(figh, 'userdata'); 
    options= gcfuserdata{2}; optionschar= gcfuserdata{4};
else
    gcfuserdata= []; options= []; optionschar= []; menuoption= 1;
end
if size(options, 2)== 1, menuoption= 1; end

[NN, mm]= size(menuoption);
menuoption= [menuoption; repmat(menuoption(end), N-NN, 1)];
if mm== 1, menuoption= [menuoption (1 : N)']; end
answer= cell(1, N); answerchar= answer;
number= zeros(N, 1);
for i= 1 : N
    answer{i}= options{menuoption(i, 1)}{menuoption(i, 2)};
    answerchar{i}= optionschar{menuoption(i, 1)}{menuoption(i, 2)};
    if isnumeric(answer{i})
%        answer{i}= num2str(answer{i});
        number(i)= 1;
    end
end

check= ones(N, 1);
ANSWER= cell(1, N); ANSWERchar= answer;
while check> 0
    lines= size(answerchar{1}, 1);
    ANSWERchar= inputdlg(questions, 'Set Options', lines, answerchar);
    ANSWER= ANSWERchar;
%    ANSWER= inputwin(questions, answer);
	if isempty(ANSWERchar), ANSWER= answer; ANSWERchar= answerchar; check= 0; yes= 0; end   % Cancel button pressed
	for i= 1 : size(ANSWERchar, 1)
        if number(i)
            try
                ANSWER{i}= eval(ANSWERchar{i});
                if isnumeric(ANSWER{i})
                    if (ANSWER{i}>= ranges(i, 1) & ANSWER{i}<= ranges(i,2)), check(i)= 0; else, check(i)= 1; end
                else
                    check(i)= 1;
                end
            catch
                check= ones(N, 1);
            end
        else
            if ischar(ANSWER{i}), check(i)= 0; else, check(i)= 1; end
        end
	end
end

if ~isempty(ANSWER)
    for i= 1 : N
        options{menuoption(i, 1)}{menuoption(i, 2)}= ANSWER{i};
        optionschar{menuoption(i, 1)}{menuoption(i, 2)}= ANSWERchar{i};
    end
    gcfuserdata{2}= options;
    gcfuserdata{4}= optionschar;
    set(figh, 'userdata', gcfuserdata);
end

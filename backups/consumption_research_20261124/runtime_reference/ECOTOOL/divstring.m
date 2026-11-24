function [STRdiv, li]= divstring(STR, character, align)
% DIVSTRING  Chops a string into parts marked by a given character
%   [STRdiv, li]= divstring(string, character, align)
%
% INPUTS:
%  string:    (*) String to divide
%  character: Character that serves as the mark to divide 'string' (default is ' ')
%  align:     Left, centered or right aligned (-1 / 0 / 1) (-1)
%
% OUTPUTS:
%  STRdiv:    String matrix, divided version of 'string'
%  li:        Size of each row of 'STRdiv'
%
% Examples:
%   divstring('a ab abc abcd abcde', [], 1)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 2, character= ' '; end
if isempty(character), character= ' '; end

if nargin< 3, align= -1; end
if isempty(align), align= -1; end

if size(STR, 1)> 1, STRdiv= STR; li= []; return; end

indx= [1 findstr(STR, character)+1]';
li= diff([indx; length(STR)])-1;
li(end)= li(end)+2;

maxli= max(li);
rli= size(li, 1);
STRdiv= char(repmat(1, rli, maxli)*abs(' '));
for i= 1:rli
   if align== -1
      STRdiv(i, 1 : li(i))= STR(indx(i):indx(i)+li(i)-1);
   elseif align== 0
      ini= max(floor((maxli - li(i))/2), 1);
      STRdiv(i, ini:ini+li(i)-1)= STR(indx(i):indx(i)+li(i)-1);
   else
      STRdiv(i, maxli-li(i)+1:maxli)= STR(indx(i):indx(i)+li(i)-1);
   end
end

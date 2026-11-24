function table= printwf(z, dec, TITLE, firstcol)
% PRINTWF  Print table output with format
%   table= printwf(y, dec, Header, firstcol)
%
% INPUTS:
%  y:        (*) Matrix of numbers (m1 x m2)
%  dec:      Number of decimals (1 x any)
%  Header:   String defining the header for each column (string)
%  firstcol: String for first column (string or character matrix m1 x any)
%
% OUTPUTS:
%  table:    Table output
%
% Examples:
%    printwf([-100; -10; -1; 1; 10; 100], 2, 'First_column');

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

[T, m]= size(z);

if nargin<4, firstcol= []; end
[Rf, Cf]= size(firstcol);
if (Rf== 1 & T~= 1)
   firstcol= divstring(firstcol);
   [Rf, Cf]= size(firstcol);
end

if nargin<3, TITLE= []; end

if nargin< 2, dec= repmat(4, 1, m); end
if isempty(dec), dec= repmat(4, 1, m); end
dec= dec(:);
ldec= size(dec, 1);
if ldec< m, dec= [dec; repmat(dec(end), m-ldec, 1)]; end

table= []; 
if isempty(TITLE)
   digits= zeros(1, m);
else
   TITLE= ['  ' strrep(TITLE, ' ', '  ')];
%   table=TITLE;
   digits= diff([findstr(TITLE, '  ') size(TITLE, 2)]);
end
for i= 1:T
   if isempty(firstcol)
      linei= [];
   else
      linei= firstcol(i, :);
   end
   for j= 1:m
      if isnan(z(i, j))
         zij= '  -';
      elseif dec(j)> -1
         zij= sprintf(['  %0.' int2str(dec(j)) 'f'], z(i, j));
      elseif dec(j)< 0
         zij= sprintf(['  %0.' int2str(abs(dec(j))) 'e'], z(i, j));
      end
      digits(j)= max([size(zij, 2) digits(j)]);
      linei= [linei zij];
   end
   if i>1
      [rT, cT]= size(table); cl= size(linei, 2);
      if cT< cl, table= [table char(abs(' ')*ones(rT, cl-cT))]; end
      if cl< cT, linei= [linei char(abs(' ')*ones(1, cT-cl))]; end
   end
   table= [table; linei];
end
[rtable, ctable]= size(table);
cfirstcol= size(firstcol, 2);
ctablet= sum(digits)+cfirstcol;
if ctable< ctablet
   table= [table char(abs(' ')*ones(rtable, ctablet-ctable))];
end

[rtable, ctable]= size(table);
cdigits= cumsum(digits);
if ~isempty(TITLE)
   TITLEF= char(abs(' ')*ones(1, ctable));
   ind= [findstr(TITLE, '  ') size(TITLE, 2)+1];
   for j=1:m
      zij= TITLE(ind(j)+2:ind(j+1)-1);
      czij= size(zij, 2);
      TITLEF(cfirstcol+((cdigits(j)-czij)+1:cdigits(j)))= zij;
   end
end
for i= 1:T
   if cfirstcol
      linei= [firstcol(i, :) char(abs(' ')*ones(1, ctable-cfirstcol))];
   else
      linei= [char(abs(' ')*ones(1, ctable))];
   end
   for j= 1:m
      if isnan(z(i, j))
         zij= '  -';
      elseif dec(j)> -1
         zij= sprintf(['  %0.' int2str(dec(j)) 'f'], z(i, j));
      elseif dec(j)< 0
         zij= sprintf(['  %0.' int2str(abs(dec(j))) 'e'], z(i, j));
      end
      czij= size(zij, 2);
      linei(cfirstcol+((cdigits(j)-czij)+1:cdigits(j)))= zij;
   end
   table(i, :)= linei;
end

if ~isempty(TITLE), table= [TITLEF; table]; end

lines= char(abs(' ')*ones(size(table, 1), 1));
table= [lines table lines];

if nargout== 0
   disp(table);
end

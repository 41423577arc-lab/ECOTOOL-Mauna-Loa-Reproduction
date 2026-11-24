%%%%%%%% AUXILIAR FUNCTION
function [numerator, denominator]= splitmodel(poly)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


if strcmp(poly, 'B'), poly= '1*B1'; end
if length(poly)== 1; poly= ['(' poly ')']; end
poly= strrep(poly, ')*(', ')(');
poly= strrep(poly, ')B(', ')(0*B0+1*B1)(');
poly= strrep(poly, '(B', '(0*B0+1*B');
poly= strrep(poly, '(-B', '(0*B0-1*B');
poly= strrep(poly, ')B', ')*B');
poly= strrep(poly, '[B', '[0*B0+1*B');
poly= strrep(poly, '[-B', '[0*B0-1*B');
poly= strrep(poly, ']B', ']*B');
poly= strrep(poly, '+B', '+1*B');
poly= strrep(poly, '-B', '-1*B');
poly= strrep(poly, 'B)', 'B1)');
poly= strrep(poly, 'B(', 'B1(');
poly= strrep(poly, 'B]', 'B1]');
poly= strrep(poly, 'B[', 'B1[');
poly= strrep(poly, 'B+', 'B1+');
poly= strrep(poly, 'B-', 'B1-');
% Modificando numeradores sin paréntesis
if ~strcmp(poly(1), '(')
    ii= findstr(poly, '/');
    if isempty(ii)
        poly= ['(' poly ')'];
    else
        poly= ['(' poly(1 : ii-1) ')' poly(ii : end)];
    end
end
% Poniendo potencias B0
paren= 1; nuevo= 1; poly= [poly '==']; iipoly= [];
for i= 2 : size(poly, 2)
    if strcmp(poly(i), '('), paren= paren+1; end
    if strcmp(poly(i), ')'), paren= paren-1; end
    if paren== 0, nuevo= 1; end
    if paren== 1 & strcmp(poly(i+1 : i+2), '*B'), nuevo= 0; end
    if paren== 1 & (strcmp(poly(i+1), '+') | strcmp(poly(i+1), '-') ...
             | strcmp(poly(i+1), ')')) & nuevo== 1
        nuevo= 0;
        iipoly= [iipoly i];
    end
end
iipoly= fliplr(iipoly);
for i= 1 : length(iipoly)
    poly= [poly(1 : iipoly(i)) '*B0' poly(iipoly(i)+1 : end)];
end
% Dividiendo en numerador y denominador
paren= 1; nuevo= 1; charsplit= 0;
for i= 2 : size(poly, 2)
    if strcmp(poly(i), '('), paren= paren+1; end
    if strcmp(poly(i), ')'), paren= paren-1; end
    if strcmp(poly(i), '/') & paren== 0, charsplit= i; break, end
    if paren== 0, nuevo= 1; end
end
if charsplit
    numerator= poly(1 : charsplit-1);
    denominator= poly(charsplit+1 : end-2);
else
    numerator= poly(1 : end-2);
    denominator= '(1*B0)';
end
% End of improvemodel function
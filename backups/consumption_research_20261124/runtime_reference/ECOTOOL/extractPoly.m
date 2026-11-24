%%%%%%%% AUXILIAR FUNCTION
function [par, polychar]= extractPoly(poly)
% Extracts parameter names, and poly for any polynomial
% poly='(a5*B)(5*B)(1-a7*B)(b8*B4)(5)(((1+a1)*cos(a2))+a3*B2)((-(1+a1)/constrain(a2,[0 1]))*B5)(B+B2-B5)B((2+3*4+a4)+(2+3*4+a4)*B+B2)(300+a1*B+(1-a2)*B100)(3-a1*B-a4*B50)(1-a8*B)(b8)'

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


ind= sort([findstr(poly, '(') findstr(poly, ')') findstr(poly, '+') findstr(poly, '-') ...
    findstr(poly, '/') findstr(poly, '*') findstr(poly, ',')  findstr(poly, '[')  findstr(poly, ']') ...
    findstr(poly, ' ')]);
par1= ' '; par= ' '; added= ' ';
for i= 2 : size(ind, 2)
    polyi= poly(ind(i-1)+1 : ind(i)-1);
    if ~isempty(polyi)
        par1= char(par1 ,polyi);
        added= char(added, poly(ind(i)));
    end
end
par1= par1(2 : end, :); added= added(2 : end, :);
for i= 1 : size(par1, 1)
    polyi= par1(i, :);
    polyi= strrep(polyi, ' ', '');
    if all(isstrprop(polyi, 'digit') + (polyi==repmat('.', 1, size(polyi, 2))))
        esnumero= 1;
    else
        esnumero= 0;
    end
    if (any(exist(polyi)== [2 5 6]) & strcmp(added(i), ')'))
        isfunction= 1;
    else
        isfunction= 0;
    end
    if (~esnumero & ~isfunction) %any(exist(polyi)== [2 5 6]) & )    % No es una función ni número
        if ~(strcmp(polyi(1), 'B') & all(isstrprop(polyi(2:end), 'digit'))) % Operador retardo
                par= char(par, polyi);
        end
    end
end
par= par(2 : end, :);  % Nombres de variables repetidos

% Creando polinomios
coef= [];
ipoly= [0 findstr(poly, ')(') size(poly, 2)];
Npoly= size(ipoly, 2)-1;
polychar= 'mconv(';
for i= 2 : Npoly+1
    power= []; coefi= ' ';
    if strcmp(poly(ipoly(i-1)+1), '(')
        polyi= [poly(ipoly(i-1)+2 : ipoly(i)-1) '='];
    else
        polyi= [poly(ipoly(i-1)+1 : ipoly(i)) '='];
    end
    iB= [findstr(polyi, '*B')-1 size(polyi, 2)];
    ini= 1; lengthcoefi= [];
    for j= 1 : size(iB, 2)-1
        coefi= char(coefi, polyi(ini : iB(j)));
        lengthcoefi= [lengthcoefi; iB(j)-ini+1];
        final= min([findstr(polyi(iB(j)+3 : end), '+') findstr(polyi(iB(j)+3 : end), '-') ...
            findstr(polyi(iB(j)+3 : end), '=')])-1;
        power= [power str2num(polyi(iB(j)+3 : iB(j)+3+final-1))];
        ini= iB(j)+3+final;
    end
    coefi= coefi(2 : end, :);
    polychari= '[';
    for j= 1 : size(coefi, 1)
        if j== 1
            zerosj= power(j);
        else
            zerosj= power(j) - power(j - 1) - 1;
        end
        if zerosj> 0
            zerosjchar= [' zeros(1, ' num2str(zerosj) ') '];
        else
            zerosjchar= '';
        end
        polychari= [polychari zerosjchar ' ' coefi(j, 1 : lengthcoefi(j))];
    end
    polychar= [polychar polychari '], '];
end
polychar= [strrep(polychar(1 : end-2), '[ ', '[') ')'];
polychar= strrep(polychar, '  ', ' ');
polychar= strrep(polychar, 'zeros(1, 1)', '0');
polychar= strrep(polychar, 'zeros(1, 2)', '0 0');
% polychar= strrep(polychar, 'zeros(1, 3)', '0 0 0');
% polychar= strrep(polychar, 'zeros(1, 4)', '0 0 0 0');
polychar= [polychar ';'];
iii= findstr(polychar, '],');
if isempty(iii)
    polychar= strrep(polychar, 'mconv(', '');
    polychar= polychar(1 : end-2);
end
if strcmp(poly, '1'), polychar= poly; end
% End of extractPoly function
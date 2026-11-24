% function [coefs, strucnumerical, diffoper, nARIMA]= polypar(model)
function [coefs, strucnumerical, diffoper]= polypar(model)
% modelo es A(B) y(t) = w1(B)/d1(B) u1(t) + w2(B)/d2(B) u2(t) + ... + Z(B)/P(B) a(t)
% {A(B), Z(B)/P(B), w1(B)/d1(B), ...}
%[coefs, strucnumerical]= polypar({'(1-p1B+0.8*B2+p4*B4)(1-p5B2)/(1+p6B)', '(2+p7B2)/(1-p8B)'})
% polysnum:  Número de polinomios de los numeradores
% polysden:  Número de polinomios de los denominadores
% model={'(1-pepe*B)(5)(((1+chiqui)*cos(a2))+a3*B2)((-(1+a1)/constrain(a2,[0 1]))*B5)/(1-B)','(a7*B10)/(1+a1*B)','(b8*B5)','1/(1-B)'}

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


N= size(model, 2);
strucnumerical= cell(N, 2);
varnames= ' '; diffoper= 1;
for i= 1 : N
    [numi, deni]= splitmodel(model{i});
    [varin, numi]= extractPoly(numi);
    if ~isempty(deni), [varid, deni]= extractPoly(deni); end
    strucnumerical{i, 1}= numi;
    strucnumerical{i, 2}= deni;
    varnames= char(varnames, varin, varid);
    % Extracting differencing operators
    diffchar= '';
    if i== 1
        iii= min(findstr(deni, '['));
        if ~isempty(iii)
            ind= [iii findstr(deni, ' -1]')+3];
            for j= 2 : size(ind ,2)
                ini= max(findstr(deni(ind(j-1) : ind(j)), '['));
                denij= deni(ind(j-1)+ini-1 : ind(j));
                if strcmp(denij, '[1 -1]'), diffchar= [diffchar denij ', ']; end
                if length(denij)> 9
                    if strcmp(denij(2:9), '1 zeros(')
                        espa= findstr(denij, ' ');
                        if length(espa)== 3
                            if strcmp(denij(espa(3) : end), ' -1]')
                                diffchar= [diffchar denij ', '];
                            end
                        end
                    end
                end
            end
            if size(ind, 2)== 2
                diffoper= eval(diffchar(1 : end-2));
            elseif ~isempty(diffchar)
                diffoper= eval(['mconv(' diffchar(1 : end-2) ');']);
            end
        end
    end
end
coefs= varnames(2 : end, :);
% Eliminando nombres de variables redundantes
lcoef= size(coefs, 1);
lcoefs= zeros(lcoef, 1); eliminate= lcoefs;
if size(coefs, 1)> 1
    for i= 1 : lcoef
        coefi= strrep(coefs(i, :), ' ', '');
        lcoefs(i)= size(coefi, 2);
        if isempty(coefi), eliminate(i)= 1; end
        for j= i+1 : lcoef
            coefj= strrep(coefs(j, :), ' ', '');
            if strcmp(coefi, coefj)
                eliminate(j)= 1;
            end
        end
    end
end
coefs(find(eliminate), :)= []; lcoefs(find(eliminate), :)= [];
[lcoefs1, iii]= sort(lcoefs, 1, 'descend');
% coefs= coefs(iii, :);
lcoef= size(coefs, 1);
for i= 1 : N
    for j= 1 : 2
        for k= 1 : lcoef
            coefk= strrep(coefs(iii(k), :), ' ', '');
            strucnumerical{i, j}= strrepwhole(strucnumerical{i, j}, coefk, ['x(' num2str(iii(k)) ')']);
        end
    end
end
% Poniendo coefs en una sola línea
COEF= '';
for i= 1 : lcoef, coefi= strrep(coefs(i, :), ' ', ''); COEF= [COEF coefi ' ']; end
coefs= COEF(1 : end-1);
% End of polypar function
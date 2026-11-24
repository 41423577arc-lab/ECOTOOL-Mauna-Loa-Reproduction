function unitRoots = checkRoots(model, coefs, par)
% Check a model with multiple inputs
nModels = length(model);
unitRoots = zeros(2, nModels);
if nModels == 1 && ~iscell(model)
    model = {model};
end
for i = 1 : nModels
    unitRoots(:, i) = checkModel(model{i}, coefs, par);
end

function uModel = checkModel(model, coef, par)
% Check one model for noise or one single input
aux = strfind(model, '/');
if isempty(aux)
    num = model;
    den = 1;
else
    num = model(1 : aux - 1);
    den = model(aux + 1 : end);
end
uModel = zeros(2, 1);
% Numerators
uModel(1) = checkPolys(num, coef, par);
% Denominators
uModel(2) = checkPolys(den, coef, par);

function uRoots = checkPolys(poly, coef, par)
% Returns whether one single polynomial has a unit root
uRoots = 0;
polysPos = [0 strfind(poly, ')')];
nPolys = length(polysPos) - 1;
if nPolys
    for i = 2 : nPolys + 1
        polyI = poly(polysPos(i - 1) + 2 : polysPos(i) - 1);
        aux = strfind(polyI, '-B');
        if isempty(aux)
            absRoots = abs(roots(convert(polyI, coef, par)));
        else
            if length(strfind(polyI, 'B')) == 1
                absRoots = 0;
            end
        end
        uRoots = any(absRoots > 0.997);
        if uRoots
            return
        end
    end
end

function polyNum = convert(poly, coef, par)
% poly = '1+a1*B+a200*B200'; coef = 'a1 a200'; par = [0.5 0.3];
% Returns polynomial converted to numerical
plus = strfind(poly, '+');
minus = strfind(poly, '-');
terms = [0 sort([plus minus]) length(poly) + 1];
polyNum = [];
nTerms = length(terms) - 1;
pow0 = 0;
if ~isempty(terms)
    for i = 2 : nTerms + 1
        [c, pow] = checkTerm(poly(terms(i - 1) + 1 : terms(i) - 1), coef, par);
        polyNum = [polyNum zeros(1, pow - pow0 - 1) c];
        pow0 = pow;
    end
end
if isempty(polyNum)
    polyNum = 1;
end

function [coefficient, pow] = checkTerm(polyii, coefff, parrr)
% Returns coefficient and power for a single term
polyii = [polyii ' '];
BBB = strfind(polyii, '*B');
if isempty(BBB)
    coefficientStr = polyii;
    pow = 0;
else
    coefficientStr = polyii(1 : BBB - 1);
    pow = str2num(polyii(BBB + 2 : end));
    if isempty(pow)
        pow = 1;
    end
end
nPar = length(parrr);
equalll = [divstring(coefff) repmat('=', nPar, 1) num2str(parrr(:)) repmat(';', nPar ,1)];
for i = 1 : nPar
    eval(equalll(i, :));
end
coefficient = eval(coefficientStr);








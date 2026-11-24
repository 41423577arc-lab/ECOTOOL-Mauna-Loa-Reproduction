function [H, obj, e]=jacobECOTOOL(funcion, x, varargin)
% function [H, e]=jacobECOTOOL(funcion,x,i1,i2,i3,i4,i5,i6,i7,i8,i9,i10,i11,i12,i13,i14,i15,i16,i17,i18,i19,i20)
% JACOB   Numerical evaluation of the Jacobian
%
% [J, e]=jacob(funcion,x,i1,i2,i3, ...)
%
% funcion: Name of the m function to evaluate the objective
% x: Point at which the Jacobian is evaluated
% i1, i2, ...: Optional inputs to the function
%
% J: Jacobian for funcion evaluated at x
% e: Residuals from function evaluated at x

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

% String for function evaluation
string=[funcion '(bb, varargin{:});'];
% for i=3:nargin
%   string= [string ',i' int2str(i-2)];
% end
% string= [string ');'];

npar= length(x);
bb= x; eval(['[obj, e]=' string]);
H= zeros(length(obj), npar); inc= 1e-5*abs(x);
for i= 1:npar
  bb= x; bb(i)= x(i)+inc(i); eval(['obj1=' string]);
  H(:, i)= (obj1-obj)/inc(i);  
end

% string=[funcion '(bb'];
% for i=3:nargin
%   string= [string ',i' int2str(i-2)];
% end
% string= [string ');'];
% 
% npar= length(x);
% bb= x; eval(['e=' string]);
% H= zeros(length(e), npar); inc= 1e-5*abs(x);
% for i= 1:npar
%   bb= x; bb(i)= x(i)+inc(i); eval(['obj1=' string]);
%   H(:, i)= (obj1-e)/inc(i);  
% end


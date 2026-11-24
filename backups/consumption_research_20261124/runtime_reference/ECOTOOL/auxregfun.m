function [obj, e]=auxregfun(x, y, u, strucnumerical, modelo, back, nans, V, DIFFoper, inicondU)
% x are the parameters of the model
% First are the noise model (AR parameters first)
% Then the TF models (for each input)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


[N, Nu]= size(u);
[N, Ny]= size(y);
for i= 1 : size(nans, 2)
   if iscell(nans), nansi= nans{i}; else, nansi= nans; end
%    if Nu> 0
%       [e, pyi]= regARIMA(y(1 : nansi(1)-1), u(1 : nansi(1)-1, :), modelo, u(nansi, :), 0, 0, x, [], 0);
%    else
      [e, pyi]= regARIMA(y(1 : nansi(1)-1), [], modelo, size(nansi, 1), [], 0, x, 0, 0);
%    end
   y(nans{i}, 1)= pyi;
end

polys= convert2poly(strucnumerical, x);
Npoly= size(polys, 1);

% e= y(:, 1);
nn= length(DIFFoper);
yhat= zeros(N-nn+1, 1);
if Nu
% % %     for i= 2 : Npoly
% % % %         inicond= max(length(polys{i, 1}), length(polys{i, 2}))-1;
% % % %         yhati= filter(polys{i, 1}, polys{i, 2}, [repmat(u(1,i-1), inicond,1); u(:, i-1)]);
% % %         yhati= filter(polys{i, 1}, polys{i, 2}, [inicondU; u(:, i-1)]);
% % %         yhat= yhat + yhati(size(inicondU, 1)+1 : end);
% % % %         if i==Npoly, plot(yhati(inicond+1:end)), title(i); drawnow,end
% % %     end
% % % %    ei= filter(polys{1, 2}, polys{1, 1}, y(:, 1) - yhat);
% % % %    e= ei(max([size(polys{i, 1}, 2) size(polys{i, 2}, 2)]) : end);
% % %    e= y - yhat; size(e)
%     for i= 2 : Npoly
%         inicond= max(length(polys{i, 1}), length(polys{i, 2}))-1;
%         yhati= filter(polys{i, 1}, polys{i, 2}, [repmat(u(1,i-1), inicond,1); u(:, i-1)]);
%         if (DIFFoper== 1)
%             if isempty(inicondU)
%                 du= u(:, i-1);
%             else
%                 du= [inicondU(:, i-1); u(:, i-1)];
%             end
%         else
%             if isempty(inicondU)
%                 du= filter(DIFFoper, 1, u(:, i-1));
%             else
%                 du= filter(DIFFoper, 1, [inicondU(:, i-1); u(:, i-1)]);
%             end
%             if nn< 1, du(1 : nn-1)= 0; end %du(length(DIFFoper) : end);
%         end
%         yhati= filter(polys{i, 1}, polys{i, 2}, du(nn:end));
%         yhat= yhat + yhati(size(inicondU, 1)+1 : end);
% %         if i==Npoly, plot(yhati(inicond+1:end)), title(i); drawnow,end
%     end
    yhat= u*x(size(x, 1)-size(u, 2)+1:end);
end
%    ei= filter(polys{1, 2}, polys{1, 1}, y(:, 1) - yhat);
%    e= ei(max([size(polys{i, 1}, 2) size(polys{i, 2}, 2)]) : end);
if (DIFFoper== 1)
   dy= y;
else
   dy= filter(DIFFoper, 1, y);
end
e= dy(nn : end) - yhat;
if back> -1          % Conditional ML
    ppoollyy= deconv(polys{1, 2}, DIFFoper);
    dfy= filter(ppoollyy, 1, e);
    e= filter(1, polys{1, 1}, dfy(size(ppoollyy, 2)+1 : end));
    obj= e'*e;
% % %     dfy= filter(polys{1, 2}, 1, e);
% % %     e= filter(1, polys{1, 1}, dfy(size(polys{1, 2}, 2)+1 : end));
% % %     obj= e'*e;
else                 % Exact ML
    ini= size(V, 1);
    % Covariance generating fuction
    sigma= filter(polys{1, 1}, deconv(polys{1, 2}, DIFFoper), [1; zeros(ini-1, 1)]);
    sigma1= conv(sigma, flipud(sigma));
    sigma= sigma1(ini : end);
    V= sigma(V);
    if polys{1, 1}== 1 % AR
        ppoollyy= deconv(polys{1, 2}, DIFFoper);
        e= filter(ppoollyy, 1, e);
        [V, D]= ldl(V);
        for i= nn+1 : nn+ini-1, ii= i-nn+1; e(i)= e(i)-V(ii, 1 : ii-1)*e(nn : nn+ii-2); end
        % obj= log(prod(diag(D))) + (y(1 : ini)./diag(D))'*y(1 : ini)+y(ini+1 : end)'*y(ini+1 : end);
        NN= N - nn + 1;
        ve= e(nn : end)'*e(nn : end)/NN;
        obj= NN*log(ve)+log(prod(diag(D))) + (e(nn : nn+ini-1)./(diag(D)))'*e(nn : nn+ini-1)/ve;
        obj= obj + e(nn+ini : end)'*e(nn+ini : end)/ve;
    else         % MA or ARMA
        [V, D]= ldl(V);
        for i= 2:N-nn+1, e(i)= e(i)-V(i, 1 : i-1)*e(1 : i-1); end
        NN= length(e);
        ve= e'*e/NN;
        D(:, 1)= diag(D);
        obj= NN*log(ve)+log(prod(D(:, 1))) + (e./(D(:, 1)))'*e/ve;
% % %         e= filter(DIFFoper, 1, e);
% % %         [V, D]= ldl(V);
% % %         for i= nn+1:N, ii= i-nn+1; e(i)= e(i)-V(ii, 1 : ii-1)*e(nn : nn+ii-2); end
% % %         ind= find(~isnan(y(nn : N)))+nn-1;
% % %         NN= length(ind);
% % %         ve= e(ind)'*e(ind)/NN;
% % %         D(:, 1)= diag(D);
% % %         obj= NN*log(ve)+log(prod(D(ind-nn+1, 1))) + (e(ind)./(D(ind-nn+1, 1)))'*e(ind)/ve;
    end
end
if (~isnan(obj) & ~isinf(obj)), set(0, 'userdata', x); end


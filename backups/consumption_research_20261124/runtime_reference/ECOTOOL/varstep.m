function [z, zmax, zmin]= varstep(ARpoly, n, typefun, sdAR, Nsimul, win, plotting);
% varstep   Var impulse and step function analysis
%
%   [z, zmax, zmin]= varstep(ARpoly, n, typefun, sdAR, Nsimul)
%
% INPUTS:
%   ARpoly:  (*) Vector AR polynomial (m x Na*m)
%            Leading matrix coefficient may different from identity 
%            matrix (structural models)
%   n:       Maximum lag for impulse or step analysis (1 x 1)
%   typefun: Impulse or step function (0/1)
%   sdAR:    Minimum and Maximum values for AR parameters for impulse 
%            or step error bounds
%            by a Montecarlo simulation (2*m x Na*m)
%   Nsimul:  Number of runs for Montecarlo simulation for error bounds 
%            (1 x 1)
%
% OUTPUTS:
%   z:    Impulse or step function (m x m x n)
%   zmax: Maximum boundary for impulse or step function for Montecarlo simulation (m x m x n)
%   zmin: Minimum boundary for impulse or step function for Montecarlo simulation (m x m x n)

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

if nargin< 6, win= 0; end
if nargin< 7, plotting= 1; end

if win> 0
    menu1= get(gcbo, 'parent');
    i1= get(menu1, 'userdata');
    i2= get(gcbo, 'userdata');
    if isempty(i1), i1= i2; end
    data= get(gcf, 'userdata');
    z= data{1}; zmin= data{2}; zmax= data{3};
    n= data{4}; m= data{5}; typefun= data{6};
else
    m= size(ARpoly, 1);
	I= eye(m);
	
	if isempty(ARpoly), ARpoly= I; end
	%if isempty(MApoly), MApoly= I; end
	MApoly= I;
    C= ARpoly(:, 1 : m);
	
	if (~all(C(:)== I(:)) & ~all(MApoly(:)== I(:)))
        errordlg('Matrix C can only be specified for pure VAR systems');
	end
	if nargin< 2, n= 20; end
	if isempty(n), n= 20; end
	
	if nargin< 3, typefun= 1; end   % step response
	if isempty(typefun), typefun= 1; end
	if typefun~= 1, typefun= 0; end
        
	%if nargin< 6, sdMA= []; end
	sdMA= [];
	if nargin< 4, sdAR= []; end
    if ~isempty(sdAR), sdAR(find(isnan(sdAR)))= 0; sdAR(1 : end, 1: m)= [eye(m);eye(m)]; end
	if nargin< 5, sdC= []; end
	if nargin< 5, Nsimul= 1000; end
	
	orderAR= size(ARpoly, 2)/m-1;
	orderMA= size(MApoly, 2)/m-1;
	Tsi= eye(m); MAT= Tsi; iMAT= Tsi;
	ARpolye= ARpoly;
	% For SVAR systems 
	if ~all(C(:)== I(:))
        for i= 1 : orderAR
            Tsi= Tsi + ARpoly(:, i*m+1 : i*m+m);
        end
        Tsi= inv(Tsi);
        MAT= inv(C)*Tsi; iMAT= inv(MAT);
        ARpolye(:, m+1 : end)= vConv(MAT, ARpoly(:, m+1 : end));
	end
	

% Calculations
	z= zeros(m, m, n);
	order= max(orderAR, orderMA);
	for i= 1 : m
        u= zeros(m, n + orderAR); zi= u;
        if typefun
            u(i, :)= ones(1, n + orderAR);
        else
            u(i, order+1)= 1;
        end
        for t= order+1 : n+order
            zi(:, t)= u(:, t);
            for k= 1 : orderAR
                zi(:, t)= zi(:, t)-ARpolye(:, k*m+1 : k*m+m)*zi(:, t-k);
            end
            for k= 1 : orderMA
                zi(:, t)= zi(:, t)+MApoly(:, k*m+1 : k*m+m)*u(:, t-k);
            end
            zi(:, t)= iMAT*zi(:, t);
        end
        z(1 : m, i, :)= zi(:, order+1 : end);
	end

% Montecarlo simulation for confidence bands
	zmax= []; zmin= [];
	if (~isempty(sdAR) | ~isempty(sdMA))
        mm= size(sdAR, 1); sdC= sdAR(:, 1 : m);
        if (isempty(sdAR) | mm==m)
            ARpolymax= ARpoly; ARpolymin= ARpoly;
        else
            ARpolymin= sdAR(1:m, :);
            ARpolymax= sdAR(m+1:end, :);
        end
        mm= size(sdMA, 1);
        if (isempty(sdMA) | mm==m)
            MApolymin= MApoly; MApolymax= MApoly;
        else
            MApolymin= sdMA(1:m, :);
            MApolymax= sdMA(m+1:end, :);
        end
        mm= size(sdC, 1);
        if (isempty(sdC) | mm==m)
            Cmax= C; Cmin= C;
        else
            Cmin= sdC(1:m, :);
            Cmax= sdC(m+1:end, :);
        end
        
        zmax= z; zmin= z; zs= z;

       if plotting, wwaitfor(fix(Nsimul/10)); end
        for i= 1 : Nsimul
            if (rem(i, 10)== 0 & plotting), if wwaitfor; break; end; end
            ARp= rand(size(ARpolymin)).*(ARpolymax-ARpolymin)+ARpolymin;
            MAp= rand(size(MApolymin)).*(MApolymax-MApolymin)+MApolymin;
			if ~all(C(:)== I(:))
                Cp= rand(size(Cmin)).*(Cmax-Cmin)+Cmin;
			end
            zs= varstep(ARp, n, typefun, [], [], 0, 0);
            zmax= max(zmax, zs);
            zmin= min(zmin, zs);
        end
        if plotting, wwaitfor(0); end
	end
    i1= m+1; i2= [];
end

if (win== 0 & plotting> 0 & nargout== 0)
   if strcmp(get(gcf,'name'), 'Text Output Window')
       fig= get(0, 'children');
       fig= fig(end);
       if strcmp(get(fig, 'name'), 'Text Output Window')
           figure;
       else
           figure(fig);
       end
   end
   clf;
   if typefun> 0
       titlestr= 'Step';
   else
       titlestr= 'Impulse';
   end
   set(gcf, 'name', ['Vector ' titlestr ' Function'], 'toolbar', 'figure');
   set(gcf, 'userdata', {z, zmin, zmax, n, m, typefun});

   %if nargin< 2, ARpoly= []; end
	
	%m= max(size(ARpoly, 1), size(MApoly, 1));
    
	if m>1
       MENU_H= findall(gcf, 'label', titlestr);
       if isempty(MENU_H), MENU_H= uimenu(gcf, 'label', titlestr); end
       delete(get(MENU_H, 'children'));
       for i= 1:m
          Hmenu= uimenu(MENU_H, 'label', ['#' int2str(i)], 'userdata', i);
          for j= 1 : m
              uimenu(Hmenu, 'label', ['#' int2str(j)], 'userdata', j, ...
                  'callback', 'varstep([], [], [], [], [], 1);');
          end
       end
       uimenu(MENU_H, 'label', 'All', 'userdata', m+1, ...
              'callback', 'varstep([], [], [], [], [], 1);');
	end
end

if (i1== m+1 & plotting> 0 & nargout== 0)
    clearscreen;
	k= 1;
    for i= 1 : m
        for j= 1 : m
            subplot(m, m, k);
            if isempty(zmin)
                zi= zeros(n, 1);
                for v= 1 : n
                   zi(v, 1)= z(i, j, v);
                end
                plot((1: n)', zi, 'k')
            else
                zi= zeros(n, 3);
                for v= 1 : n
                   zi(v, 1)= z(i, j, v);
                   zi(v, 2)= zmin(i, j, v);
                   zi(v, 3)= zmax(i, j, v);
                end
                plot((1: n)', zi(:, 1), 'k', (1:n)', zi(:, 2:3), 'r:')
            end
            v= axis; axis([0 n+1 v(3:4)]);
            line([0 n+1], [0 0], 'linestyle', ':', 'color', 'r')
            if typefun
                titlestr= 'Step';
            else
                titlestr= 'Impulse';
            end
            if i== 1, title([titlestr ' in #' int2str(j)]); end
            if j== 1, ylabel(['#' int2str(i)]); end
            k= k+1;
        end
    end
elseif (i1< m+1 & plotting> 0)
    clearscreen;
    if isempty(zmin)
        zi= zeros(n, 1);
        for v= 1 : n
           zi(v, 1)= z(i2, i1, v);
        end
        plot((1: n)', zi, 'k')
    else
        zi= zeros(n, 3);
        for v= 1 : n
           zi(v, 1)= z(i2, i1, v);
           zi(v, 2)= zmin(i2, i1, v);
           zi(v, 3)= zmax(i2, i1, v);
        end
        plot((1: n)', zi(:, 1), 'k', (1:n)', zi(:, 2:3), 'r:')
    end
    v= axis; axis([0 n+1 v(3:4)]);
    line([0 n+1], [0 0], 'linestyle', ':', 'color', 'r')
    if typefun
        titlestr= 'Step';
    else
        titlestr= 'Impulse';
    end
    title([titlestr ' in #' int2str(i1)])
    ylabel(['#' int2str(i2)]);
end

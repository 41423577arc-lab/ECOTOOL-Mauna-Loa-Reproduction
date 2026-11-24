% General purpose variables for SSpace estimation and Smoothing

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

% Table output on/off: 1/0
TABLE_OUTPUT= 0;

% Stop window on/off: 1/0
STOP_WINDOW= 0;

% Display intermediate results of optimisation on/off: 1/0
DISPLAY_RESULTS= 0;

% Objective function to minimise
OBJECTIVE_FUN= 'lliket';

% SSpace warnings on/off
SSpace_WARNINGS= 0;

% WARNING!!!: DO NOT CHANGE ANYTHING BEYOND THIS LINE, CONTACT THE AUTHOR INSTEAD
% OPTIMISER_OPTIONS: Optimiser options to control the estimation procedure
%                    It may be string or numerical depending on the Optimiser used
% OPTIMISER_COMMAND: String containing the optimiser command
% FUN_OPTIMUM:       String with command to evaluate the objective function 
%                    or numerical value of the objective function at the optimum
% EVAL_FUN:          Command to evaluate the objective funcion

%%%% Code for fminsearch optimiser  !!!!!!!
if DISPLAY_RESULTS
   OPTIMISER_OPTIONS= optimset('Display', 'iter', ...
      'LargeScale', 'off', ...
      'hessupdate', 'bfgs', ...
      'MaxIter', 1e6, ...
      'MaxFunEval', 1e6, ...
      'TolX', 1e-4, ...
      'TolFun', 1e-4);
%      'hessupdate', 'steepdesc');
else
   OPTIMISER_OPTIONS= optimset('Display', 'off', ...
      'LargeScale', 'off', ...
      'hessupdate', 'bfgs', ...
      'MaxIter', 1e6, ...
      'MaxFunEval', 1e6, ...
      'TolX', 1e-4, ...
      'TolFun', 1e-4);
%      'hessupdate', 'steepdesc');
end
OPTIMISER_COMMAND= ['[p, FUN_OPTIMUM]= fminunc(''' OBJECTIVE_FUN '''' ',p,OPTIMISER_OPTIONS,z,u,model_struc,x0,P0,Miss,timev,charsys,Inter,PInter,HANDLES,call_varargin,varargin{:});'];
EVAL_FUN= ['obj= ' OBJECTIVE_FUN '(p,z,u,model_struc,x0,P0,Miss,timev,charsys,Inter,PInter,[],call_varargin,varargin{:});'];

%%%% Code for e4min optimiser !!!!!!!
%NO= 'no'; if DISPLAY_RESULTS, NO= 'yes'; end
%OPTIMISER_OPTIONS= ['e4init; sete4opt(''toler'',1e-3,''maxiter'',7000,''verbose'',''' NO ''');'];
%OPTIMISER_COMMAND= ['[p, iter, FUN_OPTIMUM]=e4min(''' OBJECTIVE_FUN '''' ',p,'''',z,u,model_struc,x0,P0,Miss,timev,charsys,Inter,PInter,[],call_varargin,varargin{:});'];
%EVAL_FUN= ['obj= ' OBJECTIVE_FUN '(p,z,u,model_struc,x0,P0,Miss,timev,charsys,Inter,PInter,[],call_varargin,varargin{:});'];

%%%% Code for fminu optimiser  !!!!!!!
%OPTIMISER_OPTIONS= [DISPLAY_RESULTS 1e-3 1e-3 0 0 0 0 0 0 0 0 0 0 10000 0 0 0 0.5];
%OPTIMISER_COMMAND= ['[p, OPTIMISER_OPTIONS]= fminu(''' OBJECTIVE_FUN '''' ',p,OPTIMISER_OPTIONS,[],z,u,model_struc,x0,P0,Miss,timev,charsys,Inter,PInter,HANDLES,call_varargin,varargin{:});'];
%FUN_OPTIMUM= 'OPTIMISER_OPTIONS(8)';
%EVAL_FUN= ['obj= ' OBJECTIVE_FUN '(p,z,u,model_struc,x0,P0,Miss,timev,charsys,Inter,PInter,[],call_varargin,varargin{:});'];

% %%% Code for ga optimiser
% OPTIMISER_OPTIONS= ['popSize= 20; ' ...
%     'OPTIMISER_OPTIONS= gaoptimset(''display'', ''iter'', ' ...
%                            '''PopulationSize'', popSize,' ...
%                            '''StallGenLimit'', Inf,' ...
%                            '''StallTimeLimit'', Inf,' ...
%                            '''InitialPopulation'', [p''; rand(popSize-1, npar)*2-1+repmat(p'', popSize-1, 1)],' ...
%                            '''TimeLimit'', Inf,' ...
%                            '''PlotFcns'', {@gaplotbestf,@gaplotbestindiv});'];
% % FitnessFcn= @(p) lliknan(p, z, u, model_struc, x0, P0, Miss, timev, charsys, Inter, PInter, [], call_varargin, varargin);
% OPTIMISER_COMMAND= ['FitnessFcn= @(p) ' OBJECTIVE_FUN '(p, z, u, model_struc, x0, P0, Miss, timev, charsys, Inter, PInter, [], call_varargin, varargin{:}); ' ...
%     'p= ga(FitnessFcn, npar, OPTIMISER_OPTIONS);'];
% FUN_OPTIMUM= '10';
% EVAL_FUN= ['obj= ' OBJECTIVE_FUN '(p,z,u,model_struc,x0,P0,Miss,timev,charsys,Inter,PInter,[],call_varargin,varargin{:});'];




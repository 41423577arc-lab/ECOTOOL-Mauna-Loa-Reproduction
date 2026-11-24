function [f,p] = fit_uc_final4(y,model,H)
cfg=experimentConfig();
f=fitUC(y,model,cfg);
[p,~]=forecastUC(f,H);
end
function cfg = experimentConfig()
cfg = struct;
cfg.trainN = 108;
cfg.testN = 4;
cfg.oneStepOrigins = 78:107;
cfg.fourStepOrigins = 78:104;
cfg.horizon = 4;
cfg.models = ["RW","LLT","历史均值"];
cfg.logVarianceBounds = [-18,6];
cfg.maxIterations = 300;
cfg.maxFunctionEvaluations = 1200;
cfg.optimalityTolerance = 1e-7;
cfg.stepTolerance = 1e-8;
cfg.constraintTolerance = 1e-8;
cfg.startLogVariance.RW = log([.05,.95; .50,.50; .005,.995]);
cfg.startLogVariance.LLT = log([.05,.005,.95; .50,.05,.50; .005,.0005,.995]);
cfg.selectionRule = "27个训练原点、每点四步合并MAE最小；MAE数值相同时按RMSE最小；未收敛UC不参与选模";
cfg.scaleRule = "每个估计窗口单独使用窗口均值和样本标准差标准化；方差参数按标准差平方还原到元平方";
cfg.seed = 20261124;
end

function fitted = fitUC(y,model,cfg)
y=double(y(:));
mu=mean(y); sigma=std(y,0);
assert(isfinite(sigma) && sigma>0,'训练窗口的样本标准差无效。');
z=(y-mu)/sigma;
Mdl=ssm(@(theta) ssmParamMap(theta,model));
opts=optimoptions(@fmincon,'Algorithm','interior-point','Display','off', ...
    'MaxIterations',cfg.maxIterations,'MaxFunctionEvaluations',cfg.maxFunctionEvaluations, ...
    'OptimalityTolerance',cfg.optimalityTolerance,'StepTolerance',cfg.stepTolerance, ...
    'ConstraintTolerance',cfg.constraintTolerance);
starts=cfg.startLogVariance.(char(model));
lb=repmat(cfg.logVarianceBounds(1),1,size(starts,2));
ub=repmat(cfg.logVarianceBounds(2),1,size(starts,2));
trial=struct('mdl',{},'theta',{},'cov',{},'logL',{},'exitFlag',{}, ...
    'message',{},'funcCount',{},'boundary',{});
trialRows=table;
for s=1:size(starts,1)
    start=starts(s,:)';
    try
        [estMdl,theta,estCov,logL,optOut]=estimate(Mdl,z,start,'lb',lb(:),'ub',ub(:), ...
            'Options',opts,'Display','off');
        exitFlag=double(optOut.ExitFlag);
        msg=readOptimizerMessage(optOut);
        fcount=optimizerCount(optOut);
        boundary=any(abs(theta(:)-lb(:))<1e-4 | abs(theta(:)-ub(:))<1e-4);
        good=isfinite(logL) && all(isfinite(theta));
        covarianceAvailable=all(isfinite(estCov(:)));
        if good
            if ~covarianceAvailable, estCov=[]; end
            trial(end+1)=struct('mdl',estMdl,'theta',theta(:),'cov',estCov, ...
                'logL',double(logL),'exitFlag',exitFlag,'message',msg, ...
                'funcCount',fcount,'boundary',boundary); %#ok<AGROW>
            fitStatus="完成";
            if ~covarianceAvailable, fitStatus="完成；参数协方差不可用"; end
            trialRows=[trialRows; trialRecord(s,start,theta,logL,exitFlag,msg,fcount,boundary,fitStatus)]; %#ok<AGROW>
        else
            trialRows=[trialRows; trialRecord(s,start,theta,logL,exitFlag,msg,fcount,boundary,"估计结果非有限")]; %#ok<AGROW>
        end
    catch err
        trialRows=[trialRows; trialRecord(s,start,[],[], -999,string(err.message),0,false,"优化调用失败")]; %#ok<AGROW>
    end
end
assert(~isempty(trial),'模型%s在当前窗口的所有多起点估计均无有限结果。',model);
isConverged=[trial.exitFlag]>0;
if any(isConverged)
    candidates=find(isConverged);
else
    candidates=1:numel(trial);
end
[~,ii]=max([trial(candidates).logL]);
best=trial(candidates(ii));
goodTrials=trial(isConverged);
if isempty(goodTrials)
    llRange="无收敛起点"; thetaRange="无收敛起点";
else
    ll=[goodTrials.logL]; llRange=string(sprintf('%.12g',max(ll)-min(ll)));
    thetaMat=cat(2,goodTrials.theta);
    thetaRange=formatVector(max(thetaMat,[],2)'-min(thetaMat,[],2)');
end
fitted=struct('model',model,'mdl',best.mdl,'theta',best.theta,'standardizedY',z, ...
    'parameterCovariance',best.cov,'logLikelihood',best.logL, ...
    'exitFlag',best.exitFlag,'optimizerMessage',best.message, ...
    'functionCount',best.funcCount,'boundary',best.boundary, ...
    'converged',best.exitFlag>0,'multistartConvergedCount',sum(isConverged), ...
    'multistartCount',size(starts,1),'convergedLogLikelihoodRange',llRange, ...
    'convergedParameterRange',thetaRange,'center',mu,'scale',sigma, ...
    'n',numel(y),'startRecords',trialRows);
end

function [A,B,C,D,Mean0,Cov0,StateType] = ssmParamMap(theta,model)
% ssm约定：x_t=A*x_{t-1}+B*u_t；y_t=C*x_t+D*e_t，u_t、e_t为标准高斯扰动。
v=exp(theta(:));
if model=="RW"
    A=1; B=sqrt(v(1)); C=1; D=sqrt(v(2));
    Mean0=0; Cov0=1e7; StateType=2;
else
    A=[1 1;0 1]; B=diag(sqrt(v(1:2))); C=[1 0]; D=sqrt(v(3));
    Mean0=zeros(2,1); Cov0=1e7*eye(2); StateType=2*ones(2,1);
end
end

function [pred,predSD] = forecastUC(fitted,H)
[zForecast,zMSE] = forecast(fitted.mdl,H,fitted.standardizedY);
pred=double(zForecast(:))*fitted.scale+fitted.center;
predSD=sqrt(max(double(zMSE(:)),0))*fitted.scale;
assert(all(isfinite(pred)) && all(isfinite(predSD)), 'ssm预测或不确定性出现非有限数值。');
end

function row = trialRecord(startIndex,start,theta,logL,exitFlag,message,funcCount,boundary,status)
row=table(startIndex,string(mat2str(start(:)',6)),formatVector(theta),formatScalar(logL), ...
    double(exitFlag),string(message),double(funcCount),logical(boundary),string(status), ...
    'VariableNames',{'StartIndex','StartLogVariance','EstimatedLogVariance','LogLikelihood', ...
    'ExitFlag','OptimizerMessage','FunctionCount','NearBoundary','Status'});
end

function out = formatVector(v)
if isempty(v) || any(~isfinite(v(:)))
    out="未获得";
else
    out=string(mat2str(v(:)',8));
end
end

function out = formatScalar(v)
if isempty(v) || ~isscalar(v) || ~isfinite(v)
    out="未获得";
else
    out=string(sprintf('%.12g',v));
end
end

function msg = readOptimizerMessage(out)
msg="优化器已返回结果";
names=fieldnames(out);
idx=find(strcmpi(names,'message')|strcmpi(names,'OutputMessage'),1);
if ~isempty(idx)
    value=out.(names{idx});
    if ischar(value) || isstring(value), msg=string(value); end
end
end

function n = optimizerCount(out)
n=0; names=fieldnames(out);
idx=find(strcmpi(names,'FuncCount')|strcmpi(names,'FunctionCount'),1);
if ~isempty(idx) && isscalar(out.(names{idx})) && isfinite(out.(names{idx}))
    n=double(out.(names{idx}));
end
end

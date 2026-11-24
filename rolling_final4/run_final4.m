function run_final4()
here=fileparts(mfilename('fullpath')); root=fileparts(here);
addpath(fullfile(here,'src','ets'),fullfile(here,'src','uc'),fullfile(here,'src','arima'));
toolboxPath=getenv('ECOTOOL_PATH');
if isempty(toolboxPath), toolboxPath=fullfile(getenv('APPDATA'),'MathWorks','MATLAB Add-Ons','Toolboxes','ECOTOOL'); end
addpath(toolboxPath);
addpath(fullfile(here,'src','ets'),'-begin'); % suppress ECOTOOL GUI output
set(groot,'DefaultFigureVisible','off');
tAll=tic; predictions=table; parameters=table; starts=table; scaleAudit=table;
for person=["A","B","C"]
    input=fullfile(root,'data',person+"_个人总支付_自然周.xlsx");
    d=readcell(input,'Sheet','UC数据','Range','A2:A113');
    if isnumeric(d{1}), dates=datetime(cell2mat(d),'ConvertFrom','excel'); else, dates=datetime(string(d)); end
    assert(isequal(dates(:),datetime(2024,9,2)+caldays(7*(0:111)')));
    train=readmatrix(input,'Sheet','UC数据','Range','B2:B109'); train=train(:);
    old=load(fullfile(root,'output',person,'step01_training_data.mat'),'yTrain');
    assert(isequal(train,double(old.yTrain(:))),'Canonical data differs from existing UC input');
    personPred=table; personParam=table; personStarts=table; personScale=table;
    for n=108:111
        % Read exactly the observed prefix; no later target enters estimation.
        y=readmatrix(input,'Sheet','UC数据','Range',sprintf('B2:B%d',n+1)); y=y(:);
        assert(numel(y)==n && all(isfinite(y)) && all(y>=0));
        H=1; if n==108, H=4; end
        for model=["ARIMA(0,0,0)","ETS-NN","ETS-AN","UC-RW","UC-LLT"]
            t=tic; theta=""; variance=""; center=mean(y); sc=std(y,0); conv=""; flag=NaN; boundary=false; warn="";
            if startsWith(model,"ARIMA")
                [p,mu,v]=fit_mean_final4(y,H); theta=string(mu); variance=string(v); conv="解析均值"; flag=1;
            elseif startsWith(model,"ETS")
                code=extractAfter(model,"ETS-");
                [m,txt]=fit_ets_final4(y,code,H); p=m.py(:); theta=string(mat2str(m.par(:)',16));
                % ECOTOOL estimation table includes transformed smoothing parameters.
                fid=fopen(fullfile(here,'results',person,sprintf('ETS_%s_%d.txt',code,n)),'w','n','UTF-8');
                fprintf(fid,'%s\n%s\n',txt,string(m.table)); fclose(fid);
                [z,ztxt]=fit_ets_final4((y-center)/sc,code,H); restored=z.py(:)*sc+center;
                fid=fopen(fullfile(here,'results',person,sprintf('ETS_%s_%d_standardized.txt',code,n)),'w','n','UTF-8');
                fprintf(fid,'%s\n%s\n',ztxt,string(z.table)); fclose(fid);
                conv=m.final4Convergence; warn=m.final4Warning;
                % Save full API parameters; interpret alpha/beta using table labels.
                sr=table(person,model,n,center,sc,string(mat2str(m.par(:)',16)),string(mat2str(z.par(:)',16)), ...
                    string(mat2str(p',16)),string(mat2str(restored',16)),max(abs(p-restored)),conv,z.final4Convergence, ...
                    m.final4Warning,z.final4Warning,'VariableNames',{'Person','Model','OriginWeek','Center','Scale','RawParameters','StandardParameters','RawForecasts','RestoredForecasts','MaxForecastDifference','RawConvergence','StandardConvergence','RawWarning','StandardWarning'});
                personScale=[personScale;sr];
            else
                code=extractAfter(model,"UC-"); [f,p]=fit_uc_final4(y,code,H);
                theta=string(mat2str(f.theta(:)',16)); variance=string(mat2str((exp(f.theta(:))*sc^2)',16));
                flag=f.exitFlag; conv=string(f.converged); boundary=f.boundary; warn=f.optimizerMessage;
                ss=f.startRecords; ss=addvars(ss,repmat(person,height(ss),1),repmat(model,height(ss),1),repmat(n,height(ss),1),'Before',1,'NewVariableNames',{'Person','Model','OriginWeek'});
                personStarts=[personStarts;ss];
            end
            elapsed=toc(t);
            pr=table(person,model,n,center,sc,theta,variance,flag,conv,boundary,warn,elapsed, ...
                'VariableNames',{'Person','Model','OriginWeek','TrainMean','TrainSD','Parameters','VarianceYuan2','ExitFlag','Convergence','NearBoundary','Warning','ElapsedSeconds'});
            personParam=[personParam;pr];
            protocol="rolling";
            personPred=[personPred;row(person,model,protocol,n,n+1,dates(n+1),p(1),mean(abs(diff(y))))];
            if n==108
                for h=1:4
                    personPred=[personPred;row(person,model,"fixed",n,n+h,dates(n+h),p(h),mean(abs(diff(y))))];
                end
            end
            fprintf('%s n=%d %s %.2fs forecast=%.6f\n',person,n,model,elapsed,p(1));
        end
        % All forecasts at this origin are already stored before observing target.
        writetable(personPred,fullfile(here,'results',person,'预测锁定.csv'),'Encoding','UTF-8');
    end
    actual=readmatrix(input,'Sheet','UC数据','Range','B110:B113');
    personPred.Actual=actual(personPred.TargetWeek-108);
    personPred.Error=personPred.Forecast-personPred.Actual;
    personPred.AbsoluteError=abs(personPred.Error);
    writetable(personPred,fullfile(here,'results',person,'逐周预测.csv'),'Encoding','UTF-8');
    writetable(personParam,fullfile(here,'results',person,'各轮参数.csv'),'Encoding','UTF-8');
    writetable(personStarts,fullfile(here,'results',person,'UC多起点.csv'),'Encoding','UTF-8');
    writetable(personScale,fullfile(here,'results',person,'ETS尺度核验.csv'),'Encoding','UTF-8');
    predictions=[predictions;personPred]; parameters=[parameters;personParam]; starts=[starts;personStarts]; scaleAudit=[scaleAudit;personScale];
end
out=fullfile(here,'results','comparison');
writetable(predictions,fullfile(out,'all_predictions.csv'),'Encoding','UTF-8');
writetable(parameters,fullfile(out,'all_parameters.csv'),'Encoding','UTF-8');
writetable(scaleAudit,fullfile(out,'ets_scale_audit.csv'),'Encoding','UTF-8');
runtime=struct('MATLAB',version,'EstimationSeconds',toc(tAll),'FinishedAt',char(datetime('now','TimeZone','Asia/Shanghai')),'ETSPath',which('modelETS'));
fid=fopen(fullfile(out,'runtime.json'),'w','n','UTF-8'); fprintf(fid,'%s',jsonencode(runtime,PrettyPrint=true)); fclose(fid);
end
function r=row(person,model,protocol,n,target,date,p,scale)
r=table(person,model,protocol,n,target,date,p,scale,'VariableNames',{'Person','Model','Protocol','OriginWeek','TargetWeek','TargetDate','Forecast','MASEScale'});
end

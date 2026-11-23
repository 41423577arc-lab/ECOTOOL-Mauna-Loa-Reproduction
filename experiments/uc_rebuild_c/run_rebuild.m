function run_rebuild()
% C only; immutable sources, training-only selection. MATLAB R2026a.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));cd(root);
addpath(fullfile(root,'output','流程代码'));configure_ecotool();rng(20261123);
set(groot,'DefaultFigureVisible','off'); diary(fullfile(here,'run.log'));cleanup=onCleanup(@()diary('off'));
file=fullfile(root,'data','C_个人总支付_自然周.xlsx');
tr=load(fullfile(root,'output','C','step01_training_data.mat')); y=double(tr.yTrain(:)); dates=tr.tTrain;
assert(numel(y)==108&&all(isfinite(y))&&all(y>=0)&&numel(unique(dates))==108&&all(days(diff(dates))==7));
config=struct('train',108,'oneOrigins',78:107,'fourOrigins',78:104,'seed',20261123,'selection','finite complete predictions; lowest mean of MAE/mean-baseline-MAE at one and four step; RMSE tie break','scale','per-window mean/std','IQR',1.5,'MLbounds',[-10 4]);
system('git status --short > experiments/uc_rebuild_c/git_before.txt');
[~,hash]=system('certutil -hashfile data/C_个人总支付_自然周.xlsx SHA256');config.fingerprint=hash;
save(fullfile(here,'config.mat'),'config');fid=fopen(fullfile(here,'config.json'),'w');fprintf(fid,'%s',jsonencode(config,PrettyPrint=true));fclose(fid);
for name=["modelUC","auxmodelUC","clliket","lliket","SSestimET","SSpaceiniET","kfiniet"]
 copyfile(which(char(name)),fullfile(here,char(name+"_audit.m")));
end
fid=fopen(fullfile(here,'environment.txt'),'w');fprintf(fid,'%s\n%s\n',version,evalc('ver'));fprintf(fid,'modelUC0: %s (P-code, source unavailable)\n',which('modelUC0'));fclose(fid);
writetable(table(mean(y),median(y),std(y),skewness(y),kurtosis(y),min(y),max(y),quantile(y,.25),quantile(y,.75),'VariableNames',{'Mean','Median','SD','Skewness','Kurtosis','Min','Max','Q25','Q75'}),fullfile(here,'description.csv'));
q=quantile(y,[.25 .75]);lo=max(0,q(1)-1.5*diff(q));hi=q(2)+1.5*diff(q);yw=min(max(y,lo),hi);
writetable(table(dates,y,yw,log1p(y),'VariableNames',{'Date','Raw','Winsor','Log1p'}),fullfile(here,'training.csv'));
src=readtable(fullfile(root,'experiments','outlier_sensitivity','results','异常大额周来源核对.csv'),'TextType','string');writetable(src(src.Person=="C",:),fullfile(here,'outlier_source.csv'));
f=figure; tiledlayout(2,2);nexttile;plot(dates,y);title('原始训练序列');nexttile;histogram(y);title('训练分布');nexttile;plot(dates,[y yw]);legend('原始','IQR缩尾');nexttile;plot(dates,log1p(y));title('log1p');pic(f,here,'01_data');
tests=table; spectra=table;
for g=1:3
 z={y,yw,log1p(y)};z=z{g};lab=["Raw","Winsor","Log1p"];
 % ADF constant, lag chosen by BIC over 0:8 via auxiliary regression.
 bic=zeros(9,1);for lag=0:8
 dy=diff(z);ii=(10:numel(dy))';X=[ones(numel(ii),1),z(ii)];for j=1:lag,X=[X dy(ii-j)];end
 e=dy(ii)-X*(X\dy(ii));bic(lag+1)=numel(ii)*log(mean(e.^2))+size(X,2)*log(numel(ii));end
 [~,ix]=min(bic);lag=ix-1;[h,p,s]=adftest(z,'Model','ARD','Lags',lag);tests=[tests;table(lab(g),"ADF_constant_unitroot",lag,s,p,h,'VariableNames',{'Data','Test','Lag','Statistic','P','Reject'})];
 for lag=[4 8]
 [h,p,s]=kpsstest(z,'Trend',false,'Lags',lag);tests=[tests;table(lab(g),"KPSS_level_stationarity",lag,s,p,h,'VariableNames',tests.Properties.VariableNames)];end
 f=figure;tiledlayout(1,3);nexttile;autocorr(z,'NumLags',36);nexttile;parcorr(z,'NumLags',36);nexttile;
 zz=z-mean(z);power=abs(fft(zz)).^2/numel(z);freq=(1:54)'/108;plot(1./freq,power(2:55));xlim([2 54]);xlabel('周期/周');title(lab(g)+'周期图');pic(f,here,'02_dependence_'+lab(g));
 for period=[4 13 26 52]
 a=autocorr(z,'NumLags',52);tt=(1:108)';X=[ones(108,1),sin(2*pi*tt/period),cos(2*pi*tt/period)];b=X\z;rss=sum((z-X*b).^2);F=((sum((z-mean(z)).^2)-rss)/2)/(rss/105);p=1-fcdf(F,2,105);
 spectra=[spectra;table(lab(g),period,a(period+1),F,p,'VariableNames',{'Data','Period','ACF','HarmonicF','ExploratoryP'})];end
end
writetable(tests,fullfile(here,'stationarity.csv'));writetable(spectra,fullfile(here,'season_evidence.csv'));
% First priority: original ECOTOOL versus standardized calls and multistarts.
audit=table; objects=cell(2,2,3);
for b=1:2
 names=["RW","LLT"];name=names(b);
 for scale=1:2
 if scale==1,z=y;mu=0;sd=1;else,mu=mean(y);sd=std(y);z=(y-mu)/sd;end
 for start=1:3
 try
 if start==1,m=modelUC(z,[],char(name),4);else
 p0=repmat(log10(var(z)),b+1,1);p0(1:b)=p0(1:b)+(-4)*(start==3)+(-2)*(start==2); % scalar/vector corrected below
 m=modelUC(z,[],char(name),4,'CML',[],p0);
 end
 d=eco_filter(m,z);err=m.e(:)*sd; zz=d.e(3:end)./sqrt(d.F(3:end));
 audit=[audit;table(name,scale,start,string(mat2str(m.par(:)')),string(mat2str((10.^m.par(:)*sd^2)')),mean(zz),var(zz),mean(d.K(3:end,1)),max(abs(err-d.e(3:end)*sd)),m.py(1)*sd+mu,"",'VariableNames',{'Model','Scale','Start','Log10Par','VarianceOriginal','ZMean','ZVariance','MeanGain','InnovationMaxDiff','Forecast','Failure'})];objects{b,scale,start}=m;
 catch ex
 audit=[audit;table(name,scale,start,"","",NaN,NaN,NaN,NaN,NaN,string(ex.message),'VariableNames',{'Model','Scale','Start','Log10Par','VarianceOriginal','ZMean','ZVariance','MeanGain','InnovationMaxDiff','Forecast','Failure'})];
 end
 end
 end
end
writetable(audit,fullfile(here,'ecotool_audit.csv'));save(fullfile(here,'ecotool_audit.mat'),'objects','audit');
% New likelihood: per-window standardized conditional Gaussian ML, discard first 2.
% Same scale-equivariant initialization across structures; raw EML comparisons not mixed.
models=["Mean","Naive","EC_RW","EC_LLT","ML_RW","ML_LLT","ML_IRW","ML_AR1","W_RW","W_LLT","Log_RW","Q_RW_0.001","Q_RW_0.01","Q_RW_0.1","Q_LLT_0.001","Q_LLT_0.01","Q_LLT_0.1","S4_RW","S4_LLT","WS4_RW","WS4_LLT"];
% Other seasonal periods admitted only by conservative training evidence (Bonferroni).
for period=[13 26 52]
 if period<52&&any(spectra.Period==period & spectra.ExploratoryP<.05/12)
 models=[models,"S"+period+"_RW","WS"+period+"_RW"];end
end
pred=table;params=table; fits=cell(numel(models),1);
for b=1:numel(models)
 fprintf('Candidate %s (%d/%d)\n',models(b),b,numel(models));
 for n=78:108
 try
 [p,m]=fit_predict(y(1:n),models(b),4);
 params=[params;table(models(b),n,string(mat2str(m.par)),m.flag,m.objective,'VariableNames',{'Model','Origin','Parameters','ExitFlag','Objective'})];
 if n<=107,pred=[pred;rows(models(b),"one",n,1,p(1),y(n+1),mean(abs(diff(y(1:n)))))];end
 if n<=104,for h=1:4,pred=[pred;rows(models(b),"four",n,h,p(h),y(n+h),mean(abs(diff(y(1:n)))))];end,end
 if n==108,fits{b}=m;fits{b}.forecast=p;end
 catch ex
 fprintf('FAILED %s %d: %s\n',models(b),n,ex.message);
 params=[params;table(models(b),n,string(ex.message),-999,NaN,'VariableNames',params.Properties.VariableNames)];
 end
 end
end
writetable(pred,fullfile(here,'predictions.csv'));writetable(params,fullfile(here,'parameters.csv'));
metrics=table;
for protocol=["one","four"]
 for b=1:numel(models)
 z=pred(pred.Model==models(b)&pred.Protocol==protocol,:);expected=30;if protocol=="four",expected=108;end
 if height(z)~=expected,continue,end
 e=z.Forecast-z.Actual;den=abs(z.Forecast)+abs(z.Actual);sm=200*abs(e)./den;sm(den==0)=0;
 metrics=[metrics;table(models(b),protocol,height(z),mean(abs(e)),sqrt(mean(e.^2)),mean(sm),mean(abs(e)./z.Scale),'VariableNames',{'Model','Protocol','N','MAE','RMSE','sMAPE','MASE'})];end
end
writetable(metrics,fullfile(here,'metrics.csv'));score=table;
for b=1:numel(models)
 z=metrics(metrics.Model==models(b),:);base=metrics(metrics.Model=="Mean",:);
 if height(z)==2,score=[score;table(models(b),mean(z.MAE./base.MAE),mean(z.RMSE),'VariableNames',{'Model','Score','RMSE'})];end
end
score=sortrows(score,{'Score','RMSE'});selected=score.Model(1);writetable(score,fullfile(here,'selection.csv'));
% Predictions locked before loading historical holdout.
save(fullfile(here,'locked.mat'),'fits','selected','models','config');
test=readmatrix(file,'Sheet','UC数据','Range','B110:B113');test=test(:);holdout=table;holdmetrics=table;
for b=1:numel(models)
 if isempty(fits{b}),continue,end
 p=fits{b}.forecast;e=p-test;holdout=[holdout;table(repmat(models(b),4,1),(1:4)',p,test,'VariableNames',{'Model','Horizon','Forecast','Actual'})];
 holdmetrics=[holdmetrics;table(models(b),mean(abs(e)),sqrt(mean(e.^2)),mean(200*abs(e)./(abs(p)+abs(test))),mean(abs(e))/mean(abs(diff(y))),'VariableNames',{'Model','MAE','RMSE','sMAPE','MASE'})];end
writetable(holdout,fullfile(here,'holdout.csv'));writetable(holdmetrics,fullfile(here,'holdout_metrics.csv'));
diagtable=table;
for b=1:numel(models)
 m=fits{b};if isempty(m)||~isfield(m,'detail'),continue,end
 d=m.detail;zz=d.e(3:end)./sqrt(d.F(3:end));[~,p,Q]=lbqtest(zz,'Lags',[6 13 26]);
 diagtable=[diagtable;table(models(b),mean(zz),var(zz),p(1),p(2),p(3),m.AIC,m.BIC,'VariableNames',{'Model','ZMean','ZVariance','LB6P','LB13P','LB26P','AIC','BIC'})];
 if ismember(models(b),["ML_RW","ML_LLT",selected])
 f=figure;tiledlayout(3,2);nexttile;plot(dates,[y d.fitted d.filtered d.smooth]);legend('真实','样本内一步','过滤','平滑');nexttile;plot(d.K(:,1));title('水平Kalman增益');nexttile;plot(dates,y-d.smooth);title('平滑不规则成分');nexttile;plot(dates, d.e./sqrt(d.F));title('标准化创新');nexttile;autocorr(zz,'NumLags',26);nexttile;qqplot(zz);pic(f,here,'diagnostic_'+models(b));
 end
end
writetable(diagtable,fullfile(here,'diagnostics.csv'));
f=figure;bar(categorical(metrics.Model(metrics.Protocol=="four")),metrics.MAE(metrics.Protocol=="four"));ylabel('27原点四步MAE/元');pic(f,here,'09_four_origin');
f=figure;z=pred(pred.Protocol=="one"&pred.Model=="Mean",:);plot(z.Origin+1,z.Actual,'k');hold on;for name=["EC_RW","ML_RW","ML_LLT",selected],z=pred(pred.Protocol=="one"&pred.Model==name,:);plot(z.Origin+1,z.Forecast);end;legend(["真实","EC RW","ML RW","ML LLT",selected]);title('严格样本外扩展窗口一步预测');pic(f,here,'08_rolling');
f=figure;z=holdout(holdout.Model==selected,:);plot(109:112,[z.Actual z.Forecast],'-o');legend('历史保留真实值','锁定预测');title(selected+'固定原点四步');pic(f,here,'10_holdout');
save(fullfile(here,'results.mat'),'fits','models','pred','metrics','score','selected','diagtable','holdout','holdmetrics','tests','spectra','params','config','-v7.3');
checkcode(fullfile(here,'run_rebuild.m'),'-id');fprintf('COMPLETE selected=%s\n',selected);
end
function t=rows(name,protocol,n,h,p,a,s)
t=table(name,protocol,n,h,p,a,s,'VariableNames',{'Model','Protocol','Origin','Horizon','Forecast','Actual','Scale'});
end
function [p,m]=fit_predict(y,name,H)
mu=mean(y);sd=std(y);z=(y-mu)/sd;m=struct('par',[],'flag',1,'objective',NaN);
if name=="Mean",p=repmat(mu,H,1);return,end
if name=="Naive",p=repmat(y(end),H,1);return,end
if startsWith(name,'EC_'),ec=modelUC(y,[],char(extractAfter(name,'EC_')),H);p=ec.py(:);m.par=ec.par;m.ec=ec;return,end
if startsWith(name,'W'),q=quantile(y,[.25 .75]);y=min(max(y,max(0,q(1)-1.5*diff(q))),q(2)+1.5*diff(q));mu=mean(y);sd=std(y);z=(y-mu)/sd;end
islog=startsWith(name,'Log');if islog,y=log1p(y);mu=mean(y);sd=std(y);z=(y-mu)/sd;end
kind="RW";if contains(name,'LLT'),kind="LLT";elseif contains(name,'IRW'),kind="IRW";elseif contains(name,'AR1'),kind="AR1";end
period=0;tok=regexp(char(name),'S(\d+)','tokens','once');if ~isempty(tok),period=str2double(tok{1});end
% Seasonal comparator: fixed harmonic component, jointly profiled by OLS on training only.
season=zeros(numel(z)+H,1);kseason=0;if period>0,t=(1:numel(z)+H)';X=[ones(numel(t),1),sin(2*pi*t/period),cos(2*pi*t/period)];coef=X(1:numel(z),:)\z;season=X*coef;z=z-season(1:numel(z));kseason=3;end
ratio=NaN;tok=regexp(char(name),'Q_\w+_([.0-9]+)','tokens','once');if ~isempty(tok),ratio=str2double(tok{1});end
np=2;if kind=="LLT",np=3;end
options=optimset('Display','off','MaxIter',400,'MaxFunEvals',1600,'TolX',1e-5,'TolFun',1e-6);best=Inf;trials=[];
for start=[-4 -1]
 p0=[repmat(start,1,np-1) 0];if kind=="AR1",p0=[-1 0];end
 [theta,obj,flag]=fminsearch(@(v)objective(v,z,kind,ratio),p0,options);trials=[trials;theta obj flag];if obj<best,best=obj;bestp=theta;bestflag=flag;end
end
[~,d,a,T,Q,R]=kf(bestp,z,kind,ratio);p=zeros(H,1);for h=1:H,p(h)=a(1);a=T*a;end
p=p+season(numel(z)+1:end);p=p*sd+mu;
if islog,p=expm1(p+0.5*sd^2*mean(d.F(3:end)));end
m.par=bestp;m.flag=bestflag;m.objective=best;m.trials=trials;m.Q=Q*sd^2;m.R=R*sd^2;m.AIC=2*best+2*(np+kseason+2);m.BIC=2*best+(np+kseason+2)*log(numel(z)-2);m.detail=d;
m.detail.e=d.e*sd;m.detail.F=d.F*sd^2;m.detail.fitted=(d.fitted+season(1:numel(z)))*sd+mu;m.detail.filtered=(d.filtered+season(1:numel(z)))*sd+mu;m.detail.smooth=(d.smooth+season(1:numel(z)))*sd+mu;
end
function val=objective(p,z,kind,ratio)
if any(~isfinite(p))||any(p < -10)||any(p>4),val=1e10+sum(p.^2);return,end
val=kf(p,z,kind,ratio);if ~isfinite(val),val=1e12;end
end
function [val,d,a,T,Q,R]=kf(p,z,kind,ratio)
T=[1 0;0 1];Q=diag([10^p(1),0]);R=10^p(end);
if kind=="LLT",T=[1 1;0 1];Q=diag(10.^p(1:2));elseif kind=="IRW",T=[1 1;0 1];Q=diag([0 10^p(1)]);elseif kind=="AR1",T=diag([tanh(p(1)) 0]);Q=diag([10^p(2) 0]);R=0;end
if isfinite(ratio),Q(1,1)=ratio*R;if kind=="LLT",Q(2,2)=ratio*R;end,end
n=numel(z);a=[z(1);0];P=1e5*eye(2);H=[1 0];d.e=zeros(n,1);d.F=d.e;d.K=zeros(n,2);d.fitted=d.e;d.filtered=d.e;af=zeros(2,n);Pf=zeros(2,2,n);ap=af;Pp=Pf;
for t=1:n
 ap(:,t)=a;Pp(:,:,t)=P;F=H*P*H'+R;v=z(t)-H*a;K=P*H'/F;d.e(t)=v;d.F(t)=F;d.K(t,:)=K';d.fitted(t)=a(1);a=a+K*v;P=(eye(2)-K*H)*P*(eye(2)-K*H)'+K*R*K';af(:,t)=a;Pf(:,:,t)=P;d.filtered(t)=a(1);a=T*a;P=T*P*T'+Q;
end
sm=af;for t=n-1:-1:1,J=Pf(:,:,t)*T'*pinv(Pp(:,:,t+1));sm(:,t)=af(:,t)+J*(sm(:,t+1)-ap(:,t+1));end;d.smooth=sm(1,:)';val=.5*sum(log(2*pi*d.F(3:end))+d.e(3:end).^2./d.F(3:end));
end
function d=eco_filter(m,z)
phi=eye(2);if string(m.model)=="LLT",phi=[1 1;0 1];end
[x,P,T,~,E,H,~,C,Q,R,S]=auxmodelUC(m.par,phi,eye(2),[1 0],1,zeros(2,1),m.model,z(1));if isempty(P),P=1e5*eye(2);end
n=numel(z);d.e=zeros(n,1);d.F=d.e;d.K=zeros(n,2);
for t=1:n,F=H*P*H'+C*R*C';K=(T*P*H'+E*S*C')/F;v=z(t)-H*x;d.e(t)=v;d.F(t)=F;d.K(t,:)=K';A=T-K*H;cross=K*(E*S*C')';x=T*x+K*v;P=A*P*A'+E*Q*E'+K*C*R*C'*K'-cross-cross';end
assert(max(abs(m.e(:)-d.e(3:end)))<1e-4);
end
function pic(f,here,name)
name=string(name);exportgraphics(f,fullfile(here,name+'.png'),'Resolution',130);savefig(f,fullfile(here,name+'.fig'));close(f);
end




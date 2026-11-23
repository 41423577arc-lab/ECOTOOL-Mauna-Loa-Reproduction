function diagnose_uc_discrepancy(probeLimit)
% 只在独立目录排查UC差异，既有实验及模型定义保持原样。
if nargin<1, probeLimit=3; end
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'results','comparison','uc_diagnostics');
if ~isfolder(out), mkdir(out); end
D=load(fullfile(root,'results','comparison','sliding_480','checkpoint.mat')); A=D.C;
D=load(fullfile(root,'results','rolling_c','checkpoint.mat')); E=D.C;
y=A.y; assert(isequal(y,E.yall));
actual=A.actual; pred={reshape(E.pred(:,1,:),24,220),reshape(A.pred(:,3,:),24,220),reshape(A.pred(:,6,:),24,220)};
names=["扩展逐轮lambda" "滑动固定A_lambda" "滑动首轮训练lambda"];
T=table; M=table;
for j=1:3
 p=pred{j}; err=actual-p; sc=A.scales; lam=repmat(A.config.lambdaA,220,1);
 if j==1, sc=E.scales; lam=E.lambdas; elseif j==3, lam=repmat(A.config.lambdaFirst,220,1); end
 sm=200*abs(err)./(abs(actual)+abs(p)); ma=abs(err)./sc';
 for h=[1 6 12 24]
  T=[T;table(repmat(names(j),220,1),(1:220)',repmat(h,220,1),lam,sc,mean(sm(1:h,:),1)',mean(ma(1:h,:),1)',mean(abs(err(1:h,:)),1)',mean(p(1:h,:)-actual(1:h,:),1)', ...
   'VariableNames',{'protocol','round','horizon','lambda','scale','sMAPE','MASE','MAE_ppm','bias_ppm'})]; %#ok<AGROW>
 end
 M=[M;table(repmat(names(j),24,1),(1:24)',mean(sm,2),mean(ma,2),mean(p-actual,2), ...
  'VariableNames',{'protocol','horizon','sMAPE','MASE','bias_ppm'})]; %#ok<AGROW>
end
writetable(T,fullfile(out,'existing_round_metrics.csv'),'Encoding','UTF-8');
writetable(M,fullfile(out,'existing_horizon_metrics.csv'),'Encoding','UTF-8');
score=mean(abs(actual-pred{2}),1); [~,worst]=sort(score,'descend');
rounds=unique([1 worst(1:2) 110 220],'stable'); rounds=rounds(1:min(probeLimit,numel(rounds)));
variants=["原位置省略默认" "位置显式CML" "位置显式EML" "名称显式CML" "名称显式EML"];
config=struct('rounds',rounds,'variants',variants,'lambdas',[A.config.lambdaA A.config.lambdaFirst]);
path=fullfile(out,'probe_checkpoint.mat');
if isfile(path), D=load(path,'P'); P=D.P; assert(isequal(P.config,config));
else, P=struct('config',config,'models',{cell(numel(rounds),5,2)},'pred',nan(24,numel(rounds),5,2),'done',false(numel(rounds),5,2),'errors',{cell(numel(rounds),5,2)},'seconds',nan(numel(rounds),5,2)); end
before=findall(groot,'Type','figure'); visible=get(groot,'DefaultFigureVisible'); set(groot,'DefaultFigureVisible','off'); cl=onCleanup(@()restore(visible,before)); %#ok<NASGU>
for k=1:2
 for i=1:numel(rounds)
  r=rounds(i); train=y(r:r+479); lambda=config.lambdas(k); ty=vboxcox(train,lambda);
  for v=1:5
   if P.done(i,v,k), continue; end
   t=tic;
   try
    switch v
     case 1, log=evalc('m=modelUC(ty, [], ''LLT12'',24);');
     case 2, log=evalc('m=modelUC(ty, [], ''LLT12'',24,''CML'');');
     case 3, log=evalc('m=modelUC(ty, [], ''LLT12'',24,''EML'');');
     case 4, log=evalc('m=modelUC(ty,''model'',''LLT12'',''nofs'',24,''method'',''CML'');');
     case 5, log=evalc('m=modelUC(ty,''model'',''LLT12'',''nofs'',24,''method'',''EML'');');
    end
    assert(isequal(m.y,ty) && all(1+lambda*m.py(:)>0)); p=vboxcoxinv(m.py(:),lambda);
    assert(numel(p)==24 && isreal(p) && all(isfinite(p)));
    meta=struct; meta.model=m; meta.log=log; meta.input=ty; meta.lambda=lambda;
    P.models{i,v,k}=meta; P.pred(:,i,v,k)=p; P.done(i,v,k)=true;
   catch ME
    P.errors{i,v,k}=getReport(ME,'extended','hyperlinks','off');
   end
   P.seconds(i,v,k)=toc(t); tmp=[path '.tmp']; save(tmp,'P','-v7'); movefile(tmp,path,'f');
   restore('off',before); fprintf('UC诊断 r=%d lambda=%.6f %s 成功=%d %.2f秒\n',r,lambda,variants(v),P.done(i,v,k),P.seconds(i,v,k));
  end
 end
end
Q=table;
for k=1:2
 for i=1:numel(rounds)
  r=rounds(i); reference=pred{k+1}(:,r);
  for v=1:5
   if ~P.done(i,v,k), fprintf('%s\n',P.errors{i,v,k}); continue; end
   m=P.models{i,v,k}.model; lines=string(cellstr(m.table)); method=strjoin(strtrim(lines(contains(lines,'Estimation method:'))),'；');
   p=P.pred(:,i,v,k); a=actual(:,r); err=abs(a-p); sm=200*err./(abs(a)+abs(p)); ma=err/A.scales(r);
   Q=[Q;table(r,config.lambdas(k),variants(v),string(m.method),method,mean(sm(1:12)),mean(sm),mean(ma(1:12)),mean(ma),max(abs(p-reference)), ...
    'VariableNames',{'round','lambda','variant','wrapper_method','actual_method','sMAPE12','sMAPE24','MASE12','MASE24','max_change_ppm'})]; %#ok<AGROW>
  end
 end
end
writetable(Q,fullfile(out,'probe_metrics.csv'),'Encoding','UTF-8'); disp(Q);
for i=1:numel(rounds)
 r=rounds(i); fprintf('原A固定参数UC第%d轮参数和估计表：\n',r); disp(A.models{r,3}.par); disp(A.models{r,3}.table);
end
end

function restore(visible,before)
% 仅关闭本次诊断新建的图窗。
delete(setdiff(findall(groot,'Type','figure'),before)); set(groot,'DefaultFigureVisible',visible);
end

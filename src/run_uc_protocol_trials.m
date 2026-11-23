function run_uc_protocol_trials(roundLimit,nWorkers)
% 预先固定四种UC协议，不根据论文误差搜索参数，不覆盖旧实验。
if nargin<1, roundLimit=220; end
if nargin<2, nWorkers=1; end
validateattributes(roundLimit,{'numeric'},{'scalar','integer','>=',1,'<=',220});
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'results','comparison','uc_protocol_trials');
if ~isfolder(out), mkdir(out); end
D=load(fullfile(root,'results','comparison','sliding_480','checkpoint.mat')); old=D.C; y=old.y;
config=struct('schema',1,'L',480,'H',24,'R',220,'lambdaFirst',old.config.lambdaFirst,'lambdaA',.2461, ...
 'names',["滑动逐轮lambda" "扩展固定首轮lambda" "滑动首轮lambda标准化" "滑动A_lambda标准化"], ...
 'description',"只改变训练边界、训练期Box-Cox策略或可逆仿射标准化，始终modelUC(x, [], 'LLT12',24)；第4列含A参数前视风险，不作为无前视结果");
env.matlab=version; addons=matlab.addons.installedAddons; env.ecotool=addons(contains(upper(addons.Name),'ECOTOOL'),:);
for name=["modelUC" "modelUC0" "vboxcox" "vboxcoxinv" "auxvboxcoxllik"]
 path=which(name); assert(~isempty(path)); fid=fopen(path,'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
 md=java.security.MessageDigest.getInstance('SHA-256'); md.update(typecast(bytes,'int8'));
 env.hashes.(name)=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[])); env.paths.(name)=path;
end
path=fullfile(out,'checkpoint.mat');
if isfile(path)
 D=load(path,'P'); P=D.P; assert(isequal(P.config,config)&&isequal(P.y,y)&&isequal(P.env.hashes,env.hashes)&&strcmp(P.env.matlab,env.matlab));
else
 P=struct('config',config,'env',env,'y',y,'done',false(220,4),'pred',nan(24,4,220), ...
  'models',{cell(220,4)},'seconds',nan(220,4),'lambda',nan(220,4),'centers',nan(220,4), ...
  'spreads',nan(220,4),'scales',nan(220,4),'error','','started',char(datetime('now')));
end
saveAtomic(path,P); t=tic;
try
 if nWorkers>1 && any(~P.done(1:roundLimit,:),'all')
  pool=gcp('nocreate'); own=isempty(pool); if own, pool=parpool('Processes',nWorkers); end
  cleaner=onCleanup(@()finishPool(pool,own)); %#ok<NASGU>
  futures=parallel.FevalFuture.empty(0,1); tasks=zeros(0,2);
  for r=1:roundLimit
   for j=1:4
    if P.done(r,j), continue; end
    first=r; if j==2, first=1; end
    futures(end+1)=parfeval(pool,@fitOne,1,y(first:r+479),j,config); tasks(end+1,:)=[r j]; %#ok<AGROW>
   end
  end
  cancelCleanup=onCleanup(@()cancel(futures)); %#ok<NASGU>
  for k=1:numel(futures)
   [idx,result]=fetchNext(futures); r=tasks(idx,1); j=tasks(idx,2);
   assert(isempty(result.error),'%s',result.error); P=accept(P,result,r,j); saveAtomic(path,P);
   if mod(k,10)==0 || k==numel(futures), fprintf('UC协议对照 完成%s，最近第%d轮，续跑墙钟%.1f秒\n',mat2str(sum(P.done,1)),r,toc(t)); end
  end
 else
  for r=1:roundLimit
   for j=1:4
    if P.done(r,j), continue; end
    first=r; if j==2, first=1; end
    result=fitOne(y(first:r+479),j,config); assert(isempty(result.error),'%s',result.error);
    P=accept(P,result,r,j); saveAtomic(path,P);
    fprintf('UC协议试跑 第%d轮 %s %.2f秒\n',r,config.names(j),result.seconds);
   end
  end
 end
 P.error=''; P.lastRunWallSeconds=toc(t); saveAtomic(path,P); export(P,out);
catch ME
 D=load(path,'P'); P=D.P; P.error=getReport(ME,'extended','hyperlinks','off'); saveAtomic(path,P); export(P,out); rethrow(ME);
end
end

function result=fitOne(train,j,config)
% 工作进程只接收训练数据，中心和标准差也只用训练期计算。
before=findall(groot,'Type','figure'); visible=get(groot,'DefaultFigureVisible'); set(groot,'DefaultFigureVisible','off'); cleanup=onCleanup(@()restore(visible,before)); %#ok<NASGU>
result=struct('error',''); t=tic;
try
 lambda=config.lambdaFirst; if j==1, lambda=fminsearch('auxvboxcoxllik',1,optimset('Display','off'),train,12,0); elseif j==4, lambda=config.lambdaA; end
 ty=vboxcox(train,lambda); center=0; spread=1;
 if j>=3, center=mean(ty); spread=std(ty,0); assert(isfinite(spread)&&spread>0); end
 x=(ty-center)/spread; log=evalc('m=modelUC(x, [], ''LLT12'',24);');
 z=m.py(:)*spread+center; assert(numel(z)==24 && isreal(z)&&all(isfinite(z)) && all(1+lambda*z>0));
 p=vboxcoxinv(z,lambda); assert(all(isfinite(p)&p>200&p<600));
 result.pred=p; result.model=struct; result.model.fit=m; result.model.log=log; result.model.z=z;
 result.lambda=lambda; result.center=center; result.spread=spread; result.scale=mean(abs(train(13:end)-train(1:end-12))); result.seconds=toc(t);
catch ME, result.error=getReport(ME,'extended','hyperlinks','off'); end
end

function P=accept(P,R,r,j)
% 成功拟合后才设置完成标记，预测及所有恢复尺度参数同时保存。
P.pred(:,j,r)=R.pred; P.models{r,j}=R.model; P.lambda(r,j)=R.lambda; P.centers(r,j)=R.center;
P.spreads(r,j)=R.spread; P.scales(r,j)=R.scale; P.seconds(r,j)=R.seconds; P.done(r,j)=true; P.error='';
end

function export(P,out)
% 每个方案保留实际轮数，试跑结果不冒充220轮汇总。
T=table; M=table; dates=datetime(1958,3,1)+calmonths((0:722)'); dates.Format='yyyy-MM-dd';
for j=1:4
 idx=find(P.done(:,j)); if isempty(idx), continue; end
 p=reshape(P.pred(:,j,idx),24,[]); a=zeros(24,numel(idx)); for k=1:numel(idx), r=idx(k); a(:,k)=P.y(r+480:r+503); end
 e=abs(a-p); sm=200*e./(abs(a)+abs(p)); ma=e./P.scales(idx,j)';
 r=repelem(idx,24); h=repmat((1:24)',numel(idx),1); first=r; if j==2, first=ones(size(r)); end
 T=[T;table(repmat(P.config.names(j),numel(r),1),r,h,first,r+479,string(dates(r+479)),string(dates(r+479+h)),a(:),p(:),P.lambda(r,j),P.centers(r,j),P.spreads(r,j),P.scales(r,j), ...
  'VariableNames',{'protocol','round','horizon','train_start','train_end','forecast_origin','target_month','actual','predicted','lambda','center','spread','scale'})]; %#ok<AGROW>
 M=[M;table(repmat(P.config.names(j),24,1),(1:24)',repmat(numel(idx),24,1),mean(sm,2),mean(ma,2),'VariableNames',{'protocol','horizon','rounds','sMAPE','MASE'})]; %#ok<AGROW>
end
writetable(T,fullfile(out,'predictions.csv'),'Encoding','UTF-8'); writetable(M,fullfile(out,'metrics_by_horizon.csv'),'Encoding','UTF-8');
fid=fopen(fullfile(out,'audit.txt'),'w','n','UTF-8'); fprintf(fid,'待独立核验；完成%s\n',mat2str(sum(P.done,1))); fclose(fid);
end

function saveAtomic(path,P)
% 同目录原子保存，已有检查点不删除。
tmp=[path '.tmp']; save(tmp,'P','-v7'); D=load(tmp,'-mat','P'); assert(isequal(D.P.done,P.done)); movefile(tmp,path,'f');
end
function restore(visible,before)
% 保留用户已有窗口。
delete(setdiff(findall(groot,'Type','figure'),before)); set(groot,'DefaultFigureVisible',visible);
end
function finishPool(pool,own)
% 仅释放本次新建进程池。
if own, delete(pool); end
end

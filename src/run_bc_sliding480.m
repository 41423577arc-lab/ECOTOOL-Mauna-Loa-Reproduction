function run_bc_sliding480(roundLimit,nWorkers)
% 按A原协议重跑B/C，并单独保存无前视固定参数的两模型敏感性实验。
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'results','comparison','sliding_480');
if nargin<1, roundLimit=220; end
if nargin<2, nWorkers=1; end
validateattributes(roundLimit,{'numeric'},{'scalar','integer','>=',1,'<=',220});
validateattributes(nWorkers,{'numeric'},{'scalar','integer','>=',1});
if ~isfolder(out), mkdir(out); end
S=load(fullfile(root,'data','dataPLOSpaper.mat'),'CO2'); y=S.CO2(:);
assert(numel(y)==723 && all(isfinite(y)&y>0));
config=struct('L',480,'H',24,'R',220,'lambdaA',.2461, ...
 'lambdaFirst',fminsearch('auxvboxcoxllik',1,optimset('Display','off'),y(1:480),12,0), ...
 'lambdaSingle',fminsearch('auxvboxcoxllik',1,optimset('Display','off'),y(25:504),12,0), ...
 'names',["Airline" "AutoARIMA" "UC" "AR12" "Airline" "UC"], ...
 'interfaces',["modelTF(ty,'model','(1+ma1*B)(1+ma12*B12)/(1-B)(1-B12)','nofs',24)" ...
 "modelAUTO(train,'s',[1 12],'nofs',24)" "modelUC(ty, [], 'LLT12', 24)" "member_c_ar12(train,24)"], ...
 'protocol',"前四列严格照A，后两列仅用首轮训练集估计固定lambda；AutoARIMA内部默认boxcox=1，AR12原始ppm");
env.matlab=version; env.release=version('-release'); env.computer=computer;
a=matlab.addons.installedAddons; env.ecotool=a(contains(upper(a.Name),'ECOTOOL'),:);
for name=["modelTF" "modelTF0" "modelAUTO" "modelAUTO0" "modelUC" "modelUC0" "vboxcox" "vboxcoxinv" "auxvboxcoxllik" "member_c_ar12"]
 p=which(name); assert(~isempty(p),'缺少依赖%s',name); env.paths.(name)=p; env.hashes.(name)=hashFile(p);
end
path=fullfile(out,'checkpoint.mat');
if isfile(path)
 D=load(path,'C'); C=D.C;
 assert(isequal(C.y,y)&&isequal(C.config,config)&&isequal(C.env.hashes,env.hashes)&&strcmp(C.env.matlab,env.matlab),'检查点配置或依赖变化');
else
 C=struct('config',config,'env',env,'y',y,'pred',nan(24,6,220), ...
 'scales',nan(220,1),'actual',nan(24,220),'done',false(220,6), ...
 'models',{cell(220,6)},'seconds',nan(220,6),'error','','created',char(datetime('now')));
end
before=findall(groot,'Type','figure'); visible=get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off'); cleaner=onCleanup(@()restore(visible,before)); %#ok<NASGU>
atomicSave(path,C);
fid=fopen(fullfile(out,'audit.txt'),'w','n','UTF-8');
fprintf(fid,'待核验：实验续跑或重新导出后需要再次独立核验。\n'); fclose(fid);
try
 if nWorkers>1
  C=runParallel(C,path,roundLimit,nWorkers);
  exportPredictions(C,out); return;
 end
 for r=1:roundLimit
  train=y(r:r+479); actual=y(r+480:r+503); scale=mean(abs(train(13:end)-train(1:end-12)));
  if any(C.done(r,:)), assert(abs(C.scales(r)-scale)<1e-12 && isequal(C.actual(:,r),actual)); end
  for j=1:6
   if C.done(r,j), continue; end
   lambda=config.lambdaA; if j>4, lambda=config.lambdaFirst; end
   result=estimateOne(train,j,lambda);
   assert(isempty(result.error),'%s',result.error); p=result.p; meta=result.meta;
   C.pred(:,j,r)=p; C.actual(:,r)=actual; C.scales(r)=scale;
   C.models{r,j}=meta; C.seconds(r,j)=result.seconds; C.done(r,j)=true; C.error='';
   atomicSave(path,C); restore('off',before);
   fprintf('滑动窗口 第%d/220轮 列%d %s %.2f秒 完成%s\n',r,j,config.names(j),C.seconds(r,j),mat2str(sum(C.done,1)));
  end
 end
 exportPredictions(C,out); atomicSave(path,C);
catch ME
 D=load(path,'C'); C=D.C; C.error=getReport(ME,'extended','hyperlinks','off');
 atomicSave(path,C); exportPredictions(C,out); rethrow(ME);
end
end

function exportPredictions(C,out)
% 主实验与无前视敏感性实验使用不同文件，避免混淆。
dates=datetime(1958,3,1)+calmonths((0:722)'); dates.Format='yyyy-MM-dd';
for group=1:2
 T=table; M=table; js=1:4; prefix=''; if group==2, js=5:6; prefix='first_train_lambda_'; end
 for j=js
  idx=find(C.done(:,j)); if isempty(idx), continue; end
  p=reshape(C.pred(:,j,idx),24,[]); a=C.actual(:,idx); e=abs(a-p);
  sm=200*e./(abs(a)+abs(p)); ma=e./C.scales(idx)';
  rounds=repelem(idx,24); h=repmat((1:24)',numel(idx),1); n=479+rounds;
  T=[T;table(repmat(C.config.names(j),numel(h),1),rounds,rounds,n,string(dates(n)),string(dates(n+h)),h,a(:),p(:),C.scales(rounds), ...
   'VariableNames',{'model','round','train_start','train_end','forecast_origin','target_month','horizon','actual','predicted','scale'})]; %#ok<AGROW>
  M=[M;table(repmat(C.config.names(j),24,1),(1:24)',repmat(numel(idx),24,1),mean(sm,2),mean(ma,2), ...
   'VariableNames',{'model','horizon','rounds','sMAPE_percent','MASE'})]; %#ok<AGROW>
 end
 if ~isempty(T), writetable(T,fullfile(out,[prefix 'predictions.csv']),'Encoding','UTF-8'); end
 if ~isempty(M), writetable(M,fullfile(out,[prefix 'metrics_by_horizon.csv']),'Encoding','UTF-8'); end
end
fid=fopen(fullfile(out,'audit.txt'),'w','n','UTF-8'); fprintf(fid,'待独立核验；完成列数%s\n',mat2str(sum(C.done,1))); fclose(fid);
end

function atomicSave(path,C)
% 同目录原子替换，每成功拟合一个模型即保存，出错时保留此前结果。
tmp=[path '.tmp']; save(tmp,'C','-v7'); D=load(tmp,'-mat','C'); assert(isequaln(D.C.done,C.done));
[ok,msg]=movefile(tmp,path,'f'); assert(ok,'%s',msg);
end

function h=hashFile(path)
% 固定公开接口与加密后端的版本证据。
fid=fopen(path,'rb'); assert(fid>=0); cleaner=onCleanup(@()fclose(fid)); %#ok<NASGU>
b=fread(fid,Inf,'*uint8'); md=java.security.MessageDigest.getInstance('SHA-256'); md.update(typecast(b,'int8'));
h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end

function restore(visible,before)
% 不关闭用户已有图窗。
delete(setdiff(findall(groot,'Type','figure'),before)); set(groot,'DefaultFigureVisible',visible);
end

function result=estimateOne(train,j,lambda)
% 每个工作进程独立拟合，接口与串行路径完全一致；不接收未来数据。
before=findall(groot,'Type','figure'); visible=get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off'); cleaner=onCleanup(@()restore(visible,before)); %#ok<NASGU>
result=struct('p',[],'meta',[],'seconds',NaN,'error','');
t=tic;
try

   if ismember(j,[1 3 5 6]), ty=vboxcox(train,lambda); end
   if ismember(j,[1 5])
    log=evalc('m=modelTF(ty,''model'',''(1+ma1*B)(1+ma12*B12)/(1-B)(1-B12)'',''nofs'',24);');
   elseif j==2
    log=evalc('m=modelAUTO(train,''s'',[1 12],''nofs'',24);');
    assert(m.boxcox==1 && isequal(m.y,train),'AutoARIMA应自行处理变换');
   elseif ismember(j,[3 6])
    log=evalc('m=modelUC(ty, [], ''LLT12'', 24);');
   else
    [p,beta]=member_c_ar12(train,24);
   end
   if j~=4
    z=m.py(:); p=z;
    if j~=2
     assert(all(1+lambda*z>0)); p=vboxcoxinv(z,lambda);
    end
    % 自动识别有时返回元胞字段，逐字段赋值以保持元数据为标量结构。
    meta=struct; meta.model=m.model; meta.par=m.par; meta.table=m.table;
    meta.method=m.method; meta.outlier=m.outlier; meta.log=log;
    meta.rawForecast=z; meta.input=m.y; meta.lambdaExternal=NaN;
    if j~=2, meta.lambdaExternal=lambda; end
    if j==2, meta.boxcox=m.boxcox; end
   else
    meta=struct('beta',beta,'order',12,'method','原始ppm含截距OLS及24步递推');
   end
   assert(isequal(size(p),[24 1]) && isreal(p) && all(isfinite(p)&p>200&p<600));

 result.p=p; result.meta=meta; result.seconds=toc(t);
catch ME
 result.error=getReport(ME,'extended','hyperlinks','off');
end
end

function C=runParallel(C,path,roundLimit,nWorkers)
% 仅主进程写检查点，进程间不共享文件；成功任务逐个落盘并保留原有结果。
if all(C.done(1:roundLimit,:),'all'), return; end
start=tic; C.execution=struct('workers',nWorkers,'started',char(datetime('now')),'wallSeconds',NaN);
pool=gcp('nocreate'); ownPool=isempty(pool);
if ownPool, pool=parpool('Processes',nWorkers); end
cleanup=onCleanup(@()finishPool(pool,ownPool)); %#ok<NASGU>
futures=parallel.FevalFuture.empty(0,1); tasks=zeros(0,2);
for r=1:roundLimit
 for j=1:6
  if C.done(r,j), continue; end
  lambda=C.config.lambdaA; if j>4, lambda=C.config.lambdaFirst; end
  futures(end+1)=parfeval(pool,@estimateOne,1,C.y(r:r+479),j,lambda); %#ok<AGROW>
  tasks(end+1,:)=[r j]; %#ok<AGROW>
 end
end
cancelCleanup=onCleanup(@()cancel(futures)); %#ok<NASGU>
for k=1:numel(futures)
 [idx,result]=fetchNext(futures); r=tasks(idx,1); j=tasks(idx,2);
 if ~isempty(result.error)
  C.error=result.error; atomicSave(path,C); error('实验拟合失败：%s',result.error);
 end
 train=C.y(r:r+479); C.pred(:,j,r)=result.p; C.models{r,j}=result.meta;
 C.actual(:,r)=C.y(r+480:r+503); C.scales(r)=mean(abs(train(13:end)-train(1:end-12)));
 C.seconds(r,j)=result.seconds; C.done(r,j)=true; C.error=''; atomicSave(path,C);
 fprintf('并行滑动窗口 第%d轮 列%d %.2f秒 完成%s\n',r,j,result.seconds,mat2str(sum(C.done,1)));
end
C.execution.wallSeconds=toc(start); C.execution.finished=char(datetime('now'));
atomicSave(path,C);
end

function finishPool(pool,ownPool)
% 只关闭本实验新建的进程池，保留用户原有进程池。
if ownPool, delete(pool); end
end

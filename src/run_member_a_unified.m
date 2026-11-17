function run_member_a_unified(roundLimit,toolboxPath,dataPath,out)
% 在成员C分支适配A的两个模型：扩展窗口、逐轮估计变换、按轮原子保存。
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1, roundLimit=220; end
if nargin<2, toolboxPath=''; end
if nargin<3 || isempty(dataPath), dataPath=fullfile(root,'data','dataPLOSpaper.mat'); end
if nargin<4 || isempty(out), out=fullfile(root,'results','comparison'); end
validateattributes(roundLimit,{'numeric'},{'scalar','integer','>=',1,'<=',220});
if ~isempty(toolboxPath), addpath(toolboxPath); end
S=load(dataPath,'CO2'); yall=S.CO2(:);
assert(numel(yall)==723 && all(isfinite(yall) & yall>0));
env.matlab=version; addons=matlab.addons.installedAddons;
env.ecotool=addons(contains(upper(addons.Name),'ECOTOOL'),:);
for name=["modelETS" "modelNAIVE" "vboxcox" "vboxcoxinv" "modelETS0" "modelNAIVE0"]
    path=which(name); assert(~isempty(path),'缺少ECOTOOL函数：%s',name);
    env.paths.(name)=path; env.hashes.(name)=fileHash(path);
end
config=struct('H',24,'R',220,'origins',(480:699)', ...
    'names',["ETS" "SeasonalNaive"],'ets',"modelETS(ty, [], 'AA12', 24)", ...
    'naive',"modelNAIVE(ty, 24, 12).py(:,3)", ...
    'transform',"每轮仅用训练集估计Box-Cox，再逆变换到ppm");
if ~isfolder(out), mkdir(out); end
checkpoint=fullfile(out,'a_checkpoint.mat');
if isfile(checkpoint)
    D=load(checkpoint,'A'); A=D.A;
    assert(isequal(A.yall,yall) && isequal(A.config,config),'检查点数据或配置不一致');
    assert(isequal(A.env.hashes,env.hashes) && strcmp(A.env.matlab,env.matlab),'依赖或MATLAB版本变化');
    for r=find(A.done)'
        y=yall(1:479+r); sc=mean(abs(y(13:end)-y(1:end-12)));
        assert(abs(A.scales(r)-sc)<1e-12 && all(isfinite(A.pred(:,:,r)),'all'));
        assert(isequal(A.actual(:,r),yall(479+r+(1:24))));
    end
else
    A=struct('config',config,'env',env,'yall',yall,'pred',nan(24,2,220), ...
        'actual',nan(24,220),'scales',nan(220,1),'lambdas',nan(220,1), ...
        'transformed',nan(24,2,220),'models',{cell(220,1)}, ...
        'seconds',nan(220,1),'done',false(220,1),'error','');
    atomicSave(checkpoint,A);
end
before=findall(groot,'Type','figure'); visible=get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanup=onCleanup(@()restoreFigures(visible,before)); %#ok<NASGU>
try
    for r=1:roundLimit
        if A.done(r), continue; end
        t=tic; n=479+r; y=yall(1:n);
        transformLog=evalc('[ty,lambda]=vboxcox(y);');
        estimateLog=evalc('mE=modelETS(ty, [], ''AA12'', 24);');
        mN=modelNAIVE(ty,24,12);
        z=[mE.py(:) mN.py(:,3)];
        assert(isequal(size(z),[24 2]) && all(isfinite(z),'all'));
        assert(lambda==0 || all(1+lambda*z>0,'all'),'逆Box-Cox超出定义域');
        p=vboxcoxinv(z,lambda);
        assert(isreal(p) && all(isfinite(p) & p>200 & p<600,'all'),'预测不在合理ppm尺度');
        seasonal=repmat(y(end-11:end),2,1);
        assert(max(abs(p(:,2)-seasonal))<1e-9,'季节朴素接口或逆变换不正确');
        A.pred(:,:,r)=p; A.transformed(:,:,r)=z; A.actual(:,r)=yall(n+(1:24));
        A.scales(r)=mean(abs(y(13:end)-y(1:end-12))); A.lambdas(r)=lambda;
        lines=string(cellstr(mE.table)); method=strtrim(lines(contains(lines,'Estimation method:')));
        assert(isscalar(method) && all(isfinite(mE.par)));
        A.models{r}=struct('model',mE.model,'par',mE.par,'wrapperMethod',mE.method, ...
            'effectiveMethod',method,'outlier',mE.outlier,'table',mE.table, ...
            'log',[transformLog estimateLog]);
        A.seconds(r)=toc(t); A.done(r)=true; A.error='';
        atomicSave(checkpoint,A);
        fid=fopen(fullfile(out,'audit.txt'),'w'); assert(fid>=0);
        fprintf(fid,'NOT RUN：A统一实验已完成%d/220轮；请运行整合及独立核验。\n',sum(A.done)); fclose(fid);
        restoreFigures('off',before);
        fprintf('A统一实验 %d/220 | ETS与季节朴素 | %.2f秒\n',r,A.seconds(r));
    end
catch ME
    D=load(checkpoint,'A'); A=D.A; A.error=getReport(ME,'extended','hyperlinks','off');
    atomicSave(checkpoint,A); rethrow(ME);
end
fprintf('已完成%d/220轮，总模型耗时%.3f秒。\n',sum(A.done),sum(A.seconds(A.done)));
end

function atomicSave(path,A)
% 临时文件成功写入并可读后，再替换正式检查点。
tmp=[path '.tmp']; save(tmp,'A','-v7'); D=load(tmp,'-mat','A');
assert(isequaln(A.done,D.A.done)); [ok,msg]=movefile(tmp,path,'f'); assert(ok,'%s',msg);
end

function hash=fileHash(path)
% 同时记录公开包装器和加密后端的文件指纹。
fid=fopen(path,'rb'); assert(fid>=0); cleaner=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8'); md=java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(bytes,'int8')); hash=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end

function restoreFigures(visible,before)
% 仅关闭本函数新增的工具箱窗口，保留用户原有窗口。
delete(setdiff(findall(groot,'Type','figure'),before)); set(groot,'DefaultFigureVisible',visible);
end

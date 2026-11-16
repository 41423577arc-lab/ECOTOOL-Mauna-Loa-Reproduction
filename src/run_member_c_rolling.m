function run_member_c_rolling(roundLimit,toolboxPath,dataPath,out)
% RUN_MEMBER_C_ROLLING Expand CO2(1:479+r), forecast 24 months, resume per model.
% run_member_c_rolling(3); run_member_c_rolling(220);
% Optional: toolbox folder (empty uses installed path), MAT file, output folder.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1, roundLimit=220; end
if nargin<2, toolboxPath=''; end
if nargin<3 || isempty(dataPath), dataPath=fullfile(root,'data','dataPLOSpaper.mat'); end
if nargin<4 || isempty(out), out=fullfile(root,'results','rolling_c'); end
validateattributes(roundLimit,{'numeric'},{'scalar','integer','>=',1,'<=',220});
if ~isempty(toolboxPath), addpath(toolboxPath); end
fn={'modelUC','vboxcox','vboxcoxinv'};
env.matlab=version; env.release=version('-release'); env.computer=computer;
addons=matlab.addons.installedAddons;
env.ecotool=addons(contains(upper(addons.Name),'ECOTOOL'),:);
for k=1:numel(fn)
    path=which(fn{k}); assert(~isempty(path),'Missing ECOTOOL function: %s',fn{k});
    env.paths.(fn{k})=path; env.sources.(fn{k})=fileread(path);
end
env.backendPath=which('modelUC0');
assert(~isempty(env.backendPath),'Missing ECOTOOL modelUC0 backend');
env.backendSHA256=fileHash(env.backendPath);
S=load(dataPath,'CO2'); yall=S.CO2(:);
assert(numel(yall)==723 && all(isfinite(yall)) && all(yall>0));
config=struct('schema',1,'H',24,'R',220,'origins',(480:699)', ...
    'names',["UC" "AR12"],'uc','modelUC(ty, [], ''LLT12'', 24)', ...
    'arOrder',12,'arMethod','OLS with intercept; raw ppm; recursive', ...
    'scale','mean(abs(y(13:end)-y(1:end-12)))');
if ~exist(out,'dir'), mkdir(out); end
checkpoint=fullfile(out,'checkpoint.mat');
if isfile(checkpoint)
    D=load(checkpoint,'C'); C=D.C;
    assert(isequal(C.yall,yall) && isequal(C.config,config),'Checkpoint data/config mismatch');
    assert(isequal(C.env.sources,env.sources) && strcmp(C.env.matlab,env.matlab), ...
        'MATLAB or ECOTOOL source changed; use a separate output folder');
    if isfield(C.env,'backendSHA256')
        assert(strcmp(C.env.backendSHA256,env.backendSHA256),'ECOTOOL backend changed');
    else
        C.env.backendPath=env.backendPath; C.env.backendSHA256=env.backendSHA256;
    end
    validateCheckpoint(C);
else
    C=struct('config',config,'yall',yall,'env',env,'dataPath',dataPath, ...
        'pred',nan(24,2,220),'actual',nan(24,220),'scales',nan(220,1), ...
        'lambdas',nan(220,1),'models',{cell(220,2)}, ...
        'seconds',nan(220,2),'done',false(220,2),'error','', ...
        'single',[],'created',char(datetime('now')));
end
% The positional backend can disagree with the wrapper's returned method field.
% Preserve that field, and separately extract the method actually reported.
for r=find(C.done(:,1))'
    C.models{r,1}.effectiveMethod=reportedMethod(C.models{r,1}.table);
end
atomicSave(checkpoint,C);
% Never close the user's existing figures; clean up only toolbox-created ones.
oldVisible=get(groot,'DefaultFigureVisible'); before=findall(groot,'Type','figure');
set(groot,'DefaultFigureVisible','off');
cleanup=onCleanup(@()restoreFigures(oldVisible,before)); %#ok<NASGU>
exportResults(C,out); % Repair stale exports after a previous interruption.
try
    for r=1:roundLimit
        n=config.origins(r); y=yall(1:n);
        for j=1:2
            if C.done(r,j), continue; end
            t=tic;
            if j==1
                transformLog=evalc('[ty,lambda]=vboxcox(y);');
                assert(isscalar(lambda) && isfinite(lambda));
                estimateLog=evalc('m=modelUC(ty, [], ''LLT12'', 24);');
                z=m.py(:);
                assert(numel(z)==24 && isreal(z) && all(isfinite(z)));
                assert(lambda==0 || all(1+lambda*z>0),'Invalid inverse Box-Cox domain');
                p=vboxcoxinv(z,lambda);
                C.lambdas(r)=lambda;
                C.models{r,j}=struct('model',m.model,'par',m.par, ...
                    'method',m.method,'outlier',m.outlier,'table',m.table, ...
                    'effectiveMethod',reportedMethod(m.table), ...
                    'transformedForecast',z,'log',[transformLog estimateLog]);
            else
                [p,beta]=member_c_ar12(y,24);
                C.models{r,j}=struct('order',12,'beta',beta,'method',config.arMethod);
            end
            assert(isequal(size(p),[24 1]) && isreal(p) && all(isfinite(p)) ...
                && all(p>200 & p<600),'Invalid forecast or original ppm scale');
            C.pred(:,j,r)=p; C.actual(:,r)=yall(n+(1:24));
            C.scales(r)=mean(abs(y(13:end)-y(1:end-12)));
            assert(C.scales(r)>0 && isfinite(C.scales(r)));
            C.seconds(r,j)=toc(t); C.done(r,j)=true; C.error='';
            atomicSave(checkpoint,C);
            exportResults(C,out);
            restoreFigures('off',before);
            fprintf('%s ROUND %d/220 | %.2fs | UC=%d AR12=%d\n', ...
                config.names(j),r,C.seconds(r,j),sum(C.done(:,1)),sum(C.done(:,2)));
        end
    end
    % Separate single-origin example, same CO2(25:504) as existing UC and B.
    if isempty(C.single)
        t=tic; [p,beta]=member_c_ar12(yall(25:504),24);
        C.single=struct('pred',p,'beta',beta,'scale', ...
            mean(abs(yall(37:504)-yall(25:492))),'seconds',toc(t));
        atomicSave(checkpoint,C);
    end
    C.error=''; atomicSave(checkpoint,C);
    exportResults(C,out);
catch ME
    % Disk checkpoint is authoritative: never commit a partially failed model.
    if isfile(checkpoint), D=load(checkpoint,'C'); C=D.C; end
    C.error=getReport(ME,'extended','hyperlinks','off');
    atomicSave(checkpoint,C); exportResults(C,out);
    rethrow(ME);
end
end

function method=reportedMethod(estimationTable)
lines=string(cellstr(estimationTable));
method=strtrim(lines(contains(lines,'Estimation method:')));
assert(isscalar(method),'Cannot determine UC method from estimation table');
end

function hash=fileHash(path)
fid=fopen(path,'rb'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8'); md=java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(bytes,'int8')); digest=typecast(md.digest(),'uint8');
hash=lower(reshape(dec2hex(digest,2).',1,[]));
end

function validateCheckpoint(C)
assert(isequal(size(C.done),[220 2]) && islogical(C.done));
assert(isequal(size(C.pred),[24 2 220]) && isequal(size(C.actual),[24 220]));
for r=1:220
    if ~any(C.done(r,:)), continue; end
    y=C.yall(1:479+r); scale=mean(abs(y(13:end)-y(1:end-12)));
    assert(abs(C.scales(r)-scale)<1e-12,'Invalid checkpoint training scale');
    assert(isequal(C.actual(:,r),C.yall(479+r+(1:24))),'Invalid checkpoint actuals');
    for j=find(C.done(r,:))
        p=C.pred(:,j,r);
        assert(isreal(p) && all(isfinite(p) & p>200 & p<600),'Invalid completed checkpoint prediction');
        assert(~isempty(C.models{r,j}) && isfinite(C.seconds(r,j)));
        if j==1, assert(isfinite(C.lambdas(r))); end
    end
end
end

function atomicSave(path,C)
% Same-directory replacement; the old checkpoint survives an interrupted save.
tmp=[path '.tmp']; save(tmp,'C','-v7');
D=load(tmp,'-mat','C'); assert(isequaln(D.C.done,C.done));
[ok,msg]=movefile(tmp,path,'f'); assert(ok,'%s',msg);
end

function exportResults(C,out)
dates=datetime(1958,3,1)+calmonths((0:722)'); dates.Format='yyyy-MM-dd';
T=table; M=table;
for j=1:2
    idx=find(C.done(:,j));
    if ~isempty(idx)
        p=reshape(C.pred(:,j,idx),24,[]); a=C.actual(:,idx);
        e=abs(a-p); sm=200*e./(abs(a)+abs(p)); ma=e./C.scales(idx)';
        rounds=repelem(idx,24); n=479+rounds; h=repmat((1:24)',numel(idx),1);
        T=[T;table(repmat(C.config.names(j),numel(h),1),rounds, ...
            dates(n),dates(n+h),h,a(:),p(:),C.scales(rounds), ...
            'VariableNames',{'model','round','forecast_origin','target_month','horizon','actual','predicted','scale'})]; %#ok<AGROW>
        M=[M;table(repmat(C.config.names(j),24,1),(1:24)', ...
            repmat(numel(idx),24,1),mean(sm,2),mean(ma,2), ...
            'VariableNames',{'model','horizon','rounds','sMAPE_percent','MASE'})]; %#ok<AGROW>
    end
end
if ~isempty(T), atomicTable(T,fullfile(out,'predictions.csv')); end
if ~isempty(M), atomicTable(M,fullfile(out,'metrics_by_horizon.csv')); end
if ~isempty(C.single)
    a=C.yall(505:528); p=C.single.pred; e=abs(a-p);
    S=table(repmat("AR12",24,1),repmat(dates(504),24,1),dates(505:528), ...
        (1:24)',a,p,200*e./(abs(a)+abs(p)),e/C.single.scale, ...
        'VariableNames',{'model','forecast_origin','target_month','horizon','actual','predicted','sMAPE_percent','MASE'});
    atomicTable(S,fullfile(out,'ar12_single_predictions.csv'));
end
fid=fopen(fullfile(out,'status.txt.tmp'),'w'); assert(fid>=0);
fprintf(fid,'UC: %d/220\nAR12: %d/220\nPrediction rows: %d\nMATLAB: %s\n', ...
    sum(C.done(:,1)),sum(C.done(:,2)),height(T),C.env.matlab);
addonText=regexprep(evalc('disp(C.env.ecotool)'),'[ \t]+(?=\r?\n)','');
fprintf(fid,'ECOTOOL installed add-on:\n%s\n',addonText);
fprintf(fid,'modelUC: %s\nTotal model seconds: %.3f\nUpdated: %s\n', ...
    C.env.paths.modelUC,sum(C.seconds(C.done)),char(datetime('now')));
if isfield(C.env,'backendSHA256')
    fprintf(fid,'modelUC0 SHA256: %s\n',C.env.backendSHA256);
end
lastError=C.error; if isempty(lastError), lastError='(none)'; end
fprintf(fid,'Audit must be rerun after updates.\nLast error: %s\n',lastError);
fclose(fid); movefile(fullfile(out,'status.txt.tmp'),fullfile(out,'status.txt'),'f');
% An old PASS must never describe newer results.
if isfile(fullfile(out,'audit.txt'))
    fid=fopen(fullfile(out,'audit.txt'),'w'); fprintf(fid,'NOT RUN: results re-exported; run audit_member_c_rolling.\n'); fclose(fid);
end
end

function atomicTable(T,path)
tmp=[path '.tmp']; writetable(T,tmp,'FileType','text','Delimiter',',');
[ok,msg]=movefile(tmp,path,'f'); assert(ok,'%s',msg);
end

function restoreFigures(visible,before)
after=findall(groot,'Type','figure'); delete(setdiff(after,before));
set(groot,'DefaultFigureVisible',visible);
end

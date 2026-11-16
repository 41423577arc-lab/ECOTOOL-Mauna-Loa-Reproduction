function verify_member_c_rolling(dataPath,out)
% Exercise no-refit resume and audit rejection paths against temporary copies.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1 || isempty(dataPath), dataPath=fullfile(root,'data','dataPLOSpaper.mat'); end
if nargin<2 || isempty(out), out=fullfile(root,'results','rolling_c'); end
evalc('audit_member_c_rolling(220,dataPath,out);');
D=load(fullfile(out,'checkpoint.mat'),'C'); original=D.C;
evalc('run_member_c_rolling(220,'''',dataPath,out);');
D=load(fullfile(out,'checkpoint.mat'),'C');
assert(isequaln(original.pred,D.C.pred) && isequaln(original.seconds,D.C.seconds) ...
    && isequaln(original.done,D.C.done),'Resume unexpectedly refitted completed models');
tmp=tempname; mkdir(tmp);
cleanup=onCleanup(@()cleanTemp(tmp)); %#ok<NASGU>
files={'predictions.csv','metrics_by_horizon.csv','checkpoint.mat','ar12_single_predictions.csv'};
for k=1:numel(files), copyfile(fullfile(out,files{k}),fullfile(tmp,files{k})); end
T=readtable(fullfile(tmp,'predictions.csv'),'TextType','string');
M=readtable(fullfile(tmp,'metrics_by_horizon.csv'),'TextType','string');
probes=["duplicate key" "wrong actual" "nonfinite forecast" "future-data scale" "wrong metric" "checkpoint flag"];
messages=["Unique model/round/horizon keys" "Actuals match independent raw observations" ...
    "Finite predictions" "CSV scales use training-only" ...
    "Independently recomputed" "Checkpoint done flags"];
for k=1:numel(probes)
    Q=T; N=M; C=D.C;
    switch k
        case 1, Q(end,:)=Q(1,:);
        case 2, Q.actual(1)=Q.actual(1)+1;
        case 3, Q.predicted(1)=NaN;
        case 4
            y=C.yall; Q.scale(1)=mean(abs(y(13:end)-y(1:end-12)));
        case 5, N.sMAPE_percent(1)=N.sMAPE_percent(1)+0.01;
        case 6, C.done(1,1)=false;
    end
    writetable(Q,fullfile(tmp,'predictions.csv'));
    writetable(N,fullfile(tmp,'metrics_by_horizon.csv'));
    save(fullfile(tmp,'checkpoint.mat'),'C');
    rejected=false;
    try
        evalc('audit_member_c_rolling(220,dataPath,tmp);');
    catch ME
        rejected=strcmp(ME.identifier,'memberC:AuditFailed') && ...
            contains(fileread(fullfile(tmp,'audit.txt')),"FAIL: "+messages(k));
    end
    assert(rejected,'Audit did not reject expected defect: %s',probes(k));
end
evalc('audit_member_c_rolling(220,dataPath,out);');
fid=fopen(fullfile(out,'audit.txt'),'a'); assert(fid>=0);
fprintf(fid,'PASS: no-refit resume preserved all predictions, completion flags and model runtimes.\n');
fprintf(fid,'PASS: deliberately corrupted temporary data rejected: %s.\n',strjoin(probes,', '));
fclose(fid); fprintf('PASS: resume plus %d negative audit probes.\n',numel(probes));
end

function cleanTemp(folder)
% Only remove the explicitly created test files, then the empty temp directory.
names={'predictions.csv','metrics_by_horizon.csv','checkpoint.mat', ...
    'ar12_single_predictions.csv','audit.txt'};
for k=1:numel(names)
    path=fullfile(folder,names{k}); if isfile(path), delete(path); end
end
rmdir(folder);
end

function run_ets_30()
% Only 3 members x 2 raw-scale ETS models x 30 expanding origins.
here=fileparts(mfilename('fullpath'));root=fileparts(fileparts(here));
out=fullfile(here,'results');if ~isfolder(out),mkdir(out);end
assert(~isfile(fullfile(out,'ets_runtime.json')),'ETS run already completed; do not repeat 180 fits.');
assert(isfile(fullfile(out,'provenance.json')),'Run assemble_verify.py prepare first.');
manifest=jsondecode(fileread(fullfile(out,'provenance.json')));
toolboxPath=char(manifest.ECOTOOLPath);addpath(toolboxPath);
adapter=fullfile(root,'rolling_final4','src','ets');addpath(adapter,'-begin');
assert(strcmp(which('fit_ets_final4'),fullfile(adapter,'fit_ets_final4.m')));
assert(strcmp(which('textoutputWINDOW'),fullfile(adapter,'textoutputWINDOW.m')));
assert(strcmp(which('modelETS'),fullfile(toolboxPath,'modelETS.m')));
set(groot,'DefaultFigureVisible','off');cleanup=onCleanup(@()close('all','force')); %#ok<NASGU>
records=table;parameters=table;tAll=tic;
fid=fopen(fullfile(out,'ets_optimizer.log'),'w','n','UTF-8');assert(fid>0);
cleanupLog=onCleanup(@()fclose(fid)); %#ok<NASGU>
for person=["A","B","C"]
    file=fullfile(root,'data',person+"_个人总支付_自然周.xlsx");
    % Only read the 108 training weeks; no final-four amount is read here.
    dates=readcell(file,'Sheet','UC数据','Range','A2:A109');
    if isnumeric(dates{1}),dates=datetime(cell2mat(dates),'ConvertFrom','excel');else,dates=datetime(string(dates));end
    y=readmatrix(file,'Sheet','UC数据','Range','B2:B109');y=y(:);
    assert(numel(y)==108 && all(isfinite(y)) && all(y>=0));
    assert(isequal(dates(:),datetime(2024,9,2)+caldays(7*(0:107)')));
    for n=78:107
        tr=y(1:n);scale=mean(abs(diff(tr)));
        for code=["NN","AN"]
            t=tic;[m,txt]=fit_ets_final4(tr,code,1);elapsed=toc(t);
            assert(isscalar(m.py) && numel(m.par)==1+(code=="AN"));
            a=m.par(1);b=NaN;if code=="AN",b=m.par(2);end
            warningText=m.final4Warning;if warningText==":",warningText="";end
            token=regexp(txt,'Exit([0-9]+)basic','tokens','once');exitTextCode=NaN;
            if ~isempty(token),exitTextCode=str2double(token{1});end
            model="ETS-"+code;
            r=table(person,model,n,n+1,dates(n),dates(n+1),y(n+1),double(m.py),double(m.py)-y(n+1),scale, ...
                'VariableNames',{'Person','Model','OriginWeek','TargetWeek','OriginDate','TargetDate','Actual','Forecast','Error','MASEScale'});
            records=[records;r]; %#ok<AGROW>
            q=table(person,model,n,numel(tr),mean(tr),std(tr,0),scale,a,b,string(mat2str(m.par(:)',16)), ...
                exitTextCode,m.final4Convergence,warningText,elapsed, ...
                'VariableNames',{'Person','Model','OriginWeek','SampleN','TrainMean','TrainSD','MASEScale','Alpha','Beta','ParameterVector','ExitCodeFromText','OptimizationStatus','Warning','ElapsedSeconds'});
            parameters=[parameters;q]; %#ok<AGROW>
            % Save numerical output before logging; char conversion avoids fprintf
            % applying integer formatting to MATLAB string objects.
            writetable(records,fullfile(out,'ets_predictions.csv'),'Encoding','UTF-8');
            writetable(parameters,fullfile(out,'ets_parameters.csv'),'Encoding','UTF-8');
            fprintf(fid,'\n=== %s %s origin=%d target=%d elapsed=%.9f seconds ===\n',char(person),char(model),n,n+1,elapsed);
            fprintf(fid,'%s\n',char(txt));
            tableLines=string(m.table);
            for line=tableLines(:)',fprintf(fid,'%s\n',char(line));end
        end
        if mod(n-77,5)==0
            fprintf('%s %d/30 origins completed; cumulative %d fits; %.2fs\n',char(person),n-77,height(records),toc(tAll));
        end
    end
    writetable(records,fullfile(out,'ets_predictions.csv'),'Encoding','UTF-8');
    writetable(parameters,fullfile(out,'ets_parameters.csv'),'Encoding','UTF-8');
end
assert(height(records)==180 && height(parameters)==180);
runtime=struct('MATLAB',version,'StartedFromGitCommit',manifest.LocalHEAD, ...
    'EstimationSeconds',toc(tAll),'FitCount',height(parameters),'Protocol','training_30fold_expanding_one_step', ...
    'Method','ECOTOOL CML raw scale','FinishedAt',char(datetime('now','TimeZone','Asia/Shanghai')), ...
    'ModelETSPath',which('modelETS'),'AdapterPath',which('fit_ets_final4'),'WindowAdapterPath',which('textoutputWINDOW'));
f=fopen(fullfile(out,'ets_runtime.json'),'w','n','UTF-8');fprintf(f,'%s\n',jsonencode(runtime,PrettyPrint=true));fclose(f);
end

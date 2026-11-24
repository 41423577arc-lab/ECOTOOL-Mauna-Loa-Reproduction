function check_ets_affine()
% Diagnose centering versus division-only effects without scoring test errors.
here=fileparts(mfilename('fullpath')); root=fileparts(here);
toolboxPath=getenv('ECOTOOL_PATH');
if isempty(toolboxPath), toolboxPath=fullfile(getenv('APPDATA'),'MathWorks','MATLAB Add-Ons','Toolboxes','ECOTOOL'); end
addpath(toolboxPath); addpath(fullfile(here,'src','ets'),'-begin');
set(groot,'DefaultFigureVisible','off'); t=tic; rows=table;
profile on;
for person=["B","C"]
    y=readmatrix(fullfile(root,'data',person+"_个人总支付_自然周.xlsx"),'Sheet','UC数据','Range','B2:B109');
    s=std(y,0);mu=mean(y);
    for code=["NN","AN"]
        [raw,~]=fit_ets_final4(y,code,4);
        [scaled,~]=fit_ets_final4(y/s,code,4);
        [centered,~]=fit_ets_final4((y-mu)/s,code,4);
        for h=1:4
            rows=[rows;table(person,code,h,raw.py(h),scaled.py(h)*s,centered.py(h)*s+mu, ...
                max(abs(raw.par-scaled.par)),max(abs(raw.par-centered.par)), ...
                'VariableNames',{'Person','Code','Horizon','RawForecast','DivisionOnlyRestored','CenteredRestored','DivisionParameterDelta','CenteredParameterDelta'})];
        end
    end
end
writetable(rows,fullfile(here,'results','comparison','ets_affine_diagnostic.csv'),'Encoding','UTF-8');
profile off; info=profile('info'); names=string({info.FunctionTable.FunctionName})';
names=names(ismember(names,["modelETS","modelETS0","fisET","auxmodelESSS","kfiniet","SSpaceiniET","fminunc"]));
writetable(table(names),fullfile(here,'results','comparison','ets_call_trace.csv'),'Encoding','UTF-8');
fprintf('Affine diagnostic seconds %.3f\n',toc(t));close all force;
end

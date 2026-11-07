function run_member_b(toolboxPath,dataPath)
% Single-origin reproduction of the paper listing; run from any directory.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1, toolboxPath=fullfile(root,'..','ECOTOOL-unpacked','fsroot'); end
if nargin<2, dataPath=fullfile(root,'..','ECOTOOL-author','dataPLOSpaper.mat'); end
addpath(toolboxPath);
S=load(dataPath); assert(isfield(S,'CO2'),'Expected author CO2 vector');
yall=S.CO2(:); assert(numel(yall)==723 && all(isfinite(yall)));
dates=datetime(1958,3,1)+calmonths((0:numel(yall)-1)');
y=yall(25:504); actual=yall(505:528); H=24;
[ty,lambda]=vboxcox(y);
airline=modelTF(ty,'model','(1+ma1*B)(1+ma12*B12)/(1-B)(1-B12)','nofs',H);
auto=modelAUTO(y,'s',[1 12],'nofs',H);
% Current toolbox AUTO returns original-scale forecasts; inverse only Airline.
forecast=[vboxcoxinv(airline.py(:),lambda) auto.py(:)];
assert(isequal(size(forecast),[H 2]) && all(isfinite(forecast),'all'));
out=fullfile(root,'results','tables'); figs=fullfile(root,'results','figures');
if ~exist(out,'dir'), mkdir(out); end
if ~exist(figs,'dir'), mkdir(figs); end
names=["Airline" "AutoARIMA"]; scale=mean(abs(y(13:end)-y(1:end-12)));
T=table; M=table;
for j=1:2
 p=forecast(:,j); err=abs(actual-p);
 T=[T;table(repmat(names(j),H,1),repmat(dates(504),H,1),dates(505:528),(1:H)',actual,p,'VariableNames',{'model','forecast_origin','target_month','horizon','actual','predicted'})]; %#ok<AGROW>
 M=[M;table(names(j),mean(200*err./(abs(actual)+abs(p))),mean(err)/scale,'VariableNames',{'model','sMAPE_percent','MASE'})]; %#ok<AGROW>
end
writetable(T,fullfile(out,'B_single_predictions.csv')); writetable(M,fullfile(out,'B_single_metrics.csv'));
save(fullfile(out,'B_single_models.mat'),'airline','auto','lambda','scale','dataPath');
f=figure('Visible','off'); plot(dates(481:528),yall(481:528),'k-',dates(505:528),forecast); legend('Actual','Airline','Auto ARIMA','Location','best'); ylabel('CO2 (ppm)'); grid on; exportgraphics(f,fullfile(figs,'B_single_forecast.png')); close(f);
z=vdif(ty,[1 1],[1 12]); vident(z);
ff=findall(0,'Type','figure'); for k=1:numel(ff), exportgraphics(ff(k),fullfile(figs,sprintf('B_diagnostics_%d.png',k))); end
fid=fopen(fullfile(out,'B_environment.txt'),'w'); fprintf(fid,'MATLAB: %s\nLambda: %.16g\nTraining: %s to %s\nAuto model: %s\n',version,lambda,string(dates(25)),string(dates(504)),string(auto.model)); fclose(fid);
disp(M);
end


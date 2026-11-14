function run_member_b_rolling(roundLimit,toolboxPath,dataPath)
% Expanding-window evaluation, checkpointed after each complete origin.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1, roundLimit=220; end
if nargin<2, toolboxPath=fullfile(root,'..','ECOTOOL-unpacked','fsroot'); end
if nargin<3, dataPath=fullfile(root,'..','ECOTOOL-author','dataPLOSpaper.mat'); end
validateattributes(roundLimit,{'numeric'},{'scalar','integer','>=',1,'<=',220});
addpath(toolboxPath); S=load(dataPath); yall=S.CO2(:);
assert(numel(yall)==723 && all(isfinite(yall)) && all(yall>0));
H=24; R=220; origins=(480:699)';
dates=datetime(1958,3,1)+calmonths((0:722)');
out=fullfile(root,'results','rolling_b'); if ~exist(out,'dir'), mkdir(out); end
checkpoint=fullfile(out,'checkpoint.mat');
if exist(checkpoint,'file')
 C=load(checkpoint); assert(isequal(C.yall,yall) && isequal(C.origins,origins));
 pred=C.pred; actual=C.actual; scales=C.scales; lambdas=C.lambdas; models=C.models; seconds=C.seconds; done=C.done;
else
 pred=nan(H,2,R); actual=nan(H,R); scales=nan(R,1); lambdas=nan(R,1); models=cell(R,2); seconds=nan(R,1); done=false(R,1);
end
oldVisible=get(0,'DefaultFigureVisible'); set(0,'DefaultFigureVisible','off'); cleanup=onCleanup(@()set(0,'DefaultFigureVisible',oldVisible));
for r=1:roundLimit
 if done(r), continue; end
 t=tic; n=origins(r); y=yall(1:n); % No future information, no moving start.
 evalc('[ty,lambda]=vboxcox(y);');
 evalc('airline=modelTF(ty,''model'',''(1+ma1*B)(1+ma12*B12)/(1-B)(1-B12)'',''nofs'',H);');
 evalc('auto=modelAUTO(y,''s'',[1 12],''nofs'',H);');
 p=[vboxcoxinv(airline.py(:),lambda) auto.py(:)];
 assert(isequal(size(p),[24 2]) && all(isfinite(p),'all') && all(p>200 & p<600,'all'),'Invalid forecast or output scale');
 pred(:,:,r)=p; actual(:,r)=yall(n+(1:H)); scales(r)=mean(abs(y(13:end)-y(1:end-12))); lambdas(r)=lambda;
 models{r,1}=struct('model',airline.model,'par',airline.par); models{r,2}=struct('model',auto.model,'par',auto.par);
 seconds(r)=toc(t); done(r)=true;
 save([checkpoint '.tmp'],'pred','actual','scales','lambdas','models','seconds','done','yall','origins'); movefile([checkpoint '.tmp'],checkpoint,'f');
 close all; fprintf('ROUND %d/220 | origin %s | %.1fs | completed %d\n',r,string(dates(n)),seconds(r),sum(done));
end
idx=find(done); names=["Airline" "AutoARIMA"]; T=table; M=table;
for j=1:2
 sm=nan(H,numel(idx)); ma=sm;
 for k=1:numel(idx)
  r=idx(k); n=origins(r); p=pred(:,j,r); a=actual(:,r); e=abs(a-p);
  sm(:,k)=200*e./(abs(a)+abs(p)); ma(:,k)=e/scales(r);
  T=[T;table(repmat(names(j),H,1),repmat(r,H,1),repmat(dates(n),H,1),dates(n+(1:H)),(1:H)',a,p,'VariableNames',{'model','round','forecast_origin','target_month','horizon','actual','predicted'})]; %#ok<AGROW>
 end
 M=[M;table(repmat(names(j),H,1),(1:H)',repmat(numel(idx),H,1),mean(sm,2),mean(ma,2),'VariableNames',{'model','horizon','rounds','sMAPE_percent','MASE'})]; %#ok<AGROW>
end
writetable(T,fullfile(out,'predictions.csv')); writetable(M,fullfile(out,'metrics_by_horizon.csv'));
for metric=["sMAPE_percent" "MASE"]
 f=figure('Visible','off','Color','w'); ax=axes(f,'Color','w','XColor','k','YColor','k'); hold(ax,'on');
 for j=1:2, rows=M.model==names(j); plot(ax,M.horizon(rows),M.(metric)(rows),'LineWidth',1.8); end
 xlabel('Forecast horizon (months)'); ylabel(strrep(metric,'_',' ')); legend(names,'TextColor','k','Color','w','Location','best'); grid on;
 title(sprintf('%d rolling origins',sum(done)),'Color','k'); exportgraphics(f,fullfile(out,metric+'.png'),'Resolution',180); close(f);
end
fid=fopen(fullfile(out,'status.txt'),'w'); fprintf(fid,'Completed: %d/220\nMATLAB: %s\nFirst origin: %s\nLast completed origin: %s\nTotal model seconds: %.1f\n',sum(done),version,string(dates(origins(1))),string(dates(origins(idx(end)))),sum(seconds(done))); fclose(fid);
assert(height(T)==sum(done)*24*2);
disp(M(ismember(M.horizon,[1 6 12 24]),:));
end

function all_candidate_plots()
here=fileparts(mfilename('fullpath'));s=load(fullfile(here,'results.mat'));f=figure('Visible','off','Position',[20 20 1800 2100]);tiledlayout(7,3,'TileSpacing','compact');E=zeros(21,27);
for b=1:numel(s.models)
 nexttile;z=s.pred(s.pred.Model==s.models(b)&s.pred.Protocol=="one",:);plot(z.Origin+1,z.Actual,'k',z.Origin+1,z.Forecast,'r');title(s.models(b),'Interpreter','none');grid on;
 z=s.pred(s.pred.Model==s.models(b)&s.pred.Protocol=="four",:);E(b,:)=mean(reshape(abs(z.Forecast-z.Actual),4,27),1);
end
exportgraphics(f,fullfile(here,'08_all_candidates.png'),'Resolution',120);savefig(f,fullfile(here,'08_all_candidates.fig'));close(f);
f=figure('Visible','off','Position',[50 50 1400 850]);heatmap(string(78:104),s.models,E);xlabel('预测原点训练长度');ylabel('模型');title('各原点四步平均绝对误差/元');exportgraphics(f,fullfile(here,'09_origin_errors.png'),'Resolution',130);savefig(f,fullfile(here,'09_origin_errors.fig'));close(f);
end

function run_all_uc()
% 三人总支付的原自然周UC流程；各人结果分别保存。
projectRoot=fileparts(mfilename('fullpath'));
resultRoot=fullfile(projectRoot,'output');
addpath(fullfile(resultRoot,'流程代码'));
people=["cyx","tg","yyl"];
for person=people
    inputFile=fullfile(projectRoot,'data',person+"_个人总支付_自然周.xlsx");
    personDir=fullfile(resultRoot,person);
    run_uc_person(personDir,inputFile);
end
baselineDir=projectRoot+"_整理前备份_20261123";
if isfolder(baselineDir)
    compare_old_uc(projectRoot);
else
    fprintf('三人UC分析完成。未找到本地整理前备份，本次跳过历史复现核对；已发布的核对证据保留在output中。\n');
end
end

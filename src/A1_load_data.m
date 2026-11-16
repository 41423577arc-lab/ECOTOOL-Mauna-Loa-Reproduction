%% A1-1 读取数据文件
clear; close all; clc

dataFile = fullfile('data','dataPLOSpaper.mat');
whos ('-file',dataFile)

S = load(dataFile);
fieldnames(S)

x_all = S.CO2;
size(x_all)

%% A1-2 数据质量检查
sum(isnan(x_all))
min(x_all), max(x_all)

%% A1-3 建立时间轴并核对
n = size(x_all,1);
t_all = datetime(1958,3,1) + calmonths((0:n-1)');

t_all(1)
t_all(end)
t_all([1 25 504 505 end])

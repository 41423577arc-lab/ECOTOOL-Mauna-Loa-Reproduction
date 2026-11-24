function cancelbutton

h= findall(0, 'name', 'Estimation in process. Please wait .....');
data= get(h, 'userdata');
data{1}(1)= 1;
set(h, 'userdata', data);
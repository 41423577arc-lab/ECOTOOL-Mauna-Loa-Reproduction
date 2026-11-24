function [A, B, C]= poly2armax(polysnum)
% Conversion from structure to ARMAX model
%    A(B) y(t)= B1(B) u1(t) + B2 (B) u2(t)  + ... + C(B) a(t)
%    {A, C, B1, B2, ...}

% Copyright (C) 2018 Diego J. Pedregal. All rights reserved.
%
% This file is part of ECOTOOL.
% 
% ECOTOOL is free software: you can redistribute it and/or modify
% 
% ECOTOOL is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  


N= size(polysnum, 1);
polys= num2cell(ones(1, N));
A= polysnum{1 ,2};
conjpolys1= 1;
% Polynomial A
for i= 1 : N
   if length(polysnum{1, 2})== length(polysnum{i, 2})
       if sum(polysnum{1, 2}-polysnum{i, 2})~= 0
           A= conv(A, polysnum{i, 2});
           conjpolys1= conv(conjpolys1, polysnum{i, 2});
       end
   else
       A= conv(A, polysnum{i, 2});
       conjpolys1= conv(conjpolys1, polysnum{i, 2});
   end
end
% Polynomial B
for i= 1 : N
   if length(polysnum{1, 2})== length(polysnum{i, 2})
       if sum(polysnum{1, 2}-polysnum{i, 2})== 0
           polys{i}= conv(conjpolys1, polysnum{i, 1});
       else
           polys{i}= conv(polysnum{1, 2}, polysnum{i, 1});
       end
   else
       polys{i}= conv(polysnum{1, 2}, polysnum{i, 1});
   end
end
% Polynomial C
C= polys{1};
% C= conv(polysnum{1, 2}, conjpolys1);
B= [];
N= size(polys, 2);
if N> 1
   orderB= zeros(N - 1, 1);
   for i= 2 : N, orderB(i - 1)= size(polys{i}, 2); end
   B= zeros(N-1, max(orderB));
   for i= 2 : N, B(i - 1, 1:orderB(i - 1))= polys{i}; end
end
% for i= 2 : N+1
%     for j= 1 : N
%         if j~= i-1; polys{i}= conv(polys{i}, polysnum{j, 2}); end
%     end
% end
% N= size(polysnum, 1);
% polys= num2cell(ones(1, N + 1));
% for i= 1 : N
%    polys{i + 1}= polysnum{i, 1};
%    polys{1}= conv(polys{1}, polysnum{i, 2});
% end
% for i= 2 : N+1
%     for j= 1 : N
%         if j~= i-1; polys{i}= conv(polys{i}, polysnum{j, 2}); end
%     end
% end
% 
% A= polys{1};
% C= polys{2};
% B= [];
% N= size(polys, 2);
% if N> 2
%    orderB= zeros(N - 2, 1);
%    for i= 3 : N, orderB(i - 2)= size(polys{i}, 2); end
%    B= zeros(N-2, max(orderB));
%    for i= 3 : N, B(i - 2, 1:orderB(i - 2))= polys{i}; end
% end
% End function poly2armax
module signals(s1,s2,s3,s4,s5,s6,s7,b1,b2,p1,p2,p3,p4,p5,p6,p7,p8,p9,clk);
input s1;
input s2;
input s3;
input s4;
input s5;
input s6;
input s7;
input b1;
input b2;
input clk;
output reg p1;
output reg p2;
output reg p3;
output reg p4;
output reg p5;
output reg p6;
output reg p7;
output reg p8;
output reg p9;
reg initialise=1;
always @(posedge clk)
begin
	if(initialise)
	begin
		p1<=0;
		p2<=0;
		p3<=0;
		p4<=0;
		p5<=0;
		p6<=0;
		p7<=0;
		p8<=0;
		p9<=0;
		initialise=0;
	end
	if(s1)
		p1<=1;
	else
		p1<=0;
	if(s2)
		p2<=1;
	else
		p2<=0;
	if(s3)
		p3<=1;
	else 
		p3<=0;
	if(s4)
		p4<=1;
	else 
		p4<=0;
	if(s5)
		p5<=1;
	else
		p5<=0;
	if(s6)
		p6<=1;
	else 
		p6<=0;
	if(s7)
		p7<=1;
	else 
		p7<=0;
	if(b1==0)
		p8<=1;
	else
		p8<=0;
	if(b2==0)
		p9<=1;
	else
		p9<=0;
end
endmodule

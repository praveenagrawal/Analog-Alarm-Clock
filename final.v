module final(
	input wire clk,			//pixel clock: 25MHz
	input wire clrb,			//asynchronous reset
	input wire alarm_up,
	input wire alarm_down,
	input wire min_up,
	input wire min_down,
	input wire hour_up,
	input wire hour_down,
	input wire alarm_on,
	input wire theme,      //signal to change the clock theme
	input wire snooze,    //to enable snooze timer
	
	output wire hsync,		//horizontal sync out
	output wire vsync,		//vertical sync out
	output reg r,	//red vga output
	output reg g, //green vga output
	output reg b,//blue vga output
	output reg buzzer //to ring the buzzer
	);

// video structure constants
parameter hpixels = 800;// horizontal pixels per line
parameter vlines = 525; // vertical lines per frame
parameter hpulse = 96; 	// hsync pulse length
parameter vpulse = 2; 	// vsync pulse length
parameter hbp = 144; 	// end of horizontal back porch
parameter hfp = 784; 	// beginning of horizontal front porch
parameter vbp = 35; 		// end of vertical back porch
parameter vfp = 515; 	// beginning of vertical front porch
parameter x0=320; //center
parameter y0=240;  //center
parameter rad=160;
// active horizontal video is therefore: 784 - 144 = 640
// active vertical video is therefore: 515 - 35 = 480

// registers for storing the horizontal & vertical counters
reg [9:0] hc;
reg [9:0] vc;
reg clkout;
reg dclk;
reg [9:0] x;
reg [9:0] y;
reg [31:0] count;
reg [5:0] second;
reg [5:0] minute;
reg [3:0] hour;
reg [5:0] hourhand;
reg [5:0] alarm;
reg [3:0] a1; //for alarm's hand
reg [3:0] a2;
reg [3:0] m1; // for slope of second's line
reg [3:0] m2; // m1 * (y-y0)=m2 * (x-x0)
reg [3:0] slope1; //for slope of minute's hand line
reg [3:0] slope2;
reg [3:0] h1; // for slope of hour's hand
reg [3:0] h2;
reg [2:0] blackc= 3'b000;
reg [2:0] redc= 3'b100;
reg [2:0] bluec= 3'b001;
reg [2:0] greenc= 3'b010;
reg [2:0] whitec= 3'b111;
reg [2:0] yellowc= 3'b110;
reg [2:0] cyanc=3'b011;
reg [2:0] magentac=3'b101;
reg [2:0] ac; //alarm hand's colour
reg [2:0] mc; //minute hand's colour
reg [2:0] sc; //second hand's colour
reg [2:0] hhc; //hour hand's colour
reg [2:0] cc; //clock's inside colour
reg [2:0] bc; //clock's border colour
reg [2:0] backc; //background colour
reg [2:0] rc; //colour to show alarm ringing
reg setting_time; 
reg initialise=1;
reg check; //to put a condition on moving hour's hand once in every twelve minutes
reg delay;
reg delay1;
reg ring;
reg [3:0] theme_num; //to change the theme
reg theme_check;
reg [31:0] theme_delay;
reg [5:0] alarm_timer;
reg [5:0] snooze_timer;
reg stop; //to stop the alarm automatically after somet fixed time
reg begin_snooze_timer; //to give a signal to begin snooze timer
reg [31:0] alarm_counter;//to keep count for the snooze and alarm timers
reg [31:0] snooze_counter;
// Horizontal & vertical counters --
// this is how we keep track of where we are on the screen.
// ------------------------
// Sequential "always block", which is a block that is
// only triggered on signal transitions or "edges".
// posedge = rising edge  &  negedge = falling edge
// Assignment statements can only be used on type "reg" and need to be of the "non-blocking" type: <=

initial begin dclk=0; end
always @(posedge clk)
begin
	dclk<=~dclk;
end

always @(posedge dclk)
begin
	if(clrb==0 || initialise)
	begin
		theme_num<=0;
		theme_check<=0;
		theme_delay<=0;
	end
	if(theme && theme_check==0)
	begin
		theme_num<=theme_num+1;
		theme_check<=1;
	end
	theme_delay<=theme_delay+1;
	if(theme_delay==50000000)
	begin
		theme_check<=0;
		theme_delay<=0;
	end
	if(theme_num==8)
		theme_num<=0;
end

always @(posedge dclk)
begin
	if(theme_num==0)
		{ac,mc,sc,hhc,cc,bc,backc,rc}<={yellowc,bluec,bluec,bluec,blackc,redc,whitec,redc};
	else if(theme_num==1)
		{ac,mc,sc,hhc,cc,bc,backc,rc}<={yellowc,redc,redc,redc,blackc,redc,blackc,yellowc};
	else if(theme_num==2)
		{ac,mc,sc,hhc,cc,bc,backc,rc}<={blackc,whitec,whitec,whitec,redc,whitec,redc, whitec};
	else if(theme_num==3)
		{ac,mc,sc,hhc,cc,bc,backc,rc}<={redc,blackc,blackc,blackc,whitec,blackc,whitec,redc};
	else if(theme_num==4)
		{ac,mc,sc,hhc,cc,bc,backc,rc}<={redc,whitec,whitec,whitec,cyanc,whitec,cyanc,whitec};
	else if(theme_num==5)
		{ac,mc,sc,hhc,cc,bc,backc,rc}<={yellowc,redc,bluec,redc,blackc,greenc,whitec,greenc};
	else if(theme_num==6)
		{ac,mc,sc,hhc,cc,bc,backc,rc}<={redc,greenc,greenc,greenc,whitec,greenc,whitec,greenc};
	else if(theme_num==7)
		{ac,mc,sc,hhc,cc,bc,backc,rc}<={redc,whitec,whitec,whitec,greenc,whitec,greenc,whitec};
end

always @(posedge dclk)
begin
	if(clrb==0 || initialise==1)
	begin
		count<=0;
		second<=0;
		minute<=10;
		hour<=0;
		hourhand<=50;
		check<=0;
		alarm<=30;
		delay<=0;
		setting_time<=0;
		initialise<=0;
	end
	if(hour_up || hour_down || min_up || min_down)
		setting_time<=1;
	else
		setting_time<=0;
	if(alarm_up==1 && delay1==1 && alarm!=59)
	begin
		alarm<=alarm+1;
		delay1<=0;
	end
	else
	if(alarm_up==1 && delay1==1 && alarm==59)
	begin
		alarm<=0;
		delay1<=0;
	end
	if(alarm_down==1 && delay1==1 && alarm!=0)
	begin
		alarm<=alarm-1;
		delay1<=0;
	end
	if(alarm_down==1 && delay1==1 && alarm==0)
	begin
		alarm<=59;
		delay1<=0;
	end
	else if(min_up==1 && delay==1)
	begin
		minute<=minute+1;
		delay<=0;
		check<=0;
	end
	if(min_down==1 && delay==1 && minute!=0)
	begin
		minute<=minute-1;
		delay<=0;
		check<=0;
	end
	if(min_down==1 && delay==1 && minute==0)
	begin
		minute<=59;
		delay<=0;
		check<=0;
	end
	else if(hour_up==1 && delay1==1)
	begin
		hourhand<=hourhand+1;
		delay1<=0;
	end
	if(hour_down==1 && delay1==1 && hourhand!=0)
	begin
		hourhand<=hourhand-1;
		delay1<=0;
	end
	else if(hour_down==1 && delay1==1 && hourhand==0)
	begin
		hourhand<=59;
		delay1<=0;
	end
	//if(count==6250000 ||count==12500000 || count==18750000 || count==25000000)
	if(count%1000000==0)
		delay<=1;
	if(count%12500000==0)
		delay1<=1;
	if(count==25000000)
	begin
		if(setting_time==0)
			second<=second+1;
		count<=0;
	end
	else
	begin
		count<=count+1;
	end
	if(second==60)
	begin
		second<=0;
		minute<=minute+1;
		check<=0;
	end
	if(minute==60)
	begin
		minute<=0;
		hour<=hour+1;
	end
	if(hour==12)
	begin
		hour<=0;
	end
	if((minute%12==0)&& (check==0) && (minute!=0) && (setting_time==0))
	begin
		check<=1;
		hourhand<=hourhand+1;
	end
	else if((minute%12==0)&& (check==0) && (minute!=0) && (setting_time==1) && min_up)
	begin
		check<=1;
		hourhand<=hourhand+1;
	end
	else if((minute%12==0 || minute==59)&& (check==0) && (minute!=0) && (setting_time==1) && min_down)
	begin
		check<=1;
		hourhand<=hourhand-1;
	end
	if(hourhand==60)
	begin
		hourhand<=0;
	end
end

always @(posedge dclk)
begin
	if(initialise)
	begin
		alarm_timer<=0;
		snooze_timer<=0;
		stop<=0;
		begin_snooze_timer<=0;
		alarm_counter<=0;
		ring<=0;
	end
	alarm_counter<=alarm_counter+1;
	snooze_counter<=snooze_counter+1;
	if(alarm==hourhand && alarm_on==1 && stop==0)
	begin
		ring<=1;
		if(alarm_counter==25000000)
		begin
			alarm_timer<=alarm_timer+1;
			alarm_counter<=0;
		end
	end
	else
	begin
		ring<=0;
		alarm_timer<=0;
	end
	if(alarm_timer==30 && begin_snooze_timer==0)
		stop<=1;
	else if(snooze)
	begin
		begin_snooze_timer<=1;
		stop<=1;
		alarm_counter<=0;
	end
	else
	begin
	end
	if(begin_snooze_timer)
	begin
		if(snooze_counter==25000000)
		begin
			snooze_timer<=snooze_timer+1;
			snooze_counter<=0;
		end
	end
	if(snooze_timer==30)
	begin
		stop<=0;
		begin_snooze_timer<=0;
		snooze_timer<=0;
	end
	if(alarm_on==0)
	begin
		stop<=0;
	end
end

always @(posedge dclk)
begin
if (initialise)
	buzzer<=0;
if(ring && second[0])
	buzzer<=1;
else
buzzer<=0;
end

always @(posedge clk)
begin
	if ((alarm==0) || (alarm==30))
	begin
		a1=0;
		a2=1;
	end
	if ((alarm==1) || (alarm==29) || (alarm==31) || (alarm==59)) //tan(84)=9.514
	begin
		a1=1; //1000
		a2=9; //9514
	end
	if ((alarm==2) || (alarm==28) || (alarm==32) || (alarm==58)) //tan(78)=4.704
	begin
		a1=1; //1000
		a2=5; //4704
	end
	if (alarm==3 || (alarm==27) || (alarm==33) || (alarm==57)) //tan(72)=3.077
	begin
		a1=1; //1000
		a2=3; //3077
	end
	if (alarm==4 || (alarm==26) || (alarm==34) || (alarm==56)) //tan(66)=2.246
	begin
		a1=2; //1000
		a2=5; //2246
	end
	if (alarm==5 || (alarm==25) || (alarm==35) || (alarm==55)) //tan(60)=1.732
	begin
		a1=4; //1000
		a2=7;  //1732
	end
	if (alarm==6 || (alarm==24) || (alarm==36) || (alarm==54)) //tan(54)=1.376
	begin
		a1=5;  //1000
		a2=7;  //1376
	end
	if (alarm==7 || (alarm==23) || (alarm==37) || (alarm==53)) //tan(48)=1.1106
	begin
		a1=5; //10000
		a2=6; //11106
	end
	if (alarm==8 || (alarm==22) || (alarm==38) || (alarm==52)) //tan(42)=0.9004
	begin
		a1=10; //10000
		a2=9; //9004
	end
	if (alarm==9 || (alarm==21) || (alarm==39) || (alarm==51))  //tan(36)=0.7265
	begin
		a1=10; //10000
		a2=7; //7265
	end
	if (alarm==10 || (alarm==20) || (alarm==40) || (alarm==50)) //tan(30)=0.5773
	begin
		a1=5; //10000
		a2=3;  //5773
	end
	if (alarm==11 || (alarm==19) || (alarm==41) || (alarm==49)) //tan(24)=0.4452
	begin
		a1=10;  //10000
		a2=4;  //4452
	end
	if (alarm==12 || (alarm==18) || (alarm==42) || (alarm==48)) //tan(18)=0.3249
	begin
		a1=10;  //10000
		a2=3; //3249
	end
	if (alarm==13 || (alarm==17) || (alarm==43) || (alarm==47)) //tan(12)=0.2125
	begin
		a1=10; //10000
		a2=2; //2125
	end
	if (alarm==14 || (alarm==16) || (alarm==44) || (alarm==46)) //tan(6)=0.1051
	begin
		a1=10; //10000
		a2=1; //1051
	end
	if ((alarm==15) || (alarm==45)) //tan(0)=0
	begin
		a1=1;
		a2=0;
	end
end


always @(posedge clk)
begin
	if ((second==0) || (second==30))
	begin
		m1=0;
		m2=1;
	end
	if ((second==1) || (second==29) || (second==31) || (second==59)) //tan(84)=9.514
	begin
		m1=1; //1000
		m2=9; //9514
	end
	if ((second==2) || (second==28) || (second==32) || (second==58)) //tan(78)=4.704
	begin
		m1=1; //1000
		m2=5; //4704
	end
	if (second==3 || (second==27) || (second==33) || (second==57)) //tan(72)=3.077
	begin
		m1=1; //1000
		m2=3; //3077
	end
	if (second==4 || (second==26) || (second==34) || (second==56)) //tan(66)=2.246
	begin
		m1=2; //1000
		m2=5; //2246
	end
	if (second==5 || (second==25) || (second==35) || (second==55)) //tan(60)=1.732
	begin
		m1=4; //1000
		m2=7;  //1732
	end
	if (second==6 || (second==24) || (second==36) || (second==54)) //tan(54)=1.376
	begin
		m1=5;  //1000
		m2=7;  //1376
	end
	if (second==7 || (second==23) || (second==37) || (second==53)) //tan(48)=1.1106
	begin
		m1=5; //10000
		m2=6; //11106
	end
	if (second==8 || (second==22) || (second==38) || (second==52)) //tan(42)=0.9004
	begin
		m1=10; //10000
		m2=9; //9004
	end
	if (second==9 || (second==21) || (second==39) || (second==51))  //tan(36)=0.7265
	begin
		m1=10; //10000
		m2=7; //7265
	end
	if (second==10 || (second==20) || (second==40) || (second==50)) //tan(30)=0.5773
	begin
		m1=5; //10000
		m2=3;  //5773
	end
	if (second==11 || (second==19) || (second==41) || (second==49)) //tan(24)=0.4452
	begin
		m1=5;  //10000
		m2=2;  //4452
	end
	if (second==12 || (second==18) || (second==42) || (second==48)) //tan(18)=0.3249
	begin
		m1=10;  //10000
		m2=3; //3249
	end
	if (second==13 || (second==17) || (second==43) || (second==47)) //tan(12)=0.2125
	begin
		m1=10; //10000
		m2=2; //2125
	end
	if (second==14 || (second==16) || (second==44) || (second==46)) //tan(6)=0.1051
	begin
		m1=10; //10000
		m2=1; //1051
	end
	if ((second==15) || (second==45)) //tan(0)=0
	begin
		m1=1;
		m2=0;
	end
	
end

always @(posedge clk)
begin
	if ((minute==0) || (minute==30))
	begin
		slope1=0;
		slope2=1;
	end
	if ((minute==1) || (minute==29) || (minute==31) || (minute==59)) //tan(84)=9.514
	begin
		slope1=1; //1000
		slope2=9; //9514
	end
	if ((minute==2) || (minute==28) || (minute==32) || (minute==58)) //tan(78)=4.704
	begin
		slope1=1; //1000
		slope2=5; //4704
	end
	if (minute==3 || (minute==27) || (minute==33) || (minute==57)) //tan(72)=3.077
	begin
		slope1=1; //1000
		slope2=3; //3077
	end
	if (minute==4 || (minute==26) || (minute==34) || (minute==56)) //tan(66)=2.246
	begin
		slope1=2; //1000
		slope2=5; //2246
	end
	if (minute==5 || (minute==25) || (minute==35) || (minute==55)) //tan(60)=1.732
	begin
		slope1=4; //1000
		slope2=7;  //1732
	end
	if (minute==6 || (minute==24) || (minute==36) || (minute==54)) //tan(54)=1.376
	begin
		slope1=5;  //1000
		slope2=7;  //1376
	end
	if (minute==7 || (minute==23) || (minute==37) || (minute==53)) //tan(48)=1.1106
	begin
		slope1=5; //10000
		slope2=6; //11106
	end
	if (minute==8 || (minute==22) || (minute==38) || (minute==52)) //tan(42)=0.9004
	begin
		slope1=10; //10000
		slope2=9; //9004
	end
	if (minute==9 || (minute==21) || (minute==39) || (minute==51))  //tan(36)=0.7265
	begin
		slope1=10; //10000
		slope2=7; //7265
	end
	if (minute==10 || (minute==20) || (minute==40) || (minute==50)) //tan(30)=0.5773
	begin
		slope1=5; //10000
		slope2=3;  //5773
	end
	if (minute==11 || (minute==19) || (minute==41) || (minute==49)) //tan(24)=0.4452
	begin
		slope1=10;  //10000
		slope2=4;  //4452
	end
	if (minute==12 || (minute==18) || (minute==42) || (minute==48)) //tan(18)=0.3249
	begin
		slope1=10;  //10000
		slope2=3; //3249
	end
	if (minute==13 || (minute==17) || (minute==43) || (minute==47)) //tan(12)=0.2125
	begin
		slope1=10; //10000
		slope2=2; //2125
	end
	if (minute==14 || (minute==16) || (minute==44) || (minute==46)) //tan(6)=0.1051
	begin
		slope1=10; //10000
		slope2=1; //1051
	end
	if ((minute==15) || (minute==45)) //tan(0)=0
	begin
		slope1=1;
		slope2=0;
	end
	
end

always @(posedge clk)
begin
	if ((hourhand==0) || (hourhand==30))
	begin
		h1=0;
		h2=1;
	end
	if ((hourhand==1) || (hourhand==29) || (hourhand==31) || (hourhand==59)) //tan(84)=9.514
	begin
		h1=1; //1000
		h2=9; //9514
	end
	if ((hourhand==2) || (hourhand==28) || (hourhand==32) || (hourhand==58)) //tan(78)=4.704
	begin
		h1=1; //1000
		h2=5; //4704
	end
	if (hourhand==3 || (hourhand==27) || (hourhand==33) || (hourhand==57)) //tan(72)=3.077
	begin
		h1=1; //1000
		h2=3; //3077
	end
	if (hourhand==4 || (hourhand==26) || (hourhand==34) || (hourhand==56)) //tan(66)=2.246
	begin
		h1=2; //1000
		h2=5; //2246
	end
	if (hourhand==5 || (hourhand==25) || (hourhand==35) || (hourhand==55)) //tan(60)=1.732
	begin
		h1=4; //1000
		h2=7;  //1732
	end
	if (hourhand==6 || (hourhand==24) || (hourhand==36) || (hourhand==54)) //tan(54)=1.376
	begin
		h1=5;  //1000
		h2=7;  //1376
	end
	if (hourhand==7 || (hourhand==23) || (hourhand==37) || (hourhand==53)) //tan(48)=1.1106
	begin
		h1=5; //10000
		h2=6; //11106
	end
	if (hourhand==8 || (hourhand==22) || (hourhand==38) || (hourhand==52)) //tan(42)=0.9004
	begin
		h1=10; //10000
		h2=9; //9004
	end
	if (hourhand==9 || (hourhand==21) || (hourhand==39) || (hourhand==51))  //tan(36)=0.7265
	begin
		h1=10; //10000
		h2=7; //7265
	end
	if (hourhand==10 || (hourhand==20) || (hourhand==40) || (hourhand==50)) //tan(30)=0.5773
	begin
		h1=5; //10000
		h2=3;  //5773
	end
	if (hourhand==11 || (hourhand==19) || (hourhand==41) || (hourhand==49)) //tan(24)=0.4452
	begin
		h1=10;  //10000
		h2=4;  //4452
	end
	if (hourhand==12 || (hourhand==18) || (hourhand==42) || (hourhand==48)) //tan(18)=0.3249
	begin
		h1=10;  //10000
		h2=3; //3249
	end
	if (hourhand==13 || (hourhand==17) || (hourhand==43) || (hourhand==47)) //tan(12)=0.2125
	begin
		h1=10; //10000
		h2=2; //2125
	end
	if (hourhand==14 || (hourhand==16) || (hourhand==44) || (hourhand==46)) //tan(6)=0.1051
	begin
		h1=10; //10000
		h2=1; //1051
	end
	if ((hourhand==15) || (hourhand==45)) //tan(0)=0
	begin
		h1=1;
		h2=0;
	end
end

always @(posedge dclk or negedge clrb)
begin
	// reset condition
	if (clrb == 0)
	begin
		hc <= 0;
		vc <= 0;
	end
	else
	begin
		// keep counting until the end of the line
		if (hc < hpixels - 1)
			hc <= hc + 1;
		else
		// When we hit the end of the line, reset the horizontal
		// counter and increment the vertical counter.
		// If vertical counter is at the end of the frame, then
		// reset that one too.
		begin
			hc <= 0;
			if (vc < vlines - 1)
				vc <= vc + 1;
			else
				vc <= 0;
		end
		
	end
end

// "assign" statements are a quick way to
// give values to variables of type: wire
assign hsync = (hc < hpulse) ? 0:1;
assign vsync = (vc < vpulse) ? 0:1;
// Assignment statements can only be used on type "reg" and should be of the "blocking" type: =

always @(*)
begin
			// first check if we're within vertical active video range
			x<=hc-hbp;
			y<=vc-vbp;
			{r,g,b}=blackc;
			if (vc >= vbp && vc < vfp)
			begin		
					if(hc>=(hfp) || (hc<=hbp))
					begin
							{r,g,b}<=blackc;
					end
					else if(hc>hbp)
					begin
					{r,g,b}=cc;
					if(((x-x0)*(x-x0))+((y-y0)*(y-y0))<=((rad+5)*(rad+5)))
					begin
						if(((x-x0)*(x-x0))+((y-y0)*(y-y0))<=(rad*rad))
						begin
								if(((x-x0)*(x-x0))+((y-y0)*(y-y0))<=((rad-10)*(rad-10)))
								begin
									if(((a1*(y-y0))+(a2*(x-x0)))==0)
									begin
										if((x>=x0)&&(y<=y0) && alarm==0)
											{r,g,b}<=ac;
										if((x<=x0)&&(y>=y0) && alarm==45)
											{r,g,b}<=ac;
									end
									if((((a1*(y-y0))+(a2*(x-x0)))<=4)) //eqn of line
									begin
											if((alarm>0) && (alarm<=15))
											begin
													if((x>=x0)&&(y<=y0))
														{r,g,b}<=ac;
											end
											else if((alarm>=30) && (alarm<45))
											begin
													if((x<=x0)&&(y>=y0))
															{r,g,b}<=ac;
											end
									end
									else if(((((a1*(y-y0))-(a2*(x-x0)))<=4))) //eqn of line
									begin
											if((alarm>15) && (alarm<30))
											begin
													if((x>x0)&&(y>=y0))
													begin
															{r,g,b}<=ac;
													end				
											end
											else if((alarm>45) && (alarm<60))
											begin
													if((x<=x0)&&(y<y0))
													begin
															{r,g,b}<=ac;
													end				
											end
									end
								end
								if(((x-x0)*(x-x0))+((y-y0)*(y-y0))<=((rad-10)*(rad-10)))
								begin
									if((((m1*(y-y0))+(m2*(x-x0)))==0)) //eqn of line
									begin
										if((x>=x0)&&(y<=y0) && second==0)
											{r,g,b}<=sc;
										if((x<=x0)&&(y>=y0) && second==45)
											{r,g,b}<=sc;
									end
									if((((m1*(y-y0))+(m2*(x-x0)))<=5)) //eqn of line
									begin
											if((second>0) && (second<=15))
											begin
													if((x>=x0)&&(y<=y0))
															{r,g,b}<=sc;
											end
											else if((second>=30) && (second<45))
											begin
													if((x<=x0)&&(y>=y0))
															{r,g,b}<=sc;
											end
									end
									else if(((((m1*(y-y0))-(m2*(x-x0)))<=5))) //eqn of line
									begin
											if((second>15) && (second<30))
											begin
													if((x>x0)&&(y>=y0))
															{r,g,b}<=sc;
											end
											else if((second>45) && (second<60))
											begin
													if((x<=x0)&&(y<y0))
															{r,g,b}<=sc;
											end
									end
								end
								if(((x-x0)*(x-x0))+((y-y0)*(y-y0))<=((rad-10)*(rad-10)))
								begin
									if((((slope1*(y-y0))+(slope2*(x-x0)))==0)) //eqn of line
									begin
										if((x>=x0)&&(y<=y0) && minute==0)
											{r,g,b}<=mc;
										if((x<=x0)&&(y>=y0) && minute==45)
											{r,g,b}<=mc;
									end
									if((((slope1*(y-y0))+(slope2*(x-x0)))<=5)) //eqn of line
									begin
											if((minute>0) && (minute<=15))
											begin
													if((x>=x0)&&(y<=y0))
														{r,g,b}<=mc;
											end
											else if((minute>=30) && (minute<45))
											begin
													if((x<=x0)&&(y>=y0))
														{r,g,b}<=mc;
											end
									end
									else if(((((slope1*(y-y0))-(slope2*(x-x0)))<=5))) //eqn of line
									begin
											if((minute>15) && (minute<30))
											begin
													if((x>x0)&&(y>=y0))
															{r,g,b}<=mc;
											end
											else if((minute>45) && (minute<60))
											begin
													if((x<=x0)&&(y<y0))
															{r,g,b}<=mc;
											end
									end
								end
								if(((x-x0)*(x-x0))+((y-y0)*(y-y0))<=((rad-50)*(rad-50)))
								begin
									if((((h1*(y-y0))+(h2*(x-x0)))<=1)) //eqn of line
									begin
										if((x>=x0)&&(y<=y0) && hourhand==0)
											{r,g,b}<=hhc;
										if((x<=x0)&&(y>=y0) && hourhand==45)
											{r,g,b}<=hhc;
									end
									if((((h1*(y-y0))+(h2*(x-x0)))<=10)) //eqn of line
									begin
											if((hourhand>0) && (hourhand<=15))
											begin
													if((x>=x0)&&(y<=y0))
															{r,g,b}<=hhc;
											end
											else if((hourhand>=30) && (hourhand<45))
											begin
													if((x<=x0)&&(y>=y0))
															{r,g,b}<=hhc;
											end
									end
									else if(((((h1*(y-y0))-(h2*(x-x0)))<=10))) //eqn of line
									begin
											if((hourhand>15) && (hourhand<30))
											begin
													if((x>x0)&&(y>=y0))
															{r,g,b}<=hhc;
											end
											else if((hourhand>45) && (hourhand<60))
											begin
													if((x<=x0)&&(y<y0))
															{r,g,b}<=hhc;
											end
									end
								end														
								if(((x-x0)*(x-x0))+((y-y0)*(y-y0))>=((rad-7)*(rad-7)) && 
								((x-x0)*(x-x0))+((y-y0)*(y-y0))<=((rad-2)*(rad-2)))
								begin
												if(((x-x0)==0)||((y-y0)==0)||((((4*(y-y0))+(7*(x-x0)))<=10))
												||((((4*(y-y0))-(7*(x-x0)))<=10))||((((5*(y-y0))+(3*(x-x0)))<=10))
												||((((5*(y-y0))-(3*(x-x0)))<=10)))
												begin
													{r,g,b}<=bc;
												end
								end
								if(((x-x0)*(x-x0))+((y-y0)*(y-y0))<=25)
									{r,g,b}<=hhc;
						end
						else
						begin
								{r,g,b}<=bc;
						end
					end		
					else
					begin
							{r,g,b}<=backc;
					end
					if(((x-x0)*(x-x0))+((y-y0)*(y-y0))>((rad+10)*(rad+10)) && x%60<=2 && y%60<=2)
					begin
						if(buzzer)
								{r,g,b}<=rc;
					end
					if(((x-600)*(x-600))+((y-30)*(y-30))<=(25*25))
					begin
						if(alarm_on==1)
						   {r,g,b}<=redc;
						else
							{r,g,b}<=greenc;
					end
					if(((x-600)*(x-600))+((y-30)*(y-30))>=(25*25)&&((x-600)*(x-600))+((y-30)*(y-30))<=(26*26))
							{r,g,b}<=blackc;
					end
					else
					begin
						{r,g,b}<=blackc;
					end
			end
			// we're outside active vertical range so display black
			else
			begin
					{r,g,b}<=blackc;
			end
end
endmodule

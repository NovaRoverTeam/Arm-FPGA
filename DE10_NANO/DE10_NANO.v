
//=======================================================
//  This code is generated by Terasic System Builder
//=======================================================

module DE10_NANO(

	//////////// ADC //////////
	output		          		ADC_CONVST,
	output		          		ADC_SCK,
	output		          		ADC_SDI,
	input 		          		ADC_SDO,

	//////////// ARDUINO //////////
	inout 		    [15:0]		ARDUINO_IO,
	inout 		          		ARDUINO_RESET_N,

	//////////// CLOCK //////////
	input 		          		FPGA_CLK1_50,
	input 		          		FPGA_CLK2_50,
	input 		          		FPGA_CLK3_50,

	//////////// HDMI //////////
	inout 		          		HDMI_I2C_SCL,
	inout 		          		HDMI_I2C_SDA,
	inout 		          		HDMI_I2S,
	inout 		          		HDMI_LRCLK,
	inout 		          		HDMI_MCLK,
	inout 		          		HDMI_SCLK,
	output		          		HDMI_TX_CLK,
	output		          		HDMI_TX_DE,
	output		    [23:0]		HDMI_TX_D,
	output		          		HDMI_TX_HS,
	input 		          		HDMI_TX_INT,
	output		          		HDMI_TX_VS,

	//////////// KEY //////////
	input 		     [1:0]		KEY,

	//////////// LED //////////
	output		     [7:0]		LED,

	//////////// SW //////////
	input 		     [3:0]		SW,

	//////////// GPIO_0, GPIO connect to GPIO Default //////////
	inout 		    [35:0]		GPIO_0,

	//////////// GPIO_1, GPIO connect to GPIO Default //////////
	inout 		    [35:0]		GPIO_1
);



//=======================================================
//  REG/WIRE declarations
//=======================================================

wire lin_act_filtered;
wire lin_act_count;
wire [11:0] lin_act_position;

wire [15:0] lin_act_velocity;
wire lin_act_direction;
wire [15:0] lin_act_duty;

assign LED[7:0] = lin_act_velocity[7:0];	

assign GPIO_1[0] = lin_act_direction;

//=======================================================
//  Structural coding
//=======================================================

digital_filter lin_act_enc (	.iClk(FPGA_CLK1_50),
										.iIn(GPIO_1[35]),
										.oOut(lin_act_filtered));
										
encoder_decoder	lin_act_dec(.iClk(FPGA_CLK1_50),
										.iSignal(lin_act_filtered), 
										.oCount(lin_act_count));										

position_counter lin_act_pos (.iCount(lin_act_count),
										.iDirection(!lin_act_velocity[15]),
										.iRst(!KEY[1]),
										.oPosition(lin_act_position));
										defparam lin_act_pos .width=11;
										defparam lin_act_pos .MAX=1820;


SPI_slave lin_act_com (			.iClk(FPGA_CLK1_50), 
										.iSCK(ARDUINO_IO[13]), 
										.iMOSI(ARDUINO_IO[11]), 
										.oMISO(ARDUINO_IO[12]), 
										.iSSEL(ARDUINO_IO[10]), 
										.oRx(lin_act_velocity),
										.iTx({5'd0,lin_act_position}));
										
speed_decoder lin_act_spd (	.iVelocity(lin_act_velocity),
										.oDirection(lin_act_direction),
										.oDuty(lin_act_duty));
							
PWM lin_act_pwm (	.iClk(FPGA_CLK1_50), 
						.iDuty(lin_act_duty[11:0]),
						.oPwm(GPIO_1[1]));
						defparam lin_act_pwm.frequency = 10000;
						defparam lin_act_pwm.width = 12;
	
endmodule

module speed_decoder(iVelocity, oDirection, oDuty);
	input [15:0] iVelocity;
	output reg oDirection;
	parameter width = 16;
	output reg [width-1:0] oDuty;
	
	always @(iVelocity)
		begin
			if (iVelocity[15]==1)
				begin
					oDirection = 1;
					oDuty = (~(iVelocity-1'b1));
				end
			else 
				begin
					oDirection = 0;
					oDuty = iVelocity;
				end
		end
endmodule

module SPI_slave(iClk, iTx, iSCK, iMOSI, oMISO, iSSEL, oRx);
	input iClk;

	input iSCK, iSSEL, iMOSI;
	input [15:0] iTx;
	output oMISO;

	output reg [15:0] oRx;

	// sync iSCK to the FPGA clock using a 3-bits shift register
	reg [2:0] iSCKr;  always @(posedge iClk) iSCKr <= {iSCKr[1:0], iSCK};
	wire iSCK_risingedge = (iSCKr[2:1]==2'b01);  // now we can detect iSCK rising edges
	wire iSCK_fallingedge = (iSCKr[2:1]==2'b10);  // and falling edges

	// same thing for iSSEL
	reg [2:0] iSSELr;  always @(posedge iClk) iSSELr <= {iSSELr[1:0], iSSEL};
	wire iSSEL_active = ~iSSELr[1];  // iSSEL is active low
	wire iSSEL_startmessage = (iSSELr[2:1]==2'b10);  // message starts at falling edge
	wire iSSEL_endmessage = (iSSELr[2:1]==2'b01);  // message stops at rising edge

	// and for iMOSI
	reg [1:0] iMOSIr;  always @(posedge iClk) iMOSIr <= {iMOSIr[0], iMOSI};
	wire iMOSI_data = iMOSIr[1];

	// we handle SPI in 8-bits format, so we need a 3 bits counter to count the bits as they come in
	reg [3:0] bitcnt;

	reg byte_received;  // high when a byte has been received
	reg [15:0] byte_data_received;

	always @(posedge iClk)
	begin
	  if(~iSSEL_active)
		 bitcnt <= 4'b0000;
	  else
	  if(iSCK_risingedge)
	  begin
		 bitcnt <= bitcnt + 4'b0001;

		 // implement a shift-left register (since we receive the data MSB first)
		 byte_data_received <= {byte_data_received[15:0], iMOSI_data};
	  end
	end

	always @(posedge iClk) byte_received <= iSSEL_active && iSCK_risingedge && (bitcnt==4'b1111);

	// we use the LSB of the data received to control an oRx
	always @(posedge iClk) if(byte_received) oRx <= byte_data_received[15:0];

	reg [15:0] byte_data_sent;

	reg [15:0] cnt;
	always @(posedge iClk) if(iSSEL_startmessage) cnt<=cnt+16'h1;  // count the messages

	always @(posedge iClk)
	if(iSSEL_active)
	begin
	  if(iSSEL_startmessage)
		 byte_data_sent <= iTx;  // first byte sent in a message is the message count
	  else
	  if(iSCK_fallingedge)
	  begin
		 if(bitcnt==4'b0000)
			byte_data_sent <= 16'h0000;  // after that, we send 0s
		 else
			byte_data_sent <= {byte_data_sent[15:0], 1'b0};
	  end
	end

	assign oMISO = (iSSEL_active) ? byte_data_sent[15] : 1'bz;  // send MSB first
	
	
	// we assume that there is only one slave on the SPI bus
	// so we don't bother with a tri-state buffer for oMISO
	// otherwise we would need to tri-state oMISO when iSSEL is inactive

endmodule





module PWM(iClk, iDuty, oPwm);
	input iClk;
	parameter width = 12;
	input [width-1:0] iDuty;
	output reg oPwm = 0;
	
	parameter frequency = 50;
	parameter n = 2**width;
	parameter maxclk = 50000000/frequency;//(frequency*n);
	
	reg [26:0]counter1 = 0;
	
	always @ (posedge iClk)
		begin
			if (counter1 >= maxclk)
				begin
					counter1 <= 0;
				end
			else
				begin
					counter1 <= counter1 + 1;
				end
			
			if (counter1 >= iDuty*maxclk/n)
				begin
					oPwm <= 0;
				end
			else
				begin
					oPwm <= 1;
				end
		end
endmodule

module position_counter(iClk, iDirection, iCount, iRst, oPosition, oSpeed); // Counts position of a joint
	input iClk, iDirection, iCount, iRst;
	parameter width = 13;
	output reg [width-1:0]oPosition = 0;
	output reg [width-1:0]oSpeed;
	
	parameter MAX = 5000;
	//1820 for linear actuator
	
	always @ (posedge iCount or posedge iRst)
		begin
			if (iRst)
				begin
					oPosition <= 0;
				end
			else if ((iDirection == 1) && (oPosition < MAX))
				begin
					oPosition <= oPosition + 1;
				end	
			else if ((oPosition > 0) && (iDirection == 0))
				begin
					oPosition <= oPosition - 1;
				end
		end

endmodule

module quaderature_decoder(iClk, iSignalA, iSignalB, oDirection, oCount);
	input iClk, iSignalA, iSignalB;
	output reg oDirection, oCount;
	
	reg last_SignalA;
	reg last_SignalB;
	
	always @ (posedge iClk)
		begin
			case ({last_SignalA, last_SignalB, iSignalA, iSignalB})
				4'b0001:
					begin
						oDirection <= 1;
						oCount <= 1;
					end
				4'b0010:
					begin
						oDirection <= 0;
						oCount <= 1;
					end
				4'b0100:
					begin
						oDirection <= 0;
						oCount <= 1;
					end
				4'b0111:
					begin
						oDirection <= 1;
						oCount <= 1;
					end
				4'b1000:
					begin
						oDirection <= 1;
						oCount <= 1;
					end
				4'b1011:
					begin
						oDirection <= 0;
						oCount <= 1;
					end
				4'b1110:
					begin
						oDirection <= 1;
						oCount <= 1;
					end
				4'b1101:
					begin
						oDirection = 0;
						oCount <= 1;
					end
				default: 
					begin
						oCount <= 0;
					end
			
			endcase
			last_SignalA <= iSignalA;
			last_SignalB <= iSignalB;
		end
endmodule

module encoder_decoder(iClk, iSignal, oCount); // Single encoder line decoder. Returns a single clock pulse as output on an encoder signal change.
	input iClk, iSignal;
	output reg oCount;
	
	reg last_Signal;
	
	always @ (posedge iClk)
		begin
			if (last_Signal != iSignal)
				begin
					oCount <= 1;
				end
			else
				begin
					oCount <= 0;
				end
			last_Signal <= iSignal;
		end
		
	
endmodule

module digital_filter(iClk, iIn, oOut);		// Filters signal change bounce by making sure the signal hasn't changed for a large number of clock cycles before output changes.
	input iClk, iIn;
	output reg oOut;
	parameter samples = 4095;
	// 511 seemed to fix wrist motor at constant 1V
	
	reg [11:0] count = 0;
	reg last_In;
	
	always @ (posedge iClk)
		begin
			if (last_In != iIn)
				begin
					count = 0;
				end
			else if (last_In == iIn && count < samples)
				begin
					count = count + 1;
				end
			if (count == samples)
				begin
					oOut = iIn;
					count = 0;
				end
			last_In = iIn;
		end
endmodule




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
//reg [7:0] lights = 0;

/*
wire outa;
wire outb;
wire count;
wire count1;
wire direction;
wire [15:0] position;
wire [10:0] position1;



assign GPIO_1[0] = outa;

assign GPIO_1[2] = position[0];


assign GPIO_1[1] = outb;


//assign LED = position [7:0];

assign LED = ARDUINO_IO [15:8];
assign ARDUINO_RESET_N = KEY[0];

//=======================================================
//  Structural coding
//=======================================================

digital_filter fa (	.iClk(FPGA_CLK1_50),
							.iIn(GPIO_1[3]),
							.oOut(outa));
							
digital_filter fb (	.iClk(FPGA_CLK1_50),
							.iIn(GPIO_1[4]),
							.oOut(outb));							
				
encoder_decoder f1 (	.iClk(FPGA_CLK1_50),
							.iSignal(out),
							.oCount(count1));
							
position_counter f2 (.iCount(count1),
							.iDirection(SW[0]),
							.iRst(SW[3]),
							.oPosition(position1));
							defparam f2.width=11;
							defparam f2.MAX=2047;
							
quaderature_decoder f3 (	.iClk(FPGA_CLK1_50),
									.iSignalA(outa),
									.iSignalB(outb),
									.oDirection(direction),
									.oCount(count));
									
position_counter f4 (.iCount(count),
							.iDirection(direction),
							.iRst(!KEY[1]),
							.oPosition(position));
							defparam f4.width=16;
							defparam f4.MAX=65535;
							
						
PWM f5 (	.iClk(FPGA_CLK1_50),
			.iDuty({position,4'b0}),
			.oPwm(GPIO_1[4]));
			defparam f5.frequency = 50;
*/			
SPI_slave f6(.clk(FPGA_CLK1_50), .SCK(ARDUINO_IO[13]), .MOSI(ARDUINO_IO[11]), .MISO(ARDUINO_IO[12]), .SSEL(ARDUINO_IO[10]) , .LED(LED[7:0]));			
							

endmodule


module SPI_slave(clk, SCK, MOSI, MISO, SSEL, LED);
	input clk;

	input SCK, SSEL, MOSI;
	output MISO;

	output [7:0] LED;

	// sync SCK to the FPGA clock using a 3-bits shift register
	reg [2:0] SCKr;  always @(posedge clk) SCKr <= {SCKr[1:0], SCK};
	wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
	wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

	// same thing for SSEL
	reg [2:0] SSELr;  always @(posedge clk) SSELr <= {SSELr[1:0], SSEL};
	wire SSEL_active = ~SSELr[1];  // SSEL is active low
	wire SSEL_startmessage = (SSELr[2:1]==2'b10);  // message starts at falling edge
	wire SSEL_endmessage = (SSELr[2:1]==2'b01);  // message stops at rising edge

	// and for MOSI
	reg [1:0] MOSIr;  always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
	wire MOSI_data = MOSIr[1];

	// we handle SPI in 8-bits format, so we need a 3 bits counter to count the bits as they come in
	reg [2:0] bitcnt;

	reg byte_received;  // high when a byte has been received
	reg [7:0] byte_data_received;

	always @(posedge clk)
	begin
	  if(~SSEL_active)
		 bitcnt <= 3'b000;
	  else
	  if(SCK_risingedge)
	  begin
		 bitcnt <= bitcnt + 3'b001;

		 // implement a shift-left register (since we receive the data MSB first)
		 byte_data_received <= {byte_data_received[6:0], MOSI_data};
	  end
	end

	always @(posedge clk) byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);

	// we use the LSB of the data received to control an LED
	reg [7:0] LED;
	always @(posedge clk) if(byte_received) LED <= byte_data_received;

	reg [7:0] byte_data_sent;

	reg [7:0] cnt;
	always @(posedge clk) if(SSEL_startmessage) cnt<=cnt+8'h1;  // count the messages

	always @(posedge clk)
	if(SSEL_active)
	begin
	  if(SSEL_startmessage)
		 byte_data_sent <= (byte_data_received+1)<<1;  // first byte sent in a message is the message count
	  else
	  if(SCK_fallingedge)
	  begin
		 if(bitcnt==3'b000)
			byte_data_sent <= 8'h00;  // after that, we send 0s
		 else
			byte_data_sent <= {byte_data_sent[6:0], 1'b0};
	  end
	end

	assign MISO = byte_data_sent[7];  // send MSB first
	// we assume that there is only one slave on the SPI bus
	// so we don't bother with a tri-state buffer for MISO
	// otherwise we would need to tri-state MISO when SSEL is inactive

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
					oPwm <= 1;
				end
			else
				begin
					oPwm <= 0;
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



module uart_rx 
	/* BEGIN PARAMETERS LIST */
	#(
		parameter TICKS_PER_BIT = 5208,
		parameter TICKS_PER_BIT_SIZE = 13
	)
	/* END PARAMETERS LIST */ 
	
	/* BEGIN MODULE IO LIST */
	(
		input i_clk,
		input i_enable,
		
		input i_din,

		output wire w_test_led

	);
	/* END MODULE IO LIST */
	
	localparam TICKS_TO_BIT		= TICKS_PER_BIT-1;
	localparam TICKS_TO_MIDLE	= TICKS_TO_BIT/2;


reg o_recvdata;
reg o_busy;

reg [7:0] o_rxdata;

	reg r_test_led;

	assign w_test_led = r_test_led;







	
	reg [7:0] rx_data;
	assign o_rxdata = rx_data;

	reg [4:0] currentState, nextState;

	//Falling edge detection logic
	reg din_buff;
	wire din_negedge_signal = ~i_din & din_buff;
	
	//Counters registers
	reg [3:0] bit_counter;
	reg [TICKS_PER_BIT_SIZE-1:0] bit_ticks_counter;
	
	//Combinational comparator (depends of currentState)
	reg [TICKS_PER_BIT_SIZE-1:0] bit_ticks_comparator;
	
	wire bit_ticks_ovf_signal			= (bit_ticks_counter == bit_ticks_comparator);
	wire bit_counter_ovf_signal 		= (bit_counter[3]); // if equals >= 8

	//Init registers for testbench simulation
	// initial begin
	// 	currentState = STATE_IDLE;
	// 	bit_ticks_counter = 0;
	// 	bit_counter = 0;
	// 	din_buff = 1;
	// 	rx_data = 0;
	// end
	
	localparam	STATE_IDLE			= 5'b00001,
				STATE_RECEIVE_START	= 5'b00010,
				STATE_RECEIVE_DATA	= 5'b00100,
				STATE_RECEIVE_STOP	= 5'b01000,
				STATE_DONE			= 5'b10000;
	
	
	always@(*) begin
		case (currentState)

			default: begin
				nextState = STATE_IDLE;
				o_recvdata = 0;
				o_busy = 0;
				bit_ticks_comparator = TICKS_TO_MIDLE;
			end

			STATE_IDLE: begin 
				o_recvdata = 0;
				o_busy = 0;
				bit_ticks_comparator = TICKS_TO_MIDLE;
				
				if(i_enable)
					if(din_negedge_signal)
						nextState = STATE_RECEIVE_START;
					else 
						nextState = STATE_IDLE;
				else
					nextState = STATE_IDLE;
			end // -- END STATE_IDLE -- 
			
			STATE_RECEIVE_START: begin
				o_recvdata = 0;
				o_busy = 1;
				bit_ticks_comparator = TICKS_TO_MIDLE;

				if(bit_ticks_ovf_signal) begin 
					if(!din_buff)
						nextState = STATE_RECEIVE_DATA;
					else
						nextState = STATE_IDLE;
				end 
				else
					nextState = STATE_RECEIVE_START;
			end // -- END STATE_RECEIVE_START -- 
			
			STATE_RECEIVE_DATA: begin 
				o_recvdata = 0;
				o_busy = 1;
				bit_ticks_comparator = TICKS_TO_BIT;

				if(bit_counter_ovf_signal)
					nextState = STATE_RECEIVE_STOP;
				else
					nextState = STATE_RECEIVE_DATA;
			end // -- END STATE_RECEIVE_DATA -- 
			
			STATE_RECEIVE_STOP: begin
				o_recvdata = 0;
				o_busy = 1;
				bit_ticks_comparator = TICKS_TO_BIT;
				
				if(bit_ticks_ovf_signal)
					nextState = STATE_DONE;
				else
					nextState = STATE_RECEIVE_STOP;
			end // -- END STATE_RECEIVE_STOP --
			
			STATE_DONE: begin 
				o_recvdata = 1;
				o_busy = 1;
				bit_ticks_comparator = TICKS_TO_BIT;
				nextState = STATE_IDLE;
			end // -- END STATE_DONE --
		endcase
	end
	
	always @(posedge i_clk) begin 
		currentState <= nextState;
		din_buff <= i_din;
		
		if(currentState == STATE_IDLE) begin 
			bit_ticks_counter <= 0;
			bit_counter <= 0;
		end
		
		if(	currentState == STATE_RECEIVE_START || 
			currentState == STATE_RECEIVE_DATA	||
			currentState == STATE_RECEIVE_STOP) begin 
			
			if(bit_ticks_ovf_signal)
				bit_ticks_counter <= 0;
			else
				bit_ticks_counter <= bit_ticks_counter + 1;
		end
		
		
		if(currentState == STATE_RECEIVE_DATA) begin 
			if(bit_ticks_ovf_signal) begin
				bit_counter <= bit_counter + 1;
				//rx_data <= { rx_data[6:0], din_buff }; //LSB shift (Not used in this case)
				//rx_data <= { din_buff,  rx_data[7:1] }; //! MSB shift (Used for UART receiver)
				rx_data <= rx_data[7:1]; //* Another way to build a MSB shift register
				rx_data[7] <= din_buff;
			end
		end
	end



	always @(posedge i_clk) begin
		
		if(o_rxdata == 8'hff) begin
			
			r_test_led <= 'd1;
		end

		else begin
			
			r_test_led <= 'd0;
		end

	end





endmodule 

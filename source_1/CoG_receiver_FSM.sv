`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/05/2018 04:46:14 PM
// Design Name: 
// Module Name: CoG_receiver_FSM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module CoG_receiver_FSM#(
  parameter DATA_WIDTH = 8,
  parameter WIDTH      = 1280,
  parameter HEIGHT     = 1024
)(
  input  logic                    i_sys_clk,
  input  logic                    i_sys_aresetn,

  input  logic [2*DATA_WIDTH-1:0] s_axis_tdata,
  input  logic                    s_axis_tvalid,
  input  logic                    s_axis_tuser,
  input  logic                    s_axis_tlast,
  output logic                    s_axis_tready,

  output logic [DATA_WIDTH-1:0]   data_image_reg,
  //output logic [DATA_WIDTH-1:0]   data_mask_reg,
  output logic                    data_valid_reg,

  output logic [10:0]             start_point_reg,
  output logic                    start_of_fig_reg,
  output logic                    end_of_fig_reg,


  //interface to delay and synchronise end_of_line and end_of_frame..
  //..with next module, 
  output logic                    o_end_of_line_reg,
  output logic                    o_end_of_frame_reg,
  output logic                    o_new_frame_reg
  //
  //
  //output logic                    test_signal


);





//SIGNALS
typedef enum logic [2:0] {IDLE, WAITING_FOR_FIG, START_OF_FIG, PROCESSING, END_OF_FIG} statetype;
statetype state, nextstate;

//logic [DATA_WIDTH-1:0] data_image_buffer [0:2];
//logic [DATA_WIDTH-1:0] data_mask_buffer  [0:2];

logic [0:2] [DATA_WIDTH-1:0] data_image_buffer;
logic [0:2] [DATA_WIDTH-1:0] data_mask_buffer;

logic [DATA_WIDTH-1:0] data_image;
logic                  data_valid;

logic [10:0]           start_point;

logic [10:0]           pixel_counter;
logic [10:0]           line_counter;
logic                  end_of_frame;
logic                  end_of_line; 
logic                  new_frame;

logic                  o_end_of_line;
logic                  o_end_of_frame;

logic                  start_of_fig_sig;
logic                  end_of_fig_sig;

logic                  reset_tuser_detector, reset_tuser_detector_reg;
logic                  reset_eol_detector, reset_eol_detector_reg;
logic                  reset_eof_detector, reset_eof_detector_reg;

//without these signals I cant see arrays in sim.... it's so strange
logic dummy1;
logic dummy2;
//
//


////PROCESSES////

//1. show that we're ready to receive pixels
always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin 
    if ( ~i_sys_aresetn ) begin
      s_axis_tready <= 1'b0;
    end else begin
      s_axis_tready <= 1'b1;
    end
end
//
//


//2. grabing pixels from AXIS if they are valid
always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
   if   ( ~i_sys_aresetn ) begin

     data_image_buffer <= '{default:'h00};
     data_mask_buffer  <= '{default:'h00};

   end else begin
     
     //if tvalid - shift right current reg and put new data 
     if ( s_axis_tvalid ) begin

       data_image_buffer <= { s_axis_tdata[DATA_WIDTH-1:0], data_image_buffer[0:1] };
       data_mask_buffer  <= { s_axis_tdata[2*DATA_WIDTH-1:DATA_WIDTH], data_mask_buffer[0:1] };
       
     end	
   end             	
  end
//
//


//3. FSM
//state reg
always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if   ( ~i_sys_aresetn ) state <= IDLE;
    else                    state <= nextstate;	
  end


//data reg
always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if   ( ~i_sys_aresetn ) begin

      data_image_reg           <= 8'h00;
      data_valid_reg           <= 1'b0;
  
      start_point_reg          <= 0;
      start_of_fig_reg         <= 1'b0;
      end_of_fig_reg           <= 1'b0;

      o_end_of_line_reg        <= 1'b0;
      o_end_of_frame_reg       <= 1'b0;
	  o_new_frame_reg          <= 1'b0;

	  reset_tuser_detector_reg <= 1'b0;
	  reset_eol_detector_reg   <= 1'b0;
      reset_eof_detector_reg   <= 1'b0;

    end else begin

      data_image_reg           <=  data_image;
      data_valid_reg           <=  data_valid;

      start_point_reg          <= start_point;
      start_of_fig_reg         <= start_of_fig_sig;
      end_of_fig_reg           <= end_of_fig_sig;

      o_end_of_line_reg        <= o_end_of_line;
      o_end_of_frame_reg       <= o_end_of_frame;
      o_new_frame_reg          <= new_frame;

      reset_tuser_detector_reg <= reset_tuser_detector;
      reset_eol_detector_reg   <= reset_eol_detector;
      reset_eof_detector_reg   <= reset_eof_detector;

    end	
  end


//nextstage logic and output logic
always_comb
  begin
    
    nextstate = state;

    data_image           = data_image_reg;//8'h00;
    data_valid           = 1'b0;

    start_point          = start_point_reg;
    start_of_fig_sig     = 1'b0;
    end_of_fig_sig       = 1'b0;
   
    new_frame            = 1'b0;

    o_end_of_line        = 1'b0;
    o_end_of_frame       = 1'b0;

    reset_tuser_detector = 1'b0;
    reset_eol_detector   = 1'b0;
    reset_eof_detector   = 1'b0;


    case ( state )

      IDLE : begin

      	start_point = 0;
      	data_image  = 8'h00;

        if ( tuser_detected ) begin
        	new_frame            = 1'b1;
        	reset_tuser_detector = 1'b1;
        	nextstate            = WAITING_FOR_FIG;
        end	
      end //IDLE

      WAITING_FOR_FIG : begin
      	//mask is being checked for starting boundary of figure
        //if ( ( data_mask_buffer == {8'hff, 8'hff, 8'h00} ) && ( s_axis_tvalid ) ) begin
        if  ( data_mask_buffer == {8'hff, 8'hff, 8'h00} ) begin

          //this is need if mask {ff,ff,0} stops at the end of line (falling of tvalid):..
          //..two last pixels of line are valid and last but one pixels is start of fig;
          //to prevent crash of FSM we should ignore such points
          if ( eol_detected_reg ) begin
            nextstate         = WAITING_FOR_FIG;

          // normal behaviour for {ff,ff,0} case
          end else if ( s_axis_tvalid ) begin
             data_image       = data_image_buffer[1];
             data_valid       = 1'b1;
          
             //pixel counter adds new value when there is valid t_data, so..
             //..when this data is got in our buffer, pixel counter already has value = pixel_counter + 1
             // As we use data value from buffer[1], we should use value = pixel_counter - 2;

             // ps.it never can start from 0, cause image has blacked lines in the begining bcs of img filters
             start_point      = pixel_counter - 2;
            
             start_of_fig_sig = 1'b1;
             nextstate        = START_OF_FIG;
          end  


        end else begin
        
          // if end_of_line has been detected and we were waiting for new figure..
          //.. reset detector and show that line is finished and continue to wait
          if ( eol_detected_reg ) begin
            o_end_of_line        = 1'b1;
            reset_eol_detector   = 1'b1;
            nextstate            = WAITING_FOR_FIG;
          end
        
          //same situation with end_of_frame, but we should become IDLE..
          //.. to show that's new frame is coming
          if ( eof_detected_reg ) begin
            o_end_of_frame       = 1'b1;
            reset_eof_detector   = 1'b1;
            nextstate            = IDLE;
          end

        end

      end //WAITING_FOR_FIG

      START_OF_FIG : begin
      	if ( s_axis_tvalid ) begin
          
      	  data_image  = data_image_buffer[1];
          data_valid  = 1'b1;

          nextstate   = PROCESSING;
          
          //it's possible that figure has only two pixels..(though it's invalid, we check this futher) 
          //so we're checking that end_of_fig's appeared
          if ( data_mask_buffer == {8'h00, 8'hff, 8'hff} ) begin

               end_of_fig_sig = 1'b1;
               nextstate      = END_OF_FIG;  
          end
        end  	
      end //START_OF_FIG

      PROCESSING : begin
        if ( s_axis_tvalid ) begin	
      	  data_image  = data_image_buffer[1];
          data_valid  = 1'b1;
        end
        
        //IMPORTANT NOTICE: here could be situation, when mask of fig is still valid at last pixel of line..
        //..but we should remember that at a beginning of next line we always have some black pixels..
        //..these invalid black pixels help us to detect the end of fig
        if ( data_mask_buffer == {8'h00, 8'hff, 8'hff} ) begin
               data_image       = data_image_buffer[1];
               data_valid       = 1'b1;

               end_of_fig_sig   = 1'b1;

               if ( eol_detected_reg ) begin
                 o_end_of_line  = 1'b1;
               end

               if ( eof_detected_reg ) begin
                 o_end_of_frame = 1'b1;
               end

               nextstate        = END_OF_FIG; 
        end
          	
      end //PROCESSING

      END_OF_FIG : begin
        if ( o_end_of_frame_reg ) begin
          reset_eof_detector   = 1'b1;
          reset_eol_detector   = 1'b1;	
          nextstate            = IDLE;
        end else begin
          if ( o_end_of_line_reg ) begin
            reset_eol_detector = 1'b1;
          end	
          nextstate            = WAITING_FOR_FIG;
        end	

      end //END_OF_FIG	

      default : nextstate = IDLE;	
    endcase	
	    
  end
//
//

//4. input pixels and lines counter
always @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if ( ~i_sys_aresetn ) begin
      pixel_counter <= 0;
      line_counter  <= 0;
      end_of_line   <= 1'b0;
      end_of_frame  <= 1'b0;

    end else begin
      
      if ( s_axis_tvalid ) begin

        end_of_line  <= 1'b0;
        end_of_frame <= 1'b0;
        
        pixel_counter <= pixel_counter + 1;
               
        if ( pixel_counter == WIDTH - 2 ) begin
          end_of_line   <= 1'b1;

          if ( line_counter == HEIGHT - 1 ) begin
            end_of_frame  <= 1'b1;
          end	   
        end	

      end
      
      //the stuff below is better to do without minding of s_axis_tvalid
      if ( pixel_counter == WIDTH - 1 ) begin
        line_counter <= line_counter + 1;
      end

      if ( end_of_line ) begin
        pixel_counter <= 0;
      end 
      
      if ( end_of_frame ) begin
        line_counter <= 0;
      end   

    end
  end  
//
//



//DETECTORS OF STATUS SIGNALS
//Futher below we have detectors of the beginning of frame (tuser input signal),..
//..the end_of_line and the end_of_frame (from counters)
//We use detectors to save these status signals to use them in a right state of FSM


//TUSER detector
//
//signals
logic tuser_detected;
logic tuser_detected_reg;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if ( ~i_sys_aresetn ) begin
      tuser_detected_reg <= 1'b0;
    end else begin
      tuser_detected_reg <= tuser_detected;
    end   
  end
//
always_comb
  begin

    tuser_detected = tuser_detected_reg;

    if ( tuser_detected_reg ) begin
      if ( reset_tuser_detector_reg ) begin
        tuser_detected = 1'b0;
      end	
    end	else begin
      if ( ( s_axis_tuser ) && ( s_axis_tvalid ) ) begin
        tuser_detected = 1'b1;
      end
    end  

  end
//
//


//END_OF_LINE detector
//
//signals
logic eol_detected;
logic eol_detected_reg;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if ( ~i_sys_aresetn ) begin
      eol_detected_reg <= 1'b0;
    end else begin
      eol_detected_reg <= eol_detected;
    end   
  end
//
always_comb
  begin

    eol_detected = eol_detected_reg;

    if ( eol_detected_reg ) begin
      if ( reset_eol_detector ) begin
        eol_detected = 1'b0;
      end	
    end	else begin
      if ( end_of_line ) begin
        eol_detected = 1'b1;
      end
    end  

  end
//
//


//END_OF_FRAME detector
//
//signals
logic eof_detected;
logic eof_detected_reg;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if ( ~i_sys_aresetn ) begin
      eof_detected_reg <= 1'b0;
    end else begin
      eof_detected_reg <= eof_detected;
    end   
  end
//
always_comb
  begin

    eof_detected = eof_detected_reg;

    if ( eof_detected_reg ) begin
      if ( reset_eof_detector ) begin
        eof_detected = 1'b0;
      end	
    end	else begin
      if ( end_of_frame ) begin
        eof_detected = 1'b1;
      end
    end  

  end
//
//


endmodule  
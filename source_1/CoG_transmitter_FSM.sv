`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/09/2018 05:43:24 PM
// Design Name: 
// Module Name: CoG_transmitter_FSM
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


module CoG_transmitter_FSM#(
  parameter DATA_WIDTH = 8
)(
  input  logic                    i_sys_clk,
  input  logic                    i_sys_aresetn,
  
  input  logic [29:0]             i_sum_of_I_mult_coord,
  input  logic [22:0]             i_sum_of_I,
  input  logic [10:0]             i_start_point,
  input  logic                    i_point_is_valid,

  input  logic                    i_end_of_line_delayed,
  input  logic                    i_end_of_frame_delayed,
  input  logic                    i_new_frame_delayed,         

  output logic [8*DATA_WIDTH-1:0] m_axis_tdata,
  output logic                    m_axis_tvalid,
  output logic                    m_axis_tuser,
  output logic                    m_axis_tlast
  //input  logic                    m_axis_tready

  //output logic                    test
  
);


//DESCRIPTION:
//The main idea of this module to provide calculated points in AXI Stream format.
//We agreed to have maximum 2 valid points per line, so after finding 2 valid points..
//.. FSM stops at TLAST_VALID_POINT and waits for end_of_line_reg.
//Each point goes with one pixel, so the image size is 2xHEIGHT,..
//.. pixel format is 64bit: [10:0] - start_point, [33:11] - sum_of_I, [63:34] - sum_of_I_mult_coord
//FSM always provides 2 points per line: VALID POINT, VALID POINT
//                                       VALID POINT, DUMMY POINT
//                                       DUMMY POINT, DUMMY POINT
//when there is new_frame we rise TUSER with the 1st point,..
//..tlast goes with each last pixel in line.
//
//Also we use detectors of new_frame, eol and eof to use them only in certain states of FSM  

 


//SIGNALS
typedef enum logic [2:0] {IDLE, NEW_FRAME, TUSER_VALID_POINT, WATING_FOR_NEW_POINT, VALID_POINT, TLAST_VALID_POINT, DUMMY_POINT} statetype;
statetype state, nextstate;

logic [8*DATA_WIDTH-1:0] axis_data;
logic                    axis_tvalid;
logic                    axis_tuser;
logic                    axis_tlast;

logic [1:0]              all_valid_points_counter, all_valid_points_counter_reg;
logic [1:0]              only_true_points_counter, only_true_points_counter_reg;

logic                    reset_detector_FSM , reset_detector_FSM_reg;
logic                    reset_nf_detector, reset_nf_detector_reg;

logic nf_detected;
logic nf_detected_reg;

//state reg
always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if   ( ~i_sys_aresetn ) state <= IDLE;
    else                    state <= nextstate;	
  end

//data reg  
always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if ( ~i_sys_aresetn ) begin
      m_axis_tdata                  <= '{ default: 'b0};
      m_axis_tvalid                <= 1'b0;
      m_axis_tuser                 <= 1'b0;
      m_axis_tlast                 <= 1'b0;

      all_valid_points_counter_reg <= 2'h0;
      only_true_points_counter_reg <= 2'h0;
 
      reset_detector_FSM_reg       <= 1'b0;
      reset_nf_detector_reg        <= 1'b0;


    end else begin
      m_axis_tdata                 <= axis_data;
      m_axis_tvalid                <= axis_tvalid;	
      m_axis_tuser                 <= axis_tuser;
      m_axis_tlast                 <= axis_tlast;

      all_valid_points_counter_reg <= all_valid_points_counter;
      only_true_points_counter_reg <= only_true_points_counter;

      reset_detector_FSM_reg       <= reset_detector_FSM;
      reset_nf_detector_reg        <= reset_nf_detector;
    end   


  end

//nextstage logic and output logic

always_comb
  begin

  	nextstate                = state;
  	axis_data                = m_axis_tdata;
  	axis_tvalid              = 1'b0;
  	axis_tuser               = 1'b0;
    axis_tlast               = 1'b0;

    all_valid_points_counter = all_valid_points_counter_reg;
    only_true_points_counter = only_true_points_counter_reg;

    reset_detector_FSM       = 1'b0;
    reset_nf_detector        = 1'b0;

    case ( state )

      IDLE : begin

      	axis_data = 'b0;

        if ( nf_detected ) begin
          reset_nf_detector = 1'b1;
          nextstate         = NEW_FRAME;
        end	
      end //IDLE

      NEW_FRAME : begin

        if ( i_point_is_valid ) begin
          axis_data                = { i_sum_of_I_mult_coord, i_sum_of_I, i_start_point };
          axis_tvalid              = 1'b1;
          axis_tuser               = 1'b1;

          all_valid_points_counter = all_valid_points_counter_reg + 1;
          only_true_points_counter = only_true_points_counter_reg + 1;
          nextstate                = TUSER_VALID_POINT;
        end

        if ( end_of_line_reg ) begin
          axis_data                = 'b0;	
          axis_tvalid              = 1'b1;
          axis_tuser               = 1'b1;

          all_valid_points_counter = all_valid_points_counter_reg + 1;

          nextstate                = DUMMY_POINT;
        end	

      end //NEW_FRAME	
      
      TUSER_VALID_POINT : begin
        nextstate = WATING_FOR_NEW_POINT;
      end //TUSER_VALID_POINT

      WATING_FOR_NEW_POINT : begin

        if ( ( only_true_points_counter_reg == 2'h2 ) && ( end_of_frame_reg ) ) begin
          only_true_points_counter = 2'h0;
          reset_detector_FSM       = 1'b1;
          nextstate                = IDLE;
        end	
      	

      	if ( i_point_is_valid ) begin

          axis_data                = { i_sum_of_I_mult_coord, i_sum_of_I, i_start_point };	
          axis_tvalid              = 1'b1;
           
          all_valid_points_counter = all_valid_points_counter_reg + 1;
          only_true_points_counter = only_true_points_counter_reg + 1;

          nextstate                = VALID_POINT;

          if ( all_valid_points_counter_reg == 2'h1 ) begin
            axis_tlast             = 1'b1;
            nextstate              = TLAST_VALID_POINT;
          end

      	end else if ( end_of_line_reg ) begin
      	  axis_data                = 'b0;	
          axis_tvalid              = 1'b1;
          
          all_valid_points_counter = all_valid_points_counter_reg + 1;

          if ( all_valid_points_counter_reg == 2'h1 ) begin
            axis_tlast             = 1'b1; 
          end	
          nextstate                = DUMMY_POINT;
      	end	



      end //WATING_FOR_NEW_POINT

      VALID_POINT : begin
        nextstate = WATING_FOR_NEW_POINT;
      end //VALID_POINT

      TLAST_VALID_POINT : begin
        all_valid_points_counter = 2'h0;
        only_true_points_counter = 2'h0;
        if ( end_of_line_reg ) begin
          nextstate              = WATING_FOR_NEW_POINT;
          reset_detector_FSM     = 1'b1;
        end 
      end //TLAST_VALID_POINT

      DUMMY_POINT : begin
        if ( all_valid_points_counter_reg == 2'h1) begin
          axis_data                = 'b0;	
          axis_tvalid              = 1'b1;
          axis_tlast               = 1'b1;

          all_valid_points_counter = all_valid_points_counter_reg + 1;

          nextstate                = DUMMY_POINT;
        end else begin
          all_valid_points_counter = 2'h0;
          only_true_points_counter = 2'h0;
          nextstate                = WATING_FOR_NEW_POINT;

          reset_detector_FSM       = 1'b1;

          if ( end_of_frame_reg ) begin
            nextstate              = IDLE;
          end

        end	
      end //DUMMY_POINT	

      default : nextstate = IDLE;	
    	
    endcase	

  end 
//
//


//EOL and EOF DETECTOR

//signals
logic                    end_of_line, end_of_line_reg;
logic                    end_of_frame, end_of_frame_reg;

logic dummy_1;
logic dummy_2;

typedef enum logic {D_IDLE, DETECTED} detecor_statetype;
detecor_statetype d_state, d_nextstate;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if   ( ~i_sys_aresetn ) d_state <= D_IDLE;
    else                    d_state <= d_nextstate;	
  end


always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if ( ~i_sys_aresetn ) begin
      end_of_line_reg  <= 1'b0;
      end_of_frame_reg <= 1'b0;
    end else begin
      end_of_line_reg  <= end_of_line;
      end_of_frame_reg <= end_of_frame;
    end   
  end

always_comb
  begin

  	d_nextstate  = d_state;
  	end_of_line  = end_of_line_reg;
  	end_of_frame = end_of_frame_reg;
    case ( d_state )

      D_IDLE : begin
        if ( ( i_end_of_line_delayed ) || ( i_end_of_frame_delayed ) ) begin
          end_of_line  = i_end_of_line_delayed;
          end_of_frame = i_end_of_frame_delayed;

          d_nextstate  = DETECTED;
        end	
      end //IDLE
      
      DETECTED : begin
        if ( reset_detector_FSM ) begin
          end_of_line  = 1'b0;
          end_of_frame = 1'b0;

          d_nextstate  = D_IDLE;
        end	
      end  //DETECTED

      default : d_nextstate = D_IDLE;

    endcase
  end  
//
//

//NEW_FRAME DETECTOR

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if ( ~i_sys_aresetn ) begin
      nf_detected_reg  <= 1'b0;
    end else begin
      nf_detected_reg <= nf_detected;
    end   
  end

//
always_comb
  begin

    nf_detected = nf_detected_reg;

    if ( nf_detected_reg ) begin
      if ( reset_nf_detector_reg ) begin
        nf_detected = 1'b0;
      end	
    end	else begin
      if ( i_new_frame_delayed ) begin
        nf_detected = 1'b1;
      end
    end  

  end
//
//


endmodule

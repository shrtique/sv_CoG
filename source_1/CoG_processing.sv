`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2018 03:35:44 PM
// Design Name: 
// Module Name: CoG_processing
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


module CoG_processing#(
  parameter DATA_WIDTH = 8
  //parameter WIDTH      = 1280,
  //parameter HEIGHT     = 1024
)(
  input  logic                  i_sys_clk,
  input  logic                  i_sys_aresetn,

  input  logic [DATA_WIDTH-1:0] i_data_image,
  input  logic                  i_data_valid,

  input  logic [10:0]           i_start_point_value,
  input  logic                  i_start_of_fig,
  input  logic                  i_end_of_fig,

  //output logic [10:0]           o_pixels_in_fig_reg,
  output logic [29:0]           o_sum_of_I_mult_coord_reg,
  output logic [22:0]           o_sum_of_I_reg,
  output logic [10:0]           o_start_point_reg,
  output logic                  o_point_is_valid_reg,

  //interface to delay and synchronise end_of_line and end_of_frame..
  //..with next module (CoF_transsmitter)
  input  logic                  i_end_of_line_for_del,
  input  logic                  i_end_of_frame_for_del,
  input  logic                  i_new_frame_for_del,

  output logic                  o_end_of_line_delayed,
  output logic                  o_end_of_frame_delayed,
  output logic                  o_new_frame_delayed
  //

  //output logic                  test    
);
//
//


////PROCESSES////
// point = ( sum( I^2 * current_coord ) / sum( I^2 ) ) + start_point;
//

//We pipeline end_of_fig through all processing stages..
//..to reset each stage at the right time
//Each pipeline stage has its own valid signal to enable processing of next stage


//1. Squaring: we use I^2 to make weights of CoG nonlinear
// we use pixels_in_fig counter to have current_coord
// current coordinate always starts from 0 to simplify calculations
// to compensate this we add start_point coordinate to point result

//SIGNALS
logic [15:0] I_squared,     I_squared_reg_st_1;
logic [10:0] pixels_in_fig, pixels_in_fig_reg_st_1;
logic        stage_1_valid, stage_1_valid_reg;
logic        end_of_fig_del_st_1;

always_comb
  begin
    I_squared     = I_squared_reg_st_1;
    pixels_in_fig = pixels_in_fig_reg_st_1;
    
    stage_1_valid = 1'b0;

    if ( i_data_valid ) begin
      I_squared     = i_data_image * i_data_image;
      pixels_in_fig = pixels_in_fig_reg_st_1 + 1;

      stage_1_valid = 1'b1;
    end
    
    if ( end_of_fig_del_st_1 ) begin
      I_squared     = 0;
      pixels_in_fig = 0;
    end 

  end  


//let's make it with sync reset, for DSP

always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
      I_squared_reg_st_1     <= 0;
      pixels_in_fig_reg_st_1 <= 0;
      stage_1_valid_reg      <= 1'b0; 
  
      end_of_fig_del_st_1    <= 1'b0; 

    end else begin
      I_squared_reg_st_1     <= I_squared;
      pixels_in_fig_reg_st_1 <= pixels_in_fig;
      stage_1_valid_reg      <= stage_1_valid;

      end_of_fig_del_st_1    <= i_end_of_fig; 
    
    end
end 
//
//


//2. Calculating multiplication of I_squared_st_1 and current position(coordinate)..
//..current position is a value of counter "pixels_in_fig"

//SIGNALS
logic [22:0] I_mult_coord, I_mult_coord_reg;
logic        stage_2_valid, stage_2_valid_reg;

logic [15:0] I_squared_reg_st_2; //register for value form stage 1
logic        end_of_fig_del_st_2;
logic [10:0] pixels_in_fig_reg_st_2;

always_comb
  begin
    I_mult_coord  = I_mult_coord_reg;
    stage_2_valid = 1'b0;

    if ( stage_1_valid_reg ) begin
      I_mult_coord  = I_squared_reg_st_1 * pixels_in_fig_reg_st_1;
      stage_2_valid = 1'b1;
    end

    if ( end_of_fig_del_st_2 ) begin
      I_mult_coord  = 0;
    end 
  end
 //
 //

always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
      I_mult_coord_reg       <= 0;
      stage_2_valid_reg      <= 1'b0;

      I_squared_reg_st_2     <= 0;
      end_of_fig_del_st_2    <= 1'b0;
      pixels_in_fig_reg_st_2 <= 0;


    end else begin
      I_mult_coord_reg       <= I_mult_coord;
      stage_2_valid_reg      <= stage_2_valid;

      I_squared_reg_st_2     <= I_squared_reg_st_1;
      end_of_fig_del_st_2    <= end_of_fig_del_st_1;
      pixels_in_fig_reg_st_2 <= pixels_in_fig_reg_st_1;
    end
end



//fuck... we should create one extra stage here, just to pipiline the output from DSP
//unfortunately the design is awkward, so lets put some additional signals here...
logic [22:0] I_mult_coord_extra_reg;
logic        stage_extra_valid_reg;

logic [15:0] I_squared_reg_st_extra;
logic        end_of_fig_del_st_extra;
logic [10:0] pixels_in_fig_reg_st_extra;

always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
       I_mult_coord_extra_reg     <= '0;
       stage_extra_valid_reg      <= '0;

       I_squared_reg_st_extra     <= '0;
       end_of_fig_del_st_extra    <= '0;
       pixels_in_fig_reg_st_extra <= '0;
    end else begin
       I_mult_coord_extra_reg     <= I_mult_coord_reg;
       stage_extra_valid_reg      <= stage_2_valid_reg;

       I_squared_reg_st_extra     <= I_squared_reg_st_2;
       end_of_fig_del_st_extra    <= end_of_fig_del_st_2;
       pixels_in_fig_reg_st_extra <= pixels_in_fig_reg_st_2;
    end
end

//
//


//3.1 Calculating sums

//SIGNALS
logic [29:0] sum_of_I_mult_coord;
logic [22:0] sum_of_I;
logic        point_is_valid;

logic        stage_3_valid, stage_3_valid_reg;

logic        end_of_fig_del_st_3;

logic        dummy_1; //same shit, cant see in SIM end_of_fig_del_st_3
logic        dummy_2;

always_comb
  begin
    
    sum_of_I            = o_sum_of_I_reg;
    sum_of_I_mult_coord = o_sum_of_I_mult_coord_reg;
    point_is_valid      = 1'b0;


    if ( stage_extra_valid_reg ) begin
      sum_of_I            = o_sum_of_I_reg + I_squared_reg_st_extra;
      sum_of_I_mult_coord = o_sum_of_I_mult_coord_reg + I_mult_coord_extra_reg;
    end

    //we should show that the last point of figure's processed,..
    //..so we use end_of_fig of previous stage, also..
    //..check that fig has enough pixels (>= 3) and at the same time it's not too big (<= 100)
    if ( ( end_of_fig_del_st_extra )             &&
       ( pixels_in_fig_reg_st_extra > 11'd2 )  &&
       ( pixels_in_fig_reg_st_extra < 11'd101) 
       ) begin
      point_is_valid = 1'b1;
    end 

    if ( end_of_fig_del_st_3 ) begin
      sum_of_I_mult_coord = 0;
      sum_of_I            = 0;  
    end 
  end
 //
 //

always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
     
      o_sum_of_I_reg            <= 0; 
      o_sum_of_I_mult_coord_reg <= 0;
      o_point_is_valid_reg      <= 1'b0;

      end_of_fig_del_st_3       <= 1'b0;
    end else begin
     
      o_sum_of_I_reg            <= sum_of_I;
      o_sum_of_I_mult_coord_reg <= sum_of_I_mult_coord;
      o_point_is_valid_reg      <= point_is_valid;

      end_of_fig_del_st_3       <= end_of_fig_del_st_extra;
    end
end



//3.2. Save income start_point with start_of_fig,..
//..refresh start point is possible if saved start point is used

//SIGNALS
logic [10:0] start_point, start_point_reg;

logic        sp_is_grabbed, sp_is_grabbed_reg;
logic        new_start_point, new_start_point_reg;

//INPUT START POINT(SP) DETECTION FSM 
//signals
typedef enum logic {IDLE, NEW_SP} i_statetype;
i_statetype i_sp_state, i_sp_nextstate;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if   ( ~i_sys_aresetn ) i_sp_state <= IDLE;
    else                    i_sp_state <= i_sp_nextstate; 
  end

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if   ( ~i_sys_aresetn ) begin
      start_point_reg     <= '{ default: 'b0 };
      new_start_point_reg <= 1'b0;
    end else begin
      start_point_reg     <= start_point;
      new_start_point_reg <= new_start_point;
    end 
  end

always_comb
  begin

    i_sp_nextstate  = i_sp_state;
    start_point     = start_point_reg;

    new_start_point = new_start_point_reg;

    case ( i_sp_state )
 
      IDLE : begin
        if ( ( i_start_of_fig ) && ( i_data_valid ) ) begin
          start_point     = i_start_point_value;
          i_sp_nextstate  = NEW_SP;
          new_start_point = 1'b1;
        end   
      end //IDLE
      
      NEW_SP : begin
        if ( sp_is_grabbed_reg ) begin
          i_sp_nextstate  = IDLE;
          new_start_point = 1'b0;
        end
      end 
 
      default : i_sp_nextstate = IDLE;

    endcase 
  end
//  

//3.3
//OUTPUT START POINT (SP) FSM
typedef enum logic {RDY_TO_GRAB, BUSY} o_statetype;
o_statetype o_sp_state, o_sp_nextstate;

logic [10:0] o_start_point;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if   ( ~i_sys_aresetn ) o_sp_state <= RDY_TO_GRAB;
    else                    o_sp_state <= o_sp_nextstate; 
  end

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if   ( ~i_sys_aresetn ) begin
      o_start_point_reg <= '{ default: 'b0 };
      sp_is_grabbed_reg <= 1'b0;
    end else begin
      o_start_point_reg <= o_start_point;
      sp_is_grabbed_reg <= sp_is_grabbed;
    end 
  end

always_comb
  begin

    o_sp_nextstate = o_sp_state;
    o_start_point  = o_start_point_reg;
    sp_is_grabbed  = 1'b0;

    case ( o_sp_state )
 
      RDY_TO_GRAB : begin
        if ( new_start_point_reg ) begin
          o_start_point  = start_point_reg;
          sp_is_grabbed  = 1'b1;
          o_sp_nextstate = BUSY;
        end 
      end //RDY_TO_GRAB
      
      BUSY : begin
        if ( end_of_fig_del_st_3 ) begin
          o_sp_nextstate = RDY_TO_GRAB;
        end
      end //BUSY  
 
      default : o_sp_nextstate = RDY_TO_GRAB;

    endcase 
  end 
//
//


//4. PROCESS for delaying (synchronizing) end_of_line and end_of_frame for next module
//just simple delaying of these signals (shfting through buffer)
//the length of delay -> number of calculation stages of this module

//SIGNALS
logic [0:3] end_of_line_delay_line;
logic [0:3] end_of_frame_delay_line;
logic [0:3] new_frame_delay_line;

logic       dummy_3;
logic       dummy_4;
logic       dummy_5;
logic       dummy_6;


//lets try to use them without reset at all. They say it will use LUT shifter
always_ff @( posedge i_sys_clk )
  begin 
    /*
    if ( ~i_sys_aresetn ) begin
      end_of_line_delay_line  <= '{ default: 'b0 };
      end_of_frame_delay_line <= '{ default: 'b0 };
      new_frame_delay_line    <= '{ default: 'b0 };
    end else begin
     */ 
      end_of_line_delay_line  <= { i_end_of_line_for_del, end_of_line_delay_line[0:2] };
      end_of_frame_delay_line <= { i_end_of_frame_for_del, end_of_frame_delay_line[0:2] };
      new_frame_delay_line    <= { i_new_frame_for_del, new_frame_delay_line[0:2] };
    //end
end

assign o_end_of_line_delayed   = end_of_line_delay_line[3];
assign o_end_of_frame_delayed  = end_of_frame_delay_line[3];
assign o_new_frame_delayed     = new_frame_delay_line[3];
//
//
endmodule

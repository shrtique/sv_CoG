`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2018 02:58:48 PM
// Design Name: 
// Module Name: tb_CoG
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


module tb_CoG();


//const
localparam DATA_WIDTH = 8;
localparam WIDTH      = 12;
localparam HEIGHT     = 10;
//
//


//signals
logic clk;
logic aresetn;

logic [2*DATA_WIDTH-1:0] tdata;
logic                    tvalid;
logic                    tuser;
logic                    tlast;           
//
//
tb_video_stream #(
  .N                ( DATA_WIDTH ),
  .width            ( WIDTH ),
  .height           ( HEIGHT ) 

) data_generator (
  .sys_clk          ( clk ),
  .sys_aresetn      ( aresetn ),

  .reg_video_tdata  ( tdata ),
  .reg_video_tvalid ( tvalid ),
  .reg_video_tlast  ( tlast ),
  .reg_video_tuser  ( tuser )
);
//
//
//signals
logic [DATA_WIDTH-1:0] data_from_receiver;
logic                  data_from_receiver_valid;
logic [10:0]           start_point_from_receiver;
logic                  start_of_fig_from_receiver;
logic                  end_of_fig_from_receiver;
//
//
logic                  end_of_line_from_receiver;
logic                  end_of_frame_from_receiver;
logic                  new_frame_from_receiver;
//
CoG_receiver_FSM #(
  .DATA_WIDTH       ( DATA_WIDTH )

) data_receiver (
  .i_sys_clk          ( clk ),
  .i_sys_aresetn      ( aresetn ),

  .WIDTH              ( WIDTH  ),
  .HEIGHT             ( HEIGHT ),
 
  .s_axis_tdata       ( tdata ),
  .s_axis_tvalid      ( tvalid ),
  .s_axis_tuser       ( tuser ),
  .s_axis_tlast       ( tlast ),
  .s_axis_tready      (  ),

  .data_image_reg     ( data_from_receiver ),
  //.data_mask_reg    (  ),
  .data_valid_reg     ( data_from_receiver_valid ),

  .start_point_reg    ( start_point_from_receiver ),
  .start_of_fig_reg   ( start_of_fig_from_receiver ),
  .end_of_fig_reg     ( end_of_fig_from_receiver ),

  .o_end_of_line_reg  ( end_of_line_from_receiver ),
  .o_end_of_frame_reg ( end_of_frame_from_receiver ),
  .o_new_frame_reg    ( new_frame_from_receiver )


);



// signals
logic [29:0]           sum_of_I_mult_coord_from_proc;
logic [22:0]           sum_of_I_from_proc;
logic [10:0]           start_point_from_proc;
logic                  point_is_valid_from_proc;

logic                  end_of_line_from_proc;
logic                  end_of_frame_from_proc;
logic                  new_frame_from_proc;


CoG_processing#(
  .DATA_WIDTH                ( DATA_WIDTH )


) data_processing (
  .i_sys_clk                 ( clk ),
  .i_sys_aresetn             ( aresetn ),

  .i_data_image              ( data_from_receiver ),
  .i_data_valid              ( data_from_receiver_valid ),

  .i_start_point_value       ( start_point_from_receiver ),
  .i_start_of_fig            ( start_of_fig_from_receiver ),
  .i_end_of_fig              ( end_of_fig_from_receiver ),

  //.o_pixels_in_fig_reg       (  ),
  .o_start_point_reg         ( start_point_from_proc ),
  .o_sum_of_I_mult_coord_reg ( sum_of_I_mult_coord_from_proc ),
  .o_sum_of_I_reg            ( sum_of_I_from_proc ),
  .o_point_is_valid_reg      ( point_is_valid_from_proc ),
  //
  //
  .i_end_of_line_for_del     ( end_of_line_from_receiver ),
  .i_end_of_frame_for_del    ( end_of_frame_from_receiver ),
  .i_new_frame_for_del       ( new_frame_from_receiver),

  .o_end_of_line_delayed     ( end_of_line_from_proc ),
  .o_end_of_frame_delayed    ( end_of_frame_from_proc ),
  .o_new_frame_delayed       ( new_frame_from_proc) 

);
//
//


CoG_transmitter_FSM#(
  .DATA_WIDTH ( DATA_WIDTH )

) data_transmitter (
  .i_sys_clk              ( clk ),
  .i_sys_aresetn          ( aresetn ),

  .i_sum_of_I_mult_coord  ( sum_of_I_mult_coord_from_proc ),
  .i_sum_of_I             ( sum_of_I_from_proc ),
  .i_start_point          ( start_point_from_proc ),
  .i_point_is_valid       ( point_is_valid_from_proc ),

  .i_end_of_line_delayed  ( end_of_line_from_proc ),
  .i_end_of_frame_delayed ( end_of_frame_from_proc ),
  .i_new_frame_delayed    ( new_frame_from_proc ),

  .m_axis_tdata           (  ),
  .m_axis_tvalid          (  ),
  .m_axis_tuser           (  ),
  .m_axis_tlast           (  )
 
);
//
//

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/14/2018 05:40:26 PM
// Design Name: 
// Module Name: CoG_top_module
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


module CoG_top_module #(
  parameter DATA_WIDTH = 8
  //parameter WIDTH      = 1280,
  //parameter HEIGHT     = 1024
)( 

  input  logic                    i_sys_clk,
  input  logic                    i_sys_aresetn,

  input  logic [10:0]             WIDTH,
  input  logic [10:0]             HEIGHT,

  input  logic [2*DATA_WIDTH-1:0] s_axis_tdata,
  input  logic                    s_axis_tvalid,
  input  logic                    s_axis_tuser,
  input  logic                    s_axis_tlast,
  output logic                    s_axis_tready,

  output logic [8*DATA_WIDTH-1:0] m_axis_tdata,
  output logic                    m_axis_tvalid,
  output logic                    m_axis_tuser,
  output logic                    m_axis_tlast

);

// ASSIGNES
//parameters signals
logic [10:0] img_width;
logic [10:0] img_height;

assign img_width  = WIDTH;
assign img_height = HEIGHT;

////INST////

//1. RECEIVER

//signals
logic [DATA_WIDTH-1:0] data_from_receiver;
logic                  data_from_receiver_valid;

logic [10:0]           start_point_from_receiver;
logic                  start_of_fig_from_receiver;
logic                  end_of_fig_from_receiver;

logic                  end_of_line_from_receiver;
logic                  end_of_frame_from_receiver;
logic                  new_frame_from_receiver;

CoG_receiver_FSM #(
  .DATA_WIDTH       ( DATA_WIDTH )
  //.WIDTH            ( WIDTH ),
  //.HEIGHT           ( HEIGHT  )

) data_receiver (
  .i_sys_clk          ( i_sys_clk                  ),
  .i_sys_aresetn      ( i_sys_aresetn              ),
                                      
  .WIDTH              ( img_width                  ),
  .HEIGHT             ( img_height                 ),
 
  .s_axis_tdata       ( s_axis_tdata               ),
  .s_axis_tvalid      ( s_axis_tvalid              ),
  .s_axis_tuser       ( s_axis_tuser               ),
  .s_axis_tlast       ( s_axis_tlast               ),
  .s_axis_tready      ( s_axis_tready              ),

  .data_image_reg     ( data_from_receiver         ),
  .data_valid_reg     ( data_from_receiver_valid   ),

  .start_point_reg    ( start_point_from_receiver  ),
  .start_of_fig_reg   ( start_of_fig_from_receiver ),
  .end_of_fig_reg     ( end_of_fig_from_receiver   ),

  .o_end_of_line_reg  ( end_of_line_from_receiver  ),
  .o_end_of_frame_reg ( end_of_frame_from_receiver ),
  .o_new_frame_reg    ( new_frame_from_receiver    )

);
//
//

//2. PROCESSOR

//signals
logic [29:0]           sum_of_I_mult_coord_from_proc;
logic [22:0]           sum_of_I_from_proc;
logic [10:0]           start_point_from_proc;
logic                  point_is_valid_from_proc;

logic                  end_of_line_from_proc;
logic                  end_of_frame_from_proc;
logic                  new_frame_from_proc;

CoG_processing#(
  .DATA_WIDTH                ( DATA_WIDTH )
  //.WIDTH                     ( WIDTH ),
  //.HEIGHT                    ( HEIGHT )

) data_processing (
  .i_sys_clk                 ( i_sys_clk                     ),
  .i_sys_aresetn             ( i_sys_aresetn                 ),


  .i_data_image              ( data_from_receiver            ),
  .i_data_valid              ( data_from_receiver_valid      ),

  .i_start_point_value       ( start_point_from_receiver     ),
  .i_start_of_fig            ( start_of_fig_from_receiver    ),
  .i_end_of_fig              ( end_of_fig_from_receiver      ),

  //.o_pixels_in_fig_reg       (  ),
  .o_start_point_reg         ( start_point_from_proc         ),
  .o_sum_of_I_mult_coord_reg ( sum_of_I_mult_coord_from_proc ),
  .o_sum_of_I_reg            ( sum_of_I_from_proc            ),
  .o_point_is_valid_reg      ( point_is_valid_from_proc      ),
  //
  //
  .i_end_of_line_for_del     ( end_of_line_from_receiver     ),
  .i_end_of_frame_for_del    ( end_of_frame_from_receiver    ),
  .i_new_frame_for_del       ( new_frame_from_receiver       ),

  .o_end_of_line_delayed     ( end_of_line_from_proc         ),
  .o_end_of_frame_delayed    ( end_of_frame_from_proc        ),
  .o_new_frame_delayed       ( new_frame_from_proc           ) 
   
);
//
//

//3. TRANSMITTER

CoG_transmitter_FSM#(
  .DATA_WIDTH ( DATA_WIDTH )

) data_transmitter (
  .i_sys_clk              ( i_sys_clk                     ),
  .i_sys_aresetn          ( i_sys_aresetn                 ),

  .i_sum_of_I_mult_coord  ( sum_of_I_mult_coord_from_proc ),
  .i_sum_of_I             ( sum_of_I_from_proc            ),
  .i_start_point          ( start_point_from_proc         ),
  .i_point_is_valid       ( point_is_valid_from_proc      ),

  .i_end_of_line_delayed  ( end_of_line_from_proc         ),
  .i_end_of_frame_delayed ( end_of_frame_from_proc        ),
  .i_new_frame_delayed    ( new_frame_from_proc           ),

  .m_axis_tdata           ( m_axis_tdata                  ),
  .m_axis_tvalid          ( m_axis_tvalid                 ),
  .m_axis_tuser           ( m_axis_tuser                  ),
  .m_axis_tlast           ( m_axis_tlast                  )
  
);
//
//

endmodule

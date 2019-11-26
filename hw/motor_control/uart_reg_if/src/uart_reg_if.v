//-----------------------------------------------------------------------------
// Title: UART Register Interface
//-----------------------------------------------------------------------------
// Description: Implements a protocol on top of RS232 Interface to
// read and write registers.
//
// Internally the number of registers for value_in is increased by one
// to manage the version number reading.
//
// Protocol:
//
//  - Write:   recv: "S<8-bit index>W<B0><B1><B2><B3>"
//
//  - Read:    recv: "S<8-bit index>R"
//             resp: "<B0><B1><B2><B3>"
//
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by Christophe Clienti. This model is the
// confidential and proprietary property of Christophe Clienti and the
// possession or use of this file requires a written license from
// Christophe Clienti.
//-----------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module uart_reg_if
  #(parameter NUM_BYTES_PER_REG = 4,
    parameter NUM_REGISTERS     = 8)

  (input wire clock,
   input wire srst,

   // UART received interface
   input wire [7:0] uart_rx_value,
   input wire       uart_rx_value_ready,

   // UART send interface
   output reg [7:0] uart_tx_value,
   output reg       uart_tx_value_write,
   input wire       uart_tx_value_done,

   // Registers are not in/out, the component instantiating
   // uart_reg_if must connect value_in[j] to value_out[j] in order to
   // read back written values.
   input wire  [NUM_REGISTERS-1:0] [NUM_BYTES_PER_REG-1:0] [7:0] value_in,
   output wire [NUM_REGISTERS-1:0] [NUM_BYTES_PER_REG-1:0] [7:0] value_out);


   //-----------------------------------------------------------------------------
   // Constants
   //-----------------------------------------------------------------------------

   localparam LOG2_NUM_BYTES_PER_REG = $clog2(NUM_BYTES_PER_REG);
   localparam LOG2_NUM_REGISTERS     = $clog2(NUM_REGISTERS);

   localparam PROTO_SET_REG = "S";
   localparam PROTO_READ    = "R";
   localparam PROTO_WRITE   = "W";


   //-----------------------------------------------------------------------------
   // Checks
   //-----------------------------------------------------------------------------

   initial begin
      if (2**LOG2_NUM_BYTES_PER_REG != NUM_BYTES_PER_REG) begin
         $display("Error: %m: NUM_BYTES_PER_REG is not a power of two");
      end
   end


   //-----------------------------------------------------------------------------
   // Generic Variables
   //-----------------------------------------------------------------------------

   genvar reg_idx;
   genvar byte_idx;


   //-----------------------------------------------------------------------------
   // Register index
   //-----------------------------------------------------------------------------

   reg [LOG2_NUM_REGISTERS-1:0] reg_array_idx;
   reg                          reg_array_idx_enable;

   always @(posedge clock) begin
      if (srst == 1'b1) begin
         reg_array_idx <= 0;
      end
      else begin
         if (reg_array_idx_enable == 1'b1) begin
            reg_array_idx <= uart_rx_value[LOG2_NUM_REGISTERS-1:0];
         end
      end
   end


   //-----------------------------------------------------------------------------
   // Byte counter
   //-----------------------------------------------------------------------------

   reg [LOG2_NUM_BYTES_PER_REG-1:0] byte_counter;
   reg byte_counter_incr;
   reg byte_counter_reset;
   reg byte_counter_roll;

   always @(posedge clock) begin
      if (byte_counter_reset == 1'b1) begin
         byte_counter <= 0;
      end
      else if (byte_counter_incr == 1'b1) begin
         byte_counter <= byte_counter + 1'b1;
      end
   end

   always @(*) begin
      byte_counter_roll = byte_counter_incr && (byte_counter == 3);
   end


   //-----------------------------------------------------------------------------
   // Byte selection Demuxer
   //-----------------------------------------------------------------------------

   reg [NUM_REGISTERS-1:0] [NUM_BYTES_PER_REG-1:0] reg_array_sel;
   reg [NUM_BYTES_PER_REG-1:0]                     reg_array_byte_sel;

   // Decode byte_counter to generate byte select
   always @(*) begin
      reg_array_byte_sel = (1 << byte_counter);
   end

   // Generate all register write enables.
   generate
      for (reg_idx = 0; reg_idx < NUM_REGISTERS; reg_idx = reg_idx + 1) begin: GEN_REG_SEL

         always @(*) begin
            if (reg_array_idx == reg_idx) begin
               reg_array_sel[reg_idx] = reg_array_byte_sel;
            end
            else begin
               reg_array_sel[reg_idx] = 0;
            end
         end

      end
   endgenerate


   //-----------------------------------------------------------------------------
   // Registers (connected to value_out)
   //-----------------------------------------------------------------------------

   reg [NUM_REGISTERS-1:0] [NUM_BYTES_PER_REG-1:0] [7:0] reg_array;
   reg                                                   reg_array_write;

   // Generate register array. reg_array_write controls globally if
   // the registers are written and reg_array_sel gathers each
   // register write enable (for each byte of each register).
   generate
      for (reg_idx = 0; reg_idx < NUM_REGISTERS; reg_idx = reg_idx + 1) begin: GEN_REGS
         for (byte_idx = 0; byte_idx < NUM_BYTES_PER_REG; byte_idx = byte_idx + 1) begin: GEN_BYTES

            always @(posedge clock) begin
               if (srst == 1'b1) begin
                  reg_array[reg_idx][byte_idx] <= 0;
               end
               else if (reg_array_write == 1'b1 && reg_array_sel[reg_idx][byte_idx] == 1'b1) begin
                  reg_array[reg_idx][byte_idx] <= uart_rx_value;
               end
            end

         end
      end
   endgenerate

   assign value_out = reg_array;


   //-----------------------------------------------------------------------------
   // Multiplex value_in to uart_tx_value (two pipelined stages)
   //-----------------------------------------------------------------------------

   reg [LOG2_NUM_BYTES_PER_REG-1:0]  byte_counter_reg;
   reg [NUM_BYTES_PER_REG-1:0] [7:0] reg_word;
   reg                               uart_tx_value_write_comb;

   // First mux stage
   always @(posedge clock) begin
      // We memorize the input value only when the byte counter is
      // reset to prevent data change when sending the response.
      if (byte_counter_reset == 1'b1) begin
         reg_word <= value_in[reg_array_idx];
      end
   end

   // Second mux stage
   always @(posedge clock) begin
      byte_counter_reg <= byte_counter;
      uart_tx_value <= reg_word[byte_counter_reg];
   end

   always @(posedge clock) begin
      // The value is prepared two cycles before, how ever a register
      // is added to break the combinational logic delay.
      uart_tx_value_write <= uart_tx_value_write_comb;
   end


   //-----------------------------------------------------------------------------
   // Control
   //-----------------------------------------------------------------------------

   localparam STATE_IDLE        = 0;
   localparam STATE_INDEX_WAIT  = 1;
   localparam STATE_INDEX_SET   = 2;
   localparam STATE_ACTION_WAIT = 3;
   localparam STATE_RESP_WRITE  = 4;
   localparam STATE_RESP_WAIT   = 5;
   localparam STATE_RECV_WAIT   = 6;
   localparam STATE_RECV_WRITE  = 7;
   localparam NUM_STATES        = $clog2(STATE_RECV_WRITE + 1);

   reg [NUM_STATES-1:0] state_new;
   reg [NUM_STATES-1:0] state_reg;

   // State register
   always @(posedge clock) begin
      if (srst == 1'b1) begin
         state_reg <= STATE_IDLE;
      end
      else begin
         state_reg <= state_new;
      end
   end

   // Transitions
   always @(*) begin
      case (state_reg)
         default /*STATE_IDLE*/: begin
            if (uart_rx_value_ready == 1'b1 && uart_rx_value == PROTO_SET_REG) begin
               state_new = STATE_INDEX_WAIT;
            end
            else begin
               state_new = STATE_IDLE;
            end
         end

         STATE_INDEX_WAIT: begin
            if (uart_rx_value_ready == 1'b1) begin
               state_new = STATE_INDEX_SET;
            end
            else begin
               state_new = STATE_INDEX_WAIT;
            end
         end

         STATE_INDEX_SET: begin
            state_new = STATE_ACTION_WAIT;
         end

         STATE_ACTION_WAIT: begin
            if (uart_rx_value_ready == 1'b1) begin
               if (uart_rx_value == PROTO_READ) begin
                  state_new = STATE_RESP_WRITE;
               end
               else if (uart_rx_value == PROTO_WRITE) begin
                  state_new = STATE_RECV_WAIT;
               end
               else begin
                  $display("%m: Error - unknown PROTO value 0x%02h", uart_rx_value);
                  state_new = STATE_IDLE;
               end
            end
            else begin
               state_new = STATE_ACTION_WAIT;
            end
         end

         STATE_RESP_WRITE: begin
            if (byte_counter_roll == 1'b1) begin
               // If the counter rolls over, the response is fully
               // written.
               state_new = STATE_IDLE;
            end
            else begin
               state_new = STATE_RESP_WAIT;
            end
         end

         STATE_RESP_WAIT: begin
            if (uart_tx_value_done == 1'b1) begin
               state_new = STATE_RESP_WRITE;
            end
            else begin
               state_new = STATE_RESP_WAIT;
            end
         end

         STATE_RECV_WAIT: begin
            if (uart_rx_value_ready == 1'b1) begin
               state_new = STATE_RECV_WRITE;
            end
            else begin
               state_new = STATE_RECV_WAIT;
            end
         end

         STATE_RECV_WRITE: begin
            if (byte_counter_roll == 1'b1) begin
               state_new = STATE_IDLE;
            end
            else begin
               state_new = STATE_RECV_WAIT;
            end
         end

      endcase
   end

   // Actions
   always @(*) begin
      case (state_reg)
         STATE_INDEX_SET: begin
            reg_array_idx_enable     = 1;
            reg_array_write          = 0;
            uart_tx_value_write_comb = 0;
            byte_counter_incr        = 0;
            byte_counter_reset       = 1;
         end

         STATE_RESP_WRITE: begin
            reg_array_idx_enable     = 0;
            reg_array_write          = 0;
            uart_tx_value_write_comb = 1;
            byte_counter_incr        = 1;
            byte_counter_reset       = 0;
         end

         STATE_RECV_WRITE: begin
            reg_array_idx_enable     = 0;
            reg_array_write          = 1;
            uart_tx_value_write_comb = 0;
            byte_counter_incr        = 1;
            byte_counter_reset       = 0;
         end

         default: begin
            reg_array_idx_enable     = 0;
            reg_array_write          = 0;
            uart_tx_value_write_comb = 0;
            byte_counter_incr        = 0;
            byte_counter_reset       = 0;
        end
      endcase
   end



endmodule

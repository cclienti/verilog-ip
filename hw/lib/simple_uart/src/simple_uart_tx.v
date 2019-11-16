//-----------------------------------------------------------------------------
// Title         : Simple Uart TX Module
//-----------------------------------------------------------------------------
// File          : simple_uart_rx.v
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 06.11.2019
// Last modified : 06.11.2019
//-----------------------------------------------------------------------------
// Description :
// Implements a basic TX UART / 8-bit / No Parity / 1 Stop Bit
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module simple_uart_tx
  #(parameter SYSTEM_FREQ = 50_000_000,
    parameter BAUD_RATE   = 9600)

   (input wire       clock,
    input wire       srst,

    output wire      tx_bit,

    input wire [7:0] tx_value,
    input wire       tx_value_write,
    output reg       tx_value_done);

   //---------------------------------------------------------------------------
   // Constants
   //---------------------------------------------------------------------------

   localparam NUM_BITS           = 8;
   localparam BITS_COUNTER_MAX   = NUM_BITS - 1;
   localparam LOG2_NUM_BITS      = $clog2(NUM_BITS);
   localparam BAUD_COUNTER_MAX   = SYSTEM_FREQ / BAUD_RATE - 4;
   localparam BAUD_COUNTER_WIDTH = $clog2(BAUD_COUNTER_MAX + 1);


   //---------------------------------------------------------------------------
   // Baud Counter
   //---------------------------------------------------------------------------

   reg [BAUD_COUNTER_WIDTH-1 : 0] baud_counter;
   reg baud_counter_reset;
   reg baud_counter_max_new;
   reg baud_counter_max;
   reg baud_counter_max2;

   always @(posedge clock) begin
      if (baud_counter_reset == 1'b1) begin
         baud_counter <= 0;
      end
      else begin
         baud_counter <= baud_counter + 1'b1;
      end
   end

   always @(*) begin
      if (baud_counter == BAUD_COUNTER_MAX[BAUD_COUNTER_WIDTH-1:0]) begin
         baud_counter_max_new = 1'b1;
      end
      else begin
         baud_counter_max_new = 1'b0;
      end
   end

   always @(posedge clock) begin
      baud_counter_max <= baud_counter_max_new;
      baud_counter_max2 <= baud_counter_max;
   end


   //---------------------------------------------------------------------------
   // TX Bits Counter
   //---------------------------------------------------------------------------

   reg [LOG2_NUM_BITS-1 : 0] bits_counter;
   reg bits_counter_incr;
   reg bits_counter_reset;
   reg bits_counter_max;

   always @(posedge clock) begin
      if (bits_counter_reset == 1'b1) begin
         bits_counter <= 0;
      end
      else if (bits_counter_incr == 1'b1) begin
         bits_counter <= bits_counter + 1'b1;
      end
   end

   always @(posedge clock) begin
      if (bits_counter == 0) begin
         bits_counter_max <= 1'b1;
      end
      else begin
         bits_counter_max <= 1'b0;
      end
   end


   //---------------------------------------------------------------------------
   // Receive shift register
   //---------------------------------------------------------------------------

   // The tx_shift_reg width use NUM_BITS+2 bits to send the
   // start The stop will be sent automatically at the end becuse we
   // push 1 in the shift register. The bit tx_shift_reg[0] will be
   // directly assigned to the output of the module.
   reg [NUM_BITS : 0] tx_shift_reg;
   reg tx_shift;

   always @(posedge clock) begin
      if (srst == 1'b1) begin
         tx_shift_reg <= {(NUM_BITS+1){1'b1}};
      end
      else begin
         if (tx_value_write == 1'b1) begin
            tx_shift_reg <= {/*word: */ tx_value, /*start: */ 1'b0};
         end
         else if (tx_shift == 1'b1) begin
            // We send bits LSB first.
            tx_shift_reg <= {1'b1, tx_shift_reg[NUM_BITS : 1]};
         end
      end
   end


   //---------------------------------------------------------------------------
   // Finite State Machine
   //---------------------------------------------------------------------------
   // _____         _____  _____  _____  _____  _____
   // IDLE \ START /  B0 \/  B1 \/ ... \/  B7 \/ STOP
   //       \_____/\_____/\_____/\_____/\_____/
   //      |   |      |      |      |      |      |
   //    Rst  Half   Max    Max    ...
   //    Baud Baud   Baud   Baud
   //         +Rst   +Rst   +Rst
   //

   localparam STATE_IDLE       = 0;
   localparam STATE_START      = 1;
   localparam STATE_START_WAIT = 2;
   localparam STATE_SEND       = 3;
   localparam STATE_SEND_WAIT  = 4;
   localparam STATE_STOP       = 5;
   localparam STATE_STOP_WAIT  = 6;
   localparam STATE_DONE       = 7;
   localparam LOG2_STATES      = $clog2(STATE_DONE + 1);

   reg [LOG2_STATES-1 : 0] state_reg, state_new;
   reg                     tx_value_done_comb;

   // State register
   always @(posedge clock) begin
      if (srst == 1'b1) begin
         state_reg <= STATE_IDLE;
      end
      else begin
         state_reg <= state_new;
      end
   end

   // State transitions
   always @(*) begin
      case(state_reg)
         default: begin // STATE_IDLE
            if (tx_value_write == 1'b1) begin
               state_new = STATE_START;
            end
            else begin
               state_new = STATE_IDLE;
            end
         end

         STATE_START: begin
            state_new = STATE_START_WAIT;
         end

         STATE_START_WAIT: begin
            if (baud_counter_max == 1'b1) begin
               state_new = STATE_SEND;
            end
            else begin
               state_new = STATE_START_WAIT;
           end
         end

         STATE_SEND: begin
             state_new = STATE_SEND_WAIT;
         end

         STATE_SEND_WAIT: begin
            if (baud_counter_max2 == 1'b1) begin
               if (bits_counter_max == 1'b1) begin
                  state_new = STATE_STOP;
               end
               else begin
                  state_new = STATE_SEND;
              end
            end
            else begin
               state_new = STATE_SEND_WAIT;
           end
         end

         STATE_STOP: begin
            state_new = STATE_STOP_WAIT;
         end

         STATE_STOP_WAIT: begin
            // we use baud_counter_max to save cycle in order to
            // restart faster. The Stop bit will be a 2 cycles too
            // short but this not an issue.
            if (baud_counter_max == 1'b1) begin
               state_new = STATE_DONE;
            end
            else begin
               state_new = STATE_STOP_WAIT;
            end
         end

         STATE_DONE: begin
            state_new = STATE_IDLE;
         end
     endcase
   end

   // State actions
   always @(*) begin
      case(state_reg)
         default: begin // STATE_IDLE
            baud_counter_reset = 1'b1;
            bits_counter_reset = 1'b1;
            bits_counter_incr  = 1'b0;
            tx_shift           = 1'b0;
            tx_value_done_comb = 1'b0;
         end

         STATE_START: begin
            baud_counter_reset = 1'b1;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            tx_shift           = 1'b0;
            tx_value_done_comb = 1'b0;
         end

         STATE_START_WAIT: begin
            baud_counter_reset = 1'b0;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            tx_shift           = 1'b0;
            tx_value_done_comb = 1'b0;
         end

         STATE_SEND: begin
            baud_counter_reset = 1'b1;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b1;
            tx_shift           = 1'b1;
            tx_value_done_comb = 1'b0;
         end

         STATE_SEND_WAIT: begin
            baud_counter_reset = 1'b0;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            tx_shift           = 1'b0;
            tx_value_done_comb = 1'b0;
         end

         STATE_STOP: begin
            baud_counter_reset = 1'b1;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            tx_shift           = 1'b1;
            tx_value_done_comb = 1'b0;
         end

         STATE_STOP_WAIT: begin
            baud_counter_reset = 1'b0;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            tx_shift           = 1'b0;
            tx_value_done_comb = 1'b0;
         end

         STATE_DONE: begin
            baud_counter_reset = 1'b1;
            bits_counter_reset = 1'b1;
            bits_counter_incr  = 1'b0;
            tx_shift           = 1'b0;
            tx_value_done_comb = 1'b1;
         end
      endcase
   end


   //---------------------------------------------------------------------------
   // Output
   //---------------------------------------------------------------------------

   always @(posedge clock) begin
      tx_value_done <= tx_value_done_comb;
   end

   assign tx_bit = tx_shift_reg[0];

endmodule

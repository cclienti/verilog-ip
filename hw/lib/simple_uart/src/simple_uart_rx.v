//-----------------------------------------------------------------------------
// Title         : Simple Uart RX Module
//-----------------------------------------------------------------------------
// File          : simple_uart_rx.v
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 06.11.2019
// Last modified : 06.11.2019
//-----------------------------------------------------------------------------
// Description :
// Implements the basic RX UART / 8-bit / No Parity / 1 Stop Bit
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module simple_uart_rx
  #(parameter SYSTEM_FREQ = 50_000_000,
    parameter BAUD_RATE   = 9600)

   (input wire       clock,
    input wire       srst,

    input wire       rx_bit,

    output reg [7:0] rx_value,
    output reg       rx_value_ready);

   //---------------------------------------------------------------------------
   // Constants
   //---------------------------------------------------------------------------

   localparam NUM_BITS           = 8;
   localparam LOG2_NUM_BITS      = $clog2(NUM_BITS);
   localparam BITS_COUNTER_MAX   = 7;

   // Take into account FSM Latency (-3)
   localparam BAUD_COUNTER_MAX   = SYSTEM_FREQ / BAUD_RATE - 3;
   // Take into account FSM Latency + restart Latency (-5)
   localparam BAUD_COUNTER_HALF  = SYSTEM_FREQ / BAUD_RATE / 2 - 5;

   localparam BAUD_COUNTER_WIDTH = $clog2(BAUD_COUNTER_MAX + 1);


   //---------------------------------------------------------------------------
   // Baud Counter
   //---------------------------------------------------------------------------

   reg [BAUD_COUNTER_WIDTH-1 : 0] baud_counter;
   reg baud_counter_reset;
   reg baud_counter_max_new;
   reg baud_counter_max;
   reg baud_counter_half_new;
   reg baud_counter_half;

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

   always @(*) begin
      if (baud_counter == BAUD_COUNTER_HALF[BAUD_COUNTER_WIDTH-1:0]) begin
         baud_counter_half_new = 1'b1;
      end
      else begin
         baud_counter_half_new = 1'b0;
      end
   end

   always @(posedge clock) begin
      baud_counter_half <= baud_counter_half_new;
      baud_counter_max <= baud_counter_max_new;
   end


   //---------------------------------------------------------------------------
   // RX Bits Counter
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
      if (bits_counter == BITS_COUNTER_MAX[LOG2_NUM_BITS-1:0]) begin
         bits_counter_max <= 1'b1;
      end
      else begin
         bits_counter_max <= 1'b0;
      end
   end


   //---------------------------------------------------------------------------
   // Receive shift register
   //---------------------------------------------------------------------------

   reg [NUM_BITS-1 : 0] rx_shift_reg;
   reg rx_shift;

   always @(posedge clock) begin
      if (rx_shift == 1'b1) begin
         // We receive bits LSB first. So RX goes in MSB shift reg and
         // it is right shifted.
         rx_shift_reg <= {rx_bit, rx_shift_reg[NUM_BITS-1 : 1]};
      end
   end


   //---------------------------------------------------------------------------
   // Finite State Machine (Moore)
   //---------------------------------------------------------------------------
   // _____         _____  _____  _____  _____  _____
   // IDLE \ START /  B0 \/  B1 \/ ... \/  B7 \/ STOP
   //       \_____/\_____/\_____/\_____/\_____/
   //      |   |      |      |      |      |      |
   //    Rst  Half   Max    Max    ...
   //    Baud Baud   Baud   Baud
   //         +Rst   +Rst   +Rst
   //

   localparam STATE_IDLE        = 0;
   localparam STATE_START       = 1;
   localparam STATE_READ_PRE    = 2;
   localparam STATE_READ_WAIT   = 3;
   localparam STATE_READ        = 4;
   localparam STATE_READ_POST   = 5;
   localparam STATE_STOP_WAIT   = 6;
   localparam STATE_PUSH        = 7;
   localparam STATE_PUSH_WAIT   = 8;
   localparam LOG2_STATES       = $clog2(STATE_PUSH_WAIT + 1);

   reg [LOG2_STATES-1:0] state_reg, state_new;

   // State register
   always @(posedge clock) begin
      if (srst == 1'b1) begin
         state_reg <= 0;
      end
      else begin
         state_reg <= state_new;
      end
   end

   // State transitions
   always @(*) begin
      case(state_reg)
         default: begin // STATE_IDLE
            if (rx_bit == 1'b1) begin
               // RX is high, we must wait.
               state_new = STATE_IDLE;
            end
            else begin
               // RX is low, so we can start reception
               state_new = STATE_START;
            end
         end

         STATE_START: begin
            if (baud_counter_half == 1'b1) begin
               // The baud counter is at the half period value
               state_new = STATE_READ_PRE;
            end
            else begin
               // We wait for the half value of the baud counter
               state_new = STATE_START;
            end
         end

         STATE_READ_PRE: begin
            state_new = STATE_READ_WAIT;
         end

         STATE_READ_WAIT: begin
            if (baud_counter_max == 1'b1) begin
               if (bits_counter_max == 1'b1) begin
                  // Stop bit received.
                  state_new = STATE_READ_POST;
               end
               else begin
                  // We can sample the bit value.
                  state_new = STATE_READ;
               end
            end
            else begin
               // Wait for the baud counter full to sample a value.
               state_new = STATE_READ_WAIT;
            end
         end

         STATE_READ: begin
            state_new = STATE_READ_WAIT;
         end

         STATE_READ_POST: begin
            state_new = STATE_STOP_WAIT;
         end

         STATE_STOP_WAIT: begin
            if (baud_counter_max == 1'b1) begin
               state_new = STATE_PUSH;
            end
            else begin
               state_new = STATE_STOP_WAIT;
            end
         end

         STATE_PUSH: begin
            state_new = STATE_PUSH_WAIT;
         end

         STATE_PUSH_WAIT: begin
            if (baud_counter_half == 1'b1) begin
               state_new = STATE_IDLE;
            end
            else begin
               state_new = STATE_PUSH_WAIT;
            end
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
            rx_shift           = 1'b0;
            rx_value_ready_new = 1'b0;
         end

         STATE_START: begin
            baud_counter_reset = 1'b0;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            rx_shift           = 1'b0;
            rx_value_ready_new = 1'b0;
         end

         STATE_READ_PRE: begin
            baud_counter_reset = 1'b1;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            rx_shift           = 1'b0;
            rx_value_ready_new = 1'b0;
         end

         STATE_READ_WAIT: begin
            baud_counter_reset = 1'b0;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            rx_shift           = 1'b0;
            rx_value_ready_new = 1'b0;
         end

         STATE_READ: begin
            baud_counter_reset = 1'b1;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b1;
            rx_shift           = 1'b1;
            rx_value_ready_new = 1'b0;
         end

         STATE_READ_POST: begin
            baud_counter_reset = 1'b1;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            rx_shift           = 1'b1;
            rx_value_ready_new = 1'b0;
         end

         STATE_STOP_WAIT: begin
            baud_counter_reset = 1'b0;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            rx_shift           = 1'b0;
            rx_value_ready_new = 1'b0;
         end

         STATE_PUSH: begin
            baud_counter_reset = 1'b1;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            rx_shift           = 1'b0;
            rx_value_ready_new = 1'b1;
         end

         STATE_PUSH_WAIT: begin
            baud_counter_reset = 1'b0;
            bits_counter_reset = 1'b0;
            bits_counter_incr  = 1'b0;
            rx_shift           = 1'b0;
            rx_value_ready_new = 1'b0;
         end
      endcase
   end


   //---------------------------------------------------------------------------
   // Output
   //---------------------------------------------------------------------------

   reg rx_value_ready_new;
   reg rx_value_ready_trig;
   reg rx_value_ready_pre1;
   reg rx_value_ready_pre2;

   always @(posedge clock) begin
      if (srst == 1'b1) begin
         rx_value_ready_trig <= 1'b0;
      end
      if (rx_value_ready_new) begin
         rx_value_ready_trig <= 1'b1;
      end
      else if (rx_value_ready) begin
         rx_value_ready_trig <= 1'b0;
      end
   end

   always @(posedge clock) begin
      if (srst == 1'b1) begin
         rx_value_ready_pre1 <= 0;
      end
      else if (baud_counter_half && rx_value_ready_trig) begin
         rx_value_ready_pre1 <= 1'b1;
      end
      else begin
         rx_value_ready_pre1 <= 1'b0;
      end
   end

   always @(posedge clock) begin
      rx_value_ready_pre2 <= rx_value_ready_pre1;
      rx_value_ready <= rx_value_ready_pre2;
   end

   always @(posedge clock) begin
      if (rx_value_ready_new) begin
         rx_value <= rx_shift_reg;
      end
   end

endmodule

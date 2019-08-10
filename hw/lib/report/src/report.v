//                              -*- Mode: Verilog -*-
// Filename        : report.v
// Description     : Info/Warning/Error Report Module
// Author          : Christophe
// Created On      : Wed May 11 10:33:12 2016
// Last Modified By: Christophe
// Last Modified On: Wed May 11 10:33:12 2016
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps


module report #(parameter [2*8:1] UNIT = "us",
                parameter MAX_STRING_LENGTH = 1024);

   //----------------------------------------------------------------
   // Time format
   //----------------------------------------------------------------
   // $timeformat(UNIT, precision, " us", minwidth);
   //
   // UNIT      is the base that time is to be displayed in, from 0 to -15
   // precision is the number of decimal points to display.
   // "UNIT"    is a string appended to the time, such as " ns".
   // minwidth  is the minimum number of characters that will be displayed.
   //
   //   0 =   1 sec
   //  -1 = 100 ms
   //  -2 =  10 ms
   //  -3 =   1 ms
   //  -4 = 100 us
   //  -5 =  10 us
   //  -6 =   1 us
   //  -7 = 100 ns
   //  -8 =  10 ns
   //  -9 =   1 ns
   // -10 = 100 ps
   // -11 =  10 ps
   // -12 =   1 ps
   // -13 = 100 fs
   // -14 =  10 fs
   // -15 =   1 fs

   initial begin
      case (UNIT)
         "ns": begin
            $timeformat(-9, 3, " ns", 8);
         end

         "us": begin
            $timeformat(-6, 6, " us", 11);
         end

         "ms": begin
            $timeformat(-3, 9, " ms", 14);
         end

         default: begin
            $timeformat(-6, 6, " us", 11);
            warning("report: unknown timeformat");
         end
      endcase
   end

   //----------------------------------------------------------------
   // Counters
   //----------------------------------------------------------------

   integer nb_info;
   integer nb_warning;
   integer nb_error;

   initial begin
      nb_info = 0;
      nb_warning = 0;
      nb_error = 0;
   end

   //----------------------------------------------------------------
   // Display tasks
   //----------------------------------------------------------------

   reg [MAX_STRING_LENGTH*8:1] local_str;

   task info;
      input [MAX_STRING_LENGTH*8:1] msg;
      integer i;
      begin
         $write("\033[0;34mINFO at [%0t]:\033[0m %0s\n", $time, msg);
         nb_info = nb_info + 1;
      end
   endtask

   task warning;
      input [MAX_STRING_LENGTH*8:1] msg;
      begin
         $write("\033[0;33mWARNING at [%0t]:\033[0m %0s\n", $time, msg);
         nb_warning = nb_warning + 1;
      end
   endtask

   task error;
      input [MAX_STRING_LENGTH*8:1] msg;
      begin
         $write("\033[0;31mERROR at [%0t]:\033[0m %0s\n", $time, msg);
         nb_error = nb_error + 1;
      end
   endtask

   task fatal;
      input [MAX_STRING_LENGTH*8:1] msg;
      begin
         $write("\033[1;31mFATAL at [%0t]:\033[0m %0s\n", $time, msg);
         $finish;
      end
   endtask

endmodule

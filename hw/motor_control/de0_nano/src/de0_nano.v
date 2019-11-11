module de0_nano
  (input wire CLOCK_50,

   // Led
   output wire [7:0]  LED,

   // Key
   input wire [1:0]   KEY,

   // Switch
   input wire [3:0]   SW,

   // SDRAM
   output wire [12:0] DRAM_ADDR,
   output wire [1:0]  DRAM_BA,
   output wire        DRAM_CAS_N,
   output wire        DRAM_CKE,
   output wire        DRAM_CLK,
   output wire        DRAM_CS_N,
   inout wire [15:0]  DRAM_DQ,
   output wire [1:0]  DRAM_DQM,
   output wire        DRAM_RAS_N,
   output wire        DRAM_WE_N,

   // EPCS
   output wire        EPCS_ASDO,
   input wire         EPCS_DATA0,
   output wire        EPCS_DCLK,
   output wire        EPCS_NCSO,

   // Accelerometer and EEPROM
   output wire        G_SENSOR_CS_N,
   input wire         G_SENSOR_INT,
   output wire        I2C_SCLK,
   inout wire         I2C_SDAT,

   // ADC
   output wire        ADC_CS_N,
   output wire        ADC_SADDR,
   output wire        ADC_SCLK,
   input wire         ADC_SDAT,

   // 2x13 GPIO Header
   inout wire [12:0]  GPIO_2,
   input wire [2:0]   GPIO_2_IN,

   // GPIO_0, GPIO_0 connect to GPIO Default
   inout wire [33:0]  GPIO_0,
   input wire [1:0]   GPIO_0_IN,

   // GPIO_1, GPIO_1 connect to GPIO Default
   inout wire [33:0]  GPIO_1,
   input wire [1:0]   GPIO_1_IN
);

   //----------------------------------------------------
   // Constants
   //----------------------------------------------------

   localparam CLOCK_FREQ              = 50_000_000;
   localparam RESET_CYCLES            = CLOCK_FREQ / 2 - 1;
   localparam LOG2_RESET_CYCLES       = $clog2(RESET_CYCLES + 1);

   localparam SIMPLE_UART_SYSTEM_FREQ = 50_000_000;
   localparam SIMPLE_UART_BAUD_RATE   = 115_200;


   //----------------------------------------------------
   // Reset Management
   //----------------------------------------------------

   reg                             srst;
   reg [LOG2_RESET_CYCLES - 1 : 0] srst_counter;
   wire                            srst_force;

   initial begin
      srst_counter = 0;
      srst         = 1;
   end

   always @(posedge CLOCK_50) begin
      if (srst_force == 1'b1) begin
         srst_counter <= 0;
         srst <= 1'b1;
      end
      else if (srst_counter == RESET_CYCLES[LOG2_RESET_CYCLES - 1 : 0]) begin
         srst <= 1'b0;
      end
      else begin
         srst_counter <= srst_counter + 1'b1;
      end
   end


   //----------------------------------------------------
   // KEYS
   //----------------------------------------------------

   assign srst_force = !KEY[0];


   //----------------------------------------------------
   // LEDS
   //----------------------------------------------------

   // assign LED[0] = srst;
   // assign LED[1] = simple_uart_tx_value_done;
   assign LED = simple_uart_tx_value;


   //----------------------------------------------------
   // GPIO_0
   //----------------------------------------------------

   // We add two FFs on inputs to avoid meta-stability issues.
   reg [33:0] GPIO_0_reg1, GPIO_0_reg2;
   always @(posedge CLOCK_50) begin
      GPIO_0_reg1 <= GPIO_0;
      GPIO_0_reg2 <= GPIO_0_reg1;
   end

   // We add a register on output.
   reg simple_uart_tx_bit_reg;
   always @(posedge CLOCK_50) begin
      simple_uart_tx_bit_reg <= simple_uart_tx_bit;
   end

   // Assign pins
   assign GPIO_0[23] = simple_uart_tx_bit_reg;
   assign simple_uart_rx_bit = GPIO_0_reg2[21];


   //----------------------------------------------------
   // UART
   //----------------------------------------------------

   wire       simple_uart_rx_bit;
   wire       simple_uart_tx_bit;
   wire [7:0] simple_uart_rx_value;
   wire       simple_uart_rx_value_ready;
   reg [7:0]  simple_uart_tx_value;
   reg        simple_uart_tx_value_write;
   wire       simple_uart_tx_value_done;


   simple_uart #(.SYSTEM_FREQ (SIMPLE_UART_SYSTEM_FREQ),
                 .BAUD_RATE   (SIMPLE_UART_BAUD_RATE))

   simple_uart_inst (.clock          (CLOCK_50),
                     .srst           (srst),
                     .rx_bit         (simple_uart_rx_bit),
                     .tx_bit         (simple_uart_tx_bit),
                     .rx_value       (simple_uart_rx_value),
                     .rx_value_ready (simple_uart_rx_value_ready),
                     .tx_value       (simple_uart_tx_value),
                     .tx_value_write (simple_uart_tx_value_write),
                     .tx_value_done  (simple_uart_tx_value_done));

   always @(posedge CLOCK_50) begin
      if (simple_uart_rx_value_ready == 1'b1) begin
         simple_uart_tx_value <= simple_uart_rx_value;
      end
      simple_uart_tx_value_write <= simple_uart_rx_value_ready;
   end

endmodule

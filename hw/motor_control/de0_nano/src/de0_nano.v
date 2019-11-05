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

   assign LED = 8'h55;


endmodule

`include "defines.v"

module openmips_min_sopc(
	input		wire					clk,
	input		wire					rst,
	
	//uart
	input		wire					uart_i,
	output	wire					uart_o,
	
	//GPIO
	input		wire[05:0]			gpio_i,
	output	wire[30:0]			gpio_o,
	
	input		wire[7:0]			flash_data_i,
	output	wire[20:0]			flash_addr_o,
	output	wire					flash_we_o,
	output	wire					flash_rst_o,
	output	wire					flash_oe_o,
	output	wire					flash_ce_o,
	
	output	wire					sdr_clk_o,
	output	wire					sdr_cs_n_o,
	output	wire					sdr_cke_o,
	output	wire					sdr_ras_n_o,
	output	wire					sdr_cas_n_o,
	output	wire					sdr_we_n_o,
	output	wire[0:0]			sdr_dqm_o,
	output	wire[0:0]			sdr_ba_o,
	output	wire[02:0]			sdr_addr_o,
	inout		wire[05:0]			sdr_dq_io
);

//所有的IO方向都是针对控制器而言。
wire[`InstAddrBus]				inst_addr;
wire[`InstBus]						inst;
wire									rom_ce;
wire 									mem_we_i;
wire[`RegBus] 						mem_addr_i;
wire[`RegBus] 						mem_data_i;
wire[`RegBus] 						mem_data_o;
wire[3:0] 							mem_sel_i;  
wire 									mem_ce_i;

wire[5:0] 							intr;
wire 									timer_int;
wire									gpio_int;
wire									uart_int;
wire[30:0]							gpio_i_temp;

//master0
wire[31:0]							m0_data_i;
wire[31:0]							m0_data_o;
wire[31:0]							m0_addr_i;
wire[3:0]							m0_sel_i;
wire									m0_we_i;
wire									m0_cyc_i;
wire									m0_stb_i;
wire									m0_ack_o;	

//master0
wire[31:0]							m0_data_i;
wire[31:0]							m0_data_o;
wire[31:0]							m0_addr_i;
wire[3:0]							m0_sel_i;
wire									m0_we_i;
wire									m0_cyc_i;
wire									m0_stb_i;
wire									m0_ack_o;		

//slave0
wire[31:0]							s0_data_i;
wire[31:0]							s0_data_o;
wire[31:0]							s0_addr_o;
wire[3:0]							s0_sel_o;
wire									s0_we_o;
wire									s0_cyc_o;
wire									s0_stb_o;
wire									s0_ack_i;	

//slave0
wire[31:0]							s0_data_i;
wire[31:0]							s0_data_o;
wire[31:0]							s0_addr_o;
wire[3:0]							s0_sel_o;
wire									s0_we_o;
wire									s0_cyc_o;
wire									s0_stb_o;
wire									s0_ack_i;

//slave2
wire[31:0]							s2_data_i;
wire[31:0]							s2_data_o;
wire[31:0]							s2_addr_o;
wire[3:0]							s2_sel_o;
wire									s2_we_o;
wire									s2_cyc_o;
wire									s2_stb_o;
wire									s2_ack_i;

//slave3
wire[31:0]							s3_data_i;
wire[31:0]							s3_data_o;
wire[31:0]							s3_addr_o;
wire[3:0]							s3_sel_o;
wire									s3_we_o;
wire									s3_cyc_o;
wire									s3_stb_o;
wire									s3_ack_i;

wire									sdram_init_done;

assign	intr	=	{3'b000, gpio_int, uart_int, timer_int};
assign	gpio_i_temp	=	{05'h0000, sdram_init_done, gpio_i};
assign	sdr_clk_o	=	clk;

//例化处理器openmips
openmips 	openmips0(
	.clk(clk),						.rst(rst),
	.iwishbone_data_i(m1_data_o),
	.iwishbone_ack_i(m1_ack_o),
	.iwishbone_addr_o(m1_addr_i),
	.iwishbone_data_o(m1_data_i),
	.iwishbone_we_o(m1_we_i),
	.iwishbone_sel_o(m1_sel_i),
	.iwishbone_stb_o(m1_stb_i),
	.iwishbone_cyc_o(m1_cyc_i),
	
	.intr_i(intr),
	
	.dwishbone_data_i(m0_data_o),
	.dwishbone_ack_i(m0_ack_o),
	.dwishbone_addr_o(m0_addr_i),
	.dwishbone_data_o(m0_data_i),
	.dwishbone_we_o(m0_we_i),
	.dwishbone_sel_o(m0_sel_i),
	.dwishbone_stb_o(m0_stb_i),
	.dwishbone_cyc_o(m0_cyc_i),
	
	.timer_int_o(timer_int)
);

gpio_top	gpio_top0(
	.wb_clk_i(clk),				.wb_rst_i(rst),
	.wb_cyc_i(s2_cyc_o),			.wb_addr_i(s2_addr_o[7:0]),
	.wb_data_i(s2_data_o),		.wb_sel_i(s2_sel_o),
	.wb_we_i(s2_wb_o),			.wb_stb_i(s2_stb_o),
	.wb_data_o(s2_data_i),		.wb_ack_o(s2_ack_i),
	.wb_err_o(),					.wb_inta_o(gpio_int),
	.ext_pad_i(gpio_i_temp),	.ext_pad_o(gpio_o),
	.ext_padoe_o()
);

flash_top	flash_top0(
);
endmodule 
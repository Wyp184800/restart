`include "defines.v"

parameter	aw	=	19;//address-bits
parameter	dw	=	32;//data-bits
parameter	ws	=	4'h3;//wait-states

module	flash_top(
	input		wire				wb_clk_i,
	input		wire				wb_rst_i,
	input		wire[`RegBus]	wb_adr_i,
	output	reg[dw-1:0]		wb_dat_o,
	input		wire[dw-1:0]	wb_dat_i,
	input		wire[3:0]		wb
);
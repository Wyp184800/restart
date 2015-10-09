`include "defines.v"

module openmips(
	input		wire				clk,
	input		wire				rst,
	
	input		wire[`RegBus]	rom_data_i,
	output	wire[`RegBus]	rom_addr_o,
	output	wire				rom_ce_o
);

//连接if_id与id模块的变量
wire[`InstAddrBus]	pc;
wire[`InstAddrBus]	id_pc_i;
wire[`InstBus]			id_inst_i;

//连接id与id_ex模块的变量
wire[`AluOpBus]		id_aluop_o;
wire[`AluSelBus]		id_alusel_o;
wire[`RegBus]			id_reg1_o;
wire[`RegBus]			id_reg2_o;
wire						id_wreg_o;
wire[`RegAddrBus]		id_wd_o;
wire 						id_is_in_delayslot_o;
wire[`RegBus] 			id_link_address_o;	

//连接id_ex与ex模块的变量
wire[`AluOpBus]		ex_aluop_i;
wire[`AluSelBus]		ex_alusel_i;
wire[`RegBus]			ex_reg1_i;
wire[`RegBus]			ex_reg2_i;
wire						ex_wreg_i;
wire[`RegAddrBus]		ex_wd_i;
wire 						ex_is_in_delayslot_i;	
wire[`RegBus] 			ex_link_address_i;	

//连接ex与ex_mem模块的变量
wire						ex_wreg_o;
wire[`RegAddrBus]		ex_wd_o;
wire[`RegBus]			ex_wdata_o;
wire[`RegBus]			ex_hi_o;
wire[`RegBus] 			ex_lo_o;
wire 						ex_whilo_o;

//连接ex_mem与mem模块的变量
wire						mem_wreg_i;
wire[`RegAddrBus]		mem_wd_i;
wire[`RegBus]			mem_wdata_i;
wire[`RegBus] 			mem_hi_i;
wire[`RegBus] 			mem_lo_i;
wire 						mem_whilo_i;		

//连接mem与mem_wb模块的变量
wire						mem_wreg_o;
wire[`RegAddrBus]		mem_wd_o;
wire[`RegBus]			mem_wdata_o;
wire[`RegBus] 			mem_hi_o;
wire[`RegBus] 			mem_lo_o;
wire	 					mem_whilo_o;

//连接mem_wb与wb模块的变量
wire						wb_wreg_i;
wire[`RegAddrBus]		wb_wd_i;
wire[`RegBus]			wb_wdata_i;
wire[`RegBus] 			wb_hi_i;
wire[`RegBus] 			wb_lo_i;
wire 						wb_whilo_i;

//连接id与Regfile模块的变量
wire						reg1_read;
wire						reg2_read;
wire[`RegBus]			reg1_data;
wire[`RegBus]			reg2_data;
wire[`RegAddrBus]		reg1_addr;
wire[`RegAddrBus]		reg2_addr;

//连接执行阶段与hilo模块的输出，读取HI、LO寄存器
wire[`RegBus]			hi;
wire[`RegBus]			lo;

//连接执行阶段与ex_reg模块，用于多周期的MADD、MADDU、MSUB、MSUBU指令
wire[`DoubleRegBus] 	hilo_temp_o;
wire[1:0] 				cnt_o;
	
wire[`DoubleRegBus] 	hilo_temp_i;
wire[1:0] 				cnt_i;

//跳转与分支指令
wire 						is_in_delayslot_i;
wire 						is_in_delayslot_o;
wire 						next_inst_in_delayslot_o;
wire 						id_branch_flag_o;
wire[`RegBus] 			branch_target_address;

wire[5:0] stall;
wire stallreq_from_id;	
wire stallreq_from_ex;

//pc_reg例化
pc_reg	pc_reg0(
	.clk(clk),							.rst(rst),			
	.pc(pc),								.stall(stall),
	.ce(rom_ce_o),						.branch_flag_i(id_branch_flag_o),
	.branch_target_address_i(branch_target_address)
);

assign rom_addr_o = pc;//指令存储器的输入地址就是pc值

//if_id模块例化
if_id		if_id0(
	.clk(clk),	.rst(rst),			.if_pc(pc),
	.if_inst(rom_data_i),			.id_pc(id_pc_i),
	.id_inst(id_inst_i),				.stall(stall)
);

//id模块例化
id			id0(
	.rst(rst),	.pc_i(id_pc_i),	.inst_i(id_inst_i),
	
	//来自Regfile模块的输入
	.reg1_data_i(reg1_data),		.reg2_data_i(reg2_data),
	
	//处于执行阶段的指令要写入的目的寄存器信息
	.ex_wreg_i(ex_wreg_o),
	.ex_wdata_i(ex_wdata_o),
	.ex_wd_i(ex_wd_o),

   //处于访存阶段的指令要写入的目的寄存器信息
	.mem_wreg_i(mem_wreg_o),
	.mem_wdata_i(mem_wdata_o),
	.mem_wd_i(mem_wd_o),
	.is_in_delayslot_i(is_in_delayslot_i),

	
	//送到Regfile模块的信息
	.reg1_read_o(reg1_read),		.reg2_read_o(reg2_read),
	.reg1_addr_o(reg1_addr),		.reg2_addr_o(reg2_addr),
	
	//送到id_ex模块的信息
	.aluop_o(id_aluop_o),			.alusel_o(id_alusel_o),
	.reg1_o(id_reg1_o),				.reg2_o(id_reg2_o),
	.wd_o(id_wd_o),					.wreg_o(id_wreg_o),
	.next_inst_in_delayslot_o(next_inst_in_delayslot_o),	
	.branch_flag_o(id_branch_flag_o),
	.branch_target_address_o(branch_target_address),       
	.link_addr_o(id_link_address_o),
		
	.is_in_delayslot_o(id_is_in_delayslot_o),
	
	.stallreq(stallreq_from_id)
);

//Regfile模块例化
regfile	regfile1(
	.clk(clk),							.rst(rst),
	.we(wb_wreg_i),					.waddr(wb_wd_i),
	.wdata(wb_wdata_i),				.re1(reg1_read),
	.raddr1(reg1_addr),				.rdata1(reg1_data),
	.re2(reg2_read),					.raddr2(reg2_addr),
	.rdata2(reg2_data)
);

//id_ex模块例化
id_ex		id_ex0(
	.clk(clk),							.rst(rst),
	.stall(stall),
	
	//从id模块传递过来的信息
	.id_aluop(id_aluop_o),			.id_alusel(id_alusel_o),
	.id_reg1(id_reg1_o),				.id_reg2(id_reg2_o),
	.id_wd(id_wd_o),					.id_wreg(id_wreg_o),
	.id_link_address(id_link_address_o),
	.id_is_in_delayslot(id_is_in_delayslot_o),
	.next_inst_in_delayslot_i(next_inst_in_delayslot_o),		
	
	//送到ex模块的信息
	.ex_aluop(ex_aluop_i),			.ex_alusel(ex_alusel_i),
	.ex_reg1(ex_reg1_i),				.ex_reg2(ex_reg2_i),
	.ex_wd(ex_wd_i),					.ex_wreg(ex_wreg_i),
	.ex_link_address(ex_link_address_i),
  	.ex_is_in_delayslot(ex_is_in_delayslot_i),
	.is_in_delayslot_o(is_in_delayslot_i)	
);

//ex模块例化
ex			ex0(
	.rst(rst),
	
	//从id_ex模块传递过来的信息
	.aluop_i(ex_aluop_i),			.alusel_i(ex_alusel_i),
	.reg1_i(ex_reg1_i),				.reg2_i(ex_reg2_i),
	.wd_i(ex_wd_i),					.wreg_i(ex_wreg_i),
	.hi_i(hi),							.lo_i(lo),
	
	.wb_hi_i(wb_hi_i),				.wb_lo_i(wb_lo_i),
	.wb_whilo_i(wb_whilo_i),		.mem_hi_i(mem_hi_o),
	.mem_lo_i(mem_lo_o),				.mem_whilo_i(mem_whilo_o),
	
	.hilo_temp_i(hilo_temp_i),		.cnt_i(cnt_i),
	
	.link_address_i(ex_link_address_i),
	.is_in_delayslot_i(ex_is_in_delayslot_i),
	
	//输出到ex_mem模块的信息
	.wd_o(ex_wd_o),					.wreg_o(ex_wreg_o),
	.wdata_o(ex_wdata_o),			.hi_o(ex_hi_o),
	.lo_o(ex_lo_o),					.whilo_o(ex_whilo_o),
	
	.hilo_temp_o(hilo_temp_o),		.cnt_o(cnt_o),
	
	.stallreq(stallreq_from_ex)
);

//ex_mem模块例化
ex_mem	ex_mem0(
	.clk(clk),							.rst(rst),
	.stall(stall),
	
	//来自ex模块的信息
	.ex_wd(ex_wd_o),					.ex_wreg(ex_wreg_o),
	.ex_wdata(ex_wdata_o),			.ex_hi(ex_hi_o),
	.ex_lo(ex_lo_o),					.ex_whilo(ex_whilo_o),	
	
	.hilo_i(hilo_temp_o),			.cnt_i(cnt_o),
	
	//送到mem阶段的信息
	.mem_wd(mem_wd_i),				.mem_wreg(mem_wreg_i),
	.mem_wdata(mem_wdata_i),		.mem_hi(mem_hi_i),
	.mem_lo(mem_lo_i),				.mem_whilo(mem_whilo_i),		
	
	.hilo_o(hilo_temp_i),			.cnt_o(cnt_i)
);

//mem模块例化
mem		mem0(
	.rst(rst),
	
	//来自ex_mem模块的信息
	.wd_i(mem_wd_i),					.wreg_i(mem_wreg_i),
	.wdata_i(mem_wdata_i),			.hi_i(mem_hi_i),
	.lo_i(mem_lo_i),					.whilo_i(mem_whilo_i),	
	
	//送到mem_wb模块的信息
	.wd_o(mem_wd_o),					.wreg_o(mem_wreg_o),
	.wdata_o(mem_wdata_o),			.hi_o(mem_hi_o),
	.lo_o(mem_lo_o),					.whilo_o(mem_whilo_o)
);

//mem_wb模块例化
mem_wb	mem_wb0(
	.clk(clk),							.rst(rst),
	.stall(stall),
	
	//来自mem模块的信息
	.mem_wd(mem_wd_o),				.mem_wreg(mem_wreg_o),
	.mem_wdata(mem_wdata_o),		.mem_hi(mem_hi_o),
	.mem_lo(mem_lo_o),				.mem_whilo(mem_whilo_o),	
	
	//送到wb阶段的信息
	.wb_wd(wb_wd_i),					.wb_wreg(wb_wreg_i),
	.wb_wdata(wb_wdata_i),			.wb_hi(wb_hi_i),
	.wb_lo(wb_lo_i),					.wb_whilo(wb_whilo_i)
);

//hilo_reg模块例化
hilo_reg hilo_reg0(
	.clk(clk),							.rst(rst),
	
	//写端口
	.we(wb_whilo_i),					.hi_i(wb_hi_i),
	.lo_i(wb_lo_i),
	
	//读端口1
	.hi_o(hi),							.lo_o(lo)
);

//ctrl模块例化
ctrl	ctr0(
	.rst(rst),							
	
	.stallreq_from_id(stallreq_from_id),
	
	.stallreq_from_ex(stallreq_from_ex),
	
	.stall(stall)
);

endmodule

`include "defines.v"

module mem(
	input		wire					rst,
	
	//从执行阶段传递过来的信息
	input		wire[`RegAddrBus]	wd_i,
	input		wire					wreg_i,
	input		wire[`RegBus]		wdata_i,
	input		wire[`RegBus]		hi_i,
	input		wire[`RegBus]		lo_i,
	input		wire					whilo_i,
	input		wire[`AluOpBus]	aluop_i,
	input		wire[`RegBus]		mem_addr_i,
	input		wire[`RegBus]		reg2_i,
	
	//来自数据RAM的信息
	input		wire[`RegBus]		mem_data_i,
	
	//送到外部RAM的信息
	output	reg[`RegBus]		mem_addr_o,
	output	reg					mem_we_o,
	output	reg[3:0]				mem_sel_o,
	output	reg[`RegBus]		mem_data_o,
	output	reg					mem_ce_o,
	
	//送到访存阶段的结果
	output	reg[`RegAddrBus]	wd_o,
	output	reg					wreg_o,
	output	reg[`RegBus]		wdata_o,
	output	reg[`RegBus]		hi_o,
	output	reg[`RegBus]		lo_o,
	output	reg					whilo_o
);

wire[`RegBus]	zero32;
reg				mem_we;

assign	mem_we_o	=	mem_we;					//外部RAM的读写信号
assign	zero32	=  `ZeroWord;

always	@	(*)	begin
	if(rst == `RstEnable)	begin
		wd_o		<=	`NOPRegAddr;
		wreg_o	<=	`WriteDisable;
		wdata_o	<=	`ZeroWord;
		hi_o		<= `ZeroWord;
		lo_o		<= `ZeroWord;
		whilo_o	<= `WriteDisable;
		mem_addr_o	<= `ZeroWord;
		mem_we	<= `WriteDisable;
		mem_sel_o	<= 4'b0000;
		mem_data_o	<= `ZeroWord;
		mem_ce_o	<= `ChipDisable;
	end	else	begin
		wd_o		<=	wd_i;
		wreg_o	<=	wreg_i;
		wdata_o	<=	wdata_i;
		hi_o		<= hi_i;
		lo_o		<= lo_i;
		whilo_o	<= whilo_i;
		mem_we	<= `WriteDisable;
		mem_addr_o	<= `ZeroWord;
		mem_sel_o	<= 4'b1111;
		mem_ce_o		<= `ChipDisable;
		case(aluop_i)
			`EXE_LB_OP:begin
				mem_addr_o	<= mem_addr_i;
				mem_we		<= `WriteDisable;
				mem_ce_o		<= `ChipDisable;
				case(mem_addr_i[1:0])
					2'b00:begin
						wdata_o	<= {{24{mem_data_i[31]}}, mem_data_i[31:24]};
						mem_sel_o	<= 4'b1000;
					end
					2'b01:begin
						wdata_o	<=	{{24{mem_data_i[23]}}, mem_data_i[23:16]};
						mem_sel_o	<= 4'b0100;
					end
					2'b10:begin
						wdata_o	<= {{24{mem_data_i[15]}}, mem_data_i[15:8]};
						mem_sel_o	<= 4'b0010;
					end
					2'b11:begin
						wdata_o	<= {{24{mem_data_i[7]}}, mem_data_i[7:0]};
						mem_sel_o	<= 4'b0001;
					end
					default:begin
						wdata_o	<= `ZeroWord;
					end
				endcase
			end
			`EXE_LBU_OP:begin
				mem_addr_o	<= mem_addr_i;
				mem_we		<= `WriteDisable;
				mem_ce_o		<= `ChipDisable;
				case(mem_addr_i[1:0])
					2'b00:begin
						wdata_o	<= {{24{1'b0}}, mem_data_i[31:24]};
						mem_sel_o	<= 4'b1000;
					end
					2'b01:begin
						wdata_o	<=	{{24{1'b0}}, mem_data_i[23:16]};
						mem_sel_o	<= 4'b0100;
					end
					2'b10:begin
						wdata_o	<= {{24{1'b0}}, mem_data_i[15:8]};
						mem_sel_o	<= 4'b0010;
					end
					2'b11:begin
						wdata_o	<= {{24{1'b0}}, mem_data_i[7:0]};
						mem_sel_o	<= 4'b0001;
					end
					default:begin
						wdata_o	<= `ZeroWord;
					end
				endcase
			end
			`EXE_LH_OP:begin
				mem_addr_o	<= mem_addr_i;
				mem_we		<= `WriteDisable;
				mem_ce_o		<= `ChipEnable;
				case(mem_addr_i[1:0])
					2'b00:begin
						wdata_o	<= {{16{mem_data_i[31]}}, mem_data_i[31:16]};
						mem_sel_o	<= 4'b1100;
					end
					2'b10:begin
						wdata_o	<= {{16{mem_data_i[15]}}, mem_data_i[15:0]};
						mem_sel_o	<= 4'b0011;
					end
					default:begin
						wdata_o	<= `ZeroWord;
					end
				endcase
			end
			`EXE_LHU_OP:begin
				mem_addr_o	<= mem_addr_i;
				mem_we		<= `WriteDisable;
				mem_ce_o		<= `ChipEnable;
				case(mem_addr_i[1:0])
					2'b00:begin
						wdata_o	<= {{16{1'b0}}, mem_data_i[31:16]};
						mem_sel_o	<= 4'b1100;
					end
					2'b10:begin
						wdata_o	<= {{16{1'b0}}, mem_data_i[15:0]};
						mem_sel_o	<= 4'b0011;
					end
					default:begin
						wdata_o	<= `ZeroWord;
					end
				endcase
			end
	end
end

endmodule

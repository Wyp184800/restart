`include "defines.v"

module cp0_reg(
	input		wire				clk,
	input		wire				rst,
	
	input		wire				we_i,
	input		wire[4:0]		waddr_i,
	input		wire[4:0]		raddr_i,
	input		wire[`RegBus]	data_i,
	
	input		wire[5:0]		int_i,
	input		wire[31:0]		excepttype_i,
	input		wire[`RegBus]	currengt_inst_address_i,
	input		wire				is_in_delayslot_i,
	
	output	reg[`RegBus]	data_o,
	output	reg[`RegBus]	count_o,
	output	reg[`RegBus]	compare_o,
	output	reg[`RegBus]	status_o,
	output	reg[`RegBus]	cause_o,
	output	reg[`RegBus]	epc_o,
	output	reg[`RegBus]	config_o,
	output	reg[`RegBus]	prid_o,
	
	output	reg				timer_int_o
);

/*第一段，对CP0中的据存期的写操作*/

always	@	(posedge	clk)	begin
	if(rst == `RstEnable)	begin
		//Count寄存器的初始值0
		count_o		<= `ZeroWord;
		
		//Compare寄存器的初始值0
		compare_o	<= `ZeroWord;
		
		//Status寄存器的初始值，CU字段0001，表示CP0存在
		status_o		<= 32'b00010000000000000000000000000000;
		
		//Cause寄存器的初始值0
		cause_o		<= `ZeroWord;
		
		//EPC寄存器的初始值0
		epc_o			<=	`ZeroWord;
		
		//Config寄存器的初始值,BE字段为1，表示工作在大端模式
		config_o		<= 32'b00000000000000001000000000000000;
		
		//PRid寄存器的初始值
		prid_o	<=	32'b00000000010011000000000100000010;
		
		timer_int_o	<= `InterruptNotAssert;
	end	else	begin
		count_o	<= count_o + 1;		//Count寄存器的值在每个时钟周期+1
		cause_o[15:10]	<= int_i;		//Cause寄存器的[15:10]保存外部中断声明
		
		//当Compare寄存器不为0，且Count寄存器的值等于Compare寄存器的值，时钟中断发生
		if(compare_o != `ZeroWord && count_o == compare_o)	begin
			timer_int_o <= `InterruptAssert;
		end
		
		if(we_i == `WriteEnable)	begin
			case(waddr_i)
				`CP0_REG_COUNT:begin
					count_o	<= data_i;
				end
				`CP0_REG_COMPARE:begin
					compare_o	<= data_i;
					timer_int_o	<=	`InterruptNotAssert;
				end
				`CP0_REG_STATUS:begin
					status_o	<= data_i;
				end
				`CP0_REG_EPC:begin
					epc_o	<= data_i;
				end
				`CP0_REG_CAUSE:begin
					cause_o[9:8]	<= data_i[9:8];
					cause_o[23:22]	<= data_i[23:22];
				end
			endcase		//case addri
		end		//if(we_i == `WriteEnable)
		
		case(excepttype_i)
			32'h00000001:begin
				if(is_in_delayslot_i == `InDelaySlot)	begin
					epc_o	<= currengt_inst_addr_i - 4;
					cause_o[31]	<= 1'b1;
				end	else	begin
					epc_o	<= currengt_inst_addr_i;
					cause_o[31]	<= 1'b0;
				end
				status_o[1]	<= 1'b1;
				cause_o[6:2]	<= 5'b00000;
			end
			32'h00000008:begin
				if(status_o[1] == 1'b0)	begin
					if(is_in_delayslot_i == `InDelaySlot)	begin
						epc_o	<=	currengt_inst_addr_i - 4;
						cause_o[31]	<= 1'b1;
					end	else	begin
						epc_o	<= currengt_inst_addr_i;
						cause_o[30]	<= 1'b0;
					end
				end
				status_o[1]	<= 1'b1;
				cause_o[6:2]	<= 5'b01000;
			end
			32'h0000000a:begin
				if(status_o[1] <= 1'b0)	begin
					if(is_in_delayslot_i	== `InDelaySlot)	begin
						epc_o	<= currengt_inst_addr_i - 4;
						cause_o[31]	<= 1'b1;
					end	else	begin
						epc_o	<= currengt_inst_addr_i;
						cause_o[31]	<= 1'b0;
					end
				end
				status_o[1]	<= 1'b1;
				cause_o[6:2]	<= 5'b01010;
			end
			32'h0000000d:begin
				if(status_o[1]	== 1'b0)	begin
					if(is_in_delayslot_i	== `InDelaySlot)	begin
						epc_o	<= currengt_inst_addr_i - 4;
						cause_o[31]	<= 1'b1;
					end	else	begin
						epc_o	<= currengt_inst_addr_i;
						cause_o[31]	<= 1'b0;
					end
				end
				status_o[1]	<=1'b1;
				cause_o[6:2]	<=5'b01101;
			end
			32'h0000000c:begin
				if(status_o[1]	== 1'b0)	begin
					if(is_in_delayslot_i == `InDelaySlot)	begin
						epc_o	<= currengt_inst_addr_i - 4;
						cause_o[31]	<= 1'b1;
					end	else	begin
						epc_o	<= currengt_inst_addr_i;
						cause_o[31]	<= 1'b0;
					end
				end
				status_o[1]	<= 1'b1;
				cause_o[6:2]	<= 5'b01100;
			end
			32'h0000000e:begin
				status_o[1]	<= 1'b0;
			end
			default:begin
			end
		endcase
	end		//if
end

/*第二段，对CP0中寄存器的读操作*/

always	@	(*)	begin
	if(rst == `RstEnable)	begin
		data_o	<= `ZeroWord;
	end	else	begin
		case(raddr_i)
			`CP0_REG_COUNT:begin
				data_o	<= count_o;
			end
			`CP0_REG_COMPARE:begin
				data_o	<= compare_o;
			end
			`CP0_REG_STATUS:begin
				data_o	<= status_o;
			end
			`CP0_REG_CAUSE:begin
				data_o	<= cause_o;
			end
			`CP0_REG_EPC:begin
				data_o	<= epc_o;
			end
			`CP0_REG_PRid:begin
				data_o	<= prid_o;
			end
			`CP0_REG_CONFIG:begin
				data_o	<= config_o;
			end
			default:begin
				data_o	<= `ZeroWord;
			end
		endcase
	end		//if
end

endmodule 
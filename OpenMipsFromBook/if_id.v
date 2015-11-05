`include "defines.v"

module if_id(
	input		wire						clk,
	input		wire 						rst,
	input		wire[5:0]				stall,
	input		wire						flush,
	
	//来自取指阶段的信号，其中宏定义InstBus表示指令宽度，为32
	input		wire[`InstAddrBus]	if_pc,
	input		wire[`InstBus]			if_inst,
	
	//对应译码阶段的信号
	output	reg[`InstAddrBus]		id_pc,
	output	reg[`InstBus]			id_inst
);

always	@	(posedge	clk)	begin
	if(rst == `RstEnable)	begin
		id_pc		<= `ZeroWord;						//复位时pc为0
		id_inst 	<= `ZeroWord;						//复位时指令也为0，也就是nop
	end	else	begin
		if(flush == 1'b1)	begin
			id_pc		<= `ZeroWord;
			id_inst	<= `ZeroWord;
		end else
		if(stall[1] == `Stop && stall[2] == `NoStop)	begin	//流水线暂停时不传递指令
			id_pc		<=	`ZeroWord;
			id_inst	<= `ZeroWord;
		end	else
		if(stall[1] == `NoStop)	begin
			id_pc 	<= if_pc;							//其余时刻向下传递取指阶段的值
			id_inst  <= if_inst;
		end
	end
end

endmodule		
		
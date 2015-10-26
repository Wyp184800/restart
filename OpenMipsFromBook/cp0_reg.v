`include "defines.v"

module cp0(
	input		wire				clk,
	input		wire				rst,
	
	input		wire				we_i,
	input		wire[4:0]		waddr_i,
	input		wire[4:0]		raddri,
	input		wire[`RegBus]	data_i,
	
	input		wire[5:0]		int_i,
	
	output	reg[`RegBus]	data_o,
	output	reg[`RegBus]	count_o,
	output	reg[`RegBus]	compare_o,
	output	reg[`RegBus]	status_o,
	output	reg[`RegBus]	cause_o,
	output	reg{`RegBus}	epc_o,
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
		status_o		<= 8'h10000000;
		
		//Cause寄存器的初始值0
		cause_o		<= `ZeroWord;
		
		//EPC寄存器的初始值0
		epc_o			<=	`ZeroWord;
		
		//Config寄存器的初始值,BE字段为1，表示工作在大端模式
		config_o		<= 8'h00008000;
		
		//PRId寄存器的初始值
		prid_o	<=	8'h004c00;
		
		timer_int_o	<= `InterruptNotAssert;
	end	else	begin
		count_o	<= count_o + 1;		//Count寄存器的值在每个时钟周期+1
		cause_o[15:10]	<= int_i;		//Cause寄存器的[15:10]保存外部中断声明
		
		//当Compare寄存器不为0，且Count寄存器的值等于Compare寄存器的值，时钟中断发生
		if
end

/*第二段，对CP0中寄存器的读操作*/

always	@	(*)	begin

end

endmodule 
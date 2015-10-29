`include "defines.v"

module ex(
	input		wire 				rst,
	
	//译码阶段传递过来的信息
	input		wire[`AluOpBus]	aluop_i,
	input		wire[`AluSelBus]	alusel_i,
	input		wire[`RegBus]		reg1_i,
	input		wire[`RegBus]		reg2_i,
	input		wire[`RegAddrBus]	wd_i,
	input		wire					wreg_i,
	input		wire[`RegBus]		inst_i,
	
	//执行的结果	
	output	reg[`RegAddrBus]	wd_o,
	output	reg					wreg_o,
	output	reg[`RegBus]		wdata_o,
	output	wire[`AluOpBus]	aluop_o,
	output	wire[`RegBus]		mem_addr_o,
	output	wire[`RegBus]		reg2_o,
	
	//HILO模块给出的寄存器值
	input		wire[`RegBus]		hi_i,
	input		wire[`RegBus]		lo_i,
	
	//回写阶段指令是否要写HILO，用于检测HILO寄存器带来的数据相关问题
	input		wire[`RegBus]		wb_hi_i,
	input		wire[`RegBus]		wb_lo_i,
	input		wire					wb_whilo_i,
	
	//访存阶段指令是否要写HILO，用于检测HILO寄存器带来的数据相关问题
	input		wire[`RegBus]		mem_hi_i,
	input		wire[`RegBus]		mem_lo_i,
	input		wire					mem_whilo_i,
	
	//执行阶段的指令对HILO寄存器的写操作请求
	output	reg[`RegBus]		hi_o,
	output	reg[`RegBus]		lo_o,
	output	reg					whilo_o,
	
	//流水线暂停请求
	output 	reg                stallreq,

	//累乘加，累乘减指令寄存器输入
	input		wire[`DoubleRegBus]	hilo_temp_i,
	input		wire[1:0]			cnt_i,
	
	//累乘加，累乘减指令寄存器输出
	output	reg[`DoubleRegBus]	hilo_temp_o,
	output	reg[1:0]				cnt_o,
	
	//来自除法模块的输入
	input		wire[`DoubleRegBus]	div_result_i,
	input		wire					div_ready_i,
	
	//送到除法模块的输出
	output	reg[`RegBus]		div_opdata1_o,
	output	reg[`RegBus]		div_opdata2_o,
	output	reg					div_start_o,
	output	reg					signed_div_o,
	
	//branch相关
	input		wire[`RegBus]		link_address_i,
	input		wire					is_in_delayslot_i,
	
	//访存阶段的指令是否要写CP0的寄存器
	input		wire					mem_cp0_reg_we,
	input		wire[4:0]			mem_cp0_reg_waddr,
	input		wire[`RegBus]		mem_cp0_reg_data,
	
	//回写阶段的指令是否要写CP0的寄存器
	input		wire					wb_cp0_reg_we,
	input		wire[4:0]			wb_cp0_reg_waddr,
	input		wire[`RegBus]		wb_cp0_reg_data,
	
	//与CP0相连，读取指定寄存器的值
	input		wire[`RegBus]			cp0_reg_data_i,
	output	reg[4:0]				cp0_reg_raddr_o,
	
	//向流水线下一级传递，用于写CP0的寄存器
	output	reg					cp0_reg_we_o,
	output	reg[4:0]				cp0_reg_waddr_o,
	output	reg[`RegBus]		cp0_reg_data_o
);

reg[`RegBus]	logicout;							//逻辑操作的结果
reg[`RegBus]	shiftres;							//移位操作的结果
reg[`RegBus]	moveres;								//移动操作的结果
reg[`RegBus]	arithmeticres;						//保存算数运算的结果
reg[`RegBus]	HI;									//保存HI寄存器的最新值
reg[`RegBus]	LO;									//保存LO寄存器的最新值

wire				ov_sum;								//保存溢出情况
wire				reg1_eq_reg2;						//第一个操作数是否等于第二个操作数
wire				reg1_lt_reg2;						//第一个操作数是否小于第二个操作数
wire[`RegBus]	reg2_i_mux;							//保存输入的第二个操作数reg2_i的补码
wire[`RegBus]	reg1_i_not;							//保存输入的第一个操作数reg1_i取反后的值
wire[`RegBus]	result_sum;							//保存加法结果
wire[`RegBus]	opdata1_mult;						//乘法操作中的被乘数
wire[`RegBus]	opdata2_mult;						//乘法操作中的乘数
wire[`DoubleRegBus]	hilo_temp;					//临时保存乘法结果，宽度64
reg[`DoubleRegBus]	hilo_temp1;
reg[`DoubleRegBus]	mulres;						//保存乘法结果，宽度64
reg				stallreq_for_madd_msub;
reg				stallreq_for_div;					//由除法运算导致流水线暂停

//aluop_o会传递到访存阶段，解释将利用其确定加载，存储类型
assign	aluop_o = aluop_i;

//mem_addr_o会传递到访存阶段，是加载，存储指令对应的存储器地址，此处的reg1_i就是指令中地址为base的通用寄存器的值，inst_i[15:0]就是指令中的offset
assign	mem_addr_o = reg1_i + {{16{inst_i[15]}}, inst_i[15:0]};

//reg2_i是存储指令要存储的数据，或者lwl,lwr指令要加载到目的寄存器的原始值，通过reg2_o传递到访存阶段
assign	reg2_o = reg2_i;

/*第一段，根据aluop_i指示的运算子类型进行运算*/

always	@	(*)	begin								//逻辑运算
	if(rst == `RstEnable)	begin
		logicout	<= `ZeroWord;
	end	else 	begin
		case	(aluop_i)
			`EXE_OR_OP:begin
				logicout <= reg1_i | reg2_i;		//或
			end
			`EXE_AND_OP:begin
				logicout <= reg1_i & reg2_i;		//与
			end
			`EXE_NOP_OP:begin
				logicout <= ~(reg1_i | reg2_i);	//或非
			end
			`EXE_XOR_OP:begin
				logicout <= reg1_i ^ reg2_i;		//异或
			end
			default:begin
				logicout <= `ZeroWord;
			end
		endcase
	end												//if
end													//always

always	@	(*)	begin
	if(rst == `RstEnable)	begin
		shiftres	<= `ZeroWord;
	end	else 	begin
		case	(aluop_i)
			`EXE_SLL_OP:begin
				shiftres	<= reg2_i << reg1_i[4:0];
			end
			`EXE_SRL_OP:begin
				shiftres	<= reg2_i >> reg1_i[4:0];
			end
			`EXE_SRA_OP:begin
				shiftres	<= ({32{reg2_i[31]}} << (6'd32-{1'b0,reg1_i[4:0]})) | reg2_i >> reg1_i[4:0];
			end
			default:begin
				shiftres <= `ZeroWord;
			end
		endcase
	end												//if
end				

/*第二段，根据alusel_i指示的运算类型，选择一个运算结果作为最终结果*/

always 	@	(*)	begin
	wd_o		<= wd_i;								//wd_o等于wd_i，要写的目的寄存器地址
	
	//如果是add,addi,sub,subi指令，且溢出发生，那么设置wreg_o为WriteDisable，表示不写目的寄存器
	if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) ||
		(aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1))	begin
			wreg_o <= `WriteDisable;
	end	else	begin
		wreg_o <= wreg_i;
	end
	case	(alusel_i)
		`EXE_RES_LOGIC:begin
			wdata_o	<=	logicout;				//wdata_o中存放运算结果
		end
		`EXE_RES_SHIFT:begin	
			wdata_o	<= shiftres;
		end
		`EXE_RES_MOVE:begin
			wdata_o	<= moveres;
		end
		`EXE_RES_ARITHMETIC:begin				//除乘法外的简单算术操作指令
			wdata_o	<= arithmeticres;
		end
		`EXE_RES_MUL:begin						//乘法指令
			wdata_o	<= mulres[31:0];		
		end
		`EXE_RES_JUMP_BRANCH:begin
			wdata_o	<= link_address_i;
		end
		default:begin
			wdata_o	<=	`ZeroWord;
		end
	endcase
end

/*第三段，得到最新的HI,LO寄存器的值，此处要解决数据相关问题*/

always	@	(*)	begin
	if(rst == `RstEnable)	begin
		{HI,LO}	<= {`ZeroWord,`ZeroWord};
	end	else	
	if(mem_whilo_i == `WriteEnable)	begin
		{HI,LO}	<= {mem_hi_i,mem_lo_i};		//访存阶段的指令要写HI,LO寄存器
	end	else
	if(wb_whilo_i	== `WriteEnable)	begin
		{HI,LO}	<= {wb_hi_i,wb_lo_i};		//回写阶段的指令要写HI,LO寄存器
	end 	else	begin
		{HI,LO}	<= {hi_i,lo_i};
	end
end

/*第四段，MFHI,MFLO,MOVN,MOVZ指令,获得CP0指定寄存器的值*/

always	@	(*)	begin
	if(rst == `RstEnable)	begin
		moveres	<= `ZeroWord;
	end	else	begin
		moveres	<= `ZeroWord;
		case(aluop_i)
			`EXE_MFHI_OP:begin
				moveres	<= HI;
			end
			`EXE_MFLO_OP:begin
				moveres	<= LO;
			end
			`EXE_MOVZ_OP:begin
				moveres	<= reg1_i;
			end
			`EXE_MOVN_OP:begin
				moveres	<= reg1_i;
			end
			`EXE_MFC0_OP:begin
				moveres	<= cp0_reg_data_i;
				cp0_reg_raddr_o	<=	inst_i[15:11];
				if(mem_cp0_reg_we == `WriteEnable && mem_cp0_reg_waddr == inst_i[15:11])	begin
					moveres	<= mem_cp0_reg_data;
				end	else	
				if(wb_cp0_reg_we == `WriteEnable && wb_cp0_reg_waddr == inst_i[15:11])	begin
					moveres	<= wb_cp0_reg_data;
				end
			end
			default:begin
			end
		endcase
	end
end

/*第五段，计算以下五个变量的值*/
//如果是减法或者有符号比较运算，那么reg2_i_mux就是第二个操作数reg2_i的补码，否则就是reg2_i本身

assign reg2_i_mux	=	((aluop_i == `EXE_SUB_OP) || 
							(aluop_i == `EXE_SUBU_OP) ||
							(aluop_i == `EXE_SLT_OP)) ?
							(~reg2_i)+1 : reg2_i;
							
//分三种情况：
//如果是加法运算，此时reg2_i_mux就是第二个操作数reg2_i，所以result_sum就是加法运算的结果
//如果是减法运算，此时reg2_i_mux就是第二个操作数reg2_i的补码，所以result_sum就是减法运算的结果
//如果是有符号比较运算，此时reg2_i_mux也是第二个操作数reg2_i的补码，所以result_sum也是减法运算的结果，根据结果是否小于0，进而判断两个操作数的大小

assign result_sum	=	reg1_i+reg2_i_mux;

//计算是否溢出。加法指令和减法指令执行的时候，需要判断是否溢出，满足以下两种情况之一时，有溢出：
//reg1_i为整数，reg2_i_mux为整数，但两者之和为负数，
//reg1_i为负数，reg2_i_mux为负数，但两者之和为正数

assign ov_sum	=	((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || 
						((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));
						
//计算操作数1是否小于操作数2，分两种情况：
//	aluop_i为EXE_SLT_OP表示有符号比较运算，又分三种情况
//		reg1_i为负数，reg2_i为正数，显然reg1_i小于reg2_i
//		reg1_i为正数，reg2_i为正数，差小于0，此时reg1_i小于reg2_i
//		reg1_i为负数，reg2_i为负数，差小于0，此时也有reg1_i小于reg2_i
//	 无符号数比较时，直接使用比较运算符比较reg1_i和reg2_i

assign reg1_lt_reg2	=	(aluop_i == `EXE_SLT_OP) ? 
								((reg1_i[31] && !reg2_i[31]) ||
								(!reg1_i[31] && !reg2_i[31] && result_sum[31]) ||
								(reg1_i[31]  && reg2_i[31] && result_sum[31])) :
								(reg1_i < reg2_i);
								
//对操作数1逐位取反，赋给reg1_i_not

assign reg1_i_not	= ~reg1_i;

/*第六段，根据不同的算数运算类型，给arithmeticres变量赋值*/

always	@	(*)	begin
	if(rst == `RstEnable) begin
		arithmeticres	<= `ZeroWord;
	end 	else	begin
		case(aluop_i)
			`EXE_SLT_OP,`EXE_SLTU_OP:begin
				arithmeticres 	<= reg1_lt_reg2;		//比较
			end
			`EXE_ADD_OP,`EXE_ADDU_OP,`EXE_ADDI_OP,`EXE_ADDIU_OP:begin
				arithmeticres 	<= result_sum;
			end
			`EXE_SUB_OP,`EXE_SUBU_OP:begin
				arithmeticres	<= result_sum;
			end
			`EXE_CLZ_OP:begin
				arithmeticres	<= reg1_i[31] 	? 0 	: reg1_i[30] 	? 1 	:
										reg1_i[29] 	? 2 	: reg1_i[28] 	? 3 	:
										reg1_i[27] 	? 4 	: reg1_i[26] 	? 5 	:
										reg1_i[25] 	? 6 	: reg1_i[24] 	? 7 	:
										reg1_i[23] 	? 8 	: reg1_i[22] 	? 9	:
										reg1_i[21] 	? 10	: reg1_i[20] 	? 11	:
										reg1_i[19]	? 12	: reg1_i[18] 	? 13	:
										reg1_i[17]	? 14	: reg1_i[16]	? 15	:
										reg1_i[15]	? 16	: reg1_i[14]	? 17	:
										reg1_i[13]	? 18	: reg1_i[12]	? 19	:
										reg1_i[11]	? 20	: reg1_i[10]	? 21	:
										reg1_i[9]	? 22	: reg1_i[8]		? 23	:
										reg1_i[7]	? 24	: reg1_i[6]		? 25	:
										reg1_i[5]	? 26	: reg1_i[4]		? 27	:
										reg1_i[3]	? 28	: reg1_i[2]		? 29	:
										reg1_i[1]	? 30	: reg1_i[0]		? 31	:	32;
			end
			`EXE_CLO_OP:begin
				arithmeticres	<= reg1_i_not[31]	? 0	: reg1_i_not[30] 	? 1 	:
										reg1_i_not[29]	? 2	: reg1_i_not[28] 	? 3 	: 
										reg1_i_not[27] ? 4 	: reg1_i_not[26] 	? 5 	:
										reg1_i_not[25]	? 6 	: reg1_i_not[24] 	? 7 	: 
										reg1_i_not[23] ? 8 	: reg1_i_not[22] 	? 9 	: 
										reg1_i_not[21] ? 10 	: reg1_i_not[20] 	? 11 	:
										reg1_i_not[19] ? 12 	: reg1_i_not[18] 	? 13 	: 
										reg1_i_not[17] ? 14 	: reg1_i_not[16] 	? 15 	: 
										reg1_i_not[15] ? 16 	: reg1_i_not[14] 	? 17 	: 
										reg1_i_not[13] ? 18	: reg1_i_not[12]	? 19 	: 
										reg1_i_not[11] ? 20 	: reg1_i_not[10]	? 21 	: 
										reg1_i_not[9] 	? 22 	: reg1_i_not[8] 	? 23 	: 
										reg1_i_not[7] 	? 24 	: reg1_i_not[6] 	? 25 	: 
										reg1_i_not[5] 	? 26 	: reg1_i_not[4]	? 27	: 
										reg1_i_not[3] 	? 28 	: reg1_i_not[2] 	? 29 	: 
										reg1_i_not[1] 	? 30 	: reg1_i_not[0] 	? 31 	: 32;
			end
			default:begin
				arithmeticres  <= `ZeroWord;
			end
		endcase
	end
end

/*第七段，乘法运算*/

//取得乘法运算的被乘数，如果是有符号乘法且被乘数是负数，那么取补码

assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) || 
								(aluop_i == `EXE_MULT_OP) ||
								(aluop_i	== `EXE_MADD_OP) ||
								(aluop_i	== `EXE_MSUB_OP)) &&
								(reg1_i[31])) ? (~reg1_i + 1) : reg1_i;
								
//取得乘法运算的乘数，如果是有符号乘法且乘数是负数，那么取补码

assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || 
								(aluop_i == `EXE_MULT_OP) ||
								(aluop_i	== `EXE_MADD_OP) ||
								(aluop_i	== `EXE_MSUB_OP))&&
								(reg2_i[31])) ? (~reg2_i + 1) : reg2_i;
								
//得到临时乘法结果，保存在变量hilo_temp中

assign hilo_temp = opdata1_mult * opdata2_mult;

//对临时乘法结果进行修正，最终的乘法结果保存在变量mulres中，主要有两点：
//	如果有符号乘法指令mut,mult，那么需要修正临时乘法结果，如下：
//		如果被乘数与乘数两者一正一负，hilo_temp求补码，作为最终结果赋值给mulres
//		如果被乘数与乘数两者同号，hilo_temp值作为最终结果赋值给mulres
//	如果是无符号乘法指令multu，那么hilo_temp值就作为最终的乘法结果，赋值给mulres

always	@	(*)	begin
	if(rst == `RstEnable)	begin
		mulres <= {`ZeroWord,`ZeroWord};
	end	else	
	if((aluop_i == `EXE_MULT_OP) || 
		(aluop_i == `EXE_MUL_OP)  ||
		(aluop_i == `EXE_MADD_OP) ||
		(aluop_i	== `EXE_MSUB_OP))	begin
		if(reg1_i[31] ^ reg2_i[31])	begin
			mulres <= ~hilo_temp + 1;
		end	else	begin
			mulres <= hilo_temp;
		end
	end	else 	begin
		mulres <= hilo_temp;
	end
end


/*第八段，累乘加，累乘减*/

//MADD,MADDU,MSUB,MSUBU指令

always	@	(*)	begin
	if(rst == `RstEnable)	begin
		hilo_temp_o <= {`ZeroWord, `ZeroWord};
		cnt_o			<= 2'b00;
		stallreq_for_madd_msub	<= `NoStop;
	end	else	begin
		case(aluop_i)
			`EXE_MADD_OP, `EXE_MADDU_OP:begin				//MADD,MADDU指令
				if(cnt_i == 2'b00)	begin						//第一个时钟周期
					hilo_temp_o	<= mulres;
					cnt_o			<= 2'b01;
					hilo_temp1	<= {`ZeroWord, `ZeroWord};
					stallreq_for_madd_msub	<= `Stop;
				end	else
				if(cnt_i == 2'b01)	begin						//第二个时钟周期
					hilo_temp_o	<= {`ZeroWord, `ZeroWord};
					cnt_o			<= 2'b10;
					hilo_temp1	<= hilo_temp_i + {HI, LO};
					stallreq_for_madd_msub	<= `NoStop;
				end
			end
			`EXE_MSUB_OP, `EXE_MSUBU_OP:begin				//MSUB,MSUBU指令
				if(cnt_i == 2'b00)	begin
					hilo_temp_o	<= ~mulres + 1;
					cnt_o			<= 2'b01;
					stallreq_for_madd_msub	<= `Stop;
				end	else
				if(cnt_i == 2'b01)	begin
					hilo_temp_o	<= {`ZeroWord, `ZeroWord};
					cnt_o			<= 2'b10;
					hilo_temp1  <= hilo_temp_i + {HI, LO};
					stallreq_for_madd_msub	<= `NoStop;
				end
			end
			default:begin
				hilo_temp_o	<= {`ZeroWord, `ZeroWord};
				cnt_o			<= 2'b00;
				stallreq_for_madd_msub	<= `NoStop;
			end
		endcase
	end
end

/*第⑨段，暂停流水线，目前只有乘累加，累乘减会导致流水线暂停*/

always	@	(*)	begin
	stallreq = stallreq_for_madd_msub || stallreq_for_div;
end

/*第十段，确定对HI,LO寄存器的操作信息*/

always @ (*) begin
	if(rst == `RstEnable) begin
		whilo_o <= `WriteDisable;
		hi_o <= `ZeroWord;
		lo_o <= `ZeroWord;	
	end	else	begin
		case(aluop_i)
			`EXE_MSUB_OP,`EXE_MSUBU_OP:begin
				whilo_o	<= `WriteEnable;
				hi_o		<= hilo_temp1[63:32];
				lo_o		<= hilo_temp1[31:0];
			end	
			`EXE_MADD_OP,`EXE_MADDU_OP:begin
				whilo_o	<= `WriteEnable;
				hi_o		<= hilo_temp1[63:32];
				lo_o		<= hilo_temp1[31:0];
			end
			`EXE_MULT_OP,`EXE_MULTU_OP:begin
				whilo_o <= `WriteEnable;
				hi_o <= mulres[63:32];
				lo_o <= mulres[31:0];	
			end
			`EXE_MTHI_OP:begin
				whilo_o <= `WriteEnable;
				hi_o <= reg1_i;
				lo_o <= LO;
			end
			`EXE_MTLO_OP:begin
				whilo_o <= `WriteEnable;
				hi_o <= HI;
				lo_o <= reg1_i;
			end
			`EXE_DIV_OP,`EXE_DIVU_OP:begin
				whilo_o	<= `WriteEnable;
				hi_o	<= div_result_i[63:32];
				lo_o	<= div_result_i[31:0];
			end
			default:begin
				whilo_o <= `WriteDisable;
				hi_o <= `ZeroWord;
				lo_o <= `ZeroWord;
			end
		endcase
	end
end

/*第十一段，输出DIV模块的控制信息，获取DIV模块给出的结果*/
always	@	(*)	begin
	if(rst == `RstEnable)	begin
		stallreq_for_div	<= `NoStop;
		div_opdata1_o		<= `ZeroWord;
		div_opdata2_o		<= `ZeroWord;
		div_start_o			<= `DivStop;
		signed_div_o		<= 1'b0;
	end	else	begin
		stallreq_for_div	<= `NoStop;
		div_opdata1_o		<= `ZeroWord;
		div_opdata2_o		<= `ZeroWord;
		div_start_o			<= `DivStop;
		signed_div_o		<= 1'b0;
		case(aluop_i)
			`EXE_DIV_OP:begin
				if(div_ready_i == `DivResultNotReady)	begin
					div_opdata1_o	<= reg1_i;
					div_opdata2_o	<= reg2_i;
					div_start_o		<= `DivStart;
					signed_div_o	<= 1'b1;
					stallreq_for_div	<= `Stop;
				end	else
				if(div_ready_i == `DivResultReady)	begin
					div_opdata1_o	<= reg1_i;
					div_opdata2_o	<= reg2_i;
					div_start_o		<= `DivStop;
					signed_div_o	<= 1'b1;
					stallreq_for_div	<= `NoStop;
				end	else	begin
					div_opdata1_o	<= `ZeroWord;
					div_opdata2_o	<= `ZeroWord;
					div_start_o		<= `DivStop;
					signed_div_o	<= 1'b0;
					stallreq_for_div	<= `NoStop;
				end
			end
			`EXE_DIVU_OP:begin
				if(div_ready_i == `DivResultNotReady)	begin
					div_opdata1_o	<= reg1_i;
					div_opdata2_o	<= reg2_i;
					div_start_o		<= `DivStart;
					signed_div_o	<= 1'b0;
					stallreq_for_div	<= `Stop;
				end	else
				if(div_ready_i == `DivResultReady)	begin
					div_opdata1_o	<= reg1_i;
					div_opdata2_o	<= reg2_i;
					div_start_o		<= `DivStop;
					signed_div_o	<= 1'b0;
					stallreq_for_div	<= `NoStop;
				end	else	begin
					div_opdata1_o	<= `ZeroWord;
					div_opdata2_o	<= `ZeroWord;
					div_start_o		<= `DivStop;
					signed_div_o	<= 1'b0;
					stallreq_for_div	<= `NoStop;
				end
			end
			default:begin
			end
		endcase
	end
end

/*第十二段，给出mtc0指令的执行结果*/

always	@	(*)	begin
	if(rst == `RstEnable)	begin
		cp0_reg_waddr_o	<= 5'b00000;
		cp0_reg_we_o		<= `WriteDisable;
		cp0_reg_data_o		<= `ZeroWord;
	end	else
	if(aluop_i == `EXE_MTC0_OP)	begin
		cp0_reg_waddr_o	<= inst_i[15:11];
		cp0_reg_we_o		<= `WriteEnable;
		cp0_reg_data_o		<= reg1_i;
	end	else	begin
		cp0_reg_waddr_o	<= 5'b00000;
		cp0_reg_we_o		<= `WriteDisable;
		cp0_reg_data_o		<= `ZeroWord;
	end
end

endmodule

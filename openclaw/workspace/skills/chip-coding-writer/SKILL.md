---
name: "chip-coding-writer"
description: "可综合 RTL(Verilog) 编写/审查规范与高频坑：复位域、CDC、FSM、W1C、中断、数组复位、X 传播、协议时序、改动验证同步。"
---

# Chip Coding Writer — 可综合 RTL 编写规范与高频坑位

## 何时用本技能

编写或审查**可综合 Verilog RTL**时加载本技能。覆盖：注释、复位架构、跨时钟域(CDC)、FSM、寄存器堆(W1C/中断)、数组/generate 复位、X 传播、通用协议标准时序、设计改动与验证同步。

不适用于：testbench(用 UVM 规范)、纯文档、时序图。

---

## 一、基础编码规范（项目约定）

- **语言**：RTL 设计用 **Verilog**（非 synthesis 用 SystemVerilog）。Testbench 才用 SV+UVM 1.2。
- **可综合风格**：合理参数化（位宽/数量走 `parameter`，编码常量走 `` `define ``）。信号命名清晰。不玩花活套综合器。
- **文件大小**：单文件不宜过大，按功能合理拆分为多模块。
- **复位**：统一异步复位、同步释放。`always @(posedge clk or negedge rst_n)`。
- **赋值**：时序块用非阻塞 `<=`，组合块用阻塞 `=`。不混用。
- **输出**：项目产出统一到 `~/project/<项目名>/`。

### 注释规范（必须加注释）

**代码必须加注释**，且注释解释**为什么**而非**是什么**。

- **模块头**：每个 `.v` 文件开头注释块说明——模块功能、所属时钟域/复位域、关键协议或时序约定、对应设计文档章节。
- **端口**：非自明端口加行尾注释（含义、有效电平、所属域、单拍/电平）。例：`output reg trim_start, // W1C 触发, apb 域单拍脉冲`。
- **关键逻辑**：复位域划分、CDC 处理、FSM 状态转移、W1C/中断语义、数组复位等**易踩坑处必须注释根因和设计意图**，便于复查与他人接手。
- **参数**：每个 `parameter`/`` `define `` 注释物理含义与单位（如 `// 20ms@400MHz`）。
- **不写废话注释**：`a <= b; // 把 b 赋给 a` 这类无信息注释禁止。注释要传递代码本身看不出的信息（为什么这么做、约束、坑）。
- **改动留痕**：修复缺陷时，在相关代码处注释「原现象 + 为何这样改」，避免后人重蹈覆辙（本技能各坑位代码即范例）。

---

## 二、复位域划分（高频架构坑）

**铁律：先分清每个寄存器属于哪个复位域，再写 always 块。**

芯片常有多个复位域，典型：
- **配置复位**（如 `apb_rst_n`）：复位软件通过总线配置的寄存器
- **功能复位**（如 `rst_n`）：复位数据通路、FSM、状态机、控制触发位

### 坑 F5/F6：配置寄存器错误绑定功能复位域

**现象**：配置寄存器堆整个挂在功能复位 `rst_n` 上。中途功能复位（如复位恢复测试）把软件配好的参数（定时值、宽度、mode）冲回**复位默认值**，复位恢复后流程行为异常（例：init 时间被冲回 20ms 默认值导致流程超时）。

**判据**：
- 配置寄存器（time/width/mode/timeout/delay/数据）→ **配置复位域**。软件配好后功能复位不应清掉。
- 控制触发位（start/active 等 W1C）、硬件状态 flag（done/interrupt）→ **功能复位域**，复位即重启。

```verilog
// 错误：配置寄存器挂功能复位，中途复位丢配置
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) init_time_reg <= `RST_INIT_TIME;  // 功能复位会清掉软件配置
  ...
end

// 正确：配置寄存器归配置复位域
always @(posedge apb_clk or negedge apb_rst_n) begin
  if (!apb_rst_n) init_time_reg <= `RST_INIT_TIME;  // 仅配置复位清
  ...
end
```

**经验**：若 CDC 模块（如 cdc_sync）里已经把 APB 侧/功能侧复位分得很清楚，说明设计本意就是分域——寄存器堆务必跟随这个分域，别想当然全挂一个复位。

---

## 三、跨时钟域 CDC

**铁律：任何信号跨时钟域前，先判断它是「电平/准静态」还是「脉冲/事件」，两类处理方式完全不同。**

| 信号类型 | 处理方式 |
|---------|---------|
| 准静态配置值（软件配好基本不动）| 可直读不同步**前提**：应用层保证「配置期间不启动流程」。否则需多比特同步（gray/握手）|
| 多比特数据（计数值等会变）| 不能逐位 2-FF（会采到中间态）；用 gray 码或握手锁存 |
| 单拍脉冲/事件 | **toggle 同步器**：源域翻转 toggle 电平 → 目的域 N-FF 同步 + XOR 边沿检测还原单拍 |
| 电平保持信号（flag 置起后保持）| 目的域可准静态直采（亚稳态只影响早一拍/晚一拍，不影响功能）|

### 通用脉冲同步器 pulse2pulse（toggle 范式）

```verilog
module pulse2pulse #(parameter SYNC_STAGES = 2) (
  input  wire src_clk, src_rst_n, src_pulse,   // 源域单拍
  input  wire dst_clk, dst_rst_n,
  output reg  dst_pulse                         // 目的域单拍
);
  reg src_toggle;
  always @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n)     src_toggle <= 1'b0;
    else if (src_pulse) src_toggle <= ~src_toggle;

  reg [SYNC_STAGES-1:0] tog_sync; reg tog_sync_d;
  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) begin
      tog_sync <= 0; tog_sync_d <= 0; dst_pulse <= 0;
    end else begin
      tog_sync   <= {tog_sync[SYNC_STAGES-2:0], src_toggle};
      tog_sync_d <= tog_sync[SYNC_STAGES-1];
      dst_pulse  <= tog_sync[SYNC_STAGES-1] ^ tog_sync_d;
    end
endmodule
```

**约束**：两次源脉冲间隔须 ≥ 目的域同步深度（SYNC_STAGES+1 个目的 clk），否则 toggle 翻转过快丢事件。慢速 APB 写天然满足。**源脉冲必须是源域单拍**（写后自清），不能是长电平。

### 坑 F1：4-phase 握手跨域反馈丢脉冲

**现象**：跨域写用 4-phase 握手 + 反馈，连续写只有第一笔成功（反馈握手在快速连续写时丢脉冲）。

**修法**：改单向 toggle 同步器，无反馈握手。

### 跨域脉冲产生：apb 域单拍来源

W1C 触发位「写 1 置位、下一拍自清」天然就是源域单拍，正好喂给 pulse2pulse：

```verilog
always @(posedge apb_clk or negedge apb_rst_n) begin
  if (!apb_rst_n) trim_op_ctrl_reg <= 0;
  else begin
    trim_op_ctrl_reg <= 0;                 // 默认清 0
    if (reg_wr_en && reg_addr==`ADDR_OP_CTRL)
      trim_op_ctrl_reg <= reg_wdata;       // 写入覆盖默认清，保持一拍后回 0 = 单拍
  end
end
```

---

## 四、FSM 设计

### 坑 F4：退出条件混用两套定时机制

**现象**：某状态（如 S_INIT_RESET）的退出条件依赖外部 timer 的 `cnt_done`，但实际脉宽计时由另一个模块内部完成；FSM 又没正确驱动外部 timer，导致 `cnt_done` 永不来，FSM 永卡。

**根因典型**：FSM 用**电平持续拉高** `timer_start`，且 `timer_load_val=0`：
```verilog
// timer 内部：timer_start 为电平 → 每拍重载 cnt<=0 → 永远到不了递减/cnt_done
if (timer_start) cnt <= timer_load_val;          // load_val=0
else if (cnt!=0) begin cnt<=cnt-1; if(cnt==1) cnt_done<=1; end
```
`timer_start` 一直高 → 每拍重载 0 → `cnt!=0` 分支永不进 → `cnt_done` 永不脉冲。

**判据 / 修法**：
1. 退出条件的来源信号，必须确认**真的会被产生**。FSM 注释若写「计时由 X 模块负责，FSM 仅触发」，那退出条件就不该等另一个被放弃的 timer。
2. `timer_start` 应是**单拍脉冲**（启动 timer 一次），不是电平。或退出改为握手信号（如下游 ready）。
3. 多个完成机制并存时，退出条件与实际计时源必须一致。
4. **改动遗留死代码**：FSM 退出条件从外部 timer 改为握手后，该 timer 可能彻底失去调用者变成死代码（覆盖率会暴露：line 偏低 + toggle 极低）。改完审视被放弃模块是否该删，别留悬挂死逻辑。

### 坑：Moore 电平输出抢占边沿检测分支

**现象**：FSM 某状态的 Moore 输出（如 `ringo_period_start`）在该状态**全程为电平高**。下游用它做「测量启动复位」时，电平持续高会**持续抢占**下降沿/完成置位分支，使选中目标永远到不了完成态。
```verilog
// 下游: ringo_period_start 全程高 → 第一个 if 持续命中, else if 永不进
if (start && sel[gl]) ready[gl] <= 0;          // 持续清零, 抢占
else if (fall_edge)   ready[gl] <= 1;          // 永远进不来
```
**隐蔽点**：若上层用 `|ready`（任一）聚合，可能靠**未选中位的残留值**蒙混推进，长期掩盖此 bug；改成 all-selected `(ready&sel)==sel` 才暴露。
**修法**：把"启动复位"改成 **start 上升沿检测**（`start && !start_d`），只在进入那一拍复位，之后让完成分支可以置位。

### FSM 通用要点
- 状态编码用 `` `define ``，可读性优先（综合器会优化）。
- 次态组合块 `always @(*)` 默认 `next_state = state`，避免 latch。
- 输出 Moore 风格时，组合块开头给所有输出赋默认值，再 case 覆盖。
- **控制/模式位必须穷举每个取值的分支**：`trim_op_flow=0/1`、`res_value_sel` 等每个取值都要确认对应 RTL 分支都实现了，别只写默认路径。**悬空的输出 net 往往是「有定义无实现」的分支缺失红旗**。
- **FSM 转移覆盖盲区**：「任意状态中途复位→IDLE」类转移，若靠 TB 轮询抓 fsm_state 注入复位，瞬态态（只停 1 拍）抓不到 → 这些转移零覆盖。需对每个状态定点注入（按前驱条件或固定拍数），而非轮询扫描。

---

## 五、寄存器堆：W1C 与中断

### 坑 I1：W1C set-only 没自清

**现象**：`trim_op_ctrl_reg <= trim_op_ctrl_reg | reg_wdata;` 只置位、硬件消费后从不自清 → 触发位置 1 后永久有效，无法重复触发。

**修法**：根据语义选择
- **脉冲触发**（事件型）：写后下一拍自清成单拍（见三节代码）。
- **置位-消费-清**：硬件操作完成后对相应 bit 自清，需与下游联动。

### 坑：中断 mask 误用

**现象**：`if (timed_out && !interrupt_mask) flag <= 1;` —— mask=1 时连 flag 都不置位。

**正确语义**：mask 只控制「是否经接口**上报**」，不该影响 flag 置位/清除。
```verilog
// flag 无条件由事件置位，clr 清除
if (interrupt_clr)   flag <= 1'b0;
else if (timed_out)  flag <= 1'b1;
// mask 仅门控接口输出
assign trim_interrupt = flag & ~interrupt_mask;   // mask=1 不上报但 flag 仍在、仍可被 clr 清
```

### 中断清除脉冲
`interrupt_clr` 若用「寄存器位别名」实现但写逻辑从不写该位 → 恒为 0，中断永远清不掉。应做成**写 bit=1 产生的单拍清除脉冲**。

---

## 六、数组 / generate 复位

### 坑 I3：复位不完整 + 多驱动

**现象**：generate per-layer 循环里复位分支只清数组单个元素 `mem[idx*N+i]`（复位时 idx=0 只清 [0]），其余元素复位后为 **X**；且该语句在循环里重复多次，**多驱动同一数组元素**。

**修法**：
- 复位用**独立 for 循环清零整个数组**，不要嵌在 per-layer generate 里。
- 写入收拢到单一 always，避免多 always 驱动同一元素。

```verilog
// 正确：独立 for 全清
integer k;
always @(posedge clk or negedge rst_n)
  if (!rst_n) for (k=0;k<DEPTH;k=k+1) mem[k] <= 0;
  else if (wr) mem[waddr] <= wdata;
```

---

## 七、X 传播

### 坑 F3：未初始化信号经复位释放污染边沿检测

**现象**（多为 TB 坑，但 RTL 边沿检测应鲁棒）：DUT 输入未初始化为 X，复位释放后 X 进入 FSM 边沿检测器：
```verilog
trim_start_edge = trim_start && !trim_start_d;   // trim_start_d=X → edge = 1&&!X = X
// FSM 条件 (edge && ...) 判为 X→假 → 永不触发
```

**判据 / 防御**：
- TB 侧：所有 DUT 输入上电 `initial` 清 0（见 UVM TB 规范）。
- RTL 侧：复杂控制路径避免对可能为 X 的输入做组合判决；关键边沿检测寄存器确保复位初值确定。
- 仿真：开 `+UVM_VERBOSITY` 或波形查 X 来源，不要忽略红色 X。

---

## 八、通用协议标准时序（AMBA 等）

**铁律：实现总线/接口协议（AMBA APB/AHB/AXI、I2C、SPI、UART 等通用协议）时，RTL 与 TB 都必须严格按协议标准时序实现，不得自创非标准握手或人为延迟。**

### 为什么

- 标准协议时序是与外部 IP/SoC 集成的契约。自创非标准时序（多等几拍、提前/延后一拍接收）在本地仿真可能"能跑"，但**集成到标准 master/slave 时立刻挂**。
- 非标准时序会污染 TB：driver/monitor 为迁就非标准 RTL 而加补偿拍，掩盖真实协议错误，且换标准 VIP 后全部失效。

### 标准做法（以 APB3 为例）

- **两段握手**：setup 拍（`psel=1, penable=0`）→ access 拍（`psel=1, penable=1, pready=1`）。传输在 access 拍完成。
- **写**：slave 在 access 拍接收 `pwdata`（`reg_wr_en = psel & penable & pwrite` 组合，时钟沿写入），**不要打额外延迟拍**。
- **读**：slave 在 access 拍输出 `prdata`（组合直通或 access 拍寄存），master 在 access 拍采样。
- **TB driver**：标准 setup→access 两段，access 后即 idle；idle 段总线信号（psel/penable/pwrite/paddr/pwdata）回默认 0，与复位段一致（IDLE 总线确定、波形干净）。**不要为内部实现（如 CDC）加保持拍**——若 RTL 内部需要跨域，应由 RTL 自己用同步器处理，不靠 TB 拖拍补偿。
- **TB monitor**：按协议在 access 拍采样，不加迁就 RTL 的补偿延迟。

### 坑：非标准时序 + TB 补偿拍（真实案例）

**现象**：APB slave 把 `reg_wr_en`/`apb_rdata` 各打一拍（比标准晚一拍接收/输出），早期又为旧 CDC 写通路在 TB driver 里加了 `repeat(4)` 保持拍 → 「写 1 个寄存器要 5~6 个 apb_clk」。
**根因**：① RTL 非标准（access 拍不接收，延后一拍）；② TB 为迁就加保持拍；③ 架构改动（寄存器搬到 apb 域、写通路去 CDC）后保持拍变冗余但没清理，注释也过时。
**修法**：RTL 改 access 拍组合接收/输出（标准 APB3），TB driver 改纯两段握手、monitor access 拍采样。回归确认读写正确。

### 判据 / 自检
- RTL 接收/输出时机是否落在协议规定的 access/有效拍？有没有"打一拍"偏移？
- TB driver/monitor 的拍数是否等于协议标准？有没有为迁就 RTL 内部实现加补偿拍？
- 跨域需求是否由 RTL 内部同步器解决，而非靠 TB 拖拍？
- 架构改动后，原为旧实现加的时序补偿是否已清理（含过时注释）？

---

## 九、设计改动与验证同步（改了 RTL 必须同步补验证）

**铁律：每次改 RTL 行为/架构（尤其复位域、时钟域、协议时序、控制位语义），必须同步检查并补齐对应验证；否则改对了也无人证明，留下「改了没测」的盲区。**

### 核心教训

1. **行为改动 → 验证必须跟上**。把配置寄存器复位域从 `rst_n` 改到 `apb_rst_n`（核心架构改动），但验证侧**没有任何测试点真正拉 `apb_rst_n` 验证「配置寄存器被 apb_rst_n 复位」**。改对了却没人证明。改 RTL 时同步问：这个新行为，哪个测试点覆盖？没有就补。

2. **名义测试点 = 假覆盖重灾区**。测试点名字对（如「RST-02 apb_rst_n 上电复位」「FUNC-02 软件 spine_active」），但实现里**没有真实激励 + 没有断言**——只上电读一下、或只写寄存器等几拍就 PASS。判据：
   - 有没有**主动施加被测激励**？（真去拉 apb_rst_n / 真去触发该路径，而非依赖上电默认或旁路）
   - 有没有**针对性断言**？（查目标信号/寄存器的预期值，而非无检查 PASS）
   - 测试点名称声称验证 X，激励和断言是否真的针对 X？

3. **TB 基础设施要支持被测场景**。想验运行中 `apb_rst_n` 复位，但 tb_top 只有上电复位、中途复位钩子只接 `rst_n`——TB 根本没有拉 apb_rst_n 的能力。改 RTL 引入新复位/新模式时，同步确认 TB 有没有施加该场景的钩子，没有就先补基础设施。

4. **覆盖率是发现「改了没测」的探针**。toggle 某信号只有 0→1 无 1→0、某复位信号从不翻转、某分支零覆盖——往往指向「这个改动/这条路径根本没被激励」。用覆盖率反查验证盲区，不要只看 UVM_ERROR=0 就安心。

### 判据 / 自检
- 本次改的 RTL 行为（复位域/时钟域/协议/控制位语义），对应测试点是否存在且**真有激励+断言**？
- 名义测试点是否名实相符？有没有「写了就过、没检查」的假覆盖？
- 新引入的复位/模式/路径，TB 是否具备施加该场景的能力（钩子/接口）？
- 改动是否引入死代码或孤立路径？覆盖率有没有暴露未激励信号？

---

## 十、验证铁律（与编码强绑定）

1. **不猜测，去验证**。不确定就跑仿真、看波形、查 spec。无法验证就明说。
2. **测试过了但没看波形 = 不算过**。RTL bug 流片代价数百万，每行都举足轻重。
3. **覆盖边界**：4KB 边界、超时、复位中途注入、连续写、CDC 穿越、多层/多通道并行、单层/全选/随机选择。
4. **回归汇总逐 case 核实**，不要依赖单次 grep 结论误报全绿。
5. **bug 分层遮蔽**：前一个 bug 修好后，后面的 bug 才暴露。一次只能看到最靠前的失败点，修完再往下挖。
6. **无断言的 testcase 是假覆盖**：只「写寄存器 + 等几拍」就 PASS、无任何检查的 case 等于没测。必须加真实断言（查 DFT 输出脉冲、ready 置位、回读值）。
7. **聚合逻辑审视 `|任一` vs `&全部`**：多目标并行场景，`|任一就绪` 可能靠虚假位蒙混、掩盖下游 bug；按语义该用 all-selected `(ready&sel)==sel && sel!=0` 时就别图省事用 OR。
8. **用覆盖率反查盲区**：line/cond/fsm/toggle/branch 的低覆盖项往往指向未激励的路径、未测的分支、死代码；逐项分析比只看 pass/fail 更能暴露真问题。

### 波形调试高效法（不依赖 GUI）

GUI(Verdi) 启动慢/易卡时，用文本提取信号跳变更快：
```bash
fsdb2vcd test.fsdb -o /tmp/out.vcd          # fsdb 转 vcd
# python 解析 VCD：定位 $var 的 id，按 # 时间戳收集跳变
# 重点提取 fsm_state / 关键握手信号 / 复位边沿，过滤高频刷屏信号
```
远程 EDA 服务器若默认 login shell 是 csh/tcsh，heredoc/重定向会失败——把脚本写成独立 bash 文件 `scp` 过去再 `bash` 执行。

### 代码覆盖率收集（VCS）

- 编译 + 运行都要带 `-cm line+cond+fsm+tgl+branch`；运行 `-cm_dir` 指向**编译产生的 simv.vdb**（设计+数据同库），否则 urg 报 "Design not loaded" 只出功能覆盖。
- `urg -dir simv.vdb -format both -report urgReport` 生成报告；urg 在 `$VCS_HOME/bin/urg`（未必在 PATH）。
- 看 DUT 真实覆盖率用「Total Module Definition Coverage」按模块看 rtl_cc 各模块，天然排除 UVM 库实例。

---

## 十一、改动前自检清单

```
□ 代码注释是否齐全？模块头/端口/关键逻辑/参数都注释了吗？注释讲的是「为什么」吗？
□ 这个寄存器/信号属于哪个时钟域？哪个复位域？
□ 配置寄存器是否误挂功能复位域？
□ 跨域信号是电平还是脉冲？脉冲是否走了 toggle 同步器？
□ 准静态直读是否有「配置期不启动」的应用保证？
□ 总线/接口协议(APB/AHB/AXI等)是否按标准时序实现？RTL access 拍接收/输出无偏移？
□ TB driver/monitor 拍数是否等于协议标准？有没有迁就 RTL 的补偿拍？IDLE 总线回默认 0？
□ FSM 每个状态的退出条件来源信号是否真会产生？
□ 控制/模式位的每个取值分支是否都实现？有无悬空输出 net？
□ Moore 电平输出是否抢占了下游边沿/完成置位分支？
□ timer_start 是脉冲还是电平？load_val 是否非 0？退出改握手后旧 timer 是否成死代码？
□ W1C 位是否会自清？中断 flag/mask/clr 语义是否正确？
□ 数组复位是否清全部元素？是否多 always 驱动同一元素？
□ 组合块是否有默认赋值避免 latch？
□ 聚合用 |任一 还是 &全部？多目标并行语义对吗？
□ 本次 RTL 行为改动，对应测试点是否存在且真有激励+断言？
□ 名义测试点是否名实相符（非写位+等待的假覆盖）？
□ 新引入的复位/模式/路径，TB 是否有施加该场景的钩子？
□ 覆盖率是否暴露未激励信号/未测分支/死代码？
□ 改完是否编译 0 error + 跑回归(逐 case 核实) + 看关键波形？
```

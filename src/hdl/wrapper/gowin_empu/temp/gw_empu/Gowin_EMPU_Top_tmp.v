//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12.02_SP2 (64-bit)
//IP Version: 2.0
//Part Number: GW1NSR-LV4CQN48PC7/I6
//Device: GW1NSR-4C
//Created Time: Thu Jul 30 20:58:57 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	Gowin_EMPU_Top your_instance_name(
		.sys_clk(sys_clk), //input sys_clk
		.uart0_rxd(uart0_rxd), //input uart0_rxd
		.uart0_txd(uart0_txd), //output uart0_txd
		.master_hclk(master_hclk), //output master_hclk
		.master_hrst(master_hrst), //output master_hrst
		.master_hsel(master_hsel), //output master_hsel
		.master_haddr(master_haddr), //output [31:0] master_haddr
		.master_htrans(master_htrans), //output [1:0] master_htrans
		.master_hwrite(master_hwrite), //output master_hwrite
		.master_hsize(master_hsize), //output [2:0] master_hsize
		.master_hburst(master_hburst), //output [2:0] master_hburst
		.master_hprot(master_hprot), //output [3:0] master_hprot
		.master_hmemattr(master_hmemattr), //output [1:0] master_hmemattr
		.master_hexreq(master_hexreq), //output master_hexreq
		.master_hmaster(master_hmaster), //output [3:0] master_hmaster
		.master_hwdata(master_hwdata), //output [31:0] master_hwdata
		.master_hmastlock(master_hmastlock), //output master_hmastlock
		.master_hreadymux(master_hreadymux), //output master_hreadymux
		.master_hauser(master_hauser), //output master_hauser
		.master_hwuser(master_hwuser), //output [3:0] master_hwuser
		.master_hrdata(master_hrdata), //input [31:0] master_hrdata
		.master_hreadyout(master_hreadyout), //input master_hreadyout
		.master_hresp(master_hresp), //input master_hresp
		.master_hexresp(master_hexresp), //input master_hexresp
		.master_hruser(master_hruser), //input [2:0] master_hruser
		.reset_n(reset_n) //input reset_n
	);

//--------Copy end-------------------

/* Quartus Prime Version 17.1.0 Build 590 10/25/2017 SJ Lite Edition */
JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Ign)
		Device PartName(SOCVHPS) MfrSpec(OpMask(0));
	P ActionCode(Cfg)
		Device PartName(5CSEBA6) Path("C:/Users/james/Documents/Arm-FPGA/DE10_NANO/") File("Good_Config3_Base_Flipped.jic") MfrSpec(OpMask(1) SEC_Device(EPCS64) Child_OpMask(1 1));
	P ActionCode(Ign)
		Device PartName(5CSEBA6) MfrSpec(OpMask(0) SEC_Device(EPCS64) Child_OpMask(1 0) FullPath("C:/Users/james/Documents/Arm-FPGA/DE10_NANO/Good Config2 (pin moved).jic"));

ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;

#include <stdio.h>
#include "platform.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xparameters.h"

#include "xil_cache.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "sleep.h"

#define INT_CFG0_OFFSET 0x00000C00

#define XPAR_taiko_IP_0_DEVICE_ID
// Parameter definitions
#define SW1_INT_ID              61
#define SW2_INT_ID              62
#define SW3_INT_ID              63

#define INTC_DEVICE_ID          XPAR_PS7_SCUGIC_0_DEVICE_ID
#define INT_TYPE_RISING_EDGE    0x03
#define INT_TYPE_HIGHLEVEL      0x01
#define INT_TYPE_MASK           0x03

#define addr_lite 0x43C00000

static XScuGic INTCInst;
int point =0;
static void SW_intr_Handler(void *param);
int InterruptSystemSetup(XScuGic *XScuGicInstancePtr);
static int IntcInitFunction(u16 DeviceId);

static void SW_intr_Handler(void *param)
{
    int sw_id = (int)param;
    if (sw_id == 1) {
    	point = point+1;
    	printf("too late point+1 \n point:%d\n", point);
    }

    if(sw_id == 2) {
    	point = point+3;
		printf("prefect point+3 \n point:%d\n", point);
    }

    if(sw_id == 3) {
    	point = point+1;
		printf("too early point+1 \n point:%d\n", point);
    }



}

void IntcTypeSetup(XScuGic *InstancePtr, int intId, int intType)
{
    int mask;

    intType &= INT_TYPE_MASK;
    mask = XScuGic_DistReadReg(InstancePtr, INT_CFG0_OFFSET + (intId/16)*4);
    mask &= ~(INT_TYPE_MASK << (intId%16)*2);
    mask |= intType << ((intId%16)*2);
    XScuGic_DistWriteReg(InstancePtr, INT_CFG0_OFFSET + (intId/16)*4, mask);
}

int IntcInitFunction(u16 DeviceId)
{
    XScuGic_Config *IntcConfig;
    int status;

    // Interrupt controller initialisation
    IntcConfig = XScuGic_LookupConfig(DeviceId);
    status = XScuGic_CfgInitialize(&INTCInst, IntcConfig, IntcConfig->CpuBaseAddress);
    if(status != XST_SUCCESS) return XST_FAILURE;

    // Call to interrupt setup
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 &INTCInst);
    Xil_ExceptionEnable();

    // Connect SW1~SW3 interrupt to handler
    status = XScuGic_Connect(&INTCInst,
                             SW1_INT_ID,
                             (Xil_ExceptionHandler)SW_intr_Handler,
                             (void *)1);
    if(status != XST_SUCCESS) return XST_FAILURE;

    status = XScuGic_Connect(&INTCInst,
                              SW2_INT_ID,
                              (Xil_ExceptionHandler)SW_intr_Handler,
                              (void *)2);
     if(status != XST_SUCCESS) return XST_FAILURE;

     status = XScuGic_Connect(&INTCInst,
                              SW3_INT_ID,
                              (Xil_ExceptionHandler)SW_intr_Handler,
                              (void *)3);
     if(status != XST_SUCCESS) return XST_FAILURE;

     // Set interrupt type of SW1~SW3 to rising edge
     IntcTypeSetup(&INTCInst, SW1_INT_ID, INT_TYPE_RISING_EDGE);
     IntcTypeSetup(&INTCInst, SW2_INT_ID, INT_TYPE_RISING_EDGE);
     IntcTypeSetup(&INTCInst, SW3_INT_ID, INT_TYPE_RISING_EDGE);

     // Enable SW1~SW3 interrupts in the controller
     XScuGic_Enable(&INTCInst, SW1_INT_ID);
     XScuGic_Enable(&INTCInst, SW2_INT_ID);
     XScuGic_Enable(&INTCInst, SW3_INT_ID);

    return XST_SUCCESS;
}

int main(void)
{
    init_platform();

//    print("PL int test\n\r");
    IntcInitFunction(INTC_DEVICE_ID);
//    while(1);
//    cleanup_platform();

    int vaule = 0;
    int chardata = 0;
	Xil_DCacheDisable();
	Xil_Out32(addr_lite,3);
//	printf("AXI4-FULL RW TEST~\n\r");
	while(1){

		printf("start\n");
		scanf("%d",&chardata);
//		printf(&chardata);
		Xil_Out32(addr_lite,chardata);
		vaule = Xil_In32(addr_lite);
//		printf(vaule);
		sleep(1);
//		printf("\n");

	}


    return 0;
}

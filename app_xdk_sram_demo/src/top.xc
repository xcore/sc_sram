/**
 * Module:  app_xdk_sram_demo
 * Version: 1v1
 * Build:   39b0ab926f5ad1c9d6ebaef7d6ccb56c663c8cfb
 * File:    top.xc
 *
 * The copyrights, all other intellectual and industrial 
 * property rights are retained by XMOS and/or its licensors. 
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2010
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the 
 * copyright notice above.
 *
 **/                                   
///////////////////////////////////////////////////////////////////////////////////////
//
// SRAM driver
//
// top.xc
// Top level
//
// Copyright (C) 2009 XMOS Ltd
// Ayewin Oung, Ladislav Snizek
//

#include <stdlib.h>
#include <platform.h>
#include <print.h>
#include "sram.h"

void sram_test(chanend sram, int instance, chanend xlog);
void sram_simple_test(chanend sram, chanend xlog);
void xlog(chanend xlog0, chanend xlog1, chanend xlog2);

int main()
{
  chan c_sram0, c_sram1, c_sram2;
  chan c_xlog0, c_xlog1, c_xlog2;
  par
  {
    on stdcore[1] : xlog(c_xlog0, c_xlog1, c_xlog2);
    on stdcore[0] : sram(c_sram0, c_sram1, c_sram2);
    on stdcore[0] : {
			printstrln("required min tools version: 9.9.1");
			printstrln("tested with XC optimisation level O2");
#ifdef THREE_CLIENTS
      // Run three clients in parallel
      par
      {
        sram_test(c_sram0, 0, c_xlog0);
        sram_test(c_sram1, 1, c_xlog1);
        sram_test(c_sram2, 2, c_xlog2);
      }
#else
      // Run a single client
      sram_simple_test(c_sram0, c_xlog0);
      sram_test(c_sram0, 0, c_xlog0);
#endif
      exit(0);
    }
  }
	return 0;
}

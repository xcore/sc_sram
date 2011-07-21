/**
 * Module:  app_xdk_sram_demo
 * Version: 1v1
 * Build:   39b0ab926f5ad1c9d6ebaef7d6ccb56c663c8cfb
 * File:    test.xc
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
// test.xc
// Test code
//
// Copyright (C) 2009 XMOS Ltd
// Ayewin Oung, Ladislav Snizek
//

#include <xs1.h>
#include <stdlib.h>
#include <assert.h>
#include <print.h>
#include "xfifo.h"
#include "sram.h"

#define TEST_BUFFER_SIZE      (1024)

void xlog(chanend xlog0, chanend xlog1, chanend xlog2)
{
  unsigned int fifo_buf[5000];
  xfifo_t fifo;
  char buf[128];
  chan resync;
  fifo = xfifo_init(fifo_buf, 5000);
  par
  {
    while (1)
    {
      int type, arg;
      int n = 0;
      int valid;
      do
      {
        valid = 1;
        select
        {
          case slave { xlog0 :> type; xlog0 :> arg; }: n = 0; break;
          case slave { xlog1 :> type; xlog1 :> arg; }: n = 1; break;
          case slave { xlog2 :> type; xlog2 :> arg; }: n = 2; break;
          case resync :> int m:
          {
            switch (m)
            {
              case 0: xlog0 <: 0; break;
              case 1: xlog1 <: 0; break;
              case 2: xlog2 <: 0; break;
            }
            valid = 0;
          }
          break;
        }
      } while (!valid);
      xfifo_blocking_push(fifo, type);
      if (type == 'x')
        xfifo_blocking_push(fifo, n);
      else
        xfifo_blocking_push(fifo, arg);
    }
    while (1)
    {
      int type, arg;
      int n = 0;
      do
      {
        type = xfifo_blocking_pull(fifo);
        arg = xfifo_blocking_pull(fifo);
        if (type == 'c')
        {
          buf[n++] = arg;
        }
      } while (type == 'c');
      if (n > 0)
      {
        buf[n] = '\0';
        printstr(buf);
      }
      switch (type)
      {
        case 'h': printhex(arg); break;
        case 'i': printint(arg); break;
        case 'x': resync <: arg; break;
      }
    }
  }
}

void xlogchr(char c, chanend xlog)
{
  master { xlog <: (int)'c'; xlog <: (int)c; }
}

void xlogint(int n, chanend xlog)
{
  master { xlog <: (int)'i'; xlog <: n; }
}

void xloghex(unsigned x, chanend xlog)
{
  master { xlog <: (int)'h'; xlog <: x; }
}

void xlogstr(const char s[], chanend xlog)
{
  for (int i = 0; s[i] != '\0'; i++)
  {
    master
    {
      xlog <: (int)'c';
      xlog <: (int)s[i];
    }
  }
}

void xlogresync(chanend xlog)
{
  master { xlog <: (int)'x'; xlog <: 0; }
  xlog :> int;
}

// external assembler implementation.
//extern unsigned int _getChanEndHandle(chanend);

/** This return next BYTE data for test, pattern.
 */
unsigned char getNextByteData(unsigned char data)
{
   unsigned char Temp;
   int i, bitxor;

   Temp = data & (0xB9);
   data = data >> 1;

   bitxor = 0;
   for (i = 0; i < 8; i += 1)
   {
      if ((Temp & (0x1 << i)))
      {
         bitxor ^= 1;
      }
   }


   if (bitxor)
   {
      data |= 0x80;
   }

   return (data);
}


/** This return next WORD data for test, pattern.
 */
unsigned int getNextWordData(unsigned int data)
{
   /*
   unsigned int Temp;
   int i, bitxor;

   Temp = data & 0x80200006;
   data = data >> 1;

   bitxor = 0;
   for (i = 0; i < 32; i += 1)
   {
      if ((Temp & (0x1 << i)))
      {
         bitxor ^= 1;
      }
   }

   if (bitxor)
   {
      data |= 0x80000000;
   }
   */

   return (data + 1);
}

/** This perform word aligned access to SRAM device.
 */
void sram_word_access_test(chanend sram, unsigned int Buf[], unsigned int seed, int instance, int &errorCount, chanend xlog)
{
   timer tmr;
   int Result;
   int i, count;
   int SRAMWordCnt, error;
   unsigned int data;
   unsigned int adrs;

   unsigned int startTime, endTime, totalTime;

   // do the write
   SRAMWordCnt = (SRAM_SIZE_IN_BYTES / 4) >> 2;
   data = seed;
   adrs = (SRAM_SIZE_IN_BYTES / 4) * instance;
   xlogstr("writing to SRAM in word mode...\n", xlog);
   xlogresync(xlog);
   totalTime = 0;
   while (SRAMWordCnt > 0)
   {
      // how many to write this round.
      count = SRAMWordCnt;
      if (count > TEST_BUFFER_SIZE)
      {
         count = TEST_BUFFER_SIZE;
      }
      // populate buffer
      for (i = 0; i < count; i += 1)
      {
         Buf[i] = data;
         data = getNextWordData(data);
      }
      // write to SRAM using word access
      tmr :> startTime;
      Result = sram_wrw(sram, adrs, Buf, 0, count);
      tmr :> endTime;
      totalTime += (endTime - startTime);
      if (Result != 0)
      {
         xlogstr("writing to SRAM in word mode, StartAdrs ", xlog);
         xloghex(adrs, xlog);
         xlogstr(" count ", xlog);
         xloghex(count, xlog);
         xlogstr("\n", xlog);
         xlogstr("ERROR: writing to SRAM in word mode.\n", xlog);
         xlogresync(xlog);
         errorCount++;
      }
      // management internal control structures
      SRAMWordCnt -= count;
      adrs        += (count << 2);
   }
   // disaply the time.
   xlogstr("total time to write ", xlog);
   xlogint(totalTime, xlog);
   xlogstr("\n", xlog);
   xlogresync(xlog);


   // do the read & validate it.
   SRAMWordCnt = (SRAM_SIZE_IN_BYTES / 4) >> 2;
   data = seed;
   adrs = (SRAM_SIZE_IN_BYTES / 4) * instance;
   error = 0;
   xlogstr("reading back from SRAM in word mode to validate it...\n", xlog);
   xlogresync(xlog);
   totalTime = 0;
   while (SRAMWordCnt > 0)
   {
      // how many to write this round.
      count = SRAMWordCnt;
      if (count > TEST_BUFFER_SIZE)
      {
         count = TEST_BUFFER_SIZE;
      }

      // write to SRAM using word access
      tmr :> startTime;
      Result = sram_rdw(sram, adrs, Buf, 0, count);
      tmr :> endTime;
      totalTime += (endTime - startTime);
      if (Result != 0)
      {
         xlogstr("Rading from SRAM in word mode, StartAdrs ", xlog);
         xloghex(adrs, xlog);
         xlogstr(" count ", xlog);
         xloghex(count, xlog);
         xlogstr("\n", xlog);
         xlogstr("ERROR: writing to SRAM in word mode.\n", xlog);
         xlogresync(xlog);
         errorCount++;
      }
      // validate the data.
      for (i = 0; i < count; i += 1)
      {
         if (Buf[i] != data)
         {
            error += 1;
            xlogstr("Error : Adrs ", xlog);
            xloghex((adrs + (i << 2)), xlog);
            xlogstr(" Exp ", xlog);
            xloghex(data, xlog);
            xlogstr(" Act ", xlog);
            xloghex(Buf[i], xlog);
            xlogstr("\n", xlog);
            xlogresync(xlog);
            errorCount++;
         }
         data = getNextWordData(data);
      }
      // management internal control structures
      SRAMWordCnt -= count;
      adrs        += (count << 2);
   }
   // disaply the time.
   xlogstr("total time to read ", xlog);
   xlogint(totalTime, xlog);
   xlogstr("\n", xlog);
   xlogresync(xlog);

   if (error == 0)
   {
      xlogstr("test PASS\n", xlog);
      xlogresync(xlog);
   }
}


/** This perform byte aligned access to SRAM device.
 */
void sram_byte_access_test(chanend sram, unsigned char Buf[], unsigned char seed, int instance, int &errorCount, chanend xlog)
{
   timer tmr;
   int Result;
   int i, count;
   int SRAMByteCnt, error;
   unsigned char data;
   unsigned int adrs;
   unsigned int startTime, endTime, totalTime;

   // do the write
   SRAMByteCnt = (SRAM_SIZE_IN_BYTES / 4);
   data = seed;
   adrs = (SRAM_SIZE_IN_BYTES / 4) * instance;
   xlogstr("writing to SRAM in byte mode...\n", xlog);
   xlogresync(xlog);
   totalTime = 0;
   while (SRAMByteCnt > 0)
   {
      // how many to write this round.
      count = SRAMByteCnt;
      if (count > TEST_BUFFER_SIZE)
      {
         count = TEST_BUFFER_SIZE;
      }
      // populate buffer
      for (i = 0; i < count; i += 1)
      {
         Buf[i] = data;
         data = getNextByteData(data);
      }
      // write to sram using word access
      tmr :> startTime;
      Result = sram_wrb(sram, adrs, Buf, 0, count);
      tmr :> endTime;
      totalTime += (endTime - startTime);
      if (Result != 0)
      {
         xlogstr("writing to SRAM in byte mode, start address ", xlog);
         xloghex(adrs, xlog);
         xlogstr(" count ", xlog);
         xloghex(count, xlog);
         xlogchr('\n', xlog);
         xlogstr("ERROR: writing to SRAM in byte mode", xlog);
         xlogchr('\n', xlog);
         xlogresync(xlog);
         errorCount++;
      }
      // management internal control structures
      SRAMByteCnt -= count;
      adrs        += count;
   }
   // disaply the time.
   xlogstr("total time to write ", xlog);
   xlogint(totalTime, xlog);
   xlogstr("\n", xlog);
   xlogresync(xlog);


   // do the read & validate it.
   SRAMByteCnt = (SRAM_SIZE_IN_BYTES / 4);
   data = seed;
   adrs = (SRAM_SIZE_IN_BYTES / 4) * instance;
   error = 0;
   xlogstr("reading back from SRAM in byte mode to validate it...\n", xlog);
   xlogresync(xlog);
   totalTime = 0;
   while (SRAMByteCnt > 0)
   {
      // how many to write this round.
      count = SRAMByteCnt;
      if (count > TEST_BUFFER_SIZE)
      {
         count = TEST_BUFFER_SIZE;
      }

      // write to sram using word access
      tmr :> startTime;
      Result = sram_rdb(sram, adrs, Buf, 0, count);
      tmr :> endTime;
      totalTime += (endTime - startTime);
      if (Result != 0)
      {
         xlogstr("Rading from SRAM in byte mode, StartAdrs ", xlog);
         xloghex(adrs, xlog);
         xlogstr(" count ", xlog);
         xloghex(count, xlog);
         xlogstr("\n", xlog);
         xlogstr("ERROR: reading from SRAM in byte mode.\n", xlog);
         xlogresync(xlog);
         errorCount++;
      }
      // validate the data.
      for (i = 0; i < count; i += 1)
      {
         if (Buf[i] != data)
         {
            error += 1;
            xlogstr("Error : Adrs ", xlog);
            xloghex((adrs + i), xlog);
            xlogstr(" Exp ", xlog);
            xloghex(data, xlog);
            xlogstr(" Act ", xlog);
            xloghex(Buf[i], xlog);
            xlogstr("\n", xlog);
            xlogresync(xlog);
            errorCount++;
         }
         data = getNextByteData(data);
      }
      // management internal control structures
      SRAMByteCnt -= count;
      adrs        += count;
   }
   // disaply the time.
   xlogstr("total time to read ", xlog);
   xlogint(totalTime, xlog);
   xlogstr("\n", xlog);
   xlogresync(xlog);

   if (error == 0)
   {
      xlogstr("test PASS\n", xlog);
      xlogresync(xlog);
   }

}


/** Single word access mode
 */
void sram_single_word_access_test(chanend sram, unsigned int seed, int instance, int &errorCount, chanend xlog)
{
   timer tmr;
   int i, error;
   unsigned int data, addr, temp;
   int Result;
   unsigned int startTime, endTime, totalTime;

   // Do the writes.
   addr = (SRAM_SIZE_IN_BYTES / 4) * instance;
   data = seed;
   xlogstr("writing to SRAM in single word...\n", xlog);
   xlogresync(xlog);
   totalTime = 0;
   for (i = 0; i < ((SRAM_SIZE_IN_BYTES / 4) >> 2); i += 1)
   {
      tmr :> startTime;
      Result = sram_wrw_single(sram, addr, data);
      tmr :> endTime;
      totalTime += (endTime - startTime);
      if (Result != 0)
      {
         xlogstr("writing to SRAM in single word mode, Adrs ", xlog);
         xloghex(addr, xlog);
         xlogstr(" value ", xlog);
         xloghex(data, xlog);
         xlogstr("\n", xlog);
         xlogstr("ERROR: writing to SRAM in single word mode.\n", xlog);
         xlogresync(xlog);
         errorCount++;
      }
      addr += 4;
      data = getNextWordData(data);
   }
   // disaply the time.
   xlogstr("total time to write ", xlog);
   xlogint(totalTime, xlog);
   xlogstr("\n", xlog);
   xlogresync(xlog);

   // Do the reads
   error = 0;
   addr = (SRAM_SIZE_IN_BYTES / 4) * instance;
   data = seed;
   xlogstr("reading back from SRAM in single word to validate it...\n", xlog);
   xlogresync(xlog);
   totalTime = 0;
   for (i = 0; i < ((SRAM_SIZE_IN_BYTES / 4) >> 2); i += 1)
   {
      tmr :> startTime;
      temp = sram_rdw_single(sram, addr);
      tmr :> endTime;
      totalTime += (endTime - startTime);
      if (Result != 0)
      {
         xlogstr("reading from SRAM in single word mode, Adrs ", xlog);
         xloghex(addr, xlog);
         xlogstr(" value ", xlog);
         xloghex(data, xlog);
         xlogstr("\n", xlog);
         xlogstr("ERROR: reading from SRAM in single word mode.\n", xlog);
         xlogresync(xlog);
         errorCount++;
      }
      // check the data
      if (temp != data)
      {
            error += 1;
            xlogstr("Error : Adrs ", xlog);
            xloghex((addr), xlog);
            xlogstr(" Exp ", xlog);
            xloghex(data, xlog);
            xlogstr(" Act ", xlog);
            xloghex(temp, xlog);
            xlogstr("\n", xlog);
            xlogresync(xlog);
            errorCount++;
      }
      addr += 4;
      data = getNextWordData(data);
   }
   // disaply the time.
   xlogstr("total time to read ", xlog);
   xlogint(totalTime, xlog);
   xlogstr("\n", xlog);
   xlogresync(xlog);

   if (error == 0)
   {
      xlogstr("test PASS\n", xlog);
      xlogresync(xlog);
   }

}

#define TEST_FIFO_SIZE  (4096)

#if 0
/** This perform SRAM sink FIFO Write test.
 */
void sram_sink_fifo_test_Wr(chanend sram)
{
   int Result;
   unsigned int sram_chanEndHandle;
   int i, count, numEntries;
   unsigned int Buf[TEST_FIFO_SIZE >> 1];
   unsigned int data, reFillSize;

   xlogstr("SRAM sink FIFO Write thread started...\n", xlog);

   // create the fifo.
   sram_chanEndHandle = _getChanEndHandle(sram);
   Result = sram_client_sink_fifo_init(sram, TEST_FIFO_SIZE);
   if (Result != 0)
   {
      xlogstr("ERROR: Creating SRAM client sink fifo, size ", xlog);
      xloghex(TEST_FIFO_SIZE, xlog);
      xlogstr("\n", xlog);
      while (1)
      {
      }
   }

   // fill the fifo as when required, use half marker
   numEntries = 0;
   data = 0x12345678;
   count = 0;
   for (i = 0; i < (TEST_FIFO_SIZE >> 1); i += 1)
   {
      Buf[i] = data;
      data = getNextWordData(data);
   }
   // initial write to SRAM.
   Result = sram_wrw(sram, 0, Buf, 0, (TEST_FIFO_SIZE >> 1));
   if (Result == 0) {
      xlogstr("FIFO Wr: Initial buffer in SRAM.\n", xlog);
   } else {
      xlogstr("FIFO Wr: Error intial write to SRAM.\n", xlog);
   }

   reFillSize = 1024;
   // fill the fifo as required.
   while (1)
   {
      numEntries = sram_client_sink_fifo_numEntries();
      // wait until its half way and then fill.
      if ((TEST_FIFO_SIZE - numEntries) >= reFillSize)
      {
         // move the data into fifo.
         Result = sram_client_sink_fifo_fill(0, reFillSize);

         /*
         if (Result == 0) {
         } else {
            xlogstr("FIFO Wr: ERROR on fifo fill.\n", xlog);
         }
         // refill the SRAM.
         for (i = 0; i < (TEST_FIFO_SIZE >> 1); i += 1)
         {
            Buf[i] = data;
            data = getNextWordData(data);
         }
         // initial write to SRAM.
         Result = sram_wrw(sram, 0, Buf, 0, (TEST_FIFO_SIZE >> 1));
         if (Result == 0) {
         } else {
            xlogstr("FIFO Wr: ERROR Sub sequence SRAM writes.\n", xlog);
         }
         */
         count += 1;
         if ((count & 0x3FF) == 0x3FF)
         {
            xlogstr("*\n", xlog);
         }
      }
   }
}
#endif


#if 0
#define RD_TIME_OUT     50
/** This perform SRAM sink FIFO Read test.
 */
void sram_sink_fifo_test_Rd(chanend sram)
{
   unsigned int data, temp, curTime, count;
   timer rd_timer;


   xlogstr("SRAM sink FIFO Read thread started...\n", xlog);

   // wait until fifo has entries.
   data = 0;
   while (data < 2048)
   {
      data = sram_client_sink_fifo_numEntries();
   }
   xlogstr("Intial FIFO entries ", xlog);
   xloghex(data, xlog);
   xlogstr("\n", xlog);
   // read frist sample.
   data = sram_client_sink_fifo_rd();
   data = getNextWordData(data);
   count = 0;
   while (1)
   {
      // read data and compare.
      temp = sram_client_sink_fifo_rd();
      rd_timer :> curTime;
      count += 1;
      if (temp == FIFO_UNDERFLOW_MARKER)
      {
         xlogstr("FIFO Rd Error: Underflow, index ", xlog);
         xloghex(count, xlog);
         xlogstr("\n", xlog);
      }

      /*
      if (temp == data)
      {
         xlogstr("FIFO Rd Error: ", xlog);
         xlogstr(" count ", xlog);
         xloghex(count, xlog);
         xlogstr(" Exp ", xlog);
         xloghex(data, xlog);
         xlogstr(" Act ", xlog);
         xloghex(temp, xlog);
         xlogstr("\n", xlog);
      }
      data = getNextWordData(data);
      count += 1;
      if ( (count & 0xFFFF) == 0xFFFF)
      {
         xlogstr("$\n", xlog);
      }
      */
      // wait for rate control.
      rd_timer when timerafter(curTime + RD_TIME_OUT) :> curTime;
   }

}
#endif

void sram_simple_test(chanend c_sram, chanend c_xlog)
{
  const char golden[] = { 1, 2, 3, 4, 5, 6, 7, 8 };
  char ret[64];
  assert(sizeof(ret) >= sizeof(golden));
  sram_wrb(c_sram, 0, golden, 0, sizeof(golden));
  sram_rdb(c_sram, 0, ret, 0, sizeof(golden));
#if 0
  for (int i = 0; i < sizeof(golden); i++)
  {
    xlogint(ret[i], c_xlog);
    xlogchr(' ', c_xlog);
  }
  xlogchr('\n', c_xlog);
  xlogresync(c_xlog);
#else
  for (int i = 0; i < sizeof(golden); i++)
  {
    if (ret[i] != golden[i])
    {
      xlogstr("MISMATCH ", c_xlog);
      xlogint(i, c_xlog);
      xlogchr(' ', c_xlog);
      xlogint(ret[i], c_xlog);
      xlogchr(' ', c_xlog);
      xlogint(golden[i], c_xlog);
      xlogchr('\n', c_xlog);
      xlogresync(c_xlog);
    }
  }
#endif
}

/** This perform SRAM client/server component testing.
 */
void sram_test(chanend sram, int instance, chanend xlog)
{
   int errorCount = 0;
   unsigned int buf[TEST_BUFFER_SIZE];

   for (int i = 0; i < 2; i++)
   {
      xlogstr("test iteration ", xlog);
      xlogint(i, xlog);
      xlogchr('\n', xlog);
      xlogresync(xlog);

      sram_byte_access_test(sram, (buf, unsigned char[]), (unsigned char) (i + 1), instance, errorCount, xlog);
      sram_word_access_test(sram, buf, (unsigned int) (0x12345678 * (i + 1)), instance, errorCount, xlog);
      sram_single_word_access_test(sram, (unsigned int) (0x9ABCDEF0 * (i + 1)), instance, errorCount, xlog);
   }

   if (errorCount == 0)
   {
     xlogstr("all tests PASS", xlog);
     xlogchr('\n', xlog);
     xlogresync(xlog);
   }
   else
   {
     xlogstr("error count: ", xlog);
     xlogint(errorCount, xlog);
     xlogchr('\n', xlog);
     xlogresync(xlog);
     exit(1);
   }
}

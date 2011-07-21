/**
 * Module:  module_sram
 * Version: 1v1
 * Build:   8a39342ad175f92aeaee0b02bd7866e0315cae15
 * File:    sram.xc
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
// sram.xc
// SRAM interface
//
// Copyright (C) 2009 XMOS Ltd
// Ayewin Oung, Ladislav Snizek
//

#include <xs1.h>
#include <platform.h>
#include "sram.h"

// Supported commands
#define SRAM_READ_CMD            (0x51)
#define SRAM_WRITE_CMD           (0x52)
#define SRAM_READ_WORD_CMD       (0x53)
#define SRAM_WORD_WRITE_CMD      (0x54)
#define SRAM_KILL_CMD            (0x55)

// Supported response
#define SRAM_RESP_ACK            (0xAA)
#define SRAM_RESP_NACK           (0xA5)

// Number of channels to support for SRAM server.
#define SRAM_SERVER_CHANNELS     (4)

#ifdef __SRAM_TESTING__

unsigned char pSRAM[SRAM_SIZE_IN_BYTES];

#else

#define SRAM_CTL_PORT_IDLE (0x3) // Both CSn & OEn are de-asserted.
#define SRAM_CTL_PORT_RD   (0x0) // Both CSn & OEn are asserted.
#define SRAM_CTL_PORT_WR   (0x1) // CSn is asserted and OEn is de-asserted.


// external SRAM PORTS
port out p_sram_wen  = PORT_SRAM_WE_N;
port out p_sram_addr  = PORT_SRAM_ADDR;
port out p_sram_ctl  = PORT_SRAM_CTRL;   // CSn = bit1, OEn = bit0
port     p_sram_data = PORT_SRAM_DATA;
#endif

/** SRAM Interface Byte Read.
 */
static unsigned char SRAM_SvrRead(unsigned int Adrs)
{
   unsigned t;
#ifdef  __SRAM_TESTING__
   return ( pSRAM[ Adrs % SRAM_SIZE_IN_BYTES] );
#else
   unsigned int Result;
   // assert the control lines.
   //p_sram_wen <: 1;
   p_sram_ctl <: SRAM_CTL_PORT_RD;
   // read with address.
   p_sram_addr <: Adrs @ t;
   // read data with 12 ns access time.
   p_sram_data @ (t + 8) :> Result;
   // de-assert the control lines.
   p_sram_ctl <: SRAM_CTL_PORT_IDLE;
   return(Result);
#endif
}

/** SRAM Interface Byte Write.
 */
static void SRAM_SvrWrite(unsigned int Adrs, unsigned char Data)
{
#ifdef __SRAM_TESTING__
   pSRAM[ Adrs % SRAM_SIZE_IN_BYTES] = Data;
#else
   // assert the control lines.
   p_sram_ctl <: SRAM_CTL_PORT_WR;
   // wirte with WEn
   p_sram_addr  <: Adrs;
   p_sram_data <: (unsigned char)Data;
   p_sram_wen  <: 0 ;
   //sync(p_sram_wen);
   p_sram_wen <: 1;
   // de-assert the control lines & turn data to input
   p_sram_ctl <: SRAM_CTL_PORT_IDLE;
   // turn the data port to in, to avoid any potential overdrive issues.
   p_sram_data :> Adrs;
#endif
}

/** SRAM Interface Word Read.
 */
static unsigned int SRAM_SvrWordRead(unsigned int Adrs)
{
#ifdef  __SRAM_TESTING__

   unsigned int Result = 0;
   int i;

   for (i = 0; i < 4; i += 1)
   {
      Result |= ((unsigned int) pSRAM[ Adrs % SRAM_SIZE_IN_BYTES]) << (i * 8);
      Adrs += 1;
   }

   return ( Result );

#else

   //unsigned int Result;
   unsigned int Temp;
   unsigned int Data;

   // assert the control lines.
   //p_sram_wen <: 1;
   p_sram_ctl <: SRAM_CTL_PORT_RD;
   // read with address.
   p_sram_addr <: Adrs;
   sync(p_sram_addr);
   // increment address for next time.
   Adrs += 1;
   p_sram_data :> Temp;
   p_sram_data :> >> Data;   // Read first Byte
   // read with address.
   p_sram_addr <: Adrs;
   sync(p_sram_addr);
   Adrs += 1;
   //Result = Data;
   p_sram_data :> Temp;
   p_sram_data :> >> Data;   // Read second Byte
   // read with address.
   p_sram_addr <: Adrs;
   sync(p_sram_addr);
   Adrs += 1;
   //Result |= Data << 8;
   p_sram_data :> Temp;
   p_sram_data :> >> Data;   // Read third Byte
   // read with address.
   p_sram_addr <: Adrs;
   sync(p_sram_addr);
   //Result |= Data << 16;
   p_sram_data :> Temp;
   p_sram_data :> >> Data;   // Read fourth Byte
   //Result |= Data << 24;
   // de-assert the control lines.
   p_sram_ctl <: SRAM_CTL_PORT_IDLE;


   return(Data);

#endif
}

/** SRAM Interface Word Write.
 */
static void SRAM_SvrWordWrite(unsigned int Adrs, unsigned int Data)
{

#ifdef __SRAM_TESTING__
   int i;

   for (i = 0; i < 4; i += 1)
   {
      pSRAM[ Adrs % SRAM_SIZE_IN_BYTES] = (unsigned char) Data;
      Data = Data >> 8;
      Adrs += 1;
   }

#else

   // assert the control lines.
   p_sram_ctl <: SRAM_CTL_PORT_WR;
   // wirte with WEn
   p_sram_addr  <: Adrs;
   p_sram_data <: Data;   // Byte 0 write
   Adrs += 1;
   p_sram_wen  <: 0;
   //sync(p_sram_wen);
   Data = Data >> 8;
   p_sram_wen <: 1;
   // wirte with WEn
   p_sram_addr  <: Adrs;
   p_sram_data <: Data;   // Byte 1 write
   Adrs += 1;
   p_sram_wen  <: 0;
   //sync(p_sram_wen);
   Data = Data >> 8;
   p_sram_wen <: 1;
   // wirte with WEn
   p_sram_addr  <: Adrs;
   p_sram_data <: Data;   // Byte 2 write
   Adrs += 1;
   p_sram_wen  <: 0 ;
   //sync(p_sram_wen);
   Data = Data >> 8;
   p_sram_wen <: 1;
   // wirte with WEn
   p_sram_addr  <: Adrs;
   p_sram_data <: Data;   // Byte 3 write
   p_sram_wen  <: 0 ;
   //sync(p_sram_wen);
   p_sram_wen <: 1;
   // de-assert the control lines & turn data to input
   p_sram_ctl <: SRAM_CTL_PORT_IDLE;
   // turn the data port to in, to avoid any potential overdrive issues.
   p_sram_data :> Adrs;


#endif
}


/** Command execution.
 * returns 0 if received kill, else returns 1;
 */
static unsigned SRAM_SvrCmdExec(chanend ifPort, unsigned char Cmd, unsigned int Adrs, int Count)
{
   unsigned char ByteData;
   unsigned int  WordData;
   unsigned int retVal = 1;

   switch (Cmd)
   {
      case SRAM_READ_CMD:  // Byte(s) Read command.
         // Send ACK
         ifPort <: (unsigned char) SRAM_RESP_ACK;
         // use transection.
         slave
				 {
            clearbuf(p_sram_data);
            clearbuf(p_sram_addr);
            clearbuf(p_sram_ctl);
            for (int i = 0; i < Count; i++)
            {
               ifPort <: (unsigned char) SRAM_SvrRead(Adrs + i);
            }
         }
         break;
      case SRAM_WRITE_CMD:  // Byte(s) Write command.
         // use transection
         slave
				 {
            for (int i = 0; i < Count; i++)
            {
               ifPort :> ByteData;
               SRAM_SvrWrite(Adrs + i, ByteData);
            }
         }
         // Send ACK
         ifPort <: (unsigned char) SRAM_RESP_ACK;
         break;

      case SRAM_READ_WORD_CMD:  // Word(s) Read command.
         // Send ACK
         ifPort <: (unsigned char) SRAM_RESP_ACK;
         // use transection.
         slave
				 {
            for (int i = 0; i < Count; i++)
            {
               ifPort <: (unsigned int) SRAM_SvrWordRead(Adrs + (i << 2));
            }
         }
         break;
      case SRAM_WORD_WRITE_CMD:  // Word(s) Write command.
         // use transection
         slave
				 {
            for (int i = 0; i < Count; i++)
            {
               ifPort :> WordData;
               SRAM_SvrWordWrite(Adrs + (i << 2), WordData);
            }
         }
         // Send ACK
         ifPort <: (unsigned char) SRAM_RESP_ACK;
         break;

      case SRAM_KILL_CMD: 	// Kill Server cmd
          retVal = 0;       // Update return value
          ifPort <: (unsigned char) SRAM_RESP_ACK; // Send ack
	  break;

       default:    // Unsupported commands.
         ifPort <: (unsigned char) SRAM_RESP_NACK;
         break;
   }
   return retVal;
}

/** This get a Cmd data structure in a transaction, to make things faster.
 */
transaction getCmd(chanend c, unsigned char &Cmd, unsigned int &Adrs, int &Count)
{
   c :> Cmd;
   c :> Adrs;
   c :> Count;
}

/** Generic FOUR Port(s) SRAM x8 Server Component.
 */
void sram(chanend port1, chanend port2, chanend port3)
{
   // command package.
   unsigned char Cmd;
   unsigned int  Adrs;
   int Count;
   unsigned int serverActive = 1;
   timer t;
   unsigned timeNow;
   int i, chanEnabled[SRAM_SERVER_CHANNELS];


#ifndef __SRAM_TESTING__

   // Initialise the SRAM physical interfaces.
   p_sram_ctl <: SRAM_CTL_PORT_IDLE;
   p_sram_wen <: 1;
   p_sram_addr <: 0;
   p_sram_data :> Cmd; // turn around the port for safty

#endif

   // initialise the conditions
   for (i = 0; i < SRAM_SERVER_CHANNELS; i += 1)
   {
      chanEnabled[i] = 1;
   }

   // general loop.
   while (serverActive)
   {
      t :> timeNow;

      select
      {
#define SLAVE_CASE(enabled, sram_chan, Cmd, Adrs, Count) \
  case enabled => slave { sram_chan :> Cmd; sram_chan :> Adrs; sram_chan :> Count; }:
         SLAVE_CASE(chanEnabled[0], port1, Cmd, Adrs, Count);
               serverActive = SRAM_SvrCmdExec(port1, Cmd, Adrs, Count);
               break;

         SLAVE_CASE(chanEnabled[1], port2, Cmd, Adrs, Count);
               serverActive = SRAM_SvrCmdExec(port2, Cmd, Adrs, Count);
               break;

         SLAVE_CASE(chanEnabled[2], port3, Cmd, Adrs, Count);
               serverActive = SRAM_SvrCmdExec(port3, Cmd, Adrs, Count);
               break;

	 /*
#define SRAM_CHAN_SWITCH_TIMEOUT    (75)

         case t when timerafter(timeNow + SRAM_CHAN_SWITCH_TIMEOUT) :> timeNow:
            {
               // clear all guards
               for (i = 0; i < SRAM_SERVER_CHANNELS; i += 1)
               {
                  chanEnabled[i] = 1;
               }
               break;
            }
         */
      }
   }

   // serverActive must have been set low...
}

// This specify max. number of transfers per block.
#define SRAM_MAX_BLK_SIZE     (1024)


/** Generic SRAM Byte Read.
 *  c_sram   : ChannelEnd connection to SRAM server.
 *  StartAdrs  : Start address of external SRAM.
 *  Buf[]      : Local data buffer.
 *  StartIndex : Start offset within Buf[] to place to read data.
 *               This allow simple circular buffer implementation.
 *  ByteCnt    : Number of bytes to read.
 */
int sram_rdb(chanend c_sram, unsigned int StartAdrs, unsigned char Buf[], int StartIndex, int ByteCnt)
{
   int Result = 0;
   int count;
   unsigned char Resp;

   while (ByteCnt > 0)
   {
      // work out how many bytes to transfer.
      count = ByteCnt;
      if (count > SRAM_MAX_BLK_SIZE)
      {
         count = SRAM_MAX_BLK_SIZE;
      }
      // generate tranfser
      master
			{
         c_sram <: (unsigned char) SRAM_READ_CMD;
         c_sram <: (unsigned int)  StartAdrs;
         c_sram <: (int) count;
      }
      c_sram :> Resp;
      // base on response.
      switch (Resp)
      {
         case SRAM_RESP_ACK:
            master
						{
               // received byte data.
               for (int i = 0; i < count; i++)
               {
                  c_sram :> Buf[StartIndex + i];
               }
            }
            Result = 0;
            break;
         case SRAM_RESP_NACK:
            Result = 2;
            break;
         default:
            Result = 1;
            break;
      }
      // maintain the data structres.
      ByteCnt   -= count;
      StartAdrs += count;
      // sanity checking.
      if (Result != 0)
      {
         break;
      }
   }

   return (Result);
}

/** Generic SRAM Byte Write.
 *  c_sram   : ChannelEnd connection to SRAM server.
 *  StartAdrs  : Start address of external SRAM.
 *  Buf[]      : Local data buffer.
 *  StartIndex : Start offset within Buf[] for data to write.
 *               This allow simple circular buffer implementation.
 *  ByteCnt    : Number of bytes to write.
 */
int sram_wrb(chanend c_sram, unsigned int StartAdrs, const unsigned char Buf[], int StartIndex, int ByteCnt)
{
   int Result = 0;
   int count;
   unsigned char Resp;

   while (ByteCnt > 0)
   {
      // work out how many bytes to transfer.
      count = ByteCnt;
      if (count > SRAM_MAX_BLK_SIZE)
      {
         count = SRAM_MAX_BLK_SIZE;
      }
      // generate tranfser
      master
			{
         c_sram <: (unsigned char) SRAM_WRITE_CMD;
         c_sram <: (unsigned int)  StartAdrs;
         c_sram <: (int) count;
      }
      master
			{
         // output byte data.
         for (int i = 0; i < count; i++)
         {
            c_sram <: (unsigned char) Buf[StartIndex + i];
         }
      }
      // get response.
      c_sram :> Resp;
      // base on response.
      switch (Resp)
      {
         case SRAM_RESP_ACK:
            Result = 0;
            break;
         case SRAM_RESP_NACK:
            Result = 2;
            break;
         default:
            Result = 1;
            break;
      }
      // maintain the data structres.
      ByteCnt   -= count;
      StartAdrs += count;
   }

   return (Result);
}

/** Generic SRAM Word Read.
 *  c_sram   : ChannelEnd connection to SRAM server.
 *  StartAdrs  : Start address of external SRAM.
 *  Buf[]      : Local data buffer.
 *  StartIndex : Start offset within Buf[] to place to read data.
 *               This allow simple circular buffer implementation.
 *  WordCnt    : Number of word to read.
 */
int sram_rdw(chanend c_sram, unsigned int StartAdrs, unsigned int Buf[], int StartIndex, int WordCnt)
{
   int Result = 0;
   int count;
   unsigned char Resp;

   // perform the transfer.
   while (WordCnt > 0)
   {
      // work out how many Words to transfer.
      count = WordCnt;
      if (count > SRAM_MAX_BLK_SIZE)
      {
         count = SRAM_MAX_BLK_SIZE;
      }
      // generate tranfser
      master
			{
         c_sram <: (unsigned char) SRAM_READ_WORD_CMD;
         c_sram <: (unsigned int)  StartAdrs;
         c_sram <: (int) count;
      }
      c_sram :> Resp;
      // base on response.
      switch (Resp)
      {
         case SRAM_RESP_ACK:
            master
						{
               // received word data.
               for (int i = 0; i < count; i++)
               {
                  c_sram :> Buf[StartIndex + i];
               }
            }
            Result = 0;
            break;
         case SRAM_RESP_NACK:
            Result = 2;
            break;
         default:
            Result = 1;
            break;
      }
      // maintain the data structres.
      WordCnt   -= count;
      StartAdrs += (count << 2);
      // sanity checking.
      if (Result != 0)
      {
         break;
      }
   }

   return (Result);
}

/** Generic SRAM Word Write.
 *  c_sram   : ChannelEnd connection to SRAM server.
 *  StartAdrs  : Start address of external SRAM.
 *  Buf[]      : Local data buffer.
 *  StartIndex : Start offset within Buf[] for data to write.
 *               This allow simple circular buffer implementation.
 *  WordCnt    : Number of words to write.
 */
int sram_wrw(chanend c_sram, unsigned int StartAdrs, const unsigned int Buf[], int StartIndex, int WordCnt)
{
   int Result = 0;
   int count;
   unsigned char Resp;

   // do the transfer
   while (WordCnt > 0)
   {
      // work out how many bytes to transfer.
      count = WordCnt;
      if (count > SRAM_MAX_BLK_SIZE)
      {
         count = SRAM_MAX_BLK_SIZE;
      }
      // generate tranfser
      master
			{
         c_sram <: (unsigned char) SRAM_WORD_WRITE_CMD;
         c_sram <: (unsigned int)  StartAdrs;
         c_sram <: (int) count;
      }
      master
			{
         // send word data.
         for (int i = 0; i < count; i++)
         {
            c_sram <: Buf[StartIndex + i];
         }
      }
      // get response.
      c_sram :> Resp;
      // base on response.
      switch (Resp)
      {
         case SRAM_RESP_ACK:
            Result = 0;
            break;
         case SRAM_RESP_NACK:
            Result = 2;
            break;
         default:
            Result = 1;
            break;
      }
      // maintain the data structres.
      WordCnt   -= count;
      StartAdrs += (count << 2);
   }

   return (Result);
}

/** Generic SRAM single word write.
 *  c_sram   : ChannelEnd connection to SRAM server.
 *  Addr       : SRAM address to write to.
 *  Data       : Word data to write.
 */
int sram_wrw_single(chanend c_sram, unsigned int Addr, unsigned int Data)
{
   int Result = 0;
   unsigned char Resp;

   // generate tranfser
   master
	 {
      c_sram <: (unsigned char) SRAM_WORD_WRITE_CMD;
      c_sram <: (unsigned int) Addr;
      c_sram <: (int) 1;
   }
   master
	 {
     c_sram <: Data;
   }
   // get response.
   c_sram :> Resp;
   // base on response.
   switch (Resp)
   {
      case SRAM_RESP_ACK:
         Result = 0;
         break;
      case SRAM_RESP_NACK:
         Result = 2;
         break;
      default:
         Result = 1;
         break;
   }

   return (Result);
}

/** Generic SRAM single word write.
 *  c_sram   : ChannelEnd connection to SRAM server.
 *  Addr       : SRAM address to write to.
 *  Return     : Read data.
 */
unsigned int sram_rdw_single(chanend c_sram, unsigned int Addr)
{
   unsigned char Resp;
   unsigned int Data = 0xdeaddead;

   // generate tranfser
   master
	 {
      c_sram <: (unsigned char) SRAM_READ_WORD_CMD;
      c_sram <: (unsigned int) Addr;
      c_sram <: (int) 1;
   }
   c_sram :> Resp;
   // base on response.
   switch (Resp)
   {
      case SRAM_RESP_ACK:
         master
				 {
           c_sram :> Data;
         }
         break;
      default:
         break;
   }

   return (Data);
}

/** Kill server command.
 *  c_sram   : ChannelEnd connection to SRAM server.
 *  Addr       :
 *  Return     : void
 */
void sram_shutdown(chanend c_sram)
{
   unsigned char Resp;

   // generate tranfser
   master
	 {
      c_sram <: (unsigned char) SRAM_KILL_CMD;
      c_sram <: 1;
      c_sram <: 1;
   }

   c_sram :> Resp;
}

/**
 * Module:  module_sram
 * Version: 1v1
 * Build:   8a39342ad175f92aeaee0b02bd7866e0315cae15
 * File:    sram.h
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
// sram.h
// SRAM interface header
//
// Copyright (C) 2009 XMOS Ltd
// Ayewin Oung, Ladislav Snizek
//

#ifndef _sram_h_
#define _sram_h_

// Server
void sram(chanend port1, chanend port2, chanend port3);

// Size of SRAM
#ifdef __SRAM_TESTING__
#define SRAM_SIZE_IN_BYTES   (0x8000) // 32KByte to test SRAM.
#else
#define SRAM_SIZE_IN_BYTES   (0x80000) // 512KByte SRAM.
#endif

// Generic SRAM Byte Read.
// c_sram     : ChannelEnd connection to SRAM server.
// StartAdrs  : Start address of external SRAM.
// Buf[]      : Local data buffer.
// StartIndex : Start offset within Buf[] to place to read data.
//              This allow simple circular buffer implementation.
// ByteCnt    : Number of bytes to read.
//
int sram_rdb(chanend c_sram, unsigned int StartAdrs, unsigned char Buf[], int StartIndex, int ByteCnt);

// Generic SRAM Byte Write.
// c_sram     : ChannelEnd connection to SRAM server.
// StartAdrs  : Start address of external SRAM.
// Buf[]      : Local data buffer.
// StartIndex : Start offset within Buf[] for data to write.
//              This allow simple circular buffer implementation.
// ByteCnt    : Number of bytes to write.
//
int sram_wrb(chanend c_sram, unsigned int StartAdrs, const unsigned char Buf[], int StartIndex, int ByteCnt);


/******************************************************************************
 *
 * Multiple Words(s) Read/Write interface.
 *
 *****************************************************************************/

// Generic SRAM Word Read.
// c_sram     : ChannelEnd connection to SRAM server.
// StartAdrs  : Start address of external SRAM, must be word aligned.
// Buf[]      : Local data buffer.
// StartIndex : Start offset within Buf[] to place to read data.
//              This allow simple circular buffer implementation.
// WordCnt    : Number of words to read.
//
int sram_rdw(chanend c_sram, unsigned int StartAdrs, unsigned int Buf[], int StartIndex, int WordCnt);

// Generic SRAM Word Write.
// c_sram     : ChannelEnd connection to SRAM server.
// StartAdrs  : Start address of external SRAM.
// Buf[]      : Local data buffer.
// StartIndex : Start offset within Buf[] for data to write, must be word alinged.
//              This allow simple circular buffer implementation.
// WordCnt    : Number of words to write.
//
int sram_wrw(chanend c_sram, unsigned int StartAdrs, const unsigned int Buf[], int StartIndex, int WordCnt);


/******************************************************************************
 *
 * Single Read/Write interface.
 *
 *****************************************************************************/

// Generic SRAM single word write.
// c_sram     : ChannelEnd connection to SRAM server.
// Addr       : SRAM address to write to (byte address).
// Data       : Word data to write.
//
int sram_wrw_single(chanend c_sram, unsigned int Addr, unsigned int Data);

// Generic SRAM single word write.
// c_sram     : ChannelEnd connection to SRAM server.
// Addr       : SRAM address to read from (byte address).
// Return     : Read data.
//
unsigned int sram_rdw_single(chanend c_sram, unsigned int Addr);


void sram_shutdown(chanend c_sram);

#endif

/* -*- c++ -*- */

#define ZLUUDGBEE_API
#define ETTUS_API

%include "gnuradio.i"/*			*/// the common stuff

//load generated python docstrings
%include "zluudgbee_swig_doc.i"
//Header from gr-ettus
%include "ettus/device3.h"
%include "ettus/rfnoc_block.h"
%include "ettus/rfnoc_block_impl.h"

%{
#include "ettus/device3.h"
#include "ettus/rfnoc_block_impl.h"
#include "zluudgbee/zluudgbeeRX.h"
#include "zluudgbee/zluudgbeeCRC.h"
#include "zluudgbee/chdr2pdu.h"
#include "zluudgbee/dummycoord.h"
#include "zluudgbee/softcrc.h"
%}

%include "zluudgbee/zluudgbeeRX.h"
GR_SWIG_BLOCK_MAGIC2(zluudgbee, zluudgbeeRX);
%include "zluudgbee/zluudgbeeCRC.h"
GR_SWIG_BLOCK_MAGIC2(zluudgbee, zluudgbeeCRC);
%include "zluudgbee/chdr2pdu.h"
GR_SWIG_BLOCK_MAGIC2(zluudgbee, chdr2pdu);
%include "zluudgbee/dummycoord.h"
GR_SWIG_BLOCK_MAGIC2(zluudgbee, dummycoord);
%include "zluudgbee/softcrc.h"
GR_SWIG_BLOCK_MAGIC2(zluudgbee, softcrc);

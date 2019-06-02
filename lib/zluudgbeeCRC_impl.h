/* -*- c++ -*- */
/* 
 * Copyright 2019 <+YOU OR YOUR COMPANY+>.
 * 
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 * 
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this software; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#ifndef INCLUDED_ZLUUDGBEE_ZLUUDGBEECRC_IMPL_H
#define INCLUDED_ZLUUDGBEE_ZLUUDGBEECRC_IMPL_H

#include <zluudgbee/zluudgbeeCRC.h>
#include <zluudgbee/zluudgbeeCRC_block_ctrl.hpp>
#include <ettus/rfnoc_block_impl.h>

namespace gr {
  namespace zluudgbee {

    class zluudgbeeCRC_impl : public zluudgbeeCRC, public gr::ettus::rfnoc_block_impl
    {
     private:
      // Nothing to declare in this block.

     public:
      zluudgbeeCRC_impl(
        const gr::ettus::device3::sptr &dev,
        const ::uhd::stream_args_t &tx_stream_args,
        const ::uhd::stream_args_t &rx_stream_args,
        const int block_select,
        const int device_select,
        const bool enable_eob_on_stop
      );
      ~zluudgbeeCRC_impl();

      // Where all the action really happens
    };

  } // namespace zluudgbee
} // namespace gr

#endif /* INCLUDED_ZLUUDGBEE_ZLUUDGBEECRC_IMPL_H */


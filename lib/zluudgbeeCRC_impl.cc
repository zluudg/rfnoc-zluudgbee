/* -*- c++ -*- */
/* 
 * Copyright 2019 Leon Fernandez (zluudg).
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

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <gnuradio/io_signature.h>
#include "zluudgbeeCRC_impl.h"
namespace gr {
  namespace zluudgbee {
    zluudgbeeCRC::sptr
    zluudgbeeCRC::make(
        const gr::ettus::device3::sptr &dev,
        const ::uhd::stream_args_t &tx_stream_args,
        const ::uhd::stream_args_t &rx_stream_args,
        const int block_select,
        const int device_select,
        const bool enable_eob_on_stop
    )
    {
      return gnuradio::get_initial_sptr(
        new zluudgbeeCRC_impl(
            dev,
            tx_stream_args,
            rx_stream_args,
            block_select,
            device_select,
            enable_eob_on_stop
        )
      );
    }

    /*
     * The private constructor
     */
    zluudgbeeCRC_impl::zluudgbeeCRC_impl(
         const gr::ettus::device3::sptr &dev,
         const ::uhd::stream_args_t &tx_stream_args,
         const ::uhd::stream_args_t &rx_stream_args,
         const int block_select,
         const int device_select,
         const bool enable_eob_on_stop
    )
      : gr::ettus::rfnoc_block("zluudgbeeCRC"),
        gr::ettus::rfnoc_block_impl(
            dev,
            gr::ettus::rfnoc_block_impl::make_block_id("zluudgbeeCRC",  block_select, device_select),
            tx_stream_args, rx_stream_args, enable_eob_on_stop
            )
    {}

    /*
     * Our virtual destructor.
     */
    zluudgbeeCRC_impl::~zluudgbeeCRC_impl()
    {
    }

  } /* namespace zluudgbee */
} /* namespace gr */


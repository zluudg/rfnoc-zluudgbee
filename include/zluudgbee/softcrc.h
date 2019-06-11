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


#ifndef INCLUDED_ZLUUDGBEE_SOFTCRC_H
#define INCLUDED_ZLUUDGBEE_SOFTCRC_H

#include <zluudgbee/api.h>
#include <gnuradio/sync_block.h>

namespace gr {
  namespace zluudgbee {

    /*!
     * \brief <+description of block+>
     * \ingroup zluudgbee
     *
     */
    class ZLUUDGBEE_API softcrc : virtual public gr::block
    {
     public:
      typedef boost::shared_ptr<softcrc> sptr;

      /*!
       * \brief Return a shared_ptr to a new instance of zluudgbee::softcrc.
       *
       * To avoid accidental use of raw pointers, zluudgbee::softcrc's
       * constructor is in a private implementation
       * class. zluudgbee::softcrc::make is the public interface for
       * creating new instances.
       */
      static sptr make(bool rx_mode=true);
    };

  } // namespace zluudgbee
} // namespace gr

#endif /* INCLUDED_ZLUUDGBEE_SOFTCRC_H */


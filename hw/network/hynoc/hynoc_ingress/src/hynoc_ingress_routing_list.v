// SPDX-License-Identifier: CERN-OHL-P-2.0
// Copyright (c) 2013-2026 Christophe Clienti
//
// This source describes Open Hardware and is licensed under the CERN-OHL-P v2.
// You may redistribute and modify this file under the terms of the CERN-OHL-P v2
// (https://ohwr.org/cern_ohl_p_v2.txt).
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
// OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
// Please see the CERN-OHL-P v2 for applicable conditions.



localparam FLIT_PROTO_WIDTH = 4;

// List of supported routing laws
localparam PROTO_ROUTING_UCAST_CIRCUIT_SWITCH = 4'b0000;
localparam PROTO_ROUTING_MCAST_CIRCUIT_SWITCH = 4'b0001;
localparam PROTO_ROUTING_XY                   = 4'b1000;

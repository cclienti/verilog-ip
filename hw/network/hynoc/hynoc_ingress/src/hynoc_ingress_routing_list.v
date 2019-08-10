//                              -*- Mode: Verilog -*-
// Filename        : hynoc_ingress_routing_list.v
// Description     : hynoc ingress routing local parameters
// Author          : Christophe
// Created On      : Mon May  9 22:27:20 2016
// Last Modified By: Christophe
// Last Modified On: Mon May  9 22:27:20 2016
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

localparam FLIT_PROTO_WIDTH = 4;

// List of supported routing laws
localparam PROTO_ROUTING_UCAST_CIRCUIT_SWITCH = 4'b0000;
localparam PROTO_ROUTING_MCAST_CIRCUIT_SWITCH = 4'b0001;
localparam PROTO_ROUTING_XY                   = 4'b1000;

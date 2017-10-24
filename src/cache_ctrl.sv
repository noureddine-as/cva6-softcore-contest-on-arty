/* File:   cache_ctrl.svh
 * Author: Florian Zaruba <zarubaf@ethz.ch>
 * Date:   14.10.2017
 *
 * Copyright (C) 2017 ETH Zurich, University of Bologna
 * All rights reserved.
 *
 * Description: Cache controller
 */

import ariane_pkg::*;
import nbdcache_pkg::*;

module cache_ctrl #(
        parameter int unsigned SET_ASSOCIATIVITY = 8,
        parameter int unsigned INDEX_WIDTH       = 12,
        parameter int unsigned TAG_WIDTH         = 44,
        parameter int unsigned CACHE_LINE_WIDTH  = 100
    )(
        input  logic                                               clk_i,     // Clock
        input  logic                                               rst_ni,    // Asynchronous reset active low
        input  logic                                               bypass_i,  // enable cache
        output logic                                               busy_o,
        // Core request ports
        input  logic [INDEX_WIDTH-1:0]                             address_index_i,
        input  logic [TAG_WIDTH-1:0]                               address_tag_i,
        input  logic [63:0]                                        data_wdata_i,
        input  logic                                               data_req_i,
        input  logic                                               data_we_i,
        input  logic [7:0]                                         data_be_i,
        input  logic                                               kill_req_i,
        input  logic                                               tag_valid_i,
        output logic                                               data_gnt_o,
        output logic                                               data_rvalid_o,
        output logic [63:0]                                        data_rdata_o,
        input  amo_t                                               amo_op_i,
        // SRAM interface
        output logic [SET_ASSOCIATIVITY-1:0]                       req_o,  // req is valid
        output logic [INDEX_WIDTH-1:0]                             addr_o, // address into cache array
        input  logic                                               gnt_i,
        output cache_line_t                                        data_o,
        output cl_be_t                                             be_o,
        output logic [TAG_WIDTH-1:0]                               tag_o, //valid one cycle later
        input  cache_line_t [SET_ASSOCIATIVITY-1:0]                data_i,
        output logic                                               we_o,
        input  logic [SET_ASSOCIATIVITY-1:0]                       hit_way_i,
        // Miss handling
        output miss_req_t                                          miss_req_o,
        // return
        input  logic                                               miss_gnt_i,
        input  logic                                               miss_valid_i,
        input  logic [CACHE_LINE_WIDTH-1:0]                        miss_data_i,
        input  logic [63:0]                                        critical_word_i,
        input  logic                                               critical_word_valid_i,

        input  logic                                               bypass_gnt_i,
        input  logic                                               bypass_valid_i,
        input  logic [CACHE_LINE_WIDTH-1:0]                        bypass_data_i,
        // check MSHR for aliasing
        output logic [55:0]                                        mshr_addr_o,
        input  logic                                               mashr_addr_matches_i
);

    enum logic [2:0] {
        IDLE, WAIT_TAG, WAIT_TAG_BYPASSED, WAIT_REFILL_VALID, WAIT_REFILL_GNT, WAIT_TAG_SAVED, WAIT_MSHR
    } state_d, state_q;

    typedef struct packed {
        logic [INDEX_WIDTH-1:0]         index;
        logic [TAG_WIDTH-1:0]           tag;
        logic [7:0]                     be;
        logic                           we;
        logic [CACHE_LINE_WIDTH-1:0]    wdata;
        logic                           bypass;
    } mem_req_t;

    logic [SET_ASSOCIATIVITY-1:0] hit_way_d, hit_way_q;

    assign busy_o = (state_q != IDLE);

    mem_req_t mem_req_d, mem_req_q;

    // --------------
    // Cache FSM
    // --------------
    always_comb begin : cache_ctrl_fsm
        // default assignments
        state_d   = state_q;
        mem_req_d = mem_req_q;
        hit_way_d = hit_way_q;

        // output assignments
        data_gnt_o    = 1'b0;
        data_rvalid_o = 1'b0;
        data_rdata_o  = '0;
        miss_req_o    = '0;
        mshr_addr_o   = '0;
        // Memory array communication
        req_o  = '0;
        addr_o = '0;
        data_o = '0;
        be_o   = '0;
        tag_o  = '0;
        we_o   = '0;
        tag_o  = 'b0;

        case (state_q)

            IDLE: begin

                // a new request arrived
                if (data_req_i) begin
                    // save index, be and we
                    mem_req_d.index = address_index_i;
                    mem_req_d.be = data_be_i;
                    mem_req_d.we = data_we_i;
                    mem_req_d.wdata = data_wdata_i;
                    // TODO: Check for non-cache able accesses

                    // Bypass mode, check for uncacheable address here as well
                    if (bypass_i) begin
                        state_d = WAIT_TAG_BYPASSED;
                        // grant this access
                        data_gnt_o = 1'b1;
                        mem_req_d.bypass = 1'b1;
                    // ------------------
                    // Cache is enabled
                    // ------------------
                    end else begin
                        // request the cache line
                        reg_o = 'b1;
                        addr_o = address_index_i;
                        // Wait that we have access on the memory array
                        if (gnt_i) begin
                            state_d = WAIT_TAG;
                            mem_req_d.bypass = 1'b0;
                            // only for a read
                            if (!data_we_i)
                                data_gnt_o = 1'b1;
                        end
                    end
                end
            end

            // cache enabled and waiting for tag
            WAIT_TAG, WAIT_TAG_SAVED: begin
                // depending on where we come from
                tag_o = (state_q == WAIT_TAG_SAVED) ? mem_req.tag :  address_tag_i;
                // check that the client really wants to do the request
                if (!kill_req_i) begin
                    // HIT CASE
                    if (!hit_way_i) begin
                        // we can request another cache-line
                        // make another request
                        if (data_req_i) begin
                            state_d = WAIT_TAG; // switch back to WAIT_TAG
                            mem_req_d.index  = address_index_i;
                            mem_req_d.be     = data_be_i;
                            mem_req_d.we     = data_we_i;
                            mem_req_d.wdata  = data_wdata_i;
                            mem_req_d.bypass = 1'b0;

                            reg_o      = 'b1;
                            addr_o     = address_index_i;
                            data_gnt_o = gnt_i;

                            if (!gnt_i) begin
                                state_d = IDLE;
                            end

                        else
                            state_d = IDLE;
                        // report data for a read
                        if (!mem_req_q.we) begin
                            data_rvalid_o = 1'b1;
                            data_rdata_o = data_i[hit_way_i].data[mem_req_q.tag[5:0] +: 64];
                        end else begin
                            state_d = STORE;
                            hit_way_d = hit_way_i;
                        end

                    // MISS CASE
                    end else begin
                        // also save tag
                        mem_req_d.tag = address_tag_i;
                        // make a miss request
                        state_d = WAIT_REFILL_GNT;
                    end
                    // check MSHR
                    mshr_addr_o = {address_tag_i, mem_req_q.index};
                    // we've got a match on MSHR
                    if (mashr_addr_matches_i) begin
                        state_d = WAIT_MSHR;
                        // save tag
                        mem_req_d.tag = address_tag_i;
                    end
                end
            end

            // ~> we are here as we need a second round of memory access for a store
            STORE: begin
                // store data, write dirty bit
                req_o = hit_way_q;

                for (int unsigned i = 0; i < SET_ASSOCIATIVITY; i++)
                    if (hit_way_q[i])
                        be_o.state[i +: 2] = 2'b11;

                be_o.data[mem_req.index[5:0] +: 64] = mem_req.be;
                data_o.data[mem_req.index[5:0] +: 64] = mem_req.wdata;
                // ~> change the state
                data_o.dirty = 1'b1;
                data_o.valid = 1'b1;

                // got a grant ~> this is finished now
                if (gnt_i) begin
                    data_gnt_o = 1'b1;
                    NS = IDLE;
                end
            end

            // we've got a match on MSHR ~> someone is serving a request
            WAIT_MSHR: begin
                mshr_addr_o = {mem_req_q.tag, mem_req_q.index};
                // we can start a new request
                if (!mashr_addr_matches_i) begin
                    req_o = 'b1;
                    addr_o = mem_req_q.index;

                    if (gnt_i)
                        state_d = WAIT_TAG_SAVED;
                end
            end

            // its for sure a miss
            WAIT_TAG_BYPASSED: begin
                // the request was killed
                if (kill_req_i) begin
                    state_d = IDLE;
                    // we need to ack the killing
                    data_rvalid_o = 1'b1;
                end else begin
                    // save tag
                    mem_req_d.tag = address_tag_i;
                    state_d = WAIT_REFILL_GNT;
                end
            end

            // ~> wait for grant from miss unit
            WAIT_REFILL_GNT: begin

                miss_req_o.valid = 1'b1;
                miss_req_o.bypass = mem_req_q.bypass;
                miss_req_o.addr = { mem_req_q.tag, mem_req_q.index };
                miss_req_o.be = mem_req_q.be;
                miss_req_o.we = mem_req_q.we;
                miss_req_o.wdata = mem_req_q.wdata;

                // got a grant so go to valid
                if (bypass_gnt_i)
                    state_d = WAIT_REFILL_VALID;

                if (miss_gnt_i)
                    state_d = WAIT_CRITICAL_WORD;
            end
            // ~> wait for critical word to arrive
            WAIT_CRITICAL_WORD: begin

                if (critical_word_valid_i) begin
                    data_rvalid_o = 1'b1;
                    data_rdata_o = critical_word_i;
                    // we can make another request
                    if (data_req_i) begin
                        // save index, be and we
                        mem_req_d.index = address_index_i;
                        mem_req_d.be = data_be_i;
                        mem_req_d.we = data_we_i;
                        mem_req_d.wdata = data_wdata_i;
                        // request the cache line
                        reg_o = 'b1;
                        addr_o = address_index_i;
                        state_d = IDLE;

                        // Wait until we have access on the memory array
                        if (gnt_i) begin
                            state_d = WAIT_TAG;
                            mem_req_d.bypass = 1'b0;
                            data_gnt_o = 1'b1;
                        end

                    end else begin
                        state_d = IDLE;
                    end
                end
            end

            WAIT_REFILL_VALID: begin
                // got a valid answer
                if (bypass_valid_i) begin
                    data_rdata_o = bypass_data_i[63:0];
                    data_rvalid_o = 1'b1;
                    state_d = IDLE;
                end
            end

        endcase
    end

    // --------------
    // Registers
    // --------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q   <= IDLE;
            mem_req_q <= '0;
            hit_way_q <= '0;
        end else begin
            state_q   <= state_d;
            mem_req_q <= mem_req_d;
            hit_way_q <= hit_way_d;
        end
    end
endmodule

module AMO_alu (
        input logic         clk_i,
        input logic         rst_ni,
        // AMO interface
        input  logic        amo_commit_i, // commit atomic memory operation
        output logic        amo_valid_o,  // we have a valid AMO result
        output logic [63:0] amo_result_o, // result of atomic memory operation
        input  logic        amo_flush_i   // forget about AMO
    );

endmodule

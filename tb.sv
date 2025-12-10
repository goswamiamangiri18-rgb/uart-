`include "uvm_macros.svh"
import uvm_pkg::*;

class transaction extends uvm_sequence_item;
    
    typedef enum bit {WRITE = 1'b0 , READ = 1'b1} oper_type;
    
    randc oper_type oper;
    rand bit [7:0] dintx;
    bit rx;
    bit newd;
    bit tx;
    bit [7:0] doutrx;
    bit donetx;
    bit donerx;

    function new(string name = "transaction");
        super.new(name);
    endfunction

    `uvm_object_utils_begin(transaction)
        `uvm_field_enum(oper_type, oper, UVM_DEFAULT)
        `uvm_field_int(rx, UVM_DEFAULT)
        `uvm_field_int(dintx, UVM_DEFAULT)
        `uvm_field_int(newd, UVM_DEFAULT)
        `uvm_field_int(tx, UVM_DEFAULT)
        `uvm_field_int(doutrx, UVM_DEFAULT)
        `uvm_field_int(donerx, UVM_DEFAULT)
        `uvm_field_int(donetx, UVM_DEFAULT)
    `uvm_object_utils_end

endclass


class generator extends uvm_sequence #(transaction);
    `uvm_object_utils(generator)
    transaction tc;

    function new(input string path = "generator");
        super.new(path);
    endfunction

    virtual task body();
        tc = transaction::type_id::create("tc");
        repeat(20)begin
        start_item(tc);
            `uvm_info("GEN",$sformatf("Generated transaction sent to driver oper: %0d",tc.oper),UVM_NONE)
            tc.randomize();
        finish_item(tc);
        get_response(tc);
        end
    endtask

endclass 


class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)
    virtual uart_if uif;
    transaction tc;
    bit [7:0] datarx;  
    
    function new(input string path = "driver",uvm_component parent = null);
        super.new(path,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tc= transaction::type_id::create("tc",this);
        if(!uvm_config_db #(virtual uart_if)::get(this,"","uif",uif))
        `uvm_error("DRV","Virtual interface not set");
    endfunction

    virtual task run_phase(uvm_phase phase);
        if(tc.oper == 1'b0)begin
            @(posedge uif.uclktx);
            uif.rst <= 1'b0;
            uif.newd <= 1'b1;  ///start data sending op
            uif.rx <= 1'b1;
            uif.dintx = tc.dintx;
            @(posedge uif.uclktx);
            uif.newd <= 1'b0;
        end

        else if(tc.oper == 1'b1)begin
                @(posedge uif.uclkrx);
                  uif.rst <= 1'b0;
                  uif.rx <= 1'b0;
                  uif.newd <= 1'b0;
                @(posedge uif.uclkrx);
                  
                for(int i=0; i<=7; i++) begin   
                @(posedge uif.uclkrx);                
                uif.rx <= $urandom;
                datarx[i] = uif.rx;
                end                                      
        end
    endtask
endclass


class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)
    transaction tc;
    virtual uart_if uif;

    bit [7:0] srx; 
    bit [7:0] rrx; 

    uvm_analysis_port #(transaction) send;

    function new(input string path = "monitor",uvm_component parent);
        super.new(path,parent);
        send = new("send",this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tc = transaction::type_id::create("tc",this);
        if(!uvm_config_db #(virtual uart_if)::get(this,"","uif",uif))
        `uvm_error("DRV","Virtual interface not set");
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            if((uif.newd == 1'b1) && (uif.rx == 1'b1))begin
                @(posedge uif.uclktx);
                for(int i = 0; i<= 7; i++) 
                begin 
                      @(posedge uif.uclktx);
                      srx[i] = uif.tx;
                      
                end
                @(posedge uif.uclktx); 
                send.write(tc);
            end
            else if((uif.rx == 1'b0) && (uif.newd == 1'b0)) begin 
                wait(uif.donerx == 1);
                rrx = uif.doutrx;     
                @(posedge uif.uclktx); 
                send.write(tc);
            end
        end
    endtask
endclass

// class scoreboard extends uvm_scoreboard;
//     `uvm_component_utils(scoreboard)
//     transaction tc;
//     uvm_analysis_imp #(transaction,scoreboard) recv;
    
//     function new(input string path = "scoreboard",uvm_component parent = null);
//         super.new(path,parent);
//         recv = new("recv",this);
//     endfunction

//     function void build_phase(uvm_phase phase);
//         super.build_phase(phase);
//         tc = transaction::type_id::create("tc");
//     endfunction
// endclass

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    transaction tc;
    uvm_analysis_imp #(transaction, scoreboard) recv;
    
    bit [7:0] expected_data_queue[$];

    function new(input string path = "scoreboard", uvm_component parent = null);
        super.new(path, parent);
        recv = new("recv", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tc = transaction::type_id::create("tc");
    endfunction

    function void write(transaction t);
        if (t.oper == transaction::WRITE) begin
            expected_data_queue.push_back(t.dintx);
            `uvm_info("SCOREBOARD", $sformatf("WRITE operation: Stored expected data %0h", t.dintx), UVM_MEDIUM)
        end 
        else if (t.oper == transaction::READ) begin
            if (expected_data_queue.size() > 0) begin
                bit [7:0] expected_value = expected_data_queue.pop_front();
                if (expected_value == t.doutrx) begin
                    `uvm_info("SCOREBOARD", $sformatf("READ operation PASSED: Received %0h matches expected %0h", t.doutrx, expected_value), UVM_MEDIUM)
                end else begin
                    `uvm_error("SCOREBOARD", $sformatf("READ operation FAILED: Received %0h, Expected %0h", t.doutrx, expected_value))
                end
            end else begin
                `uvm_error("SCOREBOARD", "READ operation FAILED: No expected data available")
            end
        end
    endfunction
endclass


class agent extends uvm_agent;
    `uvm_component_utils(agent)
    monitor m;
    driver d;
    uvm_sequencer #(transaction) seqr;

    function new(input string path = "agent",uvm_component parent = null);
        super.new(path,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m = monitor::type_id::create("m",this);
        d = driver::type_id::create("d",this);
        seqr = uvm_sequencer #(transaction)::type_id::create("seqr",this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        d.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

class env extends uvm_env;
    `uvm_component_utils(env)
    agent a;
    scoreboard s;

    function new(input string path = "env",uvm_component parent);
        super.new(path,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        a = agent::type_id::create("a",this);
        s = scoreboard::type_id::create("s",this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        a.m.send.connect(s.recv);
    endfunction
endclass

class test extends uvm_test;
    `uvm_component_utils(test)
    env e;
    generator gen;

    function new(input string path = "test",uvm_component parent = null);
        super.new(path,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        e = env::type_id::create("e",this);
        gen = generator::type_id::create("gen");
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        gen.start(e.a.seqr);
        #60;
        phase.drop_objection(this);
    endtask
endclass

module tb_top();
    uart_if uif();

    initial begin
        uif.clk = 0;
        uif.rst = 0;
    end

    initial begin
        uvm_config_db #(virtual uart_if)::set(null,"uvm_test_top.e.a*","uif",uif);
        run_test("test");
    end



endmodule
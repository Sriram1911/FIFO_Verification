
interface fifo_if(input bit clk_wr,clk_rd);

logic wr, rd, reset;
logic [7:0] data_in;
logic empty, full;
logic [7:0] data_out;
logic [15:0] count;
    clocking cb_wr @(posedge clk_wr);
    output wr, rd, reset;
    output data_in;
    endclocking
  
  clocking cb_rd @(posedge clk_rd);
  input wr, rd, reset; 
  input data_in;
  input empty, full;
  input data_out;
  input count;
    endclocking

endinterface

class transaction;

rand bit oper;
rand bit [7:0] data_in;
bit empty, full;
bit [7:0] data_out;
bit [15:0] count;

function void display(input string ID, bit ports=0);
//   $display("------------------------------------------");
  if (ports == 1'b0)
    $display("[%0s]: OPERATION-> %b DATA_IN -> %d",ID,oper,data_in);
  else
    $display("[%0s]: EMPTY-> %b FULL-> %b DATA_OUT-> %d COUNT-> %d",ID,empty,full,data_out,count);

  $display("-----------------------------------------------");
endfunction
endclass //transaction

class generator;
    transaction tr;

    int count;
    event drv_done;
    event sco_done;
    event gen_done;
    mailbox #(transaction) gen2drv;
    function new(mailbox #(transaction) gen2drv);
        tr = new();
        this.gen2drv = gen2drv;
    endfunction

    task run();
    repeat(count)
    begin
      $display("--------------------------------------------------");
      $display("[GEN]: GENERATING NEW SEQUENCE...");
        assert (tr.randomize) else $error("[GEN]: Sequence Not Generated");
        gen2drv.put(tr);
        $display("[GEN]: SEQUENCE SENT TO DRIVER AT TIME: %0t", $time);
        tr.display("GEN",0);
        @drv_done;
        @sco_done;
    end
    $display("[GEN][%0t]: DONE!",$time);
    ->gen_done;
    endtask 
endclass

class driver;

    transaction tr_drv;
    mailbox #(transaction) gen2drv, drv2sco;
    event drv_done;
    virtual fifo_if vif;

    function new(mailbox #(transaction) gen2drv,
                 mailbox #(transaction)drv2sco,
                 virtual fifo_if vif
                );
        this.gen2drv = gen2drv;
        this.drv2sco = drv2sco;
        this.vif = vif;
    endfunction

    task dut_reset();
        vif.cb_wr.reset <= 1'b1;
        vif.cb_wr.data_in <= 1'b0;
      	vif.cb_wr.rd <= 1'b0;
      	vif.cb_wr.wr <= 1'b0;
      	
        repeat(4) @vif.cb_wr;
        vif.cb_wr.reset <= 1'b0;
        @vif.cb_wr;
    endtask

    task run();

        forever begin
            gen2drv.get(tr_drv);
            drv2sco.put(tr_drv);
            @vif.cb_wr;

            $display("[DRV]: APPLYING STIMULAS AT TIME: %0t",$time);
            tr_drv.display("DRV",0);
          
            vif.cb_wr.data_in <= tr_drv.data_in;
            if (tr_drv.oper == 1'b0)
              vif.cb_wr.wr <= 1'b1;
            else
              vif.cb_wr.rd <= 1'b1;

            @vif.cb_wr;
            vif.cb_wr.rd <= 1'b0;
            vif.cb_wr.wr <= 1'b0;
//           @vif.cb_wr;
            ->drv_done;
//              @vif.cb_wr;
        end
    endtask

endclass

class monitor;
    transaction tr_mon;
    mailbox #(transaction) mon2sco;
    virtual fifo_if vif;
    function new(mailbox #(transaction) mon2sco, virtual fifo_if vif);
      tr_mon = new();
        this.mon2sco = mon2sco;
        this.vif = vif;
    endfunction

    task run();
      forever begin
        repeat(3) @vif.cb_rd;
        tr_mon.data_out = vif.cb_rd.data_out;
        tr_mon.empty = vif.cb_rd.empty;
        tr_mon.full = vif.cb_rd.full;
        tr_mon.count = vif.cb_rd.count;
        $display("[MON]: DATA READ FROM DUT AT TIME %0t", $time);

//         @vif.cb_rd;
        $display("[MON]: DATA SENT TO SCOREBOARD AT TIME %0t", $time);
        tr_mon.display("MON",1);
        mon2sco.put(tr_mon);
      end
    endtask
endclass

class scoreboard;
  
  int errors;
    transaction tr_sco, tr_drv;
    bit [7:0] buffer[$];
    bit [7:0] temp;
  	bit prev_empty=1;
  mailbox #(transaction) mon2sco, drv2sco;
    event sco_done;
  function new(mailbox #(transaction) mon2sco, drv2sco);
        this.mon2sco = mon2sco;
        this.drv2sco = drv2sco;
    errors = 0;
    endfunction

    task run();
        forever begin
            drv2sco.get(tr_drv);
            $display("[SCO]: DATA RECEIVED FROM DRIVER AT TIME %0t",$time);
            tr_drv.display("SCO",0);
            mon2sco.get(tr_sco);
            $display("[SCO]: DATA RECEIVED FROM MONITOR AT TIME %0t",$time);
            tr_sco.display("SCO",1);
            if(tr_drv.oper == 1'b0)
              begin
                buffer.push_back(tr_drv.data_in);
                $display("[SCO]: DATA {%d} PUSHED INTO SCOREBOARD BUFFER",tr_drv.data_in);
              end
            else
              if(tr_sco.empty!=1'b1 || prev_empty == 1'b0)
              begin
                temp = buffer.pop_front();
                $display("[SCO]: DATA IS BEING COMPARED WITH %d",temp);
                assert(temp == tr_sco.data_out)
                else
                  begin
                      $error("[SCO]: DATA MISMATCH AT TIME %t",$time);
                      errors++;
                  end
                
              end

            prev_empty = tr_sco.empty;
          
            ->sco_done;
        end
          	
        
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;

    mailbox #(transaction) gen2drv, mon2soc, drv2sco;
    event drv_done, sco_done;
    virtual fifo_if vif; 
  function new(virtual fifo_if vif);
     	this.vif = vif;
        gen2drv = new();
        mon2soc = new();
        drv2sco = new();
        gen = new(gen2drv);
        gen.drv_done = drv_done;
        gen.sco_done = sco_done;
    	gen.count = 10;
        drv = new(gen2drv, drv2sco, vif);
        gen.drv_done = drv.drv_done;

        mon = new(mon2soc, vif);
        sco = new(mon2soc, drv2sco);
        sco.sco_done = sco_done;
    endfunction

    task run();
        drv.dut_reset();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_none
    endtask

endclass

module tb;
    environment env;

    bit clk;
    
  fifo_if vif(clk,clk);
  FIFO DUT(.clk(clk),
           .wr(vif.wr),
           .rd(vif.rd),
           .reset(vif.reset),
           .data_in(vif.data_in),
           .empty(vif.empty),
           .full(vif.full),
           .data_out(vif.data_out),
           .count(vif.count)
           );

    event gen_done;
    always #5 clk = ~clk;

    initial begin
      env = new(vif);
        gen_done = env.gen.gen_done;
        env.run();
        @gen_done
        repeat(10) @(posedge clk);
        $display("[TB]: NUMBER OF DATA MISMATCHES = %d",env.sco.errors);
        $finish;
    end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
endmodule
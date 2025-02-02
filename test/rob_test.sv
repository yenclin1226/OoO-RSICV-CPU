`include "../verilog/ROB.svh"

module rob_test;
	logic 				clock;
	logic 				reset;
    	logic [1:0] [4:0] 		dest_ARN;
    	logic [1:0] [$clog2(`PRF)-1:0]  dest_PRN;

	CDB_PACKET [1:0]		CDB_packet_in;
	DP_PACKET [1:0]			DP_packet_in;
	ROB_OUT_PACKET [1:0]	  	ROB_packet_out;

    	logic [1:0] 			branch_direction;
    	logic [`XLEN-1:0] 		next_pc;
    	logic 				illegal_out;
    	logic 				halt_out;
    	logic [$clog2(`WAYS):0] 	num_committed;
    	logic 				commit;
    	logic 				full;

	`ifdef DEBUG
	logic [$clog2(`ROB_ENTRIES)-1:0]	head;
	logic [$clog2(`ROB_ENTRIES)-1:0]        tail;
	logic [$clog2(`ROB_ENTRIES):0]          num_free;
	logic  					proc_nuke;
	`endif

    // Instantiate the DUT
    rob uut (
        .clock(clock),
        .reset(reset),
	.CDB_packet_in(CDB_packet_in),
        .dest_ARN(dest_ARN),
        .dest_PRN(dest_PRN),
	.DP_packet_in(DP_packet_in),
        .branch_direction(branch_direction),
	.ROB_packet_out(ROB_packet_out),
        .next_pc(next_pc),
        .illegal_out(illegal_out),
        .halt_out(halt_out),
        .num_committed(num_committed),
        .commit(commit),
	.full(full)

	`ifdef DEBUG
	,
	.head_out(head),
	.tail_out(tail),
	.num_free_out(num_free),
	.proc_nuke_out(proc_nuke)
	`endif
    );

    // Dispatch Stage Test
	// 測試 dispatch 的功能，觀察 tail 是否有正確移動
	task dispatch_test();
		begin
			$display("\nTest 1: Fill up the ROB and check full condition\n");
			CDB_packet_in[0].ROB_idx      	= 0;
			CDB_packet_in[1].ROB_idx      	= 0;
			CDB_packet_in[0].valid	      	= 0;
			CDB_packet_in[1].valid	     	= 0;
			CDB_packet_in[0].direction    	= 0;
			CDB_packet_in[1].direction    	= 0;
			CDB_packet_in[0].target       	= 0; 
			CDB_packet_in[1].target       	= 0; 
			DP_packet_in[0].valid 		= 0;
			DP_packet_in[1].valid 		= 0;
			dest_ARN = 0;
			dest_PRN = 0;
			DP_packet_in[0].reg_write = 0;
			DP_packet_in[1].reg_write = 0;
			DP_packet_in[0].is_branch = 0;
			DP_packet_in[1].is_branch = 0;
			DP_packet_in[0].is_store  = 0;
			DP_packet_in[1].is_store  = 0;
			DP_packet_in[0].PC    	  = 0;
			DP_packet_in[1].PC    	  = 0;
			DP_packet_in[0].target    = 0;
			DP_packet_in[1].target    = 0;
			branch_direction[0] 	  = 0;
			branch_direction[1] 	  = 0;
			DP_packet_in[0].illegal   = 0;
			DP_packet_in[1].illegal   = 0;
			DP_packet_in[0].halt      = 0;
			DP_packet_in[1].halt      = 0;
			
		    	for(int i = 0; i <= `ROB_ENTRIES; i++) begin
				for(int j = 0; j < `WAYS; j++) begin
					if(j == 0) begin	   
						DP_packet_in[j].valid    	= 1;
						dest_ARN[j] 	    		= $urandom % 32;
						dest_PRN[j] 	    		= $urandom % 32;
						DP_packet_in[j].reg_write 	= 1;
						DP_packet_in[j].is_branch	= 0;
						DP_packet_in[j].is_store 	= 0;
						DP_packet_in[j].PC 		= i + 4;
						DP_packet_in[j].target 	    	= 0;
						branch_direction[j] 		= 1'b0;
						DP_packet_in[j].illegal 	= 0;
						DP_packet_in[j].halt	 	= 0;
						@(negedge clock);
						DP_packet_in[j].valid	    	= 0;
						`ifdef DEBUG
						$display("tail = %0d num_free = %0d full = %0d", tail, num_free, full);
						`endif
						@(negedge clock);
					end
					else begin	   
						DP_packet_in[j].valid    	= 0;
						dest_ARN[j] 	    		= 0;
						dest_PRN[j] 	    		= 0;
						DP_packet_in[j].reg_write 	= 0;
						DP_packet_in[j].is_branch 	= 0;
						DP_packet_in[j].is_store 	= 0;
						DP_packet_in[j].PC 		= 0;
						DP_packet_in[j].target 	    	= 0;
						branch_direction[j] 		= 0;
						DP_packet_in[j].illegal 	= 0;
						DP_packet_in[j].halt	 	= 0;
						DP_packet_in[j].valid	    	= 0;
						@(negedge clock);
					end						
				end
			end
			if(full == 1 && num_free == 0)
				$display("@@@ Passed");
			else 
				$display("@@@ Failed");
		end
	endtask

	// test complete stage and retire stage's correctness
    	task complete_test();
        	begin
            		$display("\nTest 2: Complete and Retire all slots in the ROB\n");
			for(int i = 0; i <= `ROB_ENTRIES; i++) begin
				for(int j = 0; j < `WAYS; j++) begin
					if(j == 0) begin
						CDB_packet_in[j].valid     = 1;
						CDB_packet_in[j].ROB_idx   = i-1;
						CDB_packet_in[j].direction = 0;
						CDB_packet_in[j].target    = 0;
						@(negedge clock);
						CDB_packet_in[j].valid     = 0;
					end
					else begin
						CDB_packet_in[j].valid     = 0;
						CDB_packet_in[j].ROB_idx   = 0;
						CDB_packet_in[j].direction = 0;
						CDB_packet_in[j].target    = 0;
						@(negedge clock);						
					end					
				end
			end
			if(full == 0 && num_free == 32)
				$display("@@@ Passed");
			else
				$display("@@@ Failed");
        	end
    	endtask
	
	task branch_test();
			CDB_packet_in[0].ROB_idx      	= 0;
			CDB_packet_in[1].ROB_idx      	= 0;
			CDB_packet_in[0].valid	      	= 0;
			CDB_packet_in[1].valid	     	= 0;
			CDB_packet_in[0].direction    	= 0;
			CDB_packet_in[1].direction    	= 0;
			CDB_packet_in[0].target       	= 0; 
			CDB_packet_in[1].target       	= 0;
			
			$display("\nTest 3: Branch Squash Test\n");

		    	for(int i = 0; i < 2; i++) begin
				for(int j = 0; j < `WAYS; j++) begin
					if(j == 0) begin	   
						DP_packet_in[j].valid    	= 1;
						dest_ARN[j] 	    		= $urandom % 32;
						dest_PRN[j] 	    		= $urandom % 32;
						DP_packet_in[j].reg_write 	= 0;
						DP_packet_in[j].is_branch	= 1;
						DP_packet_in[j].is_store 	= 0;
						DP_packet_in[j].PC 		= i + 4;
						DP_packet_in[j].target 	    	= 0;
						branch_direction[j] 		= 1'b0;
						DP_packet_in[j].illegal 	= 0;
						DP_packet_in[j].halt	 	= 0;
						@(negedge clock);
						DP_packet_in[j].valid	    	= 0;
						@(negedge clock);
					end
					else begin	   
						DP_packet_in[j].valid    	= 0;
						dest_ARN[j] 	    		= 0;
						dest_PRN[j] 	    		= 0;
						DP_packet_in[j].reg_write 	= 0;
						DP_packet_in[j].is_branch 	= 0;
						DP_packet_in[j].is_store 	= 0;
						DP_packet_in[j].PC 		= 0;
						DP_packet_in[j].target 	    	= 0;
						branch_direction[j] 		= 0;
						DP_packet_in[j].illegal 	= 0;
						DP_packet_in[j].halt	 	= 0;
						DP_packet_in[j].valid	    	= 0;
						@(negedge clock);
					end						
				end
			end
		
			@(negedge clock);
			CDB_packet_in[0].valid     = 1;
			CDB_packet_in[0].ROB_idx   = 0;
			CDB_packet_in[0].direction = 1;
			CDB_packet_in[0].target    = 100;
			@(negedge clock);
			CDB_packet_in[0].valid     = 0;
			CDB_packet_in[0].ROB_idx   = 0;
			CDB_packet_in[0].direction = 0;
			CDB_packet_in[0].target    = 0;
			@(negedge clock);

			if(num_free == 32)
				$display("@@@ Passed");
			else
				$display("@@@ Failed");	
	endtask


	task store_test();
		// First dispatch two store instruction into ROB

			$display("\nTest 4: Store Limit Test\n");

		    	for(int i = 0; i < 2; i++) begin
				for(int j = 0; j < `WAYS; j++) begin
					if(j == 0) begin	   
						DP_packet_in[j].valid    	= 1;
						dest_ARN[j] 	    		= $urandom % 32;
						dest_PRN[j] 	    		= $urandom % 32;
						DP_packet_in[j].reg_write 	= 0;
						DP_packet_in[j].is_branch	= 0;
						DP_packet_in[j].is_store 	= 1;			// store instruction
						DP_packet_in[j].PC 		= i + 4;
						DP_packet_in[j].target 	    	= 0;
						branch_direction[j] 		= 1'b0;
						DP_packet_in[j].illegal 	= 0;
						DP_packet_in[j].halt	 	= 0;
						@(negedge clock);
						DP_packet_in[j].valid	    	= 0;
						@(negedge clock);
					end
					else begin	   
						DP_packet_in[j].valid    	= 0;
						dest_ARN[j] 	    		= 0;
						dest_PRN[j] 	    		= 0;
						DP_packet_in[j].reg_write 	= 0;
						DP_packet_in[j].is_branch 	= 0;
						DP_packet_in[j].is_store 	= 0;
						DP_packet_in[j].PC 		= 0;
						DP_packet_in[j].target 	    	= 0;
						branch_direction[j] 		= 0;
						DP_packet_in[j].illegal 	= 0;
						DP_packet_in[j].halt	 	= 0;
						DP_packet_in[j].valid	    	= 0;
						@(negedge clock);
					end						
				end
			end

			@(negedge clock);
			CDB_packet_in[0].valid     = 1;
			CDB_packet_in[0].ROB_idx   = 0;
			CDB_packet_in[0].direction = 0;
			CDB_packet_in[0].target    = 0;
			CDB_packet_in[1].valid     = 1;
			CDB_packet_in[1].ROB_idx   = 1;
			CDB_packet_in[1].direction = 0;
			CDB_packet_in[1].target    = 0;
			@(negedge clock);
			CDB_packet_in[0].valid     = 0;
			CDB_packet_in[0].ROB_idx   = 0;
			CDB_packet_in[0].direction = 0;
			CDB_packet_in[0].target    = 0;
			CDB_packet_in[1].valid     = 0;
			CDB_packet_in[1].ROB_idx   = 0;
			CDB_packet_in[1].direction = 0;
			CDB_packet_in[1].target    = 0;
			@(negedge clock);
			if(num_free == 31)			// should only retire one store instruction
				$display("@@@ Passed");
			else
				$display("@@@ Failed");

	endtask

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    // Testbench tasks and initial setup
    initial begin
        // Initialize signals
        reset = 1;
        #10;
        reset = 0;

        // Insert dispatch tests
        dispatch_test();

        #100;
        // Insert complete tests
        complete_test();

	repeat(2) @(negedge clock);
	branch_test();
	
	repeat(2) @(negedge clock);
        store_test();
		

		

        #100;
        $finish;
    end

endmodule

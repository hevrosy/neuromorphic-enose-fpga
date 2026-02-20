from pynq import Overlay, allocate
import numpy as np
import time

print("Loading FPGA Bitstream...")
overlay = Overlay("enose_accel.bit")
dma = overlay.axi_dma_0
accel = overlay.enose_accel_0

def test_enose_accel(test_name, test_data_array):
    print(f"\n{test_name}")
    print("-" * 40)
    
    num_words = len(test_data_array)
    buf = allocate(shape=(num_words,), dtype=np.uint32)
    buf[:] = test_data_array
    buf.sync_to_device() 
    
    # 1. RESET the accumulators before the run (Write 0x2 -> Bit 1)
    accel.write(0x00, 0x2)
    
    # 2. Trigger DMA transfer to stream the data
    dma.sendchannel.transfer(buf)
    dma.sendchannel.wait()
    
    # 3. START the classification (Write 0x1 -> Bit 0)
    accel.write(0x00, 0x1)
    
    # 4. Wait for DONE (Offset 0x04)
    timeout = 100000
    while timeout > 0:
        status = accel.read(0x04) 
        if (status & 0x1) == 0x1:
            break
        timeout -= 1
        
    if timeout == 0:
        print("  [WARN] Accelerator did not assert DONE flag.")
        
    # 5. Read registers at the correct offsets
    status = accel.read(0x04)         
    classification = accel.read(0x18) 
    words_rx = accel.read(0x30)       
    total_pop = accel.read(0x34)      
    
    print(f"  Status Register: {hex(status)}")
    print(f"  Classification : {classification}")
    print(f"  Words Received : {words_rx}")
    print(f"  Total Popcount : {total_pop}")
    
    buf.close()

# TEST 1: All Zeros
test_enose_accel("TEST 1: All Zeros (Expect Class 0, Pop 0)", np.zeros(10, dtype=np.uint32))

# TEST 2: All FFFs
test_enose_accel("TEST 2: All FFFs (Expect Class 2, Pop 120)", np.full(10, 0xFFFFFFFF, dtype=np.uint32))

# TEST 3: 5 bits/word
test_enose_accel("TEST 3: 5 bits/word (Expect Class 1, Pop 50)", np.full(10, 0x0000001F, dtype=np.uint32))
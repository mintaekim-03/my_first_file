#include <stdio.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"


#define NPU_BASE_ADDR       0x40000000

// [파라미터]
#define NODE1 784
#define NODE2 128
#define NODE3 32
#define NODE4 10
#define NUM_IMAGE 10
#define TOTAL_WEIGHTS  ((NODE1 * NODE2) + (NODE2 * NODE3) + (NODE3 * NODE4))

// register offset
#define REG_INPUT           0x00
#define REG_WEIGHT          0x04
#define REG_STATUS          0x08
#define REG_CTRL            0x0C
#define REG_RESULT_UPPER    0x10
#define REG_RESULT_LOWER    0x14

// Read 0x08 상태 register이다. SWAP인지 뭔지.
#define STAT_WEIGHT_DONE    (1 << 0) 
#define STAT_RESULT_SWAP    (1 << 1) // 결과 준비 완료 
#define STAT_INPUT_SWAP     (1 << 2) // 입력 버퍼 비었음 
#define STAT_RESULT_AVAIL   (1 << 3) // output valid 신호

//ps에서 적어줄 신호 CRTL signals
#define CTRL_R_REQUEST      (1 << 2) // 데이터 1개 요청 펄스
#define CTRL_R_DONE         (1 << 1) // 결과 버퍼 다 읽음 (SWAP 요청)
#define CTRL_W_DONE         (1 << 0) // 입력 버퍼 다 채움 (SWAP 요청)


int main()
{
    xil_printf("\n==Start my NPU!==\n");

    //go!
    int go = 0;
    xil_printf("Input '1' to start: ");
    scanf("%d", &go);
    if(!go) return 0;

    
    // 1. 가중치(Weight) 전송
    xil_printf("Loading Weights\n\r");
    for(int i = 0; i < TOTAL_WEIGHTS; i++){ //총 가중치 갯수만큼 넣어주기
        Xil_Out32(NPU_BASE_ADDR + REG_WEIGHT, 1); 
    }

    // 가중치 완료 대기 write_all_done을 기다림 0번 비트가 1일때까지 기다림
    while(1) {
        if (Xil_In32(NPU_BASE_ADDR + REG_STATUS) & STAT_WEIGHT_DONE) 
        break;
    }

    xil_printf("Weight Load Done!\n");
    
    // R_DONE 전송으로 출력 버퍼 상태 초기화 (최초 1회)
    xil_printf("Init Output Buffer\n");
    Xil_Out32(NPU_BASE_ADDR + REG_CTRL, CTRL_R_DONE); //R_done 주기. 그 후 초기화 어차피 HW에서 제어 로직을 짜둠
    Xil_Out32(NPU_BASE_ADDR + REG_CTRL, 0x00); // Pulse Off

    // 2. 첫 번째 이미지 전송 
    int input_start = 0;
    xil_printf("Start 1st Input?: ");
    scanf("%d", &input_start);

    if(input_start == 1){
        xil_printf("Sending Image 0...\n");
        
        for(int i = 0; i < NODE1; i++){
            Xil_Out32(NPU_BASE_ADDR + REG_INPUT, 1); 
        }

        // 입력 완료 신호 (W_DONE)
        Xil_Out32(NPU_BASE_ADDR + REG_CTRL, CTRL_W_DONE);
        Xil_Out32(NPU_BASE_ADDR + REG_CTRL, 0x00); 

        xil_printf("Image 0 Sent. Pipeline Started.\n");
    }
    else{
        xil_printf("Program stopped.\n");
        return 0;
    }

    // 3. 메인 루프 
    int input_cnt = 1;   // 1번 이미지부터 넣어야 함 
    int result_cnt = 0;  // 0번 결과부터 읽어야 함

    //상태 레지스터 값을 모아두는 변수 (신호 증발 방지용) u32는 unsigned int 이다. 
    u32 status_my_bag = 0; 

    while (result_cnt < NUM_IMAGE) //input과 output의 swap을 한 루프에 한번씩 확인을 한다.
    {
        //상태 읽기 및 누적
        // Xil_In32를 하는 순간 HW 레지스터의 0X08의 swap신호 두개는 비워지므로, 누적 하는 형식으로 한다.
        status_my_bag |= Xil_In32(NPU_BASE_ADDR + REG_STATUS);

        // write할 수 있는 상황인지 확인한다.
        int can_write = (input_cnt < NUM_IMAGE) && (status_my_bag & STAT_INPUT_SWAP);

        if(can_write) { 
            // 데이터 전송
            for(int k = 0; k < NODE1; k++ ){
                Xil_Out32(NPU_BASE_ADDR + REG_INPUT, 1); 
            }
            // 전송 완료 펄스
            Xil_Out32(NPU_BASE_ADDR + REG_CTRL, CTRL_W_DONE); 
            Xil_Out32(NPU_BASE_ADDR + REG_CTRL, 0x00); 

            xil_printf("Image %d Sent\n", input_cnt);
            input_cnt++;

            status_my_bag &= ~STAT_INPUT_SWAP; //swap신호를 꺼서 and 취해주면 swap 신호만 꺼짐
        }


        // 출력부

        // result_swap이 있는지 확인한다.
        if((result_cnt < NUM_IMAGE) && (status_my_bag & STAT_RESULT_SWAP)) { 
            
            xil_printf("Reading Result of Image %d\n", result_cnt);
            
            for(int k = 0; k < NODE4; k++) {
                // 1. 데이터 요청 펄스
                Xil_Out32(NPU_BASE_ADDR + REG_CTRL, CTRL_R_REQUEST); 
                Xil_Out32(NPU_BASE_ADDR + REG_CTRL, 0x00); 

                //o_valid 신호인 r_valid_status 신호를 기다린다. 
                while(1) {
                    u32 o_valid_check = Xil_In32(NPU_BASE_ADDR + REG_STATUS);
                    
                    //이 부분이 없어서 문제가 생겼다. 읽는 중에 swap 신호들은 초기화가 되기 때문에 읽을 때마다 swap 신호가 들어오는지 체크 한다.
                    status_my_bag |= o_valid_check; 
                    
                    if (o_valid_check & STAT_RESULT_AVAIL) break; 
                }

                u32 upper = Xil_In32(NPU_BASE_ADDR + REG_RESULT_UPPER);
                u32 lower = Xil_In32(NPU_BASE_ADDR + REG_RESULT_LOWER);
                
                long long result_all = ((long long)upper << 32) | lower;
                xil_printf("Node %d: %lld\n", k, result_all);
            }

            // 4. r_done 적어주기
            Xil_Out32(NPU_BASE_ADDR + REG_CTRL, CTRL_R_DONE);
            Xil_Out32(NPU_BASE_ADDR + REG_CTRL, 0x00);
            
            result_cnt++;
            
            // RESULT SWAP의 신호 처리 했기 때문에 꺼주기 
            status_my_bag &= ~STAT_RESULT_SWAP;
        }
    }

    xil_printf("All Done! Check the results.\n");
    return 0;
}
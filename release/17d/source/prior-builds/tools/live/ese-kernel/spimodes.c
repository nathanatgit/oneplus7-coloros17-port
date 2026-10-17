#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/ioctl.h>
struct x { uint32_t mode, len; uint8_t tx[32], rx[32]; };
#define DBG _IOWR(0xEA, 0x7E, struct x)
int main(){
  int fd=open("/dev/p73",O_RDWR); if(fd<0){perror("open");return 1;}
  int modes[]={0,1,2,3,4,5,6,7}; /* bit2 = SPI_CS_HIGH */
  for(int m=0;m<8;m++){
    struct x v={.mode=modes[m],.len=4,.tx={0x5a,0xc4,0x00,0xc4}};
    ioctl(fd,DBG,&v);
    int hit=0;
    for(int i=0;i<200 && !hit;i++){ struct x r={.mode=modes[m],.len=2}; ioctl(fd,DBG,&r);
      if(r.rx[0]|r.rx[1]){ printf("mode %d: hit after %d polls: %02x %02x\n",m,i,r.rx[0],r.rx[1]); hit=1; } usleep(1000);}
    if(!hit) printf("mode %d: nothing\n",m);
  }
  return 0;}

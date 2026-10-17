#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/ioctl.h>
struct x { uint32_t mode, len; uint8_t tx[32], rx[32]; };
#define DBG _IOWR(0xEA, 0x7E, struct x)
int main(int argc,char**argv){
  int fd=open("/dev/p73",O_RDWR); if(fd<0){perror("open");return 1;}
  for(int loop=0;loop<2;loop++){
    struct x v={.mode=loop?0x20:0,.len=8,.tx={0x5a,0xc4,0x12,0x34,0xa5,0x00,0xff,0x81}};
    int r=ioctl(fd,DBG,&v); printf("loop=%d r=%d rx:",loop,r); for(int i=0;i<8;i++)printf(" %02x",v.rx[i]); printf("\n");}
  return 0;}

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
/* usage: p73test [cycle] : optional eSE power cycle, then T=1 S(RESET) request, poll 300 ms for a non-zero byte */
int main(int argc,char**argv){
  int fd=open("/dev/p73",O_RDWR); if(fd<0){perror("open");return 1;}
  long st=0;
  printf("pwr status %d\n", ioctl(fd,0x8008ea05UL,&st));
  if(argc>1){ printf("off %d\n", ioctl(fd,0x4008ea04UL,0L)); usleep(100000); printf("on %d\n", ioctl(fd,0x4008ea04UL,1L)); usleep(50000);}
  unsigned char w[]={0x5a,0xc4,0x00,0xc4}, b[8];
  printf("write %zd\n", write(fd,w,4));
  for(int i=0;i<300;i++){ int n=read(fd,b,2); if(n>0 && (b[0]|b[1])){ printf("t=%dms rx %02x %02x\n",i,b[0],b[1]); for(int k=0;k<8;k++){n=read(fd,b,2);printf(" %02x %02x",b[0],b[1]);} printf("\n"); return 0;} usleep(1000);}
  printf("no response\n"); return 0;}

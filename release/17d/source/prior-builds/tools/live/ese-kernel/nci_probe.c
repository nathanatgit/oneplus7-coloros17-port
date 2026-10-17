#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include <sys/ioctl.h>
int main(){
  int fd=open("/dev/nq-nci",O_RDWR); if(fd<0){perror("open");return 1;}
  printf("ESE_GET_PWR=%d\n", ioctl(fd,0x8004e903UL,3));   /* _IOR(0xE9,3,uint) */
  ioctl(fd,0x4004e901UL,0); usleep(10000); ioctl(fd,0x4004e901UL,1); usleep(20000); /* NFC_SET_PWR 0/1 (ven cycle) */
  unsigned char reset[]={0x20,0x00,0x01,0x00}, b[64];
  printf("write %zd\n", write(fd,reset,4));
  struct pollfd p={fd,POLLIN}; 
  for(int i=0;i<3;i++){ if(poll(&p,1,1000)>0){ int n=read(fd,b,sizeof b); printf("rsp %d:",n); for(int j=0;j<n;j++)printf(" %02x",b[j]); printf("\n"); } else printf("timeout\n"); }
  unsigned char init[]={0x20,0x01,0x00};
  printf("write %zd\n", write(fd,init,3));
  for(int i=0;i<2;i++){ if(poll(&p,1,1000)>0){ int n=read(fd,b,sizeof b); printf("rsp %d:",n); for(int j=0;j<n;j++)printf(" %02x",b[j]); printf("\n"); } else printf("timeout\n"); }
  return 0;}

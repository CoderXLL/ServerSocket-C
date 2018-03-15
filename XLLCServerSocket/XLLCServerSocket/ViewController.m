//
//  ViewController.m
//  XLLCServerSocket
//
//  Created by 肖乐 on 2018/3/15.
//  Copyright © 2018年 IMMoveMobile. All rights reserved.
//

#import "ViewController.h"
#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>

@interface ViewController ()
{
    // 服务端socket
    int _serverSocket;
    // 客户端socket
    int _clientSocket;
}

@property (weak, nonatomic) IBOutlet UILabel *clientIPLabel;
@property (weak, nonatomic) IBOutlet UILabel *clientPortLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITextField *msgField;
@property (weak, nonatomic) IBOutlet UILabel *receiveMsgLabel;
@property (weak, nonatomic) IBOutlet UIButton *listenBtn;

// 记录状态 系统默认为NO
@property (nonatomic, assign) BOOL flag;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
}

- (IBAction)listenBtnClick:(id)sender {
    
    if (!self.flag)
    {
        self.listenBtn.selected = YES;
        // 开辟一个新的串行任务队列
        dispatch_queue_t queue = dispatch_queue_create("ListenQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_async(queue, ^{
            
            self.flag = YES;
            // 监听8080端口
            [self listenPort:8080];
            // 阻塞此队列，直到客户端连接
            while (self.flag) {
                // 扫描客户端连接
                [self accept];
            }
        });
    } else {
        self.listenBtn.selected = NO;
        self.statusLabel.text = @"监听失败";
        shutdown(_clientSocket, SHUT_RDWR);
        shutdown(_serverSocket, SHUT_RDWR);
        close(_clientSocket);
        close(_serverSocket);
        self.flag = NO;
    }
}

- (void)listenPort:(int)port
{
    // 1.初始化服务端套接字
    _serverSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    // 2.如果返回值不为-1时，则初始化成功
    if (_serverSocket != -1)
    {
        // 3.结构体
        struct sockaddr_in addr;
        // 4.清零操作
        memset(&addr, 0, sizeof(addr));
        addr.sin_len=sizeof(addr);
        addr.sin_family=AF_INET;
        addr.sin_port=htons(port);
        addr.sin_addr.s_addr=INADDR_ANY;
        // 5.绑定地址和端口号
        int bindAddr = bind(_serverSocket, (const struct sockaddr *)&addr, sizeof(addr));
        // 6.如果bindAddr为0，说明绑定成功
        if (bindAddr == 0)
        {
            // 开始监听，5为等待连接数目
            int startListen = listen(_serverSocket, 5);
            if(startListen == 0)
            {
                // 回到主线程更新UI
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.statusLabel.text = @"监听成功";
                });
                
            }else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.statusLabel.text = @"监听失败";
                });
            }
        }
    }
}

- (void)accept
{
    // 1.承载客户端端口与IP信息的结构体
    struct sockaddr_in peeraddr;
    socklen_t addrLen;
    addrLen=sizeof(peeraddr);
    // 2.接受到客户端clientSocket连接,获取到地址和端口
    _clientSocket = accept(_serverSocket, (struct sockaddr *)&peeraddr, &addrLen);
    if (_clientSocket != -1)
    {
        // 3.回到主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.clientIPLabel.text = [NSString stringWithUTF8String:inet_ntoa(peeraddr.sin_addr)];
            self.clientPortLabel.text = [NSString stringWithFormat:@"%d",ntohs(peeraddr.sin_port)];
        });
        // 4.准备接收客户端socket消息
        char buf[1024];
        size_t len=sizeof(buf);
        // 5.接受到客户端消息
        recv(_clientSocket, buf, len, 0);
        NSString *msg = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
        // 6.主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            self.receiveMsgLabel.text = msg;
        });
    }
}


- (IBAction)sendBtnClick:(id)sender {
    
    NSString *msg = self.msgField.text;
    // 开启一个异步队列
    dispatch_queue_t sendMsgQueue =  dispatch_queue_create("SENDMSG", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(sendMsgQueue, ^{
        
        const char *str = msg.UTF8String;
        send(_clientSocket, str, strlen(str), 0);
        
        char *buf[1024];
        ssize_t recvLen = recv(_clientSocket, buf, sizeof(buf), 0);
        NSString *recvStr = [[NSString alloc] initWithBytes:buf length:recvLen encoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.receiveMsgLabel.text = recvStr;
        });
    });
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

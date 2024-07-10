# trojan

## zsh

```

sudo yum update -y && sudo yum install epel-release -y && yum install wget vim net-tools  zsh git screen zip aria2 unzip -y && echo "exec /bin/zsh" >> ~/.bashrc && sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)" -Y

```


## 替换本地zsh 历史

```

cd && sudo bash -c "curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/zsh/zsh_centos > .zsh_history"

```






## 安装nginx 和certbot

```

sudo yum install epel-release -y && sudo yum update -y && sudo yum install nginx certbot python3-certbot-nginx -y

```
### 修改nginx配置文件

```

vim  /etc/nginx/nginx.conf

```
### nginx 网页目录

```
/usr/share/nginx/html/index.html

```

### nginx 停止

```

nginx -s stop

```

### nginx 看看conf语法 
```

nginx -t

```
### nginx 启动

```

nginx

```
### nginx 平滑启动
```

nginx -s  reload


```

### 安装证书


```

certbot --register-unsafely-without-email --agree-tos  --nginx -d fk.cctvbh.com


```

### 查看证书
```

certbot certificates

```


## 安装Trojan

```

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"

```


```
cd /usr/local/etc/trojan

vim /usr/local/etc/trojan/config.json

```


- `certbot certificates` 查看证书路径

- 修改: `password`
- 修改: `cert`和`key`



- 设置开机启动：`systemctl enable trojan`，
- 并启动trojan：`systemctl start trojan`

- 检查trojan是否在运行：`ss -lp | grep trojan`

- `setenforce 0`关闭再启动 trojan



